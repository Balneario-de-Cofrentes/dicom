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
end
