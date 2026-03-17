defmodule Dicom.SOPClassTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Dicom.SOPClass, as: SopClass

  describe "struct fields" do
    test "has all expected fields" do
      {:ok, sop} = SopClass.from_uid("1.2.840.10008.5.1.4.1.1.2")
      assert %SopClass{uid: _, name: _, type: _, modality: _, retired: _} = sop
    end

    test "CT Image Storage has correct metadata" do
      {:ok, sop} = SopClass.from_uid("1.2.840.10008.5.1.4.1.1.2")
      assert sop.name == "CT Image Storage"
      assert sop.type == :storage
      assert sop.modality == "CT"
      assert sop.retired == false
    end

    test "MR Image Storage has correct metadata" do
      {:ok, sop} = SopClass.from_uid("1.2.840.10008.5.1.4.1.1.4")
      assert sop.name == "MR Image Storage"
      assert sop.type == :storage
      assert sop.modality == "MR"
      assert sop.retired == false
    end

    test "Verification SOP Class has correct metadata" do
      {:ok, sop} = SopClass.from_uid("1.2.840.10008.1.1")
      assert sop.name == "Verification SOP Class"
      assert sop.type == :verification
      assert sop.modality == nil
      assert sop.retired == false
    end
  end

  describe "all/0" do
    test "returns all registered SOP classes" do
      all = SopClass.all()
      assert is_list(all)
      # 183 storage + ~50 service = >= 210
      assert length(all) >= 210
    end

    test "every entry is a SopClass struct" do
      assert Enum.all?(SopClass.all(), &match?(%SopClass{}, &1))
    end

    test "no duplicate UIDs" do
      uids = Enum.map(SopClass.all(), & &1.uid)
      assert length(uids) == length(Enum.uniq(uids))
    end

    test "every entry has a non-empty name" do
      for sop <- SopClass.all() do
        assert is_binary(sop.name) and byte_size(sop.name) > 0,
               "SOP class #{sop.uid} has empty name"
      end
    end

    test "every entry has a valid type" do
      valid_types = [
        :storage,
        :query_retrieve,
        :verification,
        :print,
        :worklist,
        :media,
        :protocol,
        :service
      ]

      for sop <- SopClass.all() do
        assert sop.type in valid_types,
               "SOP class #{sop.uid} has invalid type #{inspect(sop.type)}"
      end
    end
  end

  describe "active/0" do
    test "returns only non-retired SOP classes" do
      active = SopClass.active()
      assert Enum.all?(active, fn sop -> sop.retired == false end)
    end

    test "active count is less than all count" do
      assert length(SopClass.active()) < length(SopClass.all())
    end

    test "includes common storage classes" do
      active_uids = MapSet.new(SopClass.active(), & &1.uid)
      # CT, MR, US should be active
      assert MapSet.member?(active_uids, "1.2.840.10008.5.1.4.1.1.2")
      assert MapSet.member?(active_uids, "1.2.840.10008.5.1.4.1.1.4")
      assert MapSet.member?(active_uids, "1.2.840.10008.5.1.4.1.1.6.1")
    end
  end

  describe "storage/0" do
    test "returns only storage SOP classes" do
      storage = SopClass.storage()
      assert is_list(storage)
      # At least 170 storage classes
      assert length(storage) >= 170
      assert Enum.all?(storage, fn sop -> sop.type == :storage end)
    end

    test "includes CT, MR, US, DX, CR" do
      storage_uids = MapSet.new(SopClass.storage(), & &1.uid)
      assert MapSet.member?(storage_uids, "1.2.840.10008.5.1.4.1.1.2")
      assert MapSet.member?(storage_uids, "1.2.840.10008.5.1.4.1.1.4")
      assert MapSet.member?(storage_uids, "1.2.840.10008.5.1.4.1.1.6.1")
      assert MapSet.member?(storage_uids, "1.2.840.10008.5.1.4.1.1.1.1")
      assert MapSet.member?(storage_uids, "1.2.840.10008.5.1.4.1.1.1")
    end
  end

  describe "from_uid/1" do
    test "returns {:ok, sop_class} for known UIDs" do
      assert {:ok, %SopClass{uid: "1.2.840.10008.5.1.4.1.1.2"}} =
               SopClass.from_uid("1.2.840.10008.5.1.4.1.1.2")
    end

    test "returns {:error, :unknown_sop_class} for unknown UIDs" do
      assert {:error, :unknown_sop_class} = SopClass.from_uid("1.2.3.4.5.6.7.8.9")
    end

    test "returns {:error, :unknown_sop_class} for transfer syntax UIDs" do
      assert {:error, :unknown_sop_class} = SopClass.from_uid("1.2.840.10008.1.2.1")
    end
  end

  describe "known?/1" do
    test "returns true for known SOP classes" do
      assert SopClass.known?("1.2.840.10008.5.1.4.1.1.2")
      assert SopClass.known?("1.2.840.10008.1.1")
    end

    test "returns false for unknown UIDs" do
      refute SopClass.known?("1.2.3.4.5.6.7.8.9")
    end
  end

  describe "by_type/1" do
    test "returns storage classes" do
      storage = SopClass.by_type(:storage)
      assert length(storage) >= 170
      assert Enum.all?(storage, fn sop -> sop.type == :storage end)
    end

    test "returns query_retrieve classes" do
      qr = SopClass.by_type(:query_retrieve)
      assert length(qr) >= 6
      assert Enum.all?(qr, fn sop -> sop.type == :query_retrieve end)
    end

    test "returns verification classes" do
      ver = SopClass.by_type(:verification)
      assert length(ver) >= 1
      assert Enum.all?(ver, fn sop -> sop.type == :verification end)
    end

    test "returns print classes" do
      print = SopClass.by_type(:print)
      assert length(print) >= 5
      assert Enum.all?(print, fn sop -> sop.type == :print end)
    end

    test "returns empty list for unknown type" do
      assert SopClass.by_type(:nonexistent) == []
    end
  end

  describe "by_modality/1" do
    test "CT modality returns CT-related SOP classes" do
      ct = SopClass.by_modality("CT")
      assert length(ct) >= 2
      ct_names = Enum.map(ct, & &1.name)
      assert "CT Image Storage" in ct_names
      assert "Enhanced CT Image Storage" in ct_names
      assert "Legacy Converted Enhanced CT Image Storage" in ct_names
    end

    test "MR modality returns MR-related SOP classes" do
      mr = SopClass.by_modality("MR")
      assert length(mr) >= 2
      mr_names = Enum.map(mr, & &1.name)
      assert "MR Image Storage" in mr_names
      assert "Enhanced MR Image Storage" in mr_names
    end

    test "US modality returns ultrasound SOP classes" do
      us = SopClass.by_modality("US")
      assert length(us) >= 1
    end

    test "returns empty list for unknown modality" do
      assert SopClass.by_modality("NONEXISTENT") == []
    end

    test "common modalities are present" do
      for modality <- ~w(CT MR US DX CR NM SC SR) do
        result = SopClass.by_modality(modality)

        assert length(result) >= 1,
               "Expected at least 1 SOP class for modality #{modality}, got #{length(result)}"
      end
    end
  end

  describe "storage?/1" do
    test "returns true for storage SOP classes" do
      # CT Image Storage
      assert SopClass.storage?("1.2.840.10008.5.1.4.1.1.2")
      # MR Image Storage
      assert SopClass.storage?("1.2.840.10008.5.1.4.1.1.4")
      # US Image Storage
      assert SopClass.storage?("1.2.840.10008.5.1.4.1.1.6.1")
    end

    test "returns false for non-storage SOP classes" do
      # Verification
      refute SopClass.storage?("1.2.840.10008.1.1")
      # Patient Root Q/R FIND
      refute SopClass.storage?("1.2.840.10008.5.1.4.1.2.1.1")
    end

    test "returns false for unknown UIDs" do
      refute SopClass.storage?("1.2.3.4.5.6.7.8.9")
    end

    test "handles edge cases correctly" do
      # Hanging Protocol Storage — has different prefix than most storage classes
      assert SopClass.storage?("1.2.840.10008.5.1.4.38.1")
      # Color Palette Storage
      assert SopClass.storage?("1.2.840.10008.5.1.4.39.1")
    end
  end

  describe "retired?/1" do
    test "returns true for known retired SOP classes" do
      # Hardcoded X-Ray Angiographic Bi-Plane Image Storage (Retired)
      assert SopClass.retired?("1.2.840.10008.5.1.4.1.1.12.3")
      # Nuclear Medicine Image Storage (Retired)
      assert SopClass.retired?("1.2.840.10008.5.1.4.1.1.5")
      # Standalone Modality LUT Storage (Retired)
      assert SopClass.retired?("1.2.840.10008.5.1.4.1.1.10")
    end

    test "returns false for active SOP classes" do
      refute SopClass.retired?("1.2.840.10008.5.1.4.1.1.2")
      refute SopClass.retired?("1.2.840.10008.5.1.4.1.1.4")
    end

    test "returns false for unknown UIDs" do
      refute SopClass.retired?("1.2.3.4.5.6.7.8.9")
    end
  end

  describe "name/1" do
    test "returns {:ok, name} for known UIDs" do
      assert {:ok, "CT Image Storage"} = SopClass.name("1.2.840.10008.5.1.4.1.1.2")
      assert {:ok, "Verification SOP Class"} = SopClass.name("1.2.840.10008.1.1")
    end

    test "returns {:error, :unknown_sop_class} for unknown UIDs" do
      assert {:error, :unknown_sop_class} = SopClass.name("1.2.3.4.5.6.7.8.9")
    end
  end

  describe "backward compatibility" do
    test "UID.storage_sop_class?/1 delegates to SopClass.storage?/1" do
      # These should still work after delegation
      assert Dicom.UID.storage_sop_class?("1.2.840.10008.5.1.4.1.1.2")
      assert Dicom.UID.storage_sop_class?("1.2.840.10008.5.1.4.1.1.4")
      assert Dicom.UID.storage_sop_class?("1.2.840.10008.5.1.4.1.1.6.1")
      refute Dicom.UID.storage_sop_class?("1.2.840.10008.1.1")
      refute Dicom.UID.storage_sop_class?("1.2.3.4.5.6.7.8.9")
    end

    test "edge cases that old prefix-based check got wrong" do
      # Hanging Protocol Storage — NOT under 1.2.840.10008.5.1.4.1.1 prefix
      # Old implementation returned false, new one should return true
      assert Dicom.UID.storage_sop_class?("1.2.840.10008.5.1.4.38.1")
      # Color Palette Storage
      assert Dicom.UID.storage_sop_class?("1.2.840.10008.5.1.4.39.1")
    end
  end

  describe "modality mapping" do
    test "RT sub-modalities are correctly mapped" do
      {:ok, rt_plan} = SopClass.from_uid("1.2.840.10008.5.1.4.1.1.481.5")
      assert rt_plan.modality == "RTPLAN"

      {:ok, rt_dose} = SopClass.from_uid("1.2.840.10008.5.1.4.1.1.481.2")
      assert rt_dose.modality == "RTDOSE"

      {:ok, rt_struct} = SopClass.from_uid("1.2.840.10008.5.1.4.1.1.481.3")
      assert rt_struct.modality == "RTSTRUCT"
    end

    test "SR is correctly mapped" do
      {:ok, sr} = SopClass.from_uid("1.2.840.10008.5.1.4.1.1.88.11")
      assert sr.modality == "SR"
    end

    test "non-storage classes have nil modality" do
      {:ok, ver} = SopClass.from_uid("1.2.840.10008.1.1")
      assert ver.modality == nil

      {:ok, qr} = SopClass.from_uid("1.2.840.10008.5.1.4.1.2.1.1")
      assert qr.modality == nil
    end

    test "common modality codes are mapped correctly" do
      modality_uids = %{
        "1.2.840.10008.5.1.4.1.1.2" => "CT",
        "1.2.840.10008.5.1.4.1.1.4" => "MR",
        "1.2.840.10008.5.1.4.1.1.6.1" => "US",
        "1.2.840.10008.5.1.4.1.1.1.1" => "DX",
        "1.2.840.10008.5.1.4.1.1.1" => "CR",
        "1.2.840.10008.5.1.4.1.1.20" => "NM",
        "1.2.840.10008.5.1.4.1.1.7" => "SC",
        "1.2.840.10008.5.1.4.1.1.66.4" => "SEG"
      }

      for {uid, expected_modality} <- modality_uids do
        {:ok, sop} = SopClass.from_uid(uid)

        assert sop.modality == expected_modality,
               "Expected #{uid} (#{sop.name}) to have modality #{expected_modality}, got #{inspect(sop.modality)}"
      end
    end
  end

  describe "property tests" do
    property "all entries pass known?/1" do
      all_uids = Enum.map(SopClass.all(), & &1.uid)

      check all(uid <- member_of(all_uids)) do
        assert SopClass.known?(uid)
      end
    end

    property "from_uid succeeds for every entry in all/0" do
      all_uids = Enum.map(SopClass.all(), & &1.uid)

      check all(uid <- member_of(all_uids)) do
        assert {:ok, %SopClass{uid: ^uid}} = SopClass.from_uid(uid)
      end
    end

    property "storage entries are in storage?/1 MapSet" do
      storage_uids = Enum.map(SopClass.storage(), & &1.uid)

      check all(uid <- member_of(storage_uids)) do
        assert SopClass.storage?(uid)
      end
    end
  end
end
