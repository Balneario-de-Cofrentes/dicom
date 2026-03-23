defmodule Dicom.Codec.RLETest do
  use ExUnit.Case, async: true

  alias Dicom.Codec.RLE

  # ── Helper: build metadata ──────────────────────────────────────

  defp metadata(opts \\ []) do
    %{
      rows: Keyword.get(opts, :rows, 4),
      columns: Keyword.get(opts, :columns, 4),
      bits_allocated: Keyword.get(opts, :bits_allocated, 8),
      samples_per_pixel: Keyword.get(opts, :samples_per_pixel, 1)
    }
  end

  # ── Helper: build a minimal RLE frame from raw segments ─────────

  defp build_rle_frame(encoded_segments) do
    num_segments = length(encoded_segments)
    header_size = 64

    {offsets, _} =
      Enum.map_reduce(encoded_segments, header_size, fn seg, offset ->
        {offset, offset + byte_size(seg)}
      end)

    padded_offsets = offsets ++ List.duplicate(0, 15 - num_segments)

    header =
      [<<num_segments::little-32>> | Enum.map(padded_offsets, &<<&1::little-32>>)]
      |> IO.iodata_to_binary()

    IO.iodata_to_binary([header | encoded_segments])
  end

  # ── Segment decoding ────────────────────────────────────────────

  describe "decode_segment/2" do
    test "decodes a literal run" do
      # n=4 means copy next 5 bytes literally
      segment = <<4, 10, 20, 30, 40, 50>>
      assert {:ok, <<10, 20, 30, 40, 50>>} = RLE.decode_segment(segment, 5)
    end

    test "decodes a repeated byte run" do
      # n=253 (signed -3), repeat count = 257 - 253 = 4
      segment = <<253, 42>>
      assert {:ok, <<42, 42, 42, 42>>} = RLE.decode_segment(segment, 4)
    end

    test "decodes mixed literal and repeated runs" do
      # Literal: n=2 => 3 bytes
      # Repeat: n=254 (signed -2) => 3 repetitions
      segment = <<2, 1, 2, 3, 254, 99>>
      assert {:ok, <<1, 2, 3, 99, 99, 99>>} = RLE.decode_segment(segment, 6)
    end

    test "handles NOP byte (0x80)" do
      # NOP followed by literal
      segment = <<0x80, 1, 10, 20>>
      assert {:ok, <<10, 20>>} = RLE.decode_segment(segment, 2)
    end

    test "handles empty segment" do
      assert {:ok, <<0, 0, 0, 0>>} = RLE.decode_segment(<<>>, 4)
    end

    test "handles single literal byte" do
      segment = <<0, 77>>
      assert {:ok, <<77>>} = RLE.decode_segment(segment, 1)
    end

    test "truncates to expected length when decoded is longer" do
      # n=9 means 10 literal bytes, but we only expect 5
      segment = <<9, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>
      assert {:ok, result} = RLE.decode_segment(segment, 5)
      assert result == <<1, 2, 3, 4, 5>>
    end

    test "pads with zeros when decoded is shorter" do
      segment = <<1, 10, 20>>
      assert {:ok, result} = RLE.decode_segment(segment, 5)
      assert result == <<10, 20, 0, 0, 0>>
    end

    test "decodes max repeat count (128)" do
      # n = 257 - 128 = 129
      segment = <<129, 0xFF>>
      assert {:ok, result} = RLE.decode_segment(segment, 128)
      assert result == :binary.copy(<<0xFF>>, 128)
    end

    test "decodes max literal run (128 bytes)" do
      # n=127 means copy next 128 bytes
      data = :binary.copy(<<42>>, 128)
      segment = <<127>> <> data
      assert {:ok, result} = RLE.decode_segment(segment, 128)
      assert result == data
    end
  end

  # ── Segment encoding ────────────────────────────────────────────

  describe "encode_segment/1" do
    test "encodes empty data" do
      assert RLE.encode_segment(<<>>) == <<>>
    end

    test "encodes literal bytes (no runs)" do
      data = <<1, 2, 3, 4, 5>>
      encoded = RLE.encode_segment(data)

      # Should produce a literal run: n=4 (5 bytes), then the 5 bytes
      assert {:ok, decoded} = RLE.decode_segment(encoded, 5)
      assert decoded == data
    end

    test "encodes repeated bytes" do
      data = :binary.copy(<<42>>, 10)
      encoded = RLE.encode_segment(data)

      # The encoding should be shorter than the original
      assert byte_size(encoded) < byte_size(data)
      assert {:ok, decoded} = RLE.decode_segment(encoded, 10)
      assert decoded == data
    end

    test "encodes mixed data" do
      data = <<1, 2, 3>> <> :binary.copy(<<99>>, 8) <> <<4, 5>>
      encoded = RLE.encode_segment(data)

      assert {:ok, decoded} = RLE.decode_segment(encoded, byte_size(data))
      assert decoded == data
    end

    test "round-trip for single byte" do
      data = <<77>>
      encoded = RLE.encode_segment(data)
      assert {:ok, ^data} = RLE.decode_segment(encoded, 1)
    end

    test "round-trip for long repeated run (> 128)" do
      data = :binary.copy(<<0xAB>>, 200)
      encoded = RLE.encode_segment(data)
      assert {:ok, ^data} = RLE.decode_segment(encoded, 200)
    end

    test "round-trip for random data" do
      data = :crypto.strong_rand_bytes(256)
      encoded = RLE.encode_segment(data)
      assert {:ok, ^data} = RLE.decode_segment(encoded, 256)
    end
  end

  # ── Full frame decode ───────────────────────────────────────────

  describe "decode/2" do
    test "decodes single-segment 8-bit frame" do
      pixel_count = 16
      raw_data = :crypto.strong_rand_bytes(pixel_count)

      # Build an RLE frame: encode the raw data as one segment
      encoded_seg = RLE.encode_segment(raw_data)
      frame = build_rle_frame([encoded_seg])

      meta = metadata(rows: 4, columns: 4, bits_allocated: 8, samples_per_pixel: 1)
      assert {:ok, decoded} = RLE.decode(frame, meta)
      assert decoded == raw_data
    end

    test "decodes multi-segment 16-bit frame" do
      # 4x4 image, 16-bit pixels
      pixel_count = 16
      # Generate 16-bit little-endian pixel data
      raw_pixels =
        for i <- 0..(pixel_count - 1), into: <<>> do
          <<rem(i * 257, 65536)::little-16>>
        end

      # Split into byte planes: segment 0 = high bytes (MSB), segment 1 = low bytes (LSB)
      high_bytes =
        for <<_low, high <- raw_pixels>>, into: <<>>, do: <<high>>

      low_bytes =
        for <<low, _high <- raw_pixels>>, into: <<>>, do: <<low>>

      seg0 = RLE.encode_segment(high_bytes)
      seg1 = RLE.encode_segment(low_bytes)
      frame = build_rle_frame([seg0, seg1])

      meta = metadata(rows: 4, columns: 4, bits_allocated: 16, samples_per_pixel: 1)
      assert {:ok, decoded} = RLE.decode(frame, meta)
      assert decoded == raw_pixels
    end

    test "decodes RGB 8-bit frame (3 segments)" do
      pixel_count = 4
      # Build RGB data: R,G,B interleaved
      r_plane = <<255, 0, 128, 64>>
      g_plane = <<0, 255, 128, 32>>
      b_plane = <<128, 128, 0, 255>>

      # Raw interleaved: [R0,G0,B0, R1,G1,B1, ...]
      raw_pixels =
        for i <- 0..(pixel_count - 1), into: <<>> do
          <<:binary.at(r_plane, i), :binary.at(g_plane, i), :binary.at(b_plane, i)>>
        end

      seg_r = RLE.encode_segment(r_plane)
      seg_g = RLE.encode_segment(g_plane)
      seg_b = RLE.encode_segment(b_plane)
      frame = build_rle_frame([seg_r, seg_g, seg_b])

      meta =
        metadata(rows: 2, columns: 2, bits_allocated: 8, samples_per_pixel: 3)

      assert {:ok, decoded} = RLE.decode(frame, meta)
      assert decoded == raw_pixels
    end

    test "returns error for header too short" do
      assert {:error, :rle_header_too_short} = RLE.decode(<<1, 2, 3>>, metadata())
    end

    test "returns error for invalid segment count (0)" do
      header = <<0::little-32>> <> :binary.copy(<<0>>, 60)
      assert {:error, :rle_invalid_segment_count} = RLE.decode(header, metadata())
    end

    test "returns error for invalid segment count (> 15)" do
      header = <<16::little-32>> <> :binary.copy(<<0>>, 60)
      assert {:error, :rle_invalid_segment_count} = RLE.decode(header, metadata())
    end

    test "returns error for missing bits_allocated" do
      encoded_seg = RLE.encode_segment(<<1, 2, 3, 4>>)
      frame = build_rle_frame([encoded_seg])
      meta = %{rows: 2, columns: 2}
      assert {:error, :missing_bits_allocated} = RLE.decode(frame, meta)
    end

    test "returns error for segment count mismatch" do
      # 8-bit mono expects 1 segment, provide 2
      seg1 = RLE.encode_segment(<<1, 2, 3, 4>>)
      seg2 = RLE.encode_segment(<<5, 6, 7, 8>>)
      frame = build_rle_frame([seg1, seg2])

      meta = metadata(rows: 2, columns: 2, bits_allocated: 8, samples_per_pixel: 1)
      assert {:error, {:rle_segment_count_mismatch, _}} = RLE.decode(frame, meta)
    end
  end

  # ── Full frame encode ───────────────────────────────────────────

  describe "encode/2" do
    test "encodes and decodes 8-bit single-sample" do
      raw = :crypto.strong_rand_bytes(64)
      meta = metadata(rows: 8, columns: 8, bits_allocated: 8, samples_per_pixel: 1)

      assert {:ok, encoded} = RLE.encode(raw, meta)
      assert {:ok, decoded} = RLE.decode(encoded, meta)
      assert decoded == raw
    end

    test "encodes and decodes 16-bit single-sample" do
      pixel_count = 16

      raw =
        for i <- 0..(pixel_count - 1), into: <<>> do
          <<rem(i * 1000, 65536)::little-16>>
        end

      meta = metadata(rows: 4, columns: 4, bits_allocated: 16, samples_per_pixel: 1)

      assert {:ok, encoded} = RLE.encode(raw, meta)
      assert {:ok, decoded} = RLE.decode(encoded, meta)
      assert decoded == raw
    end

    test "encodes and decodes RGB 8-bit" do
      pixel_count = 9

      raw =
        for _ <- 1..pixel_count, into: <<>> do
          <<:rand.uniform(256) - 1, :rand.uniform(256) - 1, :rand.uniform(256) - 1>>
        end

      meta = metadata(rows: 3, columns: 3, bits_allocated: 8, samples_per_pixel: 3)

      assert {:ok, encoded} = RLE.encode(raw, meta)
      assert {:ok, decoded} = RLE.decode(encoded, meta)
      assert decoded == raw
    end

    test "round-trip with all-zero data" do
      raw = :binary.copy(<<0>>, 64)
      meta = metadata(rows: 8, columns: 8, bits_allocated: 8, samples_per_pixel: 1)

      assert {:ok, encoded} = RLE.encode(raw, meta)
      # Should compress well
      assert byte_size(encoded) < byte_size(raw) + 64
      assert {:ok, decoded} = RLE.decode(encoded, meta)
      assert decoded == raw
    end

    test "round-trip with all-same-value data" do
      raw = :binary.copy(<<0xAA>>, 100)
      meta = metadata(rows: 10, columns: 10, bits_allocated: 8, samples_per_pixel: 1)

      assert {:ok, encoded} = RLE.encode(raw, meta)
      assert {:ok, decoded} = RLE.decode(encoded, meta)
      assert decoded == raw
    end

    test "returns error for missing bits_allocated" do
      assert {:error, :missing_bits_allocated} = RLE.encode(<<1, 2, 3>>, %{})
    end
  end

  # ── Header parsing ──────────────────────────────────────────────

  describe "parse_header/1" do
    test "parses valid single-segment header" do
      header = <<1::little-32, 64::little-32>> <> :binary.copy(<<0>>, 56)
      assert {:ok, {1, [64]}} = RLE.parse_header(header)
    end

    test "parses valid multi-segment header" do
      seg1_offset = 64
      seg2_offset = 128

      header =
        <<2::little-32, seg1_offset::little-32, seg2_offset::little-32>> <>
          :binary.copy(<<0>>, 52)

      assert {:ok, {2, [64, 128]}} = RLE.parse_header(header)
    end

    test "rejects header shorter than 64 bytes" do
      assert {:error, :rle_header_too_short} = RLE.parse_header(<<1, 2, 3>>)
    end

    test "rejects zero segments" do
      header = <<0::little-32>> <> :binary.copy(<<0>>, 60)
      assert {:error, :rle_invalid_segment_count} = RLE.parse_header(header)
    end

    test "rejects more than 15 segments" do
      header = <<16::little-32>> <> :binary.copy(<<0>>, 60)
      assert {:error, :rle_invalid_segment_count} = RLE.parse_header(header)
    end
  end

  # ── Transfer syntax UIDs ────────────────────────────────────────

  describe "transfer_syntax_uids/0" do
    test "returns the RLE Lossless UID" do
      assert RLE.transfer_syntax_uids() == ["1.2.840.10008.1.2.5"]
    end
  end
end
