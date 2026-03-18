defmodule Dicom.P10.Reader do
  @moduledoc """
  DICOM P10 file reader.

  Parses a binary DICOM P10 stream into a `Dicom.DataSet`. Handles the
  preamble, File Meta Information, and the main data set with support
  for Implicit VR Little Endian, Explicit VR Little Endian, and
  Explicit VR Big Endian (retired) transfer syntaxes.

  Supports:
  - Sequences (SQ) with defined and undefined length
  - Items with defined and undefined length
  - Encapsulated pixel data with Basic Offset Table and fragments
  - Data Set Trailing Padding (FFFC,FFFC)

  Reference: DICOM PS3.10 Section 7, PS3.5 Sections 7.1, 7.5, A.4.
  """

  alias Dicom.{DataElement, DataSet, TransferSyntax, VR}
  alias Dicom.P10.Deflated

  @compile {:inline, peek_tag: 2, lookup_implicit_vr: 1}

  # Raw byte patterns for hot-path trailing padding check (avoids peek_tag + tuple allocation)
  @trailing_padding_bytes_le <<0xFC, 0xFF, 0xFC, 0xFF>>
  @trailing_padding_bytes_be <<0xFF, 0xFC, 0xFF, 0xFC>>

  @item_tag {0xFFFE, 0xE000}
  @item_delim_tag {0xFFFE, 0xE00D}
  @seq_delim_tag {0xFFFE, 0xE0DD}
  @trailing_padding_tag {0xFFFC, 0xFFFC}
  @seq_delim_bytes <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

  @doc """
  Parses a complete DICOM P10 binary into a `DataSet`.
  """
  @spec parse(binary()) :: {:ok, DataSet.t()} | {:error, term()}
  def parse(binary) when is_binary(binary) do
    with {:ok, rest} <- Dicom.P10.FileMeta.skip_preamble(binary),
         {:ok, file_meta, rest} <- read_file_meta(rest),
         transfer_syntax_uid = TransferSyntax.extract_uid(file_meta),
         {:ok, elements} <- read_data_set(rest, transfer_syntax_uid) do
      {:ok, %DataSet{file_meta: file_meta, elements: elements}}
    end
  end

  # File Meta Information is always Explicit VR Little Endian.
  # Group 0002 elements end when we hit a non-0002 group.
  defp read_file_meta(binary) do
    read_elements_while(binary, :explicit, :little, fn {group, _} -> group == 0x0002 end, %{})
  end

  defp read_data_set(binary, transfer_syntax_uid) do
    with {:ok, {vr_encoding, endianness}} <- TransferSyntax.encoding(transfer_syntax_uid) do
      # Inflate if Deflated Explicit VR Little Endian (PS3.5 Section 10)
      case inflate_if_needed(binary, transfer_syntax_uid) do
        {:ok, data} -> read_all_elements(data, vr_encoding, endianness, [])
        {:error, _} = error -> error
      end
    end
  end

  defp inflate_if_needed(binary, transfer_syntax_uid) do
    if transfer_syntax_uid == Dicom.UID.deflated_explicit_vr_little_endian() do
      Deflated.decompress(binary)
    else
      {:ok, binary}
    end
  end

  defp read_elements_while(<<>>, _vr_enc, _endian, _pred, acc) do
    {:ok, acc, <<>>}
  end

  defp read_elements_while(binary, vr_enc, endian, pred, acc) do
    case peek_tag(binary, endian) do
      {:ok, tag} ->
        if pred.(tag) do
          case read_element(binary, vr_enc, endian) do
            {:ok, element, rest} ->
              read_elements_while(rest, vr_enc, endian, pred, Map.put(acc, element.tag, element))

            {:error, _} = error ->
              error
          end
        else
          {:ok, acc, binary}
        end

      {:error, _} = error ->
        error
    end
  end

  # List accumulator: collect {tag, element} pairs, convert to map once at the end.
  # Avoids N intermediate map allocations from per-element Map.put.
  defp read_all_elements(<<>>, _vr_enc, _endian, acc), do: {:ok, Map.new(acc)}

  defp read_all_elements(binary, _vr_enc, _endian, acc) when byte_size(binary) < 4 do
    {:ok, Map.new(acc)}
  end

  # Stop at trailing padding — direct binary check avoids peek_tag + tuple allocation
  defp read_all_elements(<<@trailing_padding_bytes_le, _::binary>>, _vr_enc, :little, acc) do
    {:ok, Map.new(acc)}
  end

  defp read_all_elements(<<@trailing_padding_bytes_be, _::binary>>, _vr_enc, :big, acc) do
    {:ok, Map.new(acc)}
  end

  defp read_all_elements(binary, vr_enc, endian, acc) do
    case read_element(binary, vr_enc, endian) do
      {:ok, element, rest} ->
        read_all_elements(rest, vr_enc, endian, [{element.tag, element} | acc])

      {:error, _} = error ->
        error
    end
  end

  defp peek_tag(<<group::little-16, element::little-16, _rest::binary>>, :little) do
    {:ok, {group, element}}
  end

  defp peek_tag(<<group::big-16, element::big-16, _rest::binary>>, :big) do
    {:ok, {group, element}}
  end

  defp peek_tag(_, _), do: {:error, :unexpected_end}

  # Explicit VR Little Endian
  defp read_element(
         <<group::little-16, element::little-16, vr_bytes::binary-size(2), rest::binary>>,
         :explicit,
         :little
       ) do
    dispatch_explicit_vr(rest, {group, element}, vr_bytes, :little)
  end

  # Explicit VR Big Endian (Retired)
  defp read_element(
         <<group::big-16, element::big-16, vr_bytes::binary-size(2), rest::binary>>,
         :explicit,
         :big
       ) do
    dispatch_explicit_vr(rest, {group, element}, vr_bytes, :big)
  end

  # Implicit VR Little Endian
  defp read_element(
         <<group::little-16, element::little-16, length::little-32, rest::binary>>,
         :implicit,
         :little
       ) do
    tag = {group, element}
    vr = lookup_implicit_vr(tag)

    if vr == :SQ do
      read_sequence_items(rest, length, :implicit, :little)
      |> wrap_sequence(tag)
    else
      read_value_by_length(rest, tag, vr, length)
    end
  end

  defp read_element(_, _, _), do: {:error, :unexpected_end}

  defp dispatch_explicit_vr(rest, tag, vr_bytes, endian) do
    case VR.from_binary(vr_bytes) do
      {:ok, :SQ} ->
        read_sequence_value(rest, tag, :explicit, endian)

      {:ok, vr} ->
        if VR.long_length?(vr) do
          read_long_value(rest, tag, vr, :explicit, endian)
        else
          read_short_value(rest, tag, vr, endian)
        end

      {:error, :unknown_vr} ->
        read_short_value(rest, tag, :UN, endian)
    end
  end

  # Short value: 2-byte length (Explicit VR, non-long VRs)
  defp read_short_value(<<length::little-16, rest::binary>>, tag, vr, :little) do
    read_value_by_length(rest, tag, vr, length)
  end

  defp read_short_value(<<length::big-16, rest::binary>>, tag, vr, :big) do
    read_value_by_length(rest, tag, vr, length)
  end

  defp read_short_value(_, _, _, _), do: {:error, :unexpected_end}

  # Long value: 2 reserved bytes + 4-byte length
  # For non-SQ long VRs (OB, OW, etc.), check for encapsulated pixel data
  defp read_long_value(
         <<_reserved::16, 0xFFFFFFFF::little-32, rest::binary>>,
         tag,
         vr,
         :explicit,
         :little
       )
       when tag == {0x7FE0, 0x0010} do
    # Encapsulated pixel data
    read_encapsulated_pixel_data(rest, tag, vr)
  end

  defp read_long_value(binary, tag, vr, _vr_enc, endian) do
    case read_reserved_and_length(binary, endian) do
      {:ok, length, rest} -> read_value_by_length(rest, tag, vr, length)
      :error -> {:error, :unexpected_end}
    end
  end

  # Sequence reading (Explicit VR) — length encoding follows transfer syntax endianness
  defp read_sequence_value(binary, tag, vr_enc, endian) do
    case read_reserved_and_length(binary, endian) do
      {:ok, raw_length, rest} ->
        length = if raw_length == 0xFFFFFFFF, do: :undefined, else: raw_length

        read_sequence_items(rest, length, vr_enc, endian)
        |> wrap_sequence(tag)

      :error ->
        {:error, :unexpected_end}
    end
  end

  defp read_reserved_and_length(<<_reserved::16, length::little-32, rest::binary>>, :little) do
    {:ok, length, rest}
  end

  defp read_reserved_and_length(<<_reserved::16, length::big-32, rest::binary>>, :big) do
    {:ok, length, rest}
  end

  defp read_reserved_and_length(_, _), do: :error

  # Read items from a sequence
  defp read_sequence_items(binary, 0, _vr_enc, _endian) do
    {:ok, [], binary}
  end

  defp read_sequence_items(binary, :undefined, vr_enc, endian) do
    read_items_until_delimiter(binary, vr_enc, endian, [])
  end

  defp read_sequence_items(binary, length, vr_enc, endian)
       when is_integer(length) and byte_size(binary) >= length do
    <<seq_data::binary-size(length), rest::binary>> = binary

    case read_items_from_binary(seq_data, vr_enc, endian, []) do
      {:ok, items, _remaining} -> {:ok, items, rest}
      {:error, _} = error -> error
    end
  end

  defp read_sequence_items(_binary, length, _vr_enc, _endian) when is_integer(length) do
    {:error, :unexpected_end}
  end

  # Read items until we hit a sequence delimiter
  defp read_items_until_delimiter(binary, _vr_enc, _endian, acc) when byte_size(binary) < 8 do
    {:ok, Enum.reverse(acc), binary}
  end

  defp read_items_until_delimiter(binary, vr_enc, endian, acc) do
    case peek_tag(binary, endian) do
      {:ok, @seq_delim_tag} ->
        # Skip the sequence delimiter (tag + length = 8 bytes)
        <<_tag::32, _length::32, rest::binary>> = binary
        {:ok, Enum.reverse(acc), rest}

      {:ok, @item_tag} ->
        case read_item(binary, vr_enc, endian) do
          {:ok, item_elements, rest} ->
            read_items_until_delimiter(rest, vr_enc, endian, [item_elements | acc])

          {:error, _} = error ->
            error
        end

      _ ->
        {:ok, Enum.reverse(acc), binary}
    end
  end

  # Read items from a bounded binary (defined-length sequence)
  defp read_items_from_binary(<<>>, _vr_enc, _endian, acc) do
    {:ok, Enum.reverse(acc), <<>>}
  end

  defp read_items_from_binary(binary, _vr_enc, _endian, acc) when byte_size(binary) < 8 do
    {:ok, Enum.reverse(acc), binary}
  end

  defp read_items_from_binary(binary, vr_enc, endian, acc) do
    case read_item(binary, vr_enc, endian) do
      {:ok, item_elements, rest} ->
        read_items_from_binary(rest, vr_enc, endian, [item_elements | acc])

      {:error, _} = error ->
        error
    end
  end

  # Read a single item — item tags follow transfer syntax byte ordering (PS3.5 7.5)
  defp read_item(binary, vr_enc, endian) do
    case read_item_tag_and_length(binary, endian) do
      {:ok, 0xFFFFFFFF, rest} ->
        read_item_elements_until_delimiter(rest, vr_enc, endian, %{})

      {:ok, length, rest} ->
        if byte_size(rest) >= length do
          <<item_data::binary-size(length), remaining::binary>> = rest

          case read_all_elements(item_data, vr_enc, endian, []) do
            {:ok, elements} -> {:ok, elements, remaining}
            {:error, _} = error -> error
          end
        else
          {:error, :unexpected_end}
        end

      :error ->
        {:error, :unexpected_end}
    end
  end

  defp read_item_tag_and_length(
         <<0xFE, 0xFF, 0x00, 0xE0, length::little-32, rest::binary>>,
         :little
       ) do
    {:ok, length, rest}
  end

  defp read_item_tag_and_length(
         <<0xFF, 0xFE, 0xE0, 0x00, length::big-32, rest::binary>>,
         :big
       ) do
    {:ok, length, rest}
  end

  defp read_item_tag_and_length(_, _), do: :error

  # Read elements until item delimiter
  defp read_item_elements_until_delimiter(binary, _vr_enc, _endian, acc)
       when byte_size(binary) < 4 do
    {:ok, acc, binary}
  end

  defp read_item_elements_until_delimiter(binary, vr_enc, endian, acc) do
    case peek_tag(binary, endian) do
      {:ok, @item_delim_tag} ->
        <<_tag::32, _length::32, rest::binary>> = binary
        {:ok, acc, rest}

      {:ok, @seq_delim_tag} ->
        # Shouldn't happen inside an item, but be defensive
        {:ok, acc, binary}

      {:ok, @trailing_padding_tag} ->
        # Skip trailing padding, then look for delimiter
        case read_element(binary, vr_enc, endian) do
          {:ok, _padding, rest} -> read_item_elements_until_delimiter(rest, vr_enc, endian, acc)
          {:error, _} -> {:ok, acc, binary}
        end

      _ ->
        case read_element(binary, vr_enc, endian) do
          {:ok, element, rest} ->
            read_item_elements_until_delimiter(
              rest,
              vr_enc,
              endian,
              Map.put(acc, element.tag, element)
            )

          {:error, _} = error ->
            error
        end
    end
  end

  # Encapsulated pixel data: OB with undefined length containing items
  defp read_encapsulated_pixel_data(binary, tag, vr) do
    case read_encapsulated_fragments(binary, []) do
      {:ok, fragments, rest} ->
        {:ok, DataElement.new(tag, vr, {:encapsulated, fragments}), rest}

      {:error, _} = error ->
        error
    end
  end

  defp read_encapsulated_fragments(binary, _acc) when byte_size(binary) < 8 do
    {:error, :unexpected_end}
  end

  defp read_encapsulated_fragments(binary, acc) do
    case peek_tag(binary, :little) do
      {:ok, @seq_delim_tag} ->
        <<_tag::32, _length::32, rest::binary>> = binary
        {:ok, Enum.reverse(acc), rest}

      {:ok, @item_tag} ->
        <<_tag::32, length::little-32, rest::binary>> = binary

        if byte_size(rest) >= length do
          <<fragment::binary-size(length), remaining::binary>> = rest
          read_encapsulated_fragments(remaining, [fragment | acc])
        else
          {:error, :unexpected_end}
        end

      _ ->
        {:error, :invalid_encapsulated_pixel_data}
    end
  end

  defp wrap_sequence({:ok, items, rest}, tag) do
    {:ok, DataElement.new(tag, :SQ, items), rest}
  end

  defp wrap_sequence({:error, _} = error, _tag), do: error

  # Value reading
  defp read_value_by_length(rest, tag, vr, 0xFFFFFFFF) do
    # Undefined length for non-SQ, non-pixel-data: read until sequence delimiter
    # This handles cases like UN with undefined length
    read_until_seq_delimiter(rest, tag, vr)
  end

  defp read_value_by_length(binary, tag, vr, length) when byte_size(binary) >= length do
    <<value::binary-size(length), rest::binary>> = binary
    {:ok, DataElement.new(tag, vr, value), rest}
  end

  defp read_value_by_length(_, _, _, _), do: {:error, :unexpected_end}

  defp read_until_seq_delimiter(binary, tag, vr) do
    # Search for sequence delimiter tag
    case find_seq_delimiter(binary, 0) do
      {:ok, offset} ->
        <<value::binary-size(offset), _delim_tag::32, _delim_length::32, rest::binary>> = binary
        {:ok, DataElement.new(tag, vr, value), rest}

      :error ->
        {:error, :unexpected_end}
    end
  end

  defp find_seq_delimiter(binary, offset) when offset + 8 <= byte_size(binary) do
    case binary_part(binary, offset, 8) do
      @seq_delim_bytes -> {:ok, offset}
      _ -> find_seq_delimiter(binary, offset + 1)
    end
  end

  defp find_seq_delimiter(_, _), do: :error

  defp lookup_implicit_vr(tag) do
    case Dicom.Dictionary.Registry.lookup(tag) do
      {:ok, _name, vr, _vm} -> vr
      :error -> :UN
    end
  end
end
