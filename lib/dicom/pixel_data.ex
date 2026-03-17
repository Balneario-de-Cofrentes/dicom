defmodule Dicom.PixelData do
  @moduledoc """
  Pixel data frame extraction from DICOM data sets.

  Supports both native (uncompressed) and encapsulated (compressed)
  pixel data. For encapsulated data, handles Basic Offset Table (BOT)
  and the fragment-per-frame convention.

  Reference: DICOM PS3.5 Section A.4.
  """

  alias Dicom.{DataSet, DataElement, Tag, Value}

  @doc """
  Returns true if the pixel data is encapsulated (fragment-based).

  Encapsulated pixel data is stored as a list of fragments (first element
  is the Basic Offset Table, remaining elements are data fragments).
  """
  @spec encapsulated?(DataSet.t()) :: boolean()
  def encapsulated?(%DataSet{} = ds) do
    case get_pixel_element(ds) do
      %DataElement{value: fragments} when is_list(fragments) -> true
      %DataElement{value: {:encapsulated, fragments}} when is_list(fragments) -> true
      _ -> false
    end
  end

  @doc """
  Returns the number of frames in the pixel data.
  """
  @spec frame_count(DataSet.t()) ::
          {:ok, pos_integer()} | {:error, :no_pixel_data | :invalid_number_of_frames}
  def frame_count(%DataSet{} = ds) do
    case get_pixel_element(ds) do
      nil ->
        {:error, :no_pixel_data}

      _elem ->
        get_number_of_frames(ds)
    end
  end

  @doc """
  Extracts all frames from pixel data.

  For native pixel data, computes frame size from image dimensions and
  slices the pixel data binary.

  For encapsulated pixel data:
  - If BOT is present, uses offsets to group fragments per frame
  - If no BOT and single frame, concatenates all fragments
  - If no BOT and multi-frame, each fragment is one frame
  """
  @spec frames(DataSet.t()) :: {:ok, [binary()]} | {:error, term()}
  def frames(%DataSet{} = ds) do
    case get_pixel_element(ds) do
      nil ->
        {:error, :no_pixel_data}

      %DataElement{value: fragments} when is_list(fragments) ->
        extract_encapsulated_frames(fragments, ds)

      %DataElement{value: {:encapsulated, fragments}} when is_list(fragments) ->
        extract_encapsulated_frames(fragments, ds)

      %DataElement{value: data} when is_binary(data) ->
        extract_native_frames(data, ds)
    end
  end

  @doc """
  Extracts a single frame by zero-based index.

  For native pixel data, uses zero-copy `binary_part/3` without extracting all frames.
  """
  @spec frame(DataSet.t(), non_neg_integer()) :: {:ok, binary()} | {:error, term()}
  def frame(%DataSet{} = ds, index) when is_integer(index) and index >= 0 do
    case get_pixel_element(ds) do
      nil ->
        {:error, :no_pixel_data}

      %DataElement{value: data} when is_binary(data) ->
        extract_native_frame(data, ds, index)

      %DataElement{value: fragments} when is_list(fragments) ->
        extract_encapsulated_frame(fragments, ds, index)

      %DataElement{value: {:encapsulated, fragments}} when is_list(fragments) ->
        extract_encapsulated_frame(fragments, ds, index)
    end
  end

  def frame(_ds, _index), do: {:error, :frame_index_out_of_range}

  @doc false
  @spec validate_basic_offset_table(binary(), [binary()]) ::
          :ok | {:error, :invalid_basic_offset_table}
  def validate_basic_offset_table(bot, fragments) when is_binary(bot) and is_list(fragments) do
    with {:ok, offsets} <- parse_bot(bot) do
      validate_bot_offsets(offsets, fragments)
    end
  end

  # ── Native frame extraction ───────────────────────────────────

  defp extract_native_frame(data, ds, index) do
    with {:ok, num_frames} <- get_number_of_frames(ds),
         {:ok, frame_size} <- compute_frame_size(ds) do
      cond do
        index >= num_frames ->
          {:error, :frame_index_out_of_range}

        frame_size > 0 ->
          offset = index * frame_size

          if byte_size(data) >= offset + frame_size do
            {:ok, binary_part(data, offset, frame_size)}
          else
            {:error, :invalid_pixel_data}
          end

        index == 0 ->
          {:ok, data}

        true ->
          {:error, :frame_index_out_of_range}
      end
    end
  end

  defp extract_native_frames(data, ds) do
    with {:ok, num_frames} <- get_number_of_frames(ds),
         {:ok, frame_size} <- compute_frame_size(ds) do
      if frame_size > 0 do
        total_size = frame_size * num_frames

        if byte_size(data) >= total_size do
          frames =
            for i <- 0..(num_frames - 1) do
              binary_part(data, i * frame_size, frame_size)
            end

          {:ok, frames}
        else
          {:error, :invalid_pixel_data}
        end
      else
        {:ok, [data]}
      end
    end
  end

  defp compute_frame_size(ds) do
    with {:ok, rows} <- decode_us(ds, Tag.rows(), 0),
         {:ok, cols} <- decode_us(ds, Tag.columns(), 0),
         {:ok, bits} <- decode_us(ds, Tag.bits_allocated(), 16),
         {:ok, samples} <- decode_us(ds, Tag.samples_per_pixel(), 1) do
      {:ok, ceil_div(rows * cols * bits * samples, 8)}
    end
  end

  # ── Encapsulated frame extraction ─────────────────────────────

  defp extract_encapsulated_frames([bot | fragments], ds) do
    with {:ok, num_frames} <- get_number_of_frames(ds),
         {:ok, bot_offsets} <- parse_bot(bot) do
      cond do
        bot_offsets != [] and length(bot_offsets) != num_frames ->
          {:error, :invalid_basic_offset_table}

        bot_offsets != [] ->
          group_fragments_by_bot(bot_offsets, fragments)

        num_frames == 1 ->
          {:ok, [IO.iodata_to_binary(fragments)]}

        length(fragments) == num_frames ->
          {:ok, fragments}

        true ->
          {:error, :invalid_pixel_data}
      end
    end
  end

  defp extract_encapsulated_frames(_fragments, _ds), do: {:error, :invalid_pixel_data}

  defp extract_encapsulated_frame(fragments, ds, index) do
    case extract_encapsulated_frames(fragments, ds) do
      {:ok, all_frames} ->
        case Enum.fetch(all_frames, index) do
          {:ok, frame} -> {:ok, frame}
          :error -> {:error, :frame_index_out_of_range}
        end

      {:error, _} = error ->
        error
    end
  end

  defp parse_bot(<<>>), do: {:ok, []}

  defp parse_bot(bot) when is_binary(bot) and rem(byte_size(bot), 4) == 0 do
    {:ok, for(<<offset::little-32 <- bot>>, do: offset)}
  end

  defp parse_bot(_bot), do: {:error, :invalid_basic_offset_table}

  defp group_fragments_by_bot(offsets, fragments) do
    with :ok <- validate_bot_offsets(offsets, fragments) do
      do_group_fragments_by_bot(offsets, fragments)
    end
  end

  defp do_group_fragments_by_bot(offsets, fragments) do
    # Each offset marks the start of a frame in the fragment stream.
    # Fragment boundaries include 8-byte item headers (tag + length).
    indexed_frags = Enum.with_index(fragments)

    # Build a cumulative byte offset map for each fragment
    {frag_offsets, _} =
      Enum.map_reduce(indexed_frags, 0, fn {frag, _idx}, acc ->
        {{acc, frag}, acc + 8 + byte_size(frag)}
      end)

    valid_offsets = MapSet.new(Enum.map(frag_offsets, fn {offset, _frag} -> offset end))

    # Group fragments by which frame they belong to
    frame_ranges = Enum.zip(offsets, Enum.drop(offsets, 1) ++ [:end])

    Enum.reduce_while(frame_ranges, {:ok, []}, fn {start_offset, end_offset}, {:ok, acc} ->
      if not MapSet.member?(valid_offsets, start_offset) do
        {:halt, {:error, :invalid_basic_offset_table}}
      else
        matching =
          Enum.filter(frag_offsets, fn {offset, _frag} ->
            offset >= start_offset and
              (end_offset == :end or offset < end_offset)
          end)

        if matching == [] do
          {:halt, {:error, :invalid_basic_offset_table}}
        else
          frame =
            matching
            |> Enum.map(fn {_offset, frag} -> frag end)
            |> IO.iodata_to_binary()

          {:cont, {:ok, [frame | acc]}}
        end
      end
    end)
    |> case do
      {:ok, frames} -> {:ok, Enum.reverse(frames)}
      {:error, _} = error -> error
    end
  end

  defp validate_bot_offsets([], _fragments), do: :ok

  defp validate_bot_offsets(offsets, fragments) do
    if offsets != Enum.sort(offsets) or hd(offsets) != 0 do
      {:error, :invalid_basic_offset_table}
    else
      valid_offsets = fragment_start_offsets(fragments)

      if Enum.all?(offsets, &MapSet.member?(valid_offsets, &1)) do
        :ok
      else
        {:error, :invalid_basic_offset_table}
      end
    end
  end

  defp fragment_start_offsets(fragments) do
    {offsets, _} =
      Enum.map_reduce(fragments, 0, fn fragment, acc ->
        {acc, acc + 8 + byte_size(fragment)}
      end)

    MapSet.new(offsets)
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp get_pixel_element(%DataSet{} = ds) do
    DataSet.get_element(ds, Tag.pixel_data())
  end

  defp get_number_of_frames(ds) do
    case DataSet.get(ds, Tag.number_of_frames()) do
      nil ->
        {:ok, 1}

      val when is_binary(val) ->
        case Integer.parse(String.trim(val)) do
          {n, ""} when n > 0 -> {:ok, n}
          _ -> {:error, :invalid_number_of_frames}
        end

      val when is_integer(val) ->
        if val > 0, do: {:ok, val}, else: {:error, :invalid_number_of_frames}
    end
  end

  defp decode_us(ds, tag, default) do
    case DataSet.get(ds, tag) do
      nil ->
        {:ok, default}

      val when is_binary(val) ->
        case Value.decode(val, :US) do
          decoded when is_integer(decoded) -> {:ok, decoded}
          _ -> {:error, :invalid_pixel_data_metadata}
        end

      val when is_integer(val) ->
        {:ok, val}
    end
  end

  defp ceil_div(0, _denominator), do: 0
  defp ceil_div(numerator, denominator), do: div(numerator + denominator - 1, denominator)
end
