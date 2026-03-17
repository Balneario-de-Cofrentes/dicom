defmodule Dicom.TransferSyntaxTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Dicom.TransferSyntax

  describe "struct fields" do
    test "includes retired and fragmentable boolean fields" do
      {:ok, ts} = TransferSyntax.from_uid(Dicom.UID.explicit_vr_little_endian())
      assert Map.has_key?(ts, :retired)
      assert Map.has_key?(ts, :fragmentable)
      assert is_boolean(ts.retired)
      assert is_boolean(ts.fragmentable)
    end
  end

  describe "all/0" do
    test "returns all registered transfer syntaxes" do
      all = TransferSyntax.all()
      assert is_list(all)
      assert length(all) >= 49
      assert Enum.all?(all, &match?(%TransferSyntax{}, &1))
    end

    test "each entry has valid UID string" do
      for ts <- TransferSyntax.all() do
        assert is_binary(ts.uid)
        assert String.starts_with?(ts.uid, "1.2.840.10008.1.2")
      end
    end

    test "no duplicate UIDs" do
      uids = Enum.map(TransferSyntax.all(), & &1.uid)
      assert length(uids) == length(Enum.uniq(uids))
    end
  end

  describe "active/0" do
    test "returns only non-retired transfer syntaxes" do
      active = TransferSyntax.active()
      assert is_list(active)
      assert Enum.all?(active, fn ts -> ts.retired == false end)
    end

    test "active count is less than all count" do
      assert length(TransferSyntax.active()) < length(TransferSyntax.all())
    end

    test "includes standard active syntaxes" do
      active_uids = MapSet.new(TransferSyntax.active(), & &1.uid)
      assert MapSet.member?(active_uids, Dicom.UID.implicit_vr_little_endian())
      assert MapSet.member?(active_uids, Dicom.UID.explicit_vr_little_endian())
      assert MapSet.member?(active_uids, Dicom.UID.jpeg_baseline())
      assert MapSet.member?(active_uids, Dicom.UID.jpeg_2000_lossless())
      assert MapSet.member?(active_uids, Dicom.UID.rle_lossless())
    end
  end

  describe "retired?/1" do
    test "returns true for retired transfer syntaxes" do
      # Explicit VR Big Endian is retired
      assert TransferSyntax.retired?(Dicom.UID.explicit_vr_big_endian())
    end

    test "returns false for active transfer syntaxes" do
      refute TransferSyntax.retired?(Dicom.UID.explicit_vr_little_endian())
      refute TransferSyntax.retired?(Dicom.UID.implicit_vr_little_endian())
      refute TransferSyntax.retired?(Dicom.UID.jpeg_baseline())
    end

    test "returns false for unknown UIDs" do
      refute TransferSyntax.retired?("1.2.3.4.5.6.7.8.9")
    end

    test "retired JPEG processes are marked retired" do
      # JPEG Extended (Process 3 & 5) - retired
      assert TransferSyntax.retired?("1.2.840.10008.1.2.4.52")
      # JPEG Spectral Selection, Non-Hierarchical (Process 6 & 8) - retired
      assert TransferSyntax.retired?("1.2.840.10008.1.2.4.53")
    end
  end

  describe "fragmentable?/1" do
    test "returns true for fragmentable transfer syntaxes" do
      # MPEG2 Main Profile is fragmentable
      assert TransferSyntax.fragmentable?("1.2.840.10008.1.2.4.100")
      # HEVC Main Profile
      assert TransferSyntax.fragmentable?("1.2.840.10008.1.2.4.107")
    end

    test "returns false for non-fragmentable transfer syntaxes" do
      refute TransferSyntax.fragmentable?(Dicom.UID.explicit_vr_little_endian())
      refute TransferSyntax.fragmentable?(Dicom.UID.implicit_vr_little_endian())
      refute TransferSyntax.fragmentable?(Dicom.UID.jpeg_baseline())
    end

    test "returns false for unknown UIDs" do
      refute TransferSyntax.fragmentable?("1.2.3.4.5.6.7.8.9")
    end
  end

  describe "known?/1" do
    test "returns true for all registered UIDs" do
      for ts <- TransferSyntax.all() do
        assert TransferSyntax.known?(ts.uid),
               "Expected #{ts.uid} (#{ts.name}) to be known"
      end
    end

    test "returns false for unknown UIDs" do
      refute TransferSyntax.known?("1.2.3.4.5.6.7.8.9")
      refute TransferSyntax.known?("not.a.uid")
    end
  end

  describe "specific transfer syntax entries" do
    test "uncompressed syntaxes" do
      assert {:ok, %TransferSyntax{compressed: false, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2")

      assert {:ok, %TransferSyntax{compressed: false, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.1")

      assert {:ok, %TransferSyntax{compressed: false, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.1.99")

      assert {:ok, %TransferSyntax{compressed: false, retired: true}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.2")
    end

    test "active JPEG syntaxes" do
      # JPEG Baseline (Process 1) - active
      assert {:ok, %TransferSyntax{compressed: true, retired: false, name: "JPEG Baseline" <> _}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.50")

      # JPEG Extended (Process 2 & 4) - active
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.51")

      # JPEG Lossless Non-Hierarchical (Process 14)
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.57")

      # JPEG Lossless SV1
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.70")
    end

    test "retired JPEG processes" do
      retired_jpeg_uids = [
        "1.2.840.10008.1.2.4.52",
        "1.2.840.10008.1.2.4.53",
        "1.2.840.10008.1.2.4.54",
        "1.2.840.10008.1.2.4.55",
        "1.2.840.10008.1.2.4.56",
        "1.2.840.10008.1.2.4.58",
        "1.2.840.10008.1.2.4.59",
        "1.2.840.10008.1.2.4.60",
        "1.2.840.10008.1.2.4.61",
        "1.2.840.10008.1.2.4.62",
        "1.2.840.10008.1.2.4.63",
        "1.2.840.10008.1.2.4.64",
        "1.2.840.10008.1.2.4.65",
        "1.2.840.10008.1.2.4.66"
      ]

      for uid <- retired_jpeg_uids do
        assert {:ok, %TransferSyntax{retired: true, compressed: true}} =
                 TransferSyntax.from_uid(uid),
               "Expected #{uid} to be retired and compressed"
      end
    end

    test "JPEG-LS syntaxes" do
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.80")

      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.81")
    end

    test "JPEG 2000 syntaxes" do
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.90")

      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.91")

      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.92")

      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.93")
    end

    test "MPEG/HEVC syntaxes are fragmentable" do
      mpeg_hevc_uids = [
        "1.2.840.10008.1.2.4.100",
        "1.2.840.10008.1.2.4.101",
        "1.2.840.10008.1.2.4.102",
        "1.2.840.10008.1.2.4.103",
        "1.2.840.10008.1.2.4.104",
        "1.2.840.10008.1.2.4.105",
        "1.2.840.10008.1.2.4.106",
        "1.2.840.10008.1.2.4.107",
        "1.2.840.10008.1.2.4.108"
      ]

      for uid <- mpeg_hevc_uids do
        assert {:ok, %TransferSyntax{fragmentable: true, compressed: true}} =
                 TransferSyntax.from_uid(uid),
               "Expected #{uid} to be fragmentable and compressed"
      end
    end

    test "HTJ2K syntaxes" do
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.201")

      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.202")

      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.203")
    end

    test "JPIP syntaxes" do
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.94")

      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.95")
    end

    test "RLE Lossless" do
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.5")
    end

    test "JPEG XL syntaxes" do
      # JPEG XL Lossless
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.110")

      # JPEG XL JPEG Recompression
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.111")

      # JPEG XL
      assert {:ok, %TransferSyntax{compressed: true, retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.4.112")
    end

    test "SMPTE ST 2110 syntaxes" do
      # SMPTE ST 2110-20 Uncompressed Progressive Active Video
      assert {:ok, %TransferSyntax{retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.7.1")

      # SMPTE ST 2110-20 Uncompressed Interlaced Active Video
      assert {:ok, %TransferSyntax{retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.7.2")

      # SMPTE ST 2110-30 PCM Digital Audio
      assert {:ok, %TransferSyntax{retired: false}} =
               TransferSyntax.from_uid("1.2.840.10008.1.2.7.3")
    end
  end

  describe "backward compatibility" do
    test "from_uid still works for all original 29 UIDs" do
      original_uids = [
        "1.2.840.10008.1.2",
        "1.2.840.10008.1.2.1",
        "1.2.840.10008.1.2.1.99",
        "1.2.840.10008.1.2.2",
        "1.2.840.10008.1.2.4.50",
        "1.2.840.10008.1.2.4.51",
        "1.2.840.10008.1.2.4.57",
        "1.2.840.10008.1.2.4.70",
        "1.2.840.10008.1.2.4.80",
        "1.2.840.10008.1.2.4.81",
        "1.2.840.10008.1.2.4.90",
        "1.2.840.10008.1.2.4.91",
        "1.2.840.10008.1.2.4.92",
        "1.2.840.10008.1.2.4.93",
        "1.2.840.10008.1.2.4.100",
        "1.2.840.10008.1.2.4.101",
        "1.2.840.10008.1.2.4.102",
        "1.2.840.10008.1.2.4.103",
        "1.2.840.10008.1.2.4.104",
        "1.2.840.10008.1.2.4.105",
        "1.2.840.10008.1.2.4.106",
        "1.2.840.10008.1.2.4.107",
        "1.2.840.10008.1.2.4.108",
        "1.2.840.10008.1.2.4.201",
        "1.2.840.10008.1.2.4.202",
        "1.2.840.10008.1.2.4.203",
        "1.2.840.10008.1.2.4.94",
        "1.2.840.10008.1.2.4.95",
        "1.2.840.10008.1.2.5"
      ]

      for uid <- original_uids do
        assert {:ok, %TransferSyntax{uid: ^uid}} = TransferSyntax.from_uid(uid),
               "Original UID #{uid} should still be resolvable"
      end
    end

    test "encoding/1 unchanged behavior" do
      assert {:ok, {:implicit, :little}} = TransferSyntax.encoding("1.2.840.10008.1.2")
      assert {:ok, {:explicit, :little}} = TransferSyntax.encoding("1.2.840.10008.1.2.1")
      assert {:ok, {:explicit, :big}} = TransferSyntax.encoding("1.2.840.10008.1.2.2")
      assert {:error, :unknown_transfer_syntax} = TransferSyntax.encoding("1.2.3.4.5.6.7.8.9")

      assert {:ok, {:explicit, :little}} =
               TransferSyntax.encoding("1.2.3.4.5.6.7.8.9", lenient: true)
    end

    test "compressed?/1 unchanged behavior" do
      assert TransferSyntax.compressed?("1.2.840.10008.1.2.4.50")
      assert TransferSyntax.compressed?("1.2.840.10008.1.2.5")
      refute TransferSyntax.compressed?("1.2.840.10008.1.2.1")
      refute TransferSyntax.compressed?("1.2.840.10008.1.2")
      refute TransferSyntax.compressed?("1.2.3.4.5.6.7.8.9")
    end

    test "implicit_vr?/1 unchanged behavior" do
      assert TransferSyntax.implicit_vr?("1.2.840.10008.1.2")
      refute TransferSyntax.implicit_vr?("1.2.840.10008.1.2.1")
    end

    test "extract_uid/1 unchanged behavior" do
      elem = Dicom.DataElement.new({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      assert TransferSyntax.extract_uid(%{{0x0002, 0x0010} => elem}) == "1.2.840.10008.1.2.1"
      assert TransferSyntax.extract_uid(%{}) == "1.2.840.10008.1.2"
    end
  end

  describe "property tests" do
    property "all entries pass known?/1" do
      all_uids = Enum.map(TransferSyntax.all(), & &1.uid)

      check all(uid <- member_of(all_uids)) do
        assert TransferSyntax.known?(uid)
      end
    end

    property "from_uid succeeds for every entry in all/0" do
      all_uids = Enum.map(TransferSyntax.all(), & &1.uid)

      check all(uid <- member_of(all_uids)) do
        assert {:ok, %TransferSyntax{uid: ^uid}} = TransferSyntax.from_uid(uid)
      end
    end
  end
end
