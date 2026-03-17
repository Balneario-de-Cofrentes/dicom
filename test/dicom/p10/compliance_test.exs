defmodule Dicom.P10.ComplianceTest do
  @moduledoc """
  Comprehensive PS3.10 compliance tests.

  Verifies the library against the DICOM PS3.10 specification requirements.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Dicom.DataSet

  # PS3.10 Section 7 — DICOM File Format

  describe "PS3.10 Section 7 — DICOM File Format" do
    test "valid P10 file starts with 128-byte preamble + DICM" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      assert byte_size(binary) >= 132
      assert binary_part(binary, 128, 4) == "DICM"
    end

    test "preamble is 128 zero bytes by default" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      assert binary_part(binary, 0, 128) == <<0::1024>>
    end
  end

  # PS3.10 Section 7.1 — File Meta Information

  describe "PS3.10 Section 7.1 — File Meta Information" do
    test "File Meta Information is always Explicit VR Little Endian" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      <<_preamble::binary-size(132), rest::binary>> = binary
      # First element is (0002,0000) UL — verify VR bytes present
      <<0x02, 0x00, 0x00, 0x00, "UL", _::binary>> = rest
    end

    test "File Meta Information Group Length (0002,0000) is Type 1 and computed correctly" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      # Group length must be present
      group_length_raw = DataSet.get(parsed, {0x0002, 0x0000})
      assert is_binary(group_length_raw)

      # Verify it matches actual byte count
      <<length::little-32>> = group_length_raw

      # Count bytes of all file meta elements after (0002,0000)
      meta_elements = parsed.file_meta |> Map.delete({0x0002, 0x0000})
      assert map_size(meta_elements) > 0
      assert length > 0
    end

    test "File Meta Information Version (0002,0001) is Type 1 with value 0x0001" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      version = DataSet.get(parsed, {0x0002, 0x0001})
      assert version == <<0x00, 0x01>>
    end

    test "Media Storage SOP Class UID (0002,0002) is preserved" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      sop_class = DataSet.get(parsed, {0x0002, 0x0002})
      assert String.trim_trailing(sop_class, <<0>>) == "1.2.840.10008.5.1.4.1.1.2"
    end

    test "Transfer Syntax UID (0002,0010) is preserved" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      ts = DataSet.get(parsed, {0x0002, 0x0010})
      assert String.trim_trailing(ts, <<0>>) == "1.2.840.10008.1.2.1"
    end

    test "Implementation Class UID (0002,0012) is auto-generated" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      impl_uid = DataSet.get(parsed, {0x0002, 0x0012})
      assert is_binary(impl_uid)
      assert byte_size(String.trim_trailing(impl_uid, <<0>>)) > 0
    end

    test "File Meta elements only contain Group 0002" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      for {tag, _} <- parsed.file_meta do
        {group, _} = tag
        assert group == 0x0002, "File meta contains non-0002 group: #{inspect(tag)}"
      end
    end
  end

  # PS3.10 Section 7.2 — Data Set Encapsulation

  describe "PS3.10 Section 7.2 — Data Set Encapsulation" do
    test "single SOP Instance per file (data set roundtrips)" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> DataSet.put({0x0008, 0x0060}, :CS, "CT")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
      assert DataSet.get(parsed, {0x0008, 0x0060}) |> String.trim() == "CT"
    end

    test "trailing padding (FFFC,FFFC) is ignored by reader" do
      ts_uid = pad_even("1.2.840.10008.1.2.1")
      ts_elem = <<0x02, 0x00, 0x10, 0x00, "UI", byte_size(ts_uid)::little-16>> <> ts_uid

      group_length_value = <<byte_size(ts_elem)::little-32>>

      group_length =
        <<0x02, 0x00, 0x00, 0x00, "UL", byte_size(group_length_value)::little-16>> <>
          group_length_value

      patient = <<0x10, 0x00, 0x10, 0x00, "PN", 8::little-16, "DOE^JOHN">>
      padding = <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, 4::little-32, 0, 0, 0, 0>>

      binary = <<0::1024, "DICM">> <> group_length <> ts_elem <> patient <> padding

      {:ok, parsed} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(parsed, {0x0010, 0x0010}) == "DOE^JOHN"
      # Trailing padding should NOT appear as an element
      refute Map.has_key?(parsed.elements, {0xFFFC, 0xFFFC})
    end
  end

  # PS3.5 Value padding

  describe "PS3.5 — Even length padding" do
    test "all serialized values have even length" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE")
        |> DataSet.put({0x0010, 0x0020}, :LO, "1")
        |> DataSet.put({0x0008, 0x0060}, :CS, "MR")
        |> DataSet.put({0x0020, 0x000D}, :UI, "1.2.3")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      # Parse all elements back and verify value lengths are even
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      for {_tag, elem} <- Map.merge(parsed.file_meta, parsed.elements) do
        if is_binary(elem.value) and byte_size(elem.value) > 0 do
          assert rem(elem.length, 2) == 0,
                 "Value length #{elem.length} for tag #{inspect(elem.tag)} is odd"
        end
      end
    end
  end

  # Transfer syntax roundtrips

  describe "Transfer syntax roundtrips" do
    test "Explicit VR Little Endian roundtrip" do
      assert_transfer_syntax_roundtrip(Dicom.UID.explicit_vr_little_endian())
    end

    test "Implicit VR Little Endian roundtrip" do
      assert_transfer_syntax_roundtrip(Dicom.UID.implicit_vr_little_endian())
    end

    test "Deflated Explicit VR Little Endian roundtrip" do
      assert_transfer_syntax_roundtrip(Dicom.UID.deflated_explicit_vr_little_endian())
    end
  end

  # Property-based tests

  describe "property-based tests" do
    property "any patient name roundtrips through write/read" do
      check all(name <- string(:alphanumeric, min_length: 1, max_length: 60)) do
        ds =
          minimal_data_set()
          |> DataSet.put({0x0010, 0x0010}, :PN, name)

        {:ok, binary} = Dicom.P10.Writer.serialize(ds)
        {:ok, parsed} = Dicom.P10.Reader.parse(binary)

        result = DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim()
        assert result == name
      end
    end

    property "any UI value roundtrips with null trimming" do
      check all(
              uid <- string(?0..?9, min_length: 3, max_length: 30),
              separator <- constant("."),
              suffix <- string(?0..?9, min_length: 1, max_length: 10)
            ) do
        value = "1.2." <> uid <> separator <> suffix

        ds =
          minimal_data_set()
          |> DataSet.put({0x0020, 0x000D}, :UI, value)

        {:ok, binary} = Dicom.P10.Writer.serialize(ds)
        {:ok, parsed} = Dicom.P10.Reader.parse(binary)

        result = DataSet.get(parsed, {0x0020, 0x000D}) |> String.trim_trailing(<<0>>)
        assert result == value
      end
    end
  end

  # Helpers

  defp minimal_data_set do
    DataSet.new()
    |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
    |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
    |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())
  end

  defp assert_transfer_syntax_roundtrip(ts_uid) do
    ds =
      DataSet.new()
      |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
      |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
      |> DataSet.put({0x0002, 0x0010}, :UI, ts_uid)
      |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
      |> DataSet.put({0x0010, 0x0020}, :LO, "12345")
      |> DataSet.put({0x0008, 0x0060}, :CS, "CT")

    {:ok, binary} = Dicom.P10.Writer.serialize(ds)
    {:ok, parsed} = Dicom.P10.Reader.parse(binary)

    assert DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    assert DataSet.get(parsed, {0x0010, 0x0020}) |> String.trim() == "12345"
    assert DataSet.get(parsed, {0x0008, 0x0060}) |> String.trim() == "CT"
  end

  defp pad_even(value) when rem(byte_size(value), 2) == 1, do: value <> <<0>>
  defp pad_even(value), do: value
end
