defmodule Dicom.P10.Stream.Parser do
  @moduledoc """
  Streaming DICOM P10 state machine parser.

  Emits `Dicom.P10.Stream.Event` values as it traverses a DICOM P10 binary.
  Tracks state through phases: preamble -> file_meta -> data_set -> done.

  Handles sequences, items, and encapsulated pixel data via a nesting stack
  with `bytes_consumed_in_frame` tracking for defined-length containers.

  This module is not meant to be used directly. Use `Dicom.P10.Stream` instead.
  """

  alias Dicom.P10.Stream.Source
  alias Dicom.{DataElement, TransferSyntax, VR}

  @compile {:inline, read_tag: 2}

  @item_tag {0xFFFE, 0xE000}
  @item_delim_tag {0xFFFE, 0xE00D}
  @seq_delim_tag {0xFFFE, 0xE0DD}
  @trailing_padding_tag {0xFFFC, 0xFFFC}

  @type frame ::
          {:sequence, non_neg_integer() | :undefined, non_neg_integer()}
          | {:item, non_neg_integer() | :undefined, non_neg_integer()}
          | {:pixel_data, non_neg_integer()}

  @type state :: %{
          phase: :preamble | :file_meta | :data_set | :done,
          source: Source.t(),
          vr_encoding: :implicit | :explicit,
          endianness: :little | :big,
          transfer_syntax_uid: String.t() | nil,
          file_meta: %{Dicom.DataElement.tag() => DataElement.t()},
          stack: [frame()],
          pixel_fragment_index: non_neg_integer()
        }

  @doc """
  Creates a new parser state from a source.
  """
  @spec new(Source.t()) :: state()
  def new(source) do
    %{
      phase: :preamble,
      source: source,
      vr_encoding: :explicit,
      endianness: :little,
      transfer_syntax_uid: nil,
      file_meta: %{},
      stack: [],
      pixel_fragment_index: 0
    }
  end

  @doc """
  Advances the parser by one step, returning the next event and updated state.

  Returns `{event, state}` or `nil` when parsing is complete.
  """
  @spec next(state()) :: {Dicom.P10.Stream.Event.t(), state()} | nil
  def next(%{phase: :done}), do: nil

  def next(%{phase: :preamble} = state) do
    case Source.ensure(state.source, 132) do
      {:ok, source} ->
        case Source.peek(source, 132) do
          {:ok, <<_preamble::binary-size(128), "DICM", _::binary>>} ->
            {:ok, _, source} = Source.consume(source, 132)
            state = %{state | source: source, phase: :file_meta}
            {:file_meta_start, state}

          {:ok, _} ->
            {{:error, :invalid_preamble}, %{state | phase: :done}}
        end

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  def next(%{phase: :file_meta} = state) do
    case ensure_bytes(state, 4) do
      {:ok, state} ->
        case read_tag(state.source, :little) do
          {:ok, {group, _} = tag} when group == 0x0002 ->
            case read_element_explicit(state, tag, :little) do
              {:ok, element, state} ->
                file_meta = Map.put(state.file_meta, element.tag, element)
                state = %{state | file_meta: file_meta}
                {{:element, element}, state}

              {:error, reason} ->
                {{:error, reason}, %{state | phase: :done}}
            end

          {:ok, _non_meta_tag} ->
            transition_to_data_set(state)
        end

      {:error, _} ->
        transition_to_data_set(state)
    end
  end

  def next(%{phase: :data_set, stack: []} = state) do
    case ensure_bytes(state, 4) do
      {:ok, state} ->
        case check_trailing_padding(state) do
          :trailing_padding -> {:end, %{state | phase: :done}}
          :continue -> read_next_data_element(state)
        end

      {:error, :unexpected_end} ->
        {:end, %{state | phase: :done}}
    end
  end

  def next(%{phase: :data_set, stack: [{:sequence, :undefined, _} | _]} = state) do
    case ensure_bytes(state, 4) do
      {:ok, state} ->
        case read_tag(state.source, state.endianness) do
          {:ok, @seq_delim_tag} ->
            {:ok, _, source} = Source.consume(state.source, 8)
            state = %{state | source: source, stack: tl(state.stack)}
            {:sequence_end, state}

          {:ok, @item_tag} ->
            read_item_start(state)

          _ ->
            state = %{state | stack: tl(state.stack)}
            {:sequence_end, state}
        end

      {:error, :unexpected_end} ->
        state = %{state | stack: tl(state.stack)}
        {:sequence_end, state}
    end
  end

  def next(%{phase: :data_set, stack: [{:sequence, remaining, consumed} | rest]} = state)
      when is_integer(remaining) do
    if consumed >= remaining do
      state = %{state | stack: rest}
      {:sequence_end, state}
    else
      case ensure_bytes(state, 4) do
        {:ok, state} ->
          case read_tag(state.source, state.endianness) do
            {:ok, @item_tag} -> read_item_start(state)
            _ -> {:sequence_end, %{state | stack: rest}}
          end

        {:error, :unexpected_end} ->
          {:sequence_end, %{state | stack: rest}}
      end
    end
  end

  def next(%{phase: :data_set, stack: [{:item, :undefined, _} | _]} = state) do
    case ensure_bytes(state, 4) do
      {:ok, state} ->
        case read_tag(state.source, state.endianness) do
          {:ok, @item_delim_tag} ->
            {:ok, _, source} = Source.consume(state.source, 8)
            state = %{state | source: source, stack: tl(state.stack)}
            {:item_end, state}

          {:ok, @seq_delim_tag} ->
            state = %{state | stack: tl(state.stack)}
            {:item_end, state}

          {:ok, @trailing_padding_tag} ->
            skip_trailing_padding_in_item(state)

          _ ->
            read_next_data_element(state)
        end

      {:error, :unexpected_end} ->
        state = %{state | stack: tl(state.stack)}
        {:item_end, state}
    end
  end

  def next(%{phase: :data_set, stack: [{:item, remaining, consumed} | rest]} = state)
      when is_integer(remaining) do
    if consumed >= remaining do
      state = %{state | stack: rest}
      {:item_end, state}
    else
      case ensure_bytes(state, 4) do
        {:ok, state} -> read_next_data_element(state)
        {:error, :unexpected_end} -> {:item_end, %{state | stack: rest}}
      end
    end
  end

  def next(%{phase: :data_set, stack: [{:pixel_data, frag_index} | rest]} = state) do
    case ensure_bytes(state, 8) do
      {:ok, state} ->
        case read_tag(state.source, :little) do
          {:ok, @seq_delim_tag} ->
            {:ok, _, source} = Source.consume(state.source, 8)
            state = %{state | source: source, stack: rest, pixel_fragment_index: 0}
            {:pixel_data_end, state}

          {:ok, @item_tag} ->
            {:ok, _, source} = Source.consume(state.source, 4)
            state = %{state | source: source}

            case read_uint32(state, :little) do
              {:ok, length, state} ->
                case Source.ensure(state.source, length) do
                  {:ok, source} ->
                    {:ok, fragment, source} = Source.consume(source, length)

                    state = %{
                      state
                      | source: source,
                        stack: [{:pixel_data, frag_index + 1} | rest],
                        pixel_fragment_index: frag_index + 1
                    }

                    {{:pixel_data_fragment, frag_index, fragment}, state}

                  {:error, reason} ->
                    {{:error, reason}, %{state | phase: :done}}
                end
            end

          _ ->
            state = %{state | stack: rest, pixel_fragment_index: 0}
            {:pixel_data_end, state}
        end

      {:error, :unexpected_end} ->
        state = %{state | stack: rest, pixel_fragment_index: 0}
        {:pixel_data_end, state}
    end
  end

  # --- Private helpers ---

  defp transition_to_data_set(state) do
    ts_uid = TransferSyntax.extract_uid(state.file_meta)
    {:ok, {vr_encoding, endianness}} = TransferSyntax.encoding(ts_uid)

    # Handle deflated transfer syntax
    state =
      if ts_uid == Dicom.UID.deflated_explicit_vr_little_endian() do
        inflate_remaining(state)
      else
        state
      end

    state = %{
      state
      | phase: :data_set,
        transfer_syntax_uid: ts_uid,
        vr_encoding: vr_encoding,
        endianness: endianness
    }

    {{:file_meta_end, ts_uid}, state}
  end

  defp inflate_remaining(state) do
    # Collect all remaining bytes and inflate
    buffer = state.source.buffer

    if byte_size(buffer) > 0 do
      inflated = :zlib.uncompress(buffer)
      %{state | source: Source.from_binary(inflated)}
    else
      state
    end
  end

  defp check_trailing_padding(state) do
    case Source.peek(state.source, 4) do
      {:ok, <<0xFC, 0xFF, 0xFC, 0xFF>>} when state.endianness == :little -> :trailing_padding
      {:ok, <<0xFF, 0xFC, 0xFF, 0xFC>>} when state.endianness == :big -> :trailing_padding
      _ -> :continue
    end
  end

  defp read_next_data_element(state) do
    {:ok, tag} = read_tag(state.source, state.endianness)

    case tag do
      @trailing_padding_tag ->
        {:end, %{state | phase: :done}}

      tag ->
        case state.vr_encoding do
          :explicit -> read_element_dispatch_explicit(state, tag, state.endianness)
          :implicit -> read_element_implicit(state, tag)
        end
    end
  end

  defp read_element_explicit(state, tag, endianness) do
    source = state.source
    {:ok, _, source} = Source.consume(source, 4)
    state = %{state | source: source}

    case ensure_bytes(state, 2) do
      {:ok, state} ->
        {:ok, vr_bytes, source} = Source.consume(state.source, 2)
        state = %{state | source: source}

        case VR.from_binary(vr_bytes) do
          {:ok, :SQ} ->
            read_sequence_header(state, tag, endianness)

          {:ok, vr} ->
            if VR.long_length?(vr) do
              read_long_value(state, tag, vr, endianness)
            else
              read_short_value(state, tag, vr, endianness)
            end

          {:error, :unknown_vr} ->
            read_short_value(state, tag, :UN, endianness)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_element_dispatch_explicit(state, tag, endianness) do
    source = state.source
    {:ok, _, source} = Source.consume(source, 4)
    state = %{state | source: source}

    case ensure_bytes(state, 2) do
      {:ok, state} ->
        {:ok, vr_bytes, source} = Source.consume(state.source, 2)
        state = %{state | source: source}

        case VR.from_binary(vr_bytes) do
          {:ok, :SQ} ->
            emit_sequence_start(state, tag, endianness)

          {:ok, vr} ->
            if VR.long_length?(vr) do
              check_encapsulated_pixel_data(state, tag, vr, endianness)
            else
              read_short_value_emit(state, tag, vr, endianness)
            end

          {:error, :unknown_vr} ->
            read_short_value_emit(state, tag, :UN, endianness)
        end

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  defp read_element_implicit(state, tag) do
    source = state.source
    {:ok, _, source} = Source.consume(source, 4)
    state = %{state | source: source}

    vr = lookup_implicit_vr(tag)

    case read_uint32(state, :little) do
      {:ok, raw_length, state} ->
        if vr == :SQ do
          length = if raw_length == 0xFFFFFFFF, do: :undefined, else: raw_length
          state = push_frame(state, {:sequence, length, 0})
          {{:sequence_start, tag, length}, state}
        else
          read_value_by_length(state, tag, vr, raw_length)
        end

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  defp emit_sequence_start(state, tag, endianness) do
    case read_reserved_and_length(state, endianness) do
      {:ok, raw_length, state} ->
        length = if raw_length == 0xFFFFFFFF, do: :undefined, else: raw_length
        state = push_frame(state, {:sequence, length, 0})
        {{:sequence_start, tag, length}, state}

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  defp check_encapsulated_pixel_data(state, tag, vr, endianness) do
    case read_reserved_and_length(state, endianness) do
      {:ok, 0xFFFFFFFF, state} when tag == {0x7FE0, 0x0010} ->
        state = push_frame(state, {:pixel_data, 0})
        {{:pixel_data_start, tag, vr}, state}

      {:ok, length, state} ->
        read_value_by_length(state, tag, vr, length)

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  defp read_short_value_emit(state, tag, vr, endianness) do
    case read_short_length(state, endianness) do
      {:ok, length, state} ->
        read_value_by_length(state, tag, vr, length)

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  defp read_sequence_header(state, tag, endianness) do
    case read_reserved_and_length(state, endianness) do
      {:ok, raw_length, state} ->
        length = if raw_length == 0xFFFFFFFF, do: :undefined, else: raw_length

        case read_sequence_items_eager(state, length) do
          {:ok, items, state} ->
            {:ok, DataElement.new(tag, :SQ, items), state}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_sequence_items_eager(state, :undefined) do
    read_items_until_delimiter_eager(state, [])
  end

  defp read_sequence_items_eager(state, 0) do
    {:ok, [], state}
  end

  defp read_sequence_items_eager(state, length) when is_integer(length) do
    start_offset = Source.bytes_consumed(state.source)
    read_items_bounded_eager(state, start_offset, length, [])
  end

  defp read_items_until_delimiter_eager(state, acc) do
    case ensure_bytes(state, 8) do
      {:ok, state} ->
        case read_tag(state.source, state.endianness) do
          {:ok, @seq_delim_tag} ->
            {:ok, _, source} = Source.consume(state.source, 8)
            {:ok, Enum.reverse(acc), %{state | source: source}}

          {:ok, @item_tag} ->
            case read_item_eager(state) do
              {:ok, item, state} ->
                read_items_until_delimiter_eager(state, [item | acc])

              {:error, _} = error ->
                error
            end

          _ ->
            {:ok, Enum.reverse(acc), state}
        end

      {:error, :unexpected_end} ->
        {:ok, Enum.reverse(acc), state}
    end
  end

  defp read_items_bounded_eager(state, start_offset, length, acc) do
    consumed = Source.bytes_consumed(state.source) - start_offset

    if consumed >= length do
      {:ok, Enum.reverse(acc), state}
    else
      case ensure_bytes(state, 8) do
        {:ok, state} ->
          case read_item_eager(state) do
            {:ok, item, state} ->
              read_items_bounded_eager(state, start_offset, length, [item | acc])

            {:error, _} = error ->
              error
          end

        {:error, :unexpected_end} ->
          {:ok, Enum.reverse(acc), state}
      end
    end
  end

  defp read_item_eager(state) do
    {:ok, _, source} = Source.consume(state.source, 4)
    state = %{state | source: source}

    case read_uint32(state, state.endianness) do
      {:ok, 0xFFFFFFFF, state} ->
        read_item_elements_until_delimiter_eager(state, %{})

      {:ok, length, state} ->
        start_offset = Source.bytes_consumed(state.source)
        read_item_elements_bounded_eager(state, start_offset, length, %{})

      {:error, _} = error ->
        error
    end
  end

  defp read_item_elements_until_delimiter_eager(state, acc) do
    case ensure_bytes(state, 4) do
      {:ok, state} ->
        case read_tag(state.source, state.endianness) do
          {:ok, @item_delim_tag} ->
            {:ok, _, source} = Source.consume(state.source, 8)
            {:ok, acc, %{state | source: source}}

          {:ok, @seq_delim_tag} ->
            {:ok, acc, state}

          {:ok, tag} ->
            case read_single_element(state, tag) do
              {:ok, element, state} ->
                read_item_elements_until_delimiter_eager(
                  state,
                  Map.put(acc, element.tag, element)
                )

              {:error, _} = error ->
                error
            end
        end

      {:error, :unexpected_end} ->
        {:ok, acc, state}
    end
  end

  defp read_item_elements_bounded_eager(state, start_offset, length, acc) do
    consumed = Source.bytes_consumed(state.source) - start_offset

    if consumed >= length do
      {:ok, acc, state}
    else
      case ensure_bytes(state, 4) do
        {:ok, state} ->
          {:ok, tag} = read_tag(state.source, state.endianness)

          case read_single_element(state, tag) do
            {:ok, element, state} ->
              read_item_elements_bounded_eager(
                state,
                start_offset,
                length,
                Map.put(acc, element.tag, element)
              )

            {:error, _} = error ->
              error
          end

        {:error, :unexpected_end} ->
          {:ok, acc, state}
      end
    end
  end

  defp read_single_element(state, tag) do
    case state.vr_encoding do
      :explicit ->
        read_element_explicit(state, tag, state.endianness)

      :implicit ->
        {:ok, _, source} = Source.consume(state.source, 4)
        state = %{state | source: source}
        vr = lookup_implicit_vr(tag)

        case read_uint32(state, :little) do
          {:ok, raw_length, state} ->
            if vr == :SQ do
              length = if raw_length == 0xFFFFFFFF, do: :undefined, else: raw_length

              case read_sequence_items_eager(state, length) do
                {:ok, items, state} -> {:ok, DataElement.new(tag, :SQ, items), state}
                {:error, _} = error -> error
              end
            else
              read_value_for_element(state, tag, vr, raw_length)
            end

          {:error, _} = error ->
            error
        end
    end
  end

  defp read_value_for_element(state, tag, vr, 0xFFFFFFFF)
       when tag == {0x7FE0, 0x0010} do
    # Encapsulated pixel data in file meta context
    read_encapsulated_fragments_eager(state, tag, vr)
  end

  defp read_value_for_element(state, tag, vr, length) do
    case Source.ensure(state.source, length) do
      {:ok, source} ->
        {:ok, value, source} = Source.consume(source, length)
        state = %{state | source: source}
        {:ok, DataElement.new(tag, vr, value), state}

      {:error, _} = error ->
        error
    end
  end

  defp read_encapsulated_fragments_eager(state, tag, vr) do
    case read_fragments_eager(state, []) do
      {:ok, fragments, state} ->
        {:ok, DataElement.new(tag, vr, {:encapsulated, fragments}), state}

      {:error, _} = error ->
        error
    end
  end

  defp read_fragments_eager(state, acc) do
    case ensure_bytes(state, 8) do
      {:ok, state} ->
        case read_tag(state.source, :little) do
          {:ok, @seq_delim_tag} ->
            {:ok, _, source} = Source.consume(state.source, 8)
            {:ok, Enum.reverse(acc), %{state | source: source}}

          {:ok, @item_tag} ->
            {:ok, _, source} = Source.consume(state.source, 4)
            state = %{state | source: source}

            {:ok, length, state} = read_uint32(state, :little)

            case Source.ensure(state.source, length) do
              {:ok, source} ->
                {:ok, fragment, source} = Source.consume(source, length)
                read_fragments_eager(%{state | source: source}, [fragment | acc])

              {:error, _} = error ->
                error
            end

          _ ->
            {:ok, Enum.reverse(acc), state}
        end

      {:error, :unexpected_end} ->
        {:ok, Enum.reverse(acc), state}
    end
  end

  defp read_item_start(state) do
    {:ok, _, source} = Source.consume(state.source, 4)
    state = %{state | source: source}

    case read_uint32(state, state.endianness) do
      {:ok, raw_length, state} ->
        length = if raw_length == 0xFFFFFFFF, do: :undefined, else: raw_length
        state = push_frame(state, {:item, length, 0})
        {{:item_start, length}, state}

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  defp skip_trailing_padding_in_item(state) do
    # Read the trailing padding element and discard it, then continue
    case read_single_element(state, @trailing_padding_tag) do
      {:ok, _padding, state} -> next(state)
      {:error, _} -> {:item_end, %{state | stack: tl(state.stack)}}
    end
  end

  defp read_value_by_length(state, tag, _vr, length) when length == 0xFFFFFFFF do
    # Undefined length non-SQ, non-pixel-data: skip to sequence delimiter
    {{:error, {:unsupported_undefined_length, tag}}, %{state | phase: :done}}
  end

  defp read_value_by_length(state, tag, vr, length) do
    case Source.ensure(state.source, length) do
      {:ok, source} ->
        {:ok, value, source} = Source.consume(source, length)
        state = update_frame_consumed(state, 6 + header_size(vr, state.vr_encoding) + length)
        state = %{state | source: source}
        {{:element, DataElement.new(tag, vr, value)}, state}

      {:error, reason} ->
        {{:error, reason}, %{state | phase: :done}}
    end
  end

  defp header_size(_vr, :implicit), do: 2
  defp header_size(vr, :explicit), do: if(VR.long_length?(vr), do: 6, else: 2)

  defp read_short_value(state, tag, vr, endianness) do
    case read_short_length(state, endianness) do
      {:ok, length, state} ->
        case Source.ensure(state.source, length) do
          {:ok, source} ->
            {:ok, value, source} = Source.consume(source, length)
            {:ok, DataElement.new(tag, vr, value), %{state | source: source}}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  defp read_long_value(state, tag, vr, endianness) do
    case read_reserved_and_length(state, endianness) do
      {:ok, 0xFFFFFFFF, state} when tag == {0x7FE0, 0x0010} ->
        read_encapsulated_fragments_eager(state, tag, vr)

      {:ok, length, state} ->
        case Source.ensure(state.source, length) do
          {:ok, source} ->
            {:ok, value, source} = Source.consume(source, length)
            {:ok, DataElement.new(tag, vr, value), %{state | source: source}}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  defp read_reserved_and_length(state, endianness) do
    case ensure_bytes(state, 6) do
      {:ok, state} ->
        {:ok, _, source} = Source.consume(state.source, 2)
        state = %{state | source: source}
        read_uint32(state, endianness)

      {:error, _} = error ->
        error
    end
  end

  defp read_short_length(state, :little) do
    case ensure_bytes(state, 2) do
      {:ok, state} ->
        {:ok, <<length::little-16>>, source} = Source.consume(state.source, 2)
        {:ok, length, %{state | source: source}}

      {:error, _} = error ->
        error
    end
  end

  defp read_short_length(state, :big) do
    case ensure_bytes(state, 2) do
      {:ok, state} ->
        {:ok, <<length::big-16>>, source} = Source.consume(state.source, 2)
        {:ok, length, %{state | source: source}}

      {:error, _} = error ->
        error
    end
  end

  defp read_uint32(state, endianness) do
    case ensure_bytes(state, 4) do
      {:ok, state} ->
        {:ok, data, source} = Source.consume(state.source, 4)
        state = %{state | source: source}

        value =
          case endianness do
            :little -> :binary.decode_unsigned(data, :little)
            :big -> :binary.decode_unsigned(data, :big)
          end

        {:ok, value, state}

      {:error, _} = error ->
        error
    end
  end

  defp read_tag(source, :little) do
    {:ok, <<group::little-16, element::little-16>>} = Source.peek(source, 4)
    {:ok, {group, element}}
  end

  defp read_tag(source, :big) do
    {:ok, <<group::big-16, element::big-16>>} = Source.peek(source, 4)
    {:ok, {group, element}}
  end

  defp ensure_bytes(state, n) do
    case Source.ensure(state.source, n) do
      {:ok, source} -> {:ok, %{state | source: source}}
      {:error, _} = error -> error
    end
  end

  defp push_frame(state, frame) do
    %{state | stack: [frame | state.stack]}
  end

  defp update_frame_consumed(state, bytes) do
    case state.stack do
      [{type, length, consumed} | rest] when type in [:sequence, :item] ->
        %{state | stack: [{type, length, consumed + bytes} | rest]}

      _ ->
        state
    end
  end

  defp lookup_implicit_vr(tag) do
    case Dicom.Dictionary.Registry.lookup(tag) do
      {:ok, _name, vr, _vm} -> vr
      :error -> :UN
    end
  end
end
