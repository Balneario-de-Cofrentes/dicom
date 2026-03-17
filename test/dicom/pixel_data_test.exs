defmodule Dicom.PixelDataTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, DataElement, PixelData, Tag}

  # ── Helper: build a data set with image metadata ───────────────

  defp image_ds(rows, cols, bits_allocated, samples_per_pixel, opts \\ []) do
    num_frames = Keyword.get(opts, :frames, 1)
    pixel_data = Keyword.get(opts, :pixel_data, nil)
    pixel_vr = Keyword.get(opts, :pixel_vr, :OW)

    ds =
      DataSet.new()
      |> DataSet.put(Tag.rows(), :US, <<rows::little-16>>)
      |> DataSet.put(Tag.columns(), :US, <<cols::little-16>>)
      |> DataSet.put(Tag.bits_allocated(), :US, <<bits_allocated::little-16>>)
      |> DataSet.put(Tag.samples_per_pixel(), :US, <<samples_per_pixel::little-16>>)

    ds =
      if num_frames > 1 do
        DataSet.put(ds, Tag.number_of_frames(), :IS, Integer.to_string(num_frames))
      else
        ds
      end

    if pixel_data do
      DataSet.put(ds, Tag.pixel_data(), pixel_vr, pixel_data)
    else
      ds
    end
  end

  # ── encapsulated? ──────────────────────────────────────────────

  describe "encapsulated?/1" do
    test "returns false for native pixel data (OW)" do
      ds = image_ds(256, 256, 16, 1, pixel_data: :crypto.strong_rand_bytes(256 * 256 * 2))
      refute PixelData.encapsulated?(ds)
    end

    test "returns true for encapsulated pixel data (OB with fragments)" do
      # Build encapsulated: BOT item + 1 data fragment
      fragment = <<1, 2, 3, 4>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      data_item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment)::little-32>> <> fragment
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
      encap = bot <> data_item <> seq_delim

      ds = image_ds(2, 2, 8, 1, pixel_data: encap, pixel_vr: :OB)
      # Mark as encapsulated by storing as list of fragments
      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [<<>>, fragment],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert PixelData.encapsulated?(ds)
    end

    test "returns false when no pixel data" do
      ds = DataSet.new()
      refute PixelData.encapsulated?(ds)
    end
  end

  # ── frame_count ────────────────────────────────────────────────

  describe "frame_count/1" do
    test "returns 1 for single-frame native image" do
      pixels = :crypto.strong_rand_bytes(64 * 64 * 2)
      ds = image_ds(64, 64, 16, 1, pixel_data: pixels)
      assert {:ok, 1} = PixelData.frame_count(ds)
    end

    test "uses NumberOfFrames when present" do
      pixels = :crypto.strong_rand_bytes(64 * 64 * 2 * 5)
      ds = image_ds(64, 64, 16, 1, frames: 5, pixel_data: pixels)
      assert {:ok, 5} = PixelData.frame_count(ds)
    end

    test "returns error when no pixel data" do
      ds = DataSet.new()
      assert {:error, :no_pixel_data} = PixelData.frame_count(ds)
    end
  end

  # ── frames (native) ───────────────────────────────────────────

  describe "frames/1 - native pixel data" do
    test "extracts single frame" do
      pixels = :crypto.strong_rand_bytes(64 * 64 * 2)
      ds = image_ds(64, 64, 16, 1, pixel_data: pixels)
      assert {:ok, [frame]} = PixelData.frames(ds)
      assert frame == pixels
    end

    test "extracts multiple frames" do
      frame_size = 32 * 32 * 2
      frame1 = :crypto.strong_rand_bytes(frame_size)
      frame2 = :crypto.strong_rand_bytes(frame_size)
      frame3 = :crypto.strong_rand_bytes(frame_size)
      pixels = frame1 <> frame2 <> frame3

      ds = image_ds(32, 32, 16, 1, frames: 3, pixel_data: pixels)
      assert {:ok, frames} = PixelData.frames(ds)
      assert length(frames) == 3
      assert Enum.at(frames, 0) == frame1
      assert Enum.at(frames, 1) == frame2
      assert Enum.at(frames, 2) == frame3
    end

    test "handles RGB (3 samples per pixel)" do
      frame_size = 16 * 16 * 1 * 3
      pixels = :crypto.strong_rand_bytes(frame_size)
      ds = image_ds(16, 16, 8, 3, pixel_data: pixels)
      assert {:ok, [frame]} = PixelData.frames(ds)
      assert byte_size(frame) == frame_size
    end

    test "handles 8-bit allocated" do
      pixels = :crypto.strong_rand_bytes(32 * 32 * 1)
      ds = image_ds(32, 32, 8, 1, pixel_data: pixels)
      assert {:ok, [frame]} = PixelData.frames(ds)
      assert byte_size(frame) == 32 * 32
    end

    test "handles bit-packed native data when BitsAllocated is 1" do
      pixels = <<0b10101010, 0b11001100>>
      ds = image_ds(4, 4, 1, 1, pixel_data: pixels)

      assert {:ok, [frame]} = PixelData.frames(ds)
      assert frame == pixels
      assert byte_size(frame) == 2
    end

    test "returns error for native pixel data shorter than declared geometry" do
      ds = image_ds(2, 2, 16, 1, frames: 2, pixel_data: <<0, 1, 2, 3, 4, 5, 6, 7>>)
      assert {:error, :invalid_pixel_data} = PixelData.frames(ds)
    end

    test "returns error when no pixel data" do
      ds = image_ds(64, 64, 16, 1)
      assert {:error, :no_pixel_data} = PixelData.frames(ds)
    end
  end

  # ── frame/2 (single frame extraction) ─────────────────────────

  describe "frame/2 - native pixel data" do
    test "extracts frame by zero-based index" do
      frame_size = 16 * 16 * 2
      frame0 = :crypto.strong_rand_bytes(frame_size)
      frame1 = :crypto.strong_rand_bytes(frame_size)
      pixels = frame0 <> frame1

      ds = image_ds(16, 16, 16, 1, frames: 2, pixel_data: pixels)
      assert {:ok, ^frame0} = PixelData.frame(ds, 0)
      assert {:ok, ^frame1} = PixelData.frame(ds, 1)
    end

    test "returns error for out-of-range index" do
      pixels = :crypto.strong_rand_bytes(16 * 16 * 2)
      ds = image_ds(16, 16, 16, 1, pixel_data: pixels)
      assert {:error, :frame_index_out_of_range} = PixelData.frame(ds, 1)
      assert {:error, :frame_index_out_of_range} = PixelData.frame(ds, -1)
    end
  end

  # ── frames (encapsulated) ─────────────────────────────────────

  describe "frames/1 - encapsulated pixel data" do
    test "extracts single frame from fragments" do
      fragment = :crypto.strong_rand_bytes(100)
      ds = image_ds(10, 10, 8, 1)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [<<>>, fragment],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:ok, [frame]} = PixelData.frames(ds)
      assert frame == fragment
    end

    test "with multiple fragments and no BOT, each fragment is a frame" do
      frag1 = :crypto.strong_rand_bytes(50)
      frag2 = :crypto.strong_rand_bytes(50)
      frag3 = :crypto.strong_rand_bytes(50)

      ds = image_ds(10, 5, 8, 1, frames: 3)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [<<>>, frag1, frag2, frag3],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:ok, frames} = PixelData.frames(ds)
      assert length(frames) == 3
      assert Enum.at(frames, 0) == frag1
      assert Enum.at(frames, 1) == frag2
      assert Enum.at(frames, 2) == frag3
    end

    test "with BOT offsets, groups fragments per frame" do
      frag1a = :crypto.strong_rand_bytes(30)
      frag1b = :crypto.strong_rand_bytes(20)
      frag2 = :crypto.strong_rand_bytes(40)

      # BOT: frame 0 at offset 0, frame 1 at offset after frag1a + frag1b
      # Each fragment has 8-byte header (item tag 4 + length 4)
      offset_frame1 = 0
      offset_frame2 = 8 + byte_size(frag1a) + (8 + byte_size(frag1b))
      bot = <<offset_frame1::little-32, offset_frame2::little-32>>

      ds = image_ds(10, 5, 8, 1, frames: 2)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [bot, frag1a, frag1b, frag2],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:ok, frames} = PixelData.frames(ds)
      assert length(frames) == 2
      assert Enum.at(frames, 0) == frag1a <> frag1b
      assert Enum.at(frames, 1) == frag2
    end

    test "returns error when BOT offset count does not match NumberOfFrames" do
      frag1 = :crypto.strong_rand_bytes(30)
      frag2 = :crypto.strong_rand_bytes(30)
      bot = <<0::little-32>>

      ds = image_ds(10, 3, 8, 1, frames: 2)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [bot, frag1, frag2],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:error, :invalid_basic_offset_table} = PixelData.frames(ds)
    end

    test "returns error when BOT does not start at the first fragment boundary" do
      frag1 = :crypto.strong_rand_bytes(2)
      frag2 = :crypto.strong_rand_bytes(2)
      bot = <<8::little-32>>

      ds = image_ds(1, 1, 8, 1)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [bot, frag1, frag2],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:error, :invalid_basic_offset_table} = PixelData.frames(ds)
    end

    test "returns error when BOT offset points into the middle of a fragment" do
      frag1 = :crypto.strong_rand_bytes(2)
      frag2 = :crypto.strong_rand_bytes(2)
      bot = <<2::little-32>>

      ds = image_ds(1, 1, 8, 1)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [bot, frag1, frag2],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:error, :invalid_basic_offset_table} = PixelData.frames(ds)
    end

    test "returns error when multi-frame encapsulated data without BOT cannot be split safely" do
      frag1a = :crypto.strong_rand_bytes(30)
      frag1b = :crypto.strong_rand_bytes(20)
      frag2 = :crypto.strong_rand_bytes(40)

      ds = image_ds(10, 5, 8, 1, frames: 2)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [<<>>, frag1a, frag1b, frag2],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:error, :invalid_pixel_data} = PixelData.frames(ds)
    end
  end

  # ── frame/2 - encapsulated pixel data ────────────────────────

  describe "frame/2 - encapsulated pixel data" do
    test "extracts single frame by index" do
      fragment = :crypto.strong_rand_bytes(100)
      ds = image_ds(10, 10, 8, 1)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [<<>>, fragment],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:ok, ^fragment} = PixelData.frame(ds, 0)
    end

    test "returns error for out-of-range index in encapsulated" do
      fragment = :crypto.strong_rand_bytes(100)
      ds = image_ds(10, 10, 8, 1)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: [<<>>, fragment],
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:error, :frame_index_out_of_range} = PixelData.frame(ds, 1)
    end
  end

  # ── frame/2 - no pixel data ─────────────────────────────────

  describe "frame/2 - edge cases" do
    test "returns error when no pixel data" do
      ds = DataSet.new()
      assert {:error, :no_pixel_data} = PixelData.frame(ds, 0)
    end

    test "native frame with zero frame_size returns whole data for index 0" do
      # No rows/cols metadata → frame_size is 0
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(100)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)
      assert {:ok, ^data} = PixelData.frame(ds, 0)
    end

    test "native frame with zero frame_size returns error for index > 0" do
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(100)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)
      assert {:error, :frame_index_out_of_range} = PixelData.frame(ds, 1)
    end

    test "native frames with zero frame_size returns data as single frame" do
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(100)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)
      assert {:ok, [^data]} = PixelData.frames(ds)
    end

    test "number_of_frames as integer" do
      # Provide NumberOfFrames as an already-decoded integer
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(200)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)

      elem = %DataElement{
        tag: Tag.number_of_frames(),
        vr: :IS,
        value: 2,
        length: 0
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.number_of_frames(), elem)}

      # With zero frame_size, returns data as single frame regardless
      assert {:ok, [^data]} = PixelData.frames(ds)
    end
  end

  # ── encapsulated? with {:encapsulated, _} value ─────────────

  describe "encapsulated? with {:encapsulated, _} tuple" do
    test "returns true for {:encapsulated, fragments} tuple" do
      ds = DataSet.new()

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: {:encapsulated, [<<1, 2>>, <<3, 4>>]},
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}
      assert PixelData.encapsulated?(ds)
    end
  end

  # ── NumberOfFrames edge cases ─────────────────────────────────

  describe "get_number_of_frames edge cases" do
    test "unparseable NumberOfFrames string returns error" do
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(100)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)
      ds = DataSet.put(ds, Tag.number_of_frames(), :IS, "not_a_number")
      assert {:error, :invalid_number_of_frames} = PixelData.frame_count(ds)
    end

    test "empty NumberOfFrames string returns error" do
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(100)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)
      ds = DataSet.put(ds, Tag.number_of_frames(), :IS, "")
      assert {:error, :invalid_number_of_frames} = PixelData.frame_count(ds)
    end

    test "zero NumberOfFrames returns error" do
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(100)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)
      ds = DataSet.put(ds, Tag.number_of_frames(), :IS, "0")
      assert {:error, :invalid_number_of_frames} = PixelData.frame_count(ds)
    end

    test "NumberOfFrames with trailing junk returns error" do
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(100)
      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)
      ds = DataSet.put(ds, Tag.number_of_frames(), :IS, "2junk")
      assert {:error, :invalid_number_of_frames} = PixelData.frame_count(ds)
    end
  end

  # ── frame/2 with {:encapsulated, _} ─────────────────────────

  describe "frame/2 with encapsulated tuple value" do
    test "returns frames from {:encapsulated, fragments} via frames path" do
      ds = DataSet.new()
      ds = DataSet.put(ds, Tag.rows(), :US, <<10::little-16>>)
      ds = DataSet.put(ds, Tag.columns(), :US, <<10::little-16>>)
      ds = DataSet.put(ds, Tag.bits_allocated(), :US, <<8::little-16>>)
      ds = DataSet.put(ds, Tag.samples_per_pixel(), :US, <<1::little-16>>)

      fragment = :crypto.strong_rand_bytes(100)

      elem = %DataElement{
        tag: Tag.pixel_data(),
        vr: :OB,
        value: {:encapsulated, [<<>>, fragment]},
        length: :undefined
      }

      ds = %{ds | elements: Map.put(ds.elements, Tag.pixel_data(), elem)}

      assert {:ok, ^fragment} = PixelData.frame(ds, 0)
      assert {:error, :frame_index_out_of_range} = PixelData.frame(ds, 1)
    end
  end

  # ── decode_us edge case ──────────────────────────────────────

  describe "decode_us edge cases" do
    test "BitsAllocated as integer works" do
      ds = DataSet.new()
      data = :crypto.strong_rand_bytes(32 * 32 * 2)

      ds = DataSet.put(ds, Tag.pixel_data(), :OW, data)

      # Set rows/cols as integers (pre-decoded)
      ds = %{
        ds
        | elements:
            ds.elements
            |> Map.put(
              Tag.rows(),
              %DataElement{tag: Tag.rows(), vr: :US, value: 32, length: 2}
            )
            |> Map.put(
              Tag.columns(),
              %DataElement{tag: Tag.columns(), vr: :US, value: 32, length: 2}
            )
            |> Map.put(
              Tag.bits_allocated(),
              %DataElement{tag: Tag.bits_allocated(), vr: :US, value: 16, length: 2}
            )
            |> Map.put(
              Tag.samples_per_pixel(),
              %DataElement{tag: Tag.samples_per_pixel(), vr: :US, value: 1, length: 2}
            )
      }

      assert {:ok, [frame]} = PixelData.frames(ds)
      assert byte_size(frame) == 32 * 32 * 2
    end
  end

  # ── Property: frame_count == length(frames) ───────────────────

  describe "property: frame_count matches frames length" do
    test "native multi-frame consistency" do
      for num_frames <- [1, 2, 5, 10] do
        frame_size = 8 * 8 * 2
        pixels = :crypto.strong_rand_bytes(frame_size * num_frames)
        ds = image_ds(8, 8, 16, 1, frames: num_frames, pixel_data: pixels)

        {:ok, count} = PixelData.frame_count(ds)
        {:ok, frames} = PixelData.frames(ds)

        assert count == length(frames),
               "frame_count=#{count} != length(frames)=#{length(frames)} for #{num_frames} frames"
      end
    end
  end

  describe "frame/2 - native frame index out of range with unknown frame size" do
    test "returns error when frame_size is 0 and index > 0" do
      # Missing BitsAllocated → frame_size computes to nil/0
      ds =
        DataSet.new()
        |> DataSet.put(Tag.rows(), :US, <<8::little-16>>)
        |> DataSet.put(Tag.columns(), :US, <<8::little-16>>)
        |> DataSet.put(Tag.samples_per_pixel(), :US, <<1::little-16>>)
        |> DataSet.put({0x7FE0, 0x0010}, :OW, :crypto.strong_rand_bytes(128))

      assert {:error, _} = PixelData.frame(ds, 1)
    end
  end

  describe "reassemble_frames error propagation" do
    test "encapsulated frames with single fragment returns frame" do
      # BOT (empty) + one fragment
      frags = [<<>>, <<1, 2, 3, 4>>]
      elem = DataElement.new({0x7FE0, 0x0010}, :OB, frags)

      ds =
        DataSet.new()
        |> DataSet.put(Tag.rows(), :US, <<2::little-16>>)
        |> DataSet.put(Tag.columns(), :US, <<2::little-16>>)
        |> DataSet.put(Tag.bits_allocated(), :US, <<8::little-16>>)
        |> DataSet.put(Tag.samples_per_pixel(), :US, <<1::little-16>>)
        |> DataSet.put(Tag.number_of_frames(), :IS, "1")

      ds = %{ds | elements: Map.put(ds.elements, {0x7FE0, 0x0010}, elem)}

      result = PixelData.frame(ds, 0)
      assert match?({:ok, _}, result)
    end

    test "encapsulated frame index out of range" do
      frags = [<<>>, <<1, 2, 3, 4>>]
      elem = DataElement.new({0x7FE0, 0x0010}, :OB, frags)

      ds =
        DataSet.new()
        |> DataSet.put(Tag.rows(), :US, <<2::little-16>>)
        |> DataSet.put(Tag.columns(), :US, <<2::little-16>>)
        |> DataSet.put(Tag.bits_allocated(), :US, <<8::little-16>>)
        |> DataSet.put(Tag.samples_per_pixel(), :US, <<1::little-16>>)
        |> DataSet.put(Tag.number_of_frames(), :IS, "1")

      ds = %{ds | elements: Map.put(ds.elements, {0x7FE0, 0x0010}, elem)}

      assert {:error, :frame_index_out_of_range} = PixelData.frame(ds, 99)
    end
  end

  describe "native frame edge cases" do
    test "frame_size=0 with index>0 returns out of range" do
      # When Rows=0 → frame_size=0, but NumberOfFrames=2 and index=1
      # Exercises the `true ->` branch in extract_native_frame (L115)
      pixel_data = <<1, 2, 3, 4, 5, 6, 7, 8>>
      elem = DataElement.new({0x7FE0, 0x0010}, :OW, pixel_data)

      ds =
        DataSet.new()
        |> DataSet.put(Tag.rows(), :US, <<0::little-16>>)
        |> DataSet.put(Tag.columns(), :US, <<4::little-16>>)
        |> DataSet.put(Tag.bits_allocated(), :US, <<8::little-16>>)
        |> DataSet.put(Tag.samples_per_pixel(), :US, <<1::little-16>>)
        |> DataSet.put(Tag.number_of_frames(), :IS, "2")

      ds = %{ds | elements: Map.put(ds.elements, {0x7FE0, 0x0010}, elem)}

      # index=0 with frame_size=0 returns entire data
      assert {:ok, ^pixel_data} = PixelData.frame(ds, 0)

      # index=1 with frame_size=0 returns error (can't slice)
      assert {:error, :frame_index_out_of_range} = PixelData.frame(ds, 1)
    end

    test "returns invalid_pixel_data when requested frame exceeds available bytes" do
      ds = image_ds(2, 2, 16, 1, frames: 2, pixel_data: <<0, 1, 2, 3, 4, 5, 6, 7>>)
      assert {:error, :invalid_pixel_data} = PixelData.frame(ds, 1)
    end

    test "returns invalid_number_of_frames instead of raising for zero NumberOfFrames" do
      ds =
        image_ds(2, 2, 8, 1, pixel_data: <<1, 2, 3, 4>>)
        |> DataSet.put(Tag.number_of_frames(), :IS, "0")

      assert {:error, :invalid_number_of_frames} = PixelData.frames(ds)
      assert {:error, :invalid_number_of_frames} = PixelData.frame(ds, 0)
    end
  end
end
