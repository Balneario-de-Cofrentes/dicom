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

    test "rejects UID with single component" do
      refute Dicom.UID.valid?("12345")
    end

    test "rejects UID with trailing dot" do
      refute Dicom.UID.valid?("1.2.3.")
    end

    test "rejects UID with consecutive dots" do
      refute Dicom.UID.valid?("1..2.3")
    end

    test "rejects invalid root arcs" do
      refute Dicom.UID.valid?("3.40.5")
      refute Dicom.UID.valid?("1.40.5")
      refute Dicom.UID.valid?("2.-1.5")
    end

    test "rejects non-binary input" do
      refute Dicom.UID.valid?(123)
      refute Dicom.UID.valid?(nil)
    end
  end

  describe "transfer_syntax?/1" do
    test "returns true for known transfer syntaxes" do
      assert Dicom.UID.transfer_syntax?("1.2.840.10008.1.2")
      assert Dicom.UID.transfer_syntax?("1.2.840.10008.1.2.1")
      assert Dicom.UID.transfer_syntax?("1.2.840.10008.1.2.4.50")
    end

    test "returns false for Storage Commitment Push Model (false positive fix)" do
      refute Dicom.UID.transfer_syntax?("1.2.840.10008.1.20.1")
    end

    test "returns false for non-transfer-syntax UIDs" do
      refute Dicom.UID.transfer_syntax?("1.2.840.10008.5.1.4.1.1.2")
      refute Dicom.UID.transfer_syntax?("1.2.3.4.5")
    end
  end

  describe "generate/0 validity" do
    test "generated UIDs always pass valid?/1" do
      for _ <- 1..100 do
        uid = Dicom.UID.generate()
        assert Dicom.UID.valid?(uid), "Generated UID #{uid} is not valid"
      end
    end

    test "generated UIDs are <= 64 characters" do
      for _ <- 1..100 do
        uid = Dicom.UID.generate()
        assert byte_size(uid) <= 64, "Generated UID #{uid} exceeds 64 chars (#{byte_size(uid)})"
      end
    end
  end
end
