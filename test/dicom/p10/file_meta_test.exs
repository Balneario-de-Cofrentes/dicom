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
end
