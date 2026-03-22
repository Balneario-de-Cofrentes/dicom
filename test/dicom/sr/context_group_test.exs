defmodule Dicom.SR.ContextGroupTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, ContextGroup}
  alias Dicom.SR.ContextGroup.Registry
  alias Dicom.SR.Templates.Helpers

  # ── Registry tests ────────────────────────────────────

  describe "Registry.size/0" do
    test "contains 1200+ context groups" do
      assert Registry.size() >= 1200
    end
  end

  describe "Registry.lookup/1" do
    test "returns {:ok, entry} for CID 244 (Laterality)" do
      assert {:ok, entry} = Registry.lookup(244)
      assert entry.name == "Laterality"
      assert entry.extensible == false
      assert %MapSet{} = entry.codes
    end

    test "returns {:ok, entry} for CID 29 (Acquisition Modality)" do
      assert {:ok, entry} = Registry.lookup(29)
      assert entry.name == "Acquisition Modality"
      assert entry.extensible == true
    end

    test "returns {:ok, entry} for CID 7021 (Measurement Report Document Title)" do
      assert {:ok, entry} = Registry.lookup(7021)
      assert entry.name == "Measurement Report Document Title"
      assert entry.extensible == true
    end

    test "returns :error for non-existent CID" do
      assert :error = Registry.lookup(999_999)
    end
  end

  describe "Registry.member?/3" do
    test "returns true for code in CID 247" do
      # Right is in CID 247 (Laterality Left-Right Only)
      assert Registry.member?(247, "SCT", "24028007") == true
    end

    test "returns false for code not in CID 247" do
      assert Registry.member?(247, "SCT", "0000000") == false
    end

    test "returns :unknown_cid for non-existent CID" do
      assert Registry.member?(999_999, "SCT", "24028007") == :unknown_cid
    end
  end

  describe "Registry.extensible?/1" do
    test "CID 244 is non-extensible" do
      assert Registry.extensible?(244) == false
    end

    test "CID 29 is extensible" do
      assert Registry.extensible?(29) == true
    end

    test "returns :unknown_cid for non-existent CID" do
      assert Registry.extensible?(999_999) == :unknown_cid
    end
  end

  describe "include resolution" do
    test "CID 244 contains codes from CID 247" do
      # CID 244 includes CID 247
      # CID 247 has SCT:24028007 (Right) and SCT:7771000 (Left)
      assert Registry.member?(244, "SCT", "24028007") == true
      assert Registry.member?(244, "SCT", "7771000") == true
    end

    test "CID 244 contains its own codes" do
      # CID 244 has SCT:51440002 (Bilateral) and SCT:66459002 (Unilateral)
      assert Registry.member?(244, "SCT", "51440002") == true
      assert Registry.member?(244, "SCT", "66459002") == true
    end

    test "CID 244 has exactly 4 codes (2 own + 2 from CID 247)" do
      {:ok, entry} = Registry.lookup(244)
      assert MapSet.size(entry.codes) == 4
    end
  end

  # ── ContextGroup public API tests ────────────────────

  describe "ContextGroup.validate/2" do
    test "returns :ok for code in non-extensible CID" do
      code = Code.new("24028007", "SCT", "Right")
      assert ContextGroup.validate(code, 244) == :ok
    end

    test "returns {:error, :not_in_cid} for code not in non-extensible CID" do
      code = Code.new("0000000", "SCT", "Unknown")
      assert ContextGroup.validate(code, 244) == {:error, :not_in_cid}
    end

    test "returns :ok for code in extensible CID" do
      # CID 29 is extensible; use a code that is actually in it
      {:ok, entry} = Registry.lookup(29)
      {scheme, value} = entry.codes |> MapSet.to_list() |> hd()
      code = Code.new(value, scheme, "Some meaning")
      assert ContextGroup.validate(code, 29) == :ok
    end

    test "returns {:ok, :extensible} for non-member code in extensible CID" do
      code = Code.new("FAKE_VALUE", "FAKE", "Fake meaning")
      assert ContextGroup.validate(code, 29) == {:ok, :extensible}
    end

    test "returns {:error, :unknown_cid} for non-existent CID" do
      code = Code.new("24028007", "SCT", "Right")
      assert ContextGroup.validate(code, 999_999) == {:error, :unknown_cid}
    end
  end

  describe "ContextGroup.valid?/2" do
    test "returns true for code in CID" do
      code = Code.new("24028007", "SCT", "Right")
      assert ContextGroup.valid?(code, 244) == true
    end

    test "returns true for non-member code in extensible CID" do
      code = Code.new("FAKE_VALUE", "FAKE", "Fake meaning")
      assert ContextGroup.valid?(code, 29) == true
    end

    test "returns false for non-member code in non-extensible CID" do
      code = Code.new("0000000", "SCT", "Unknown")
      assert ContextGroup.valid?(code, 244) == false
    end

    test "returns false for unknown CID" do
      code = Code.new("24028007", "SCT", "Right")
      assert ContextGroup.valid?(code, 999_999) == false
    end
  end

  describe "ContextGroup.name/1" do
    test "returns name for known CID" do
      assert {:ok, "Laterality"} = ContextGroup.name(244)
    end

    test "returns :error for unknown CID" do
      assert :error = ContextGroup.name(999_999)
    end
  end

  describe "ContextGroup.extensible?/1" do
    test "returns false for non-extensible CID" do
      assert ContextGroup.extensible?(244) == false
    end

    test "returns true for extensible CID" do
      assert ContextGroup.extensible?(29) == true
    end

    test "returns :error for unknown CID" do
      assert ContextGroup.extensible?(999_999) == :error
    end
  end

  describe "ContextGroup.size/0" do
    test "delegates to Registry.size/0" do
      assert ContextGroup.size() == Registry.size()
      assert ContextGroup.size() >= 1200
    end
  end

  # ── Helpers.validate_code!/3 tests ───────────────────

  describe "Helpers.validate_code!/3" do
    test "returns code when valid in non-extensible CID" do
      code = Code.new("24028007", "SCT", "Right")
      assert Helpers.validate_code!(code, 244, "laterality") == code
    end

    test "returns code when non-member in extensible CID" do
      code = Code.new("FAKE_VALUE", "FAKE", "Fake meaning")
      assert Helpers.validate_code!(code, 29, "modality") == code
    end

    test "raises ArgumentError for non-member in non-extensible CID" do
      code = Code.new("0000000", "SCT", "Unknown")

      assert_raise ArgumentError,
                   ~r/laterality: code SCT:0000000 is not a member of CID 244/,
                   fn ->
                     Helpers.validate_code!(code, 244, "laterality")
                   end
    end

    test "returns code for unknown CID (pass-through)" do
      code = Code.new("24028007", "SCT", "Right")
      assert Helpers.validate_code!(code, 999_999, "field") == code
    end
  end
end
