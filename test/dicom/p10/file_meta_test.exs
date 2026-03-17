defmodule Dicom.P10.FileMetaTest do
  use ExUnit.Case, async: true

  describe "sanitize_preamble/1" do
    test "zeros out the preamble while preserving DICM and data" do
      # Create a binary with non-zero preamble
      preamble = String.duplicate("X", 128)
      rest = "some data"
      binary = preamble <> "DICM" <> rest

      {:ok, sanitized} = Dicom.P10.FileMeta.sanitize_preamble(binary)

      # Preamble should be zeroed
      assert binary_part(sanitized, 0, 128) == <<0::1024>>
      # DICM should still be there
      assert binary_part(sanitized, 128, 4) == "DICM"
      # Data should be preserved
      assert binary_part(sanitized, 132, byte_size(rest)) == rest
    end

    test "returns error for non-DICOM binary" do
      assert {:error, :invalid_preamble} = Dicom.P10.FileMeta.sanitize_preamble(<<"not dicom">>)
    end

    test "preserves already-clean preamble" do
      clean = <<0::1024, "DICM", "data">>
      {:ok, sanitized} = Dicom.P10.FileMeta.sanitize_preamble(clean)
      assert sanitized == clean
    end
  end

  describe "validate_preamble/1" do
    test "returns :ok for all-zero preamble" do
      binary = <<0::1024, "DICM", "data">>
      assert :ok = Dicom.P10.FileMeta.validate_preamble(binary)
    end

    test "returns :ok for TIFF little-endian preamble" do
      # TIFF LE magic: 49 49 2A 00
      tiff_preamble = <<0x49, 0x49, 0x2A, 0x00>> <> :binary.copy(<<0>>, 124)
      binary = tiff_preamble <> "DICM" <> "data"
      assert :ok = Dicom.P10.FileMeta.validate_preamble(binary)
    end

    test "returns :ok for TIFF big-endian preamble" do
      # TIFF BE magic: 4D 4D 00 2A
      tiff_preamble = <<0x4D, 0x4D, 0x00, 0x2A>> <> :binary.copy(<<0>>, 124)
      binary = tiff_preamble <> "DICM" <> "data"
      assert :ok = Dicom.P10.FileMeta.validate_preamble(binary)
    end

    test "returns warning for non-standard preamble content" do
      bad_preamble = String.duplicate("X", 128)
      binary = bad_preamble <> "DICM" <> "data"
      assert {:warning, :non_standard_preamble} = Dicom.P10.FileMeta.validate_preamble(binary)
    end

    test "returns error for non-DICOM binary" do
      assert {:error, :invalid_preamble} = Dicom.P10.FileMeta.validate_preamble(<<"not dicom">>)
    end
  end
end
