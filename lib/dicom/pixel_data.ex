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
      _ -> false
    end
  end

  @doc """
  Returns the number of frames in the pixel data.
  """
  @spec frame_count(DataSet.t()) :: {:ok, pos_integer()} | {:error, :no_pixel_data}
  def frame_count(%DataSet{} = ds) do
    case get_pixel_element(ds) do
      nil ->
        {:error, :no_pixel_data}

      _elem ->
        nf = get_number_of_frames(ds)
        {:ok, nf}
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
        # For encapsulated data, fall back to extracting all frames
        {:ok, all_frames} = extract_encapsulated_frames(fragments, ds)

        case Enum.fetch(all_frames, index) do
          {:ok, frame} -> {:ok, frame}
          :error -> {:error, :frame_index_out_of_range}
        end
    end
  end

  def frame(_ds, _index), do: {:error, :frame_index_out_of_range}

  # ── Native frame extraction ───────────────────────────────────

  defp extract_native_frame(data, ds, index) do
    num_frames = get_number_of_frames(ds)
    frame_size = compute_frame_size(ds)

    cond do
      index >= num_frames ->
        {:error, :frame_index_out_of_range}

      frame_size > 0 ->
        {:ok, binary_part(data, index * frame_size, frame_size)}

      index == 0 ->
        {:ok, data}

      true ->
        {:error, :frame_index_out_of_range}
    end
  end

  defp extract_native_frames(data, ds) do
    num_frames = get_number_of_frames(ds)
    frame_size = compute_frame_size(ds)

    if frame_size > 0 do
      frames =
        for i <- 0..(num_frames - 1) do
          binary_part(data, i * frame_size, frame_size)
        end

      {:ok, frames}
    else
      {:ok, [data]}
    end
  end

  defp compute_frame_size(ds) do
    rows = decode_us(ds, Tag.rows(), 0)
    cols = decode_us(ds, Tag.columns(), 0)
    bits = decode_us(ds, Tag.bits_allocated(), 16)
    samples = decode_us(ds, Tag.samples_per_pixel(), 1)
    rows * cols * div(bits, 8) * samples
  end

  # ── Encapsulated frame extraction ─────────────────────────────

  defp extract_encapsulated_frames([bot | fragments], ds) do
    num_frames = get_number_of_frames(ds)
    bot_offsets = parse_bot(bot)

    cond do
      bot_offsets != [] and length(bot_offsets) == num_frames ->
        group_fragments_by_bot(bot_offsets, fragments)

      num_frames == 1 ->
        {:ok, [IO.iodata_to_binary(fragments)]}

      true ->
        {:ok, fragments}
    end
  end

  defp parse_bot(<<>>), do: []

  defp parse_bot(bot) when is_binary(bot) do
    for <<offset::little-32 <- bot>>, do: offset
  end

  defp group_fragments_by_bot(offsets, fragments) do
    # Each offset marks the start of a frame in the fragment stream.
    # Fragment boundaries include 8-byte item headers (tag + length).
    indexed_frags = Enum.with_index(fragments)

    # Build a cumulative byte offset map for each fragment
    {frag_offsets, _} =
      Enum.map_reduce(indexed_frags, 0, fn {frag, _idx}, acc ->
        {{acc, frag}, acc + 8 + byte_size(frag)}
      end)

    # Group fragments by which frame they belong to
    frame_ranges = Enum.zip(offsets, Enum.drop(offsets, 1) ++ [:end])

    frames =
      Enum.map(frame_ranges, fn {start_offset, end_offset} ->
        matching =
          Enum.filter(frag_offsets, fn {offset, _frag} ->
            offset >= start_offset and
              (end_offset == :end or offset < end_offset)
          end)

        matching
        |> Enum.map(fn {_offset, frag} -> frag end)
        |> IO.iodata_to_binary()
      end)

    {:ok, frames}
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp get_pixel_element(%DataSet{} = ds) do
    DataSet.get_element(ds, Tag.pixel_data())
  end

  defp get_number_of_frames(ds) do
    case DataSet.get(ds, Tag.number_of_frames()) do
      nil ->
        1

      val when is_binary(val) ->
        case Integer.parse(String.trim(val)) do
          {n, _} -> n
          :error -> 1
        end

      val when is_integer(val) ->
        val
    end
  end

  defp decode_us(ds, tag, default) do
    case DataSet.get(ds, tag) do
      nil -> default
      val when is_binary(val) -> Value.decode(val, :US)
      val when is_integer(val) -> val
    end
  end
end
