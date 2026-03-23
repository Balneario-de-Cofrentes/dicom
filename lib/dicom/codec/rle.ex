defmodule Dicom.Codec.RLE do
  @moduledoc """
  DICOM RLE Lossless codec per PS3.5 Annex G.

  Transfer Syntax UID: 1.2.840.10008.1.2.5

  ## RLE Format

  Each RLE-compressed frame consists of:

  1. **RLE Header** (64 bytes):
     - `uint32` number of segments (1..15)
     - 15 `uint32` segment offsets (unused offsets are zero)

  2. **Segments**: One per byte plane. For single-byte pixels (8-bit),
     there is one segment. For 16-bit pixels, segment 1 contains
     all high bytes and segment 2 all low bytes (byte-plane separation).

  3. **RLE Encoding** (per segment):
     - `n` in 0..127: copy the next `n + 1` bytes literally
     - `n` = -128 (0x80): no operation (skip)
     - `n` in -127..-1: repeat the next byte `1 - n` times

  All multi-byte integers in the header are little-endian unsigned 32-bit.

  Reference: DICOM PS3.5 Annex G.
  """

  @behaviour Dicom.Codec

  @rle_lossless_uid "1.2.840.10008.1.2.5"
  @header_size 64
  @max_segments 15

  # ── Behaviour callbacks ──────────────────────────────────────

  @impl true
  @doc """
  Decodes an RLE-compressed frame to raw pixel data.

  Requires `:bits_allocated` and `:samples_per_pixel` in metadata
  to determine the expected number of segments and output size.
  Requires `:rows` and `:columns` to compute total pixel count.
  """
  @spec decode(binary(), Dicom.Codec.metadata()) :: {:ok, binary()} | {:error, term()}
  def decode(data, metadata) when is_binary(data) and is_map(metadata) do
    with {:ok, {num_segments, offsets}} <- parse_header(data),
         {:ok, expected_segments} <- expected_segment_count(metadata),
         :ok <- validate_segment_count(num_segments, expected_segments),
         {:ok, segments} <- extract_segments(data, num_segments, offsets),
         {:ok, decoded_segments} <- decode_all_segments(segments, metadata),
         {:ok, raw} <- interleave_segments(decoded_segments, metadata) do
      {:ok, raw}
    end
  end

  @impl true
  @doc """
  Encodes raw pixel data to RLE-compressed form.

  Requires `:bits_allocated` and `:samples_per_pixel` in metadata
  to determine byte-plane segmentation.
  """
  @spec encode(binary(), Dicom.Codec.metadata()) :: {:ok, binary()} | {:error, term()}
  def encode(data, metadata) when is_binary(data) and is_map(metadata) do
    with {:ok, bytes_per_sample} <- bytes_per_sample(metadata),
         {:ok, samples_per_pixel} <- samples_per_pixel(metadata) do
      num_segments = bytes_per_sample * samples_per_pixel
      planes = deinterleave(data, bytes_per_sample, samples_per_pixel)
      encoded_segments = Enum.map(planes, &encode_segment/1)
      {:ok, build_rle_frame(encoded_segments, num_segments)}
    end
  end

  @impl true
  @spec transfer_syntax_uids() :: [String.t()]
  def transfer_syntax_uids, do: [@rle_lossless_uid]

  # ── Header parsing ─────────────────────────────────────────────

  @doc false
  @spec parse_header(binary()) :: {:ok, {pos_integer(), [non_neg_integer()]}} | {:error, term()}
  def parse_header(data) when byte_size(data) < @header_size do
    {:error, :rle_header_too_short}
  end

  def parse_header(<<num_segments::little-32, offsets_bin::binary-size(60), _rest::binary>>) do
    if num_segments < 1 or num_segments > @max_segments do
      {:error, :rle_invalid_segment_count}
    else
      offsets = for <<offset::little-32 <- offsets_bin>>, do: offset
      {:ok, {num_segments, Enum.take(offsets, num_segments)}}
    end
  end

  # ── Segment extraction ─────────────────────────────────────────

  defp extract_segments(data, num_segments, offsets) do
    data_size = byte_size(data)

    # Compute segment boundaries: each segment runs from its offset
    # to the next segment's offset (or end of data for the last segment).
    boundaries =
      offsets
      |> Enum.with_index()
      |> Enum.map(fn {offset, idx} ->
        end_offset =
          if idx < num_segments - 1 do
            Enum.at(offsets, idx + 1)
          else
            data_size
          end

        {offset, end_offset}
      end)

    segments =
      Enum.reduce_while(boundaries, {:ok, []}, fn {start, stop}, {:ok, acc} ->
        if start > data_size or stop > data_size or start > stop do
          {:halt, {:error, :rle_invalid_segment_offset}}
        else
          segment = binary_part(data, start, stop - start)
          {:cont, {:ok, [segment | acc]}}
        end
      end)

    case segments do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  # ── RLE segment decoding ───────────────────────────────────────

  defp decode_all_segments(segments, metadata) do
    pixel_count = pixel_count(metadata)

    results =
      Enum.reduce_while(segments, {:ok, []}, fn segment, {:ok, acc} ->
        case decode_segment(segment, pixel_count) do
          {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
          error -> {:halt, error}
        end
      end)

    case results do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  @doc false
  @spec decode_segment(binary(), non_neg_integer()) :: {:ok, binary()} | {:error, term()}
  def decode_segment(segment, expected_length) do
    case do_decode_segment(segment, []) do
      {:ok, iodata} ->
        result = IO.iodata_to_binary(iodata)

        # RLE segments may have trailing padding; truncate to expected length
        cond do
          byte_size(result) >= expected_length ->
            {:ok, binary_part(result, 0, expected_length)}

          true ->
            # Pad with zeros if the decoded segment is shorter
            pad_size = expected_length - byte_size(result)
            {:ok, result <> :binary.copy(<<0>>, pad_size)}
        end

      error ->
        error
    end
  end

  defp do_decode_segment(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  # n = -128 (0x80): NOP
  defp do_decode_segment(<<0x80, rest::binary>>, acc) do
    do_decode_segment(rest, acc)
  end

  # n in 0..127: literal run of n+1 bytes
  defp do_decode_segment(<<n, rest::binary>>, acc) when n <= 127 do
    count = n + 1

    if byte_size(rest) >= count do
      <<literal::binary-size(count), remaining::binary>> = rest
      do_decode_segment(remaining, [literal | acc])
    else
      # Emit what we have
      {:ok, Enum.reverse([rest | acc])}
    end
  end

  # n in 129..255 (signed: -127..-1): repeat next byte (1 - n_signed) times
  # where n_signed = n - 256 for n > 127, so repeat count = 1 - (n - 256) = 257 - n
  defp do_decode_segment(<<n, rest::binary>>, acc) when n >= 129 do
    repeat_count = 257 - n

    if byte_size(rest) >= 1 do
      <<byte, remaining::binary>> = rest
      do_decode_segment(remaining, [:binary.copy(<<byte>>, repeat_count) | acc])
    else
      {:ok, Enum.reverse(acc)}
    end
  end

  # ── RLE segment encoding ───────────────────────────────────────

  @doc false
  @spec encode_segment(binary()) :: binary()
  def encode_segment(<<>>), do: <<>>

  def encode_segment(data) when is_binary(data) do
    data
    |> :binary.bin_to_list()
    |> do_encode_segment([])
    |> IO.iodata_to_binary()
  end

  # Encoding strategy: scan for runs of identical bytes (min length 3)
  # and literal sequences.
  defp do_encode_segment([], acc), do: Enum.reverse(acc)

  defp do_encode_segment([byte | rest] = input, acc) do
    {run_length, after_run} = count_run(byte, rest, 1)

    if run_length >= 3 do
      # Encode repeated run: max 128 per RLE control byte
      encode_repeated_runs(byte, run_length, after_run, acc)
    else
      # Collect literal bytes
      {literals, remaining} = collect_literals(input, [])
      encode_literal_runs(literals, remaining, acc)
    end
  end

  defp count_run(_byte, [], count), do: {count, []}

  defp count_run(byte, [byte | rest], count) when count < 128 do
    count_run(byte, rest, count + 1)
  end

  defp count_run(_byte, rest, count), do: {count, rest}

  defp encode_repeated_runs(_byte, 0, rest, acc) do
    do_encode_segment(rest, acc)
  end

  defp encode_repeated_runs(byte, count, rest, acc) when count > 128 do
    # n_unsigned = 257 - repeat_count, for repeat_count=128 => n=129
    n = 257 - 128
    encode_repeated_runs(byte, count - 128, rest, [<<n, byte>> | acc])
  end

  defp encode_repeated_runs(byte, count, rest, acc) do
    n = 257 - count
    do_encode_segment(rest, [<<n, byte>> | acc])
  end

  # Collect literals until we hit a run of 3+ identical bytes or end of input.
  # Max literal run is 128 bytes.
  defp collect_literals([], acc), do: {Enum.reverse(acc), []}

  defp collect_literals(input, acc) when length(acc) >= 128 do
    {Enum.reverse(acc), input}
  end

  defp collect_literals([a, a, a | _rest] = input, acc) do
    # A run of 3+ identical starts here; stop collecting literals
    {Enum.reverse(acc), input}
  end

  defp collect_literals([byte | rest], acc) do
    collect_literals(rest, [byte | acc])
  end

  defp encode_literal_runs([], rest, acc), do: do_encode_segment(rest, acc)

  defp encode_literal_runs(literals, rest, acc) do
    count = length(literals)
    n = count - 1
    bytes = :binary.list_to_bin(literals)
    do_encode_segment(rest, [<<n, bytes::binary>> | acc])
  end

  # ── Byte-plane interleaving / deinterleaving ───────────────────

  # After RLE decode, segments contain separated byte planes.
  # For 16-bit data with 1 sample/pixel: segment 0 = high bytes, segment 1 = low bytes.
  # We need to interleave them back: [H0,L0,H1,L1,...] for little-endian output.
  #
  # Per DICOM PS3.5 Annex G, RLE stores byte planes in big-endian order:
  # segment 0 = most significant byte, segment N-1 = least significant byte.
  # The output should be native (little-endian) pixel data.
  defp interleave_segments([single], _metadata), do: {:ok, single}

  defp interleave_segments(segments, metadata) do
    bytes_per = bytes_per_sample!(metadata)
    spp = samples_per_pixel!(metadata)

    if bytes_per == 1 and spp > 1 do
      # Multiple samples, 1 byte each: segments are sample planes
      # Interleave: pixel[i] = [seg0[i], seg1[i], seg2[i]]
      {:ok, interleave_sample_planes(segments)}
    else
      # Multi-byte samples: segments are byte planes within each sample
      # For spp > 1 with multi-byte samples, groups of `bytes_per` segments
      # form one sample's byte planes.
      grouped = Enum.chunk_every(segments, bytes_per)

      interleaved_samples =
        Enum.map(grouped, fn byte_planes ->
          interleave_byte_planes(byte_planes)
        end)

      if spp == 1 do
        {:ok, hd(interleaved_samples)}
      else
        {:ok, interleave_sample_planes(interleaved_samples)}
      end
    end
  end

  # Interleave byte planes for a single multi-byte-per-sample channel.
  # Segments are in big-endian order: seg[0] = MSB, seg[N-1] = LSB.
  # Output is little-endian: [LSB, ..., MSB] per pixel.
  defp interleave_byte_planes(segments) do
    # Reverse to get LSB-first order
    reversed = Enum.reverse(segments)
    lists = Enum.map(reversed, &:binary.bin_to_list/1)
    pixel_count = length(hd(lists))

    0..(pixel_count - 1)
    |> Enum.map(fn i ->
      Enum.map(lists, fn plane -> Enum.at(plane, i) end)
    end)
    |> List.flatten()
    |> :binary.list_to_bin()
  end

  # Interleave per-sample planes: each segment is one complete sample plane.
  # Output: [sample0_pixel0, sample1_pixel0, sample2_pixel0, sample0_pixel1, ...]
  defp interleave_sample_planes(segments) do
    lists = Enum.map(segments, &byte_list/1)
    pixel_count = length(hd(lists))

    0..(pixel_count - 1)
    |> Enum.map(fn i ->
      Enum.map(lists, fn plane -> Enum.at(plane, i) end)
    end)
    |> List.flatten()
    |> :binary.list_to_bin()
  end

  defp byte_list(bin) when is_binary(bin), do: :binary.bin_to_list(bin)

  # Deinterleave raw pixels into byte planes for encoding.
  defp deinterleave(data, bytes_per_sample, samples_per_pixel) do
    total_samples = bytes_per_sample * samples_per_pixel
    pixel_bytes = :binary.bin_to_list(data)
    pixel_count = div(length(pixel_bytes), total_samples)

    if bytes_per_sample == 1 and samples_per_pixel > 1 do
      # Separate sample planes
      for sample_idx <- 0..(samples_per_pixel - 1) do
        for i <- 0..(pixel_count - 1) do
          Enum.at(pixel_bytes, i * samples_per_pixel + sample_idx)
        end
        |> :binary.list_to_bin()
      end
    else
      # Separate byte planes per sample, in big-endian order (MSB first)
      for sample_idx <- 0..(samples_per_pixel - 1),
          # byte_idx 0 = MSB (maps to last byte in little-endian pixel)
          byte_idx <- 0..(bytes_per_sample - 1) do
        # In little-endian pixel data, byte 0 = LSB, byte N-1 = MSB
        # RLE segment 0 = MSB = little-endian byte (bytes_per_sample - 1)
        le_byte_idx = bytes_per_sample - 1 - byte_idx

        for i <- 0..(pixel_count - 1) do
          base = i * total_samples + sample_idx * bytes_per_sample
          Enum.at(pixel_bytes, base + le_byte_idx)
        end
        |> :binary.list_to_bin()
      end
    end
  end

  # ── Metadata helpers ───────────────────────────────────────────

  defp expected_segment_count(metadata) do
    with {:ok, bps} <- bytes_per_sample(metadata),
         {:ok, spp} <- samples_per_pixel(metadata) do
      {:ok, bps * spp}
    end
  end

  defp bytes_per_sample(%{bits_allocated: bits}) when bits > 0 do
    {:ok, ceil_div(bits, 8)}
  end

  defp bytes_per_sample(_), do: {:error, :missing_bits_allocated}

  defp bytes_per_sample!(metadata), do: elem(bytes_per_sample(metadata), 1)

  defp samples_per_pixel(%{samples_per_pixel: spp}) when spp > 0, do: {:ok, spp}
  defp samples_per_pixel(_), do: {:ok, 1}

  defp samples_per_pixel!(metadata), do: elem(samples_per_pixel(metadata), 1)

  defp pixel_count(%{rows: rows, columns: cols}) when rows > 0 and cols > 0 do
    rows * cols
  end

  defp pixel_count(_), do: 0

  defp validate_segment_count(actual, expected) when actual == expected, do: :ok

  defp validate_segment_count(actual, expected) do
    {:error, {:rle_segment_count_mismatch, expected: expected, actual: actual}}
  end

  # ── Frame building ─────────────────────────────────────────────

  defp build_rle_frame(encoded_segments, num_segments) do
    # Build header: num_segments + 15 offsets
    # Data starts at byte 64 (header size)
    {offsets, _} =
      Enum.map_reduce(encoded_segments, @header_size, fn seg, offset ->
        {offset, offset + byte_size(seg)}
      end)

    # Pad offsets to 15 entries
    padded_offsets = offsets ++ List.duplicate(0, @max_segments - num_segments)

    header =
      [<<num_segments::little-32>> | Enum.map(padded_offsets, &<<&1::little-32>>)]
      |> IO.iodata_to_binary()

    IO.iodata_to_binary([header | encoded_segments])
  end

  defp ceil_div(n, d), do: div(n + d - 1, d)
end
