defmodule Dicom.P10.ReaderTest do
  use ExUnit.Case, async: true

  alias Dicom.DataSet

  describe "parse/1" do
    test "rejects binaries without DICM prefix" do
      assert {:error, :invalid_preamble} = Dicom.P10.Reader.parse(<<"not dicom">>)
    end

    test "rejects binary shorter than 132 bytes" do
      assert {:error, :invalid_preamble} = Dicom.P10.Reader.parse(<<0::128>>)
    end

    test "parses a minimal valid P10 binary" do
      binary = build_p10_binary([])
      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert %DataSet{} = ds
    end

    test "parses file meta information in Explicit VR Little Endian" do
      file_meta_elements = [
        elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      ]

      binary = build_p10_binary(file_meta_elements)
      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      ts = DataSet.get(ds, {0x0002, 0x0010})
      assert String.trim_trailing(ts, <<0>>) == "1.2.840.10008.1.2.1"
    end

    test "ignores Data Set Trailing Padding (FFFC,FFFC)" do
      # Build a P10 with explicit VR LE transfer syntax, then a data element, then padding
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      patient_name = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")

      # Trailing padding: tag FFFC,FFFC with OB VR and some zero bytes
      padding_data = <<0, 0, 0, 0>>

      padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, byte_size(padding_data)::little-32>> <>
          padding_data

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> patient_name <> padding

      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      # Should have patient name but NOT the trailing padding as a data element
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end

    test "handles implicit VR Little Endian transfer syntax" do
      # File meta with implicit VR LE
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.840.10008.1.2"))

      # Data set element in implicit VR: tag(4) + length(4) + value
      patient_name_value = "DOE^JOHN"

      implicit_element =
        <<0x10, 0x00, 0x10, 0x00, byte_size(patient_name_value)::little-32>> <>
          patient_name_value

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> implicit_element

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "reads unknown Group 0002 tags without error (PS3.10 7.1)" do
      # Build file meta with transfer syntax + an unknown (0002,FFFF) tag
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      unknown_value = pad_to_even("FUTURE_DATA")

      unknown_elem =
        <<0x02, 0x00, 0xFF, 0xFF, "SH", byte_size(unknown_value)::little-16>> <> unknown_value

      all_meta = ts_elem <> unknown_elem
      group_length = build_group_length_element(all_meta)

      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      binary = <<0::1024, "DICM">> <> group_length <> all_meta <> patient

      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      # Unknown tag should be stored in file_meta (not cause an error)
      assert Map.has_key?(ds.file_meta, {0x0002, 0xFFFF})
      # Normal data set elements should still be readable
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end

    test "handles Explicit VR Big Endian (retired) transfer syntax" do
      # File meta always Explicit VR LE, but transfer syntax says Big Endian
      ts_uid = pad_to_even("1.2.840.10008.1.2.2")
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, ts_uid)

      # Data set element in Explicit VR Big Endian
      # Tag: group big-endian, element big-endian, VR, length, value
      patient_name_value = "DOE^JOHN"

      big_endian_elem =
        <<0x00, 0x10, 0x00, 0x10, "PN", byte_size(patient_name_value)::big-16>> <>
          patient_name_value

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> big_endian_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "handles elements with zero length" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      empty_elem = elem_explicit({0x0010, 0x0010}, :PN, "")

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> empty_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) == ""
    end
  end

  # Helpers for building test DICOM binaries

  defp build_p10_binary(file_meta_elements) do
    ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
    all_meta = [ts_elem | file_meta_elements]
    meta_binary = IO.iodata_to_binary(all_meta)

    group_length = build_group_length_element(meta_binary)

    <<0::1024, "DICM">> <> group_length <> meta_binary
  end

  defp build_group_length_element(meta_binary) when is_binary(meta_binary) do
    # (0002,0000) UL with value = byte_size of remaining file meta
    length_value = <<byte_size(meta_binary)::little-32>>
    <<0x02, 0x00, 0x00, 0x00, "UL", byte_size(length_value)::little-16>> <> length_value
  end

  defp build_group_length_element(meta_elements) when is_list(meta_elements) do
    build_group_length_element(IO.iodata_to_binary(meta_elements))
  end

  defp elem_explicit({group, element}, vr, value) do
    value_binary = pad_to_even(value)
    vr_str = Atom.to_string(vr)

    if Dicom.VR.long_length?(vr) do
      <<group::little-16, element::little-16>> <>
        vr_str <> <<0::16, byte_size(value_binary)::little-32>> <> value_binary
    else
      <<group::little-16, element::little-16>> <>
        vr_str <> <<byte_size(value_binary)::little-16>> <> value_binary
    end
  end

  defp pad_to_even(value) when is_binary(value) do
    if rem(byte_size(value), 2) == 1 do
      value <> <<0>>
    else
      value
    end
  end
end
