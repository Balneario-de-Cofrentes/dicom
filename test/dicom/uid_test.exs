defmodule Dicom.UIDTest do
  use ExUnit.Case, async: true

  describe "generate/0" do
    test "generates valid UID" do
      uid = Dicom.UID.generate()
      assert is_binary(uid)
      assert byte_size(uid) <= 64
    end

    test "generates unique UIDs" do
      uid1 = Dicom.UID.generate()
      uid2 = Dicom.UID.generate()
      assert uid1 != uid2
    end

    test "generated UID matches DICOM format" do
      uid = Dicom.UID.generate()
      # UIDs are dot-separated numeric components
      assert Regex.match?(~r/^[0-9]+(\.[0-9]+)+$/, uid)
    end

    test "generated UID starts with org root" do
      uid = Dicom.UID.generate()
      assert String.starts_with?(uid, "1.2.826.0.1.3680043.10.1137.")
    end
  end

  describe "valid?/1" do
    test "accepts valid UIDs" do
      assert Dicom.UID.valid?("1.2.840.10008.1.2")
      assert Dicom.UID.valid?("1.2.3.4")
    end

    test "rejects UIDs longer than 64 characters" do
      long = "1.2." <> String.duplicate("1234567890.", 6)
      refute Dicom.UID.valid?(long)
    end

    test "rejects empty string" do
      refute Dicom.UID.valid?("")
    end

    test "rejects UIDs with invalid characters" do
      refute Dicom.UID.valid?("1.2.abc")
      refute Dicom.UID.valid?("1.2.3 4")
    end

    test "rejects UIDs with leading zeros in components" do
      refute Dicom.UID.valid?("1.02.3")
    end

    test "accepts single-digit zero component" do
      assert Dicom.UID.valid?("1.0.3")
    end
  end
end
