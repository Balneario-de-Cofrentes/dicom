defmodule Dicom.P10.ReaderTest do
  use ExUnit.Case, async: true

  alias Dicom.DataSet

  import Dicom.TestHelpers,
    only: [pad_to_even: 1, elem_explicit: 3, build_group_length_element: 1]

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

    test "stops gracefully at end of data (PS3.10 7.2 — EOF is end of Data Set)" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> patient

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end

    test "stops gracefully with trailing bytes fewer than a tag (< 4 bytes)" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")

      # Add 3 trailing bytes (not enough for a tag)
      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> patient <> <<0, 0, 0>>

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end

    test "Group 0002 tags never appear in data set elements" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      version_elem = elem_explicit({0x0002, 0x0001}, :OB, <<0, 1>>)
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")

      all_meta = ts_elem <> version_elem
      group_length = build_group_length_element(all_meta)

      binary = <<0::1024, "DICM">> <> group_length <> all_meta <> patient

      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      # No Group 0002 tags in elements
      for {{group, _}, _} <- ds.elements do
        refute group == 0x0002, "Group 0002 tag found in data set elements"
      end

      # Group 0002 tags should be in file_meta only
      assert Map.has_key?(ds.file_meta, {0x0002, 0x0010})
      assert Map.has_key?(ds.file_meta, {0x0002, 0x0001})
    end
  end

  describe "error handling — truncated binaries" do
    test "returns error for binary truncated mid-element value" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Data element header says 100 bytes but only 4 available
      truncated_elem = <<0x10, 0x00, 0x10, 0x00, "PN", 100::little-16, "DOE^">>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> truncated_elem

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "returns error for binary truncated after tag bytes only" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Only 4 bytes of tag, no VR or length
      truncated = <<0x10, 0x00, 0x10, 0x00>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> truncated

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "returns error for binary truncated in long-value VR header" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # OB VR with reserved bytes but no length
      truncated = <<0x10, 0x00, 0x10, 0x00, "OB", 0::16>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> truncated

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "returns error for encapsulated pixel data with truncated fragment" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Pixel data with undefined length, then a fragment item that claims 100 bytes but has only 2
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      truncated_frag = <<0xFE, 0xFF, 0x00, 0xE0, 100::little-32, 0xAB, 0xCD>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> pixel_tag <> bot <> truncated_frag

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "returns error for sequence item with declared length exceeding available data" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # SQ with defined length, but item claims more bytes than available
      item = <<0xFE, 0xFF, 0x00, 0xE0, 1000::little-32, "short">>
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "returns error for a truncated defined-length sequence payload" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      truncated_sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 12::little-32, 0xFE, 0xFF, 0x00, 0xE0,
          4::little-32, 0x08, 0x00>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> truncated_sq

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end
  end

  describe "UN with undefined length (PS3.5 7.1)" do
    test "reads UN element with undefined length terminated by sequence delimiter" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # UN VR with reserved bytes + undefined length (0xFFFFFFFF)
      un_data = <<"MYSTERY_DATA1234">>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      un_elem =
        <<0x09, 0x00, 0x10, 0x00, "UN", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          un_data <> seq_delim

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> un_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0009, 0x0010}) == un_data
    end

    test "returns error for UN element with undefined length and no delimiter" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # UN with undefined length, no sequence delimiter — malformed
      un_data = <<"ALL_REMAINING_DATA">>

      un_elem =
        <<0x09, 0x00, 0x10, 0x00, "UN", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <> un_data

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> un_elem

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "does not swallow following elements when undefined-length value is missing a delimiter" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      undef_elem =
        <<0x09, 0x00, 0x10, 0x00, "UN", 0::16, 0xFF, 0xFF, 0xFF, 0xFF, "ABC">>

      trailing_elem = <<0x10, 0x00, 0x10, 0x00, "PN", 0x08, 0x00, "DOE^JOHN">>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> undef_elem <> trailing_elem

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "does not stop on sequence delimiter tag bytes unless the full delimiter is present" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      un_data = <<1, 2, 3, 0xFE, 0xFF, 0xDD, 0xE0, 9, 9, 9>>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      un_elem =
        <<0x09, 0x00, 0x10, 0x00, "UN", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          un_data <> seq_delim

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> un_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0009, 0x0010}) == un_data
    end
  end

  describe "Explicit VR Big Endian extended (PS3.5 A.1)" do
    test "reads long-value VR (OB) in Big Endian" do
      ts_uid = pad_to_even("1.2.840.10008.1.2.2")
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, ts_uid)

      # OB element in Big Endian: tag BE, VR, reserved, length BE, value
      ob_data = <<1, 2, 3, 4, 5, 6, 7, 8>>

      be_ob_elem =
        <<0x00, 0x09, 0x00, 0x10, "OB", 0::16, byte_size(ob_data)::big-32>> <> ob_data

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> be_ob_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0009, 0x0010}) == ob_data
    end

    test "reads sequence in Big Endian" do
      ts_uid = pad_to_even("1.2.840.10008.1.2.2")
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, ts_uid)

      # Inner element in BE: tag BE, VR, length BE, value
      inner_value = pad_to_even("1.2.3.4")

      inner_elem =
        <<0x00, 0x08, 0x11, 0x50, "UI", byte_size(inner_value)::big-16>> <> inner_value

      # Item with defined length — item tags follow TS byte ordering (PS3.5 7.5)
      # BE item tag: group FFFE BE = FF FE, element E000 BE = E0 00
      item = <<0xFF, 0xFE, 0xE0, 0x00, byte_size(inner_elem)::big-32>> <> inner_elem

      # SQ in BE: tag BE, VR SQ, reserved, length BE
      sq =
        <<0x00, 0x08, 0x11, 0x15, "SQ", 0::16, byte_size(item)::big-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "reads multiple elements in Big Endian" do
      ts_uid = pad_to_even("1.2.840.10008.1.2.2")
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, ts_uid)

      patient = <<0x00, 0x10, 0x00, 0x10, "PN", 8::big-16, "DOE^JOHN">>
      modality = <<0x00, 0x08, 0x00, 0x60, "CS", 2::big-16, "CT">>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> modality <> patient

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
      assert DataSet.get(ds, {0x0008, 0x0060}) == "CT"
    end

    test "handles trailing padding in Big Endian data set" do
      ts_uid = pad_to_even("1.2.840.10008.1.2.2")
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, ts_uid)

      patient = <<0x00, 0x10, 0x00, 0x10, "PN", 8::big-16, "DOE^JOHN">>

      # Trailing padding tag in BE: (FFFC,FFFC) → 0xFF, 0xFC, 0xFF, 0xFC
      padding = <<0xFF, 0xFC, 0xFF, 0xFC, "OB", 0::16, 4::big-32, 0, 0, 0, 0>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> patient <> padding

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
      # Trailing padding should be silently consumed
      assert map_size(ds.elements) == 1
    end

    test "reads undefined-length sequence in Big Endian" do
      ts_uid = pad_to_even("1.2.840.10008.1.2.2")
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, ts_uid)

      # Inner element in BE
      inner_value = pad_to_even("1.2.3.4")

      inner_elem =
        <<0x00, 0x08, 0x11, 0x50, "UI", byte_size(inner_value)::big-16>> <> inner_value

      # Item with defined length, BE item tag
      item = <<0xFF, 0xFE, 0xE0, 0x00, byte_size(inner_elem)::big-32>> <> inner_elem

      # Sequence delimiter in BE
      seq_delim = <<0xFF, 0xFE, 0xE0, 0xDD, 0::big-32>>

      # SQ with undefined length (0xFFFFFFFF) in BE
      sq =
        <<0x00, 0x08, 0x11, 0x15, "SQ", 0::16, 0xFFFFFFFF::big-32>> <> item <> seq_delim

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq) and length(seq) == 1
    end
  end

  describe "sequences with undefined-length items" do
    test "reads sequence with undefined-length items terminated by item delimiter" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Inner element: (0008,0060) CS "CT"
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      # Item with undefined length (0xFFFFFFFF), terminated by item delimiter
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner <> item_delim

      # SQ with defined length
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "reads sequence with undefined length terminated by sequence delimiter" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Inner element: (0008,0060) CS "MR"
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "MR">>

      # Item with defined length
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner)::little-32>> <> inner

      # Sequence delimiter
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      # SQ with undefined length (0xFFFFFFFF)
      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> seq_delim

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "reads empty sequence with zero length" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # SQ with zero length
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0::little-32>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0008, 0x1115}) == []
    end
  end

  describe "unknown VR handling" do
    test "reads element with unknown VR as UN with short length" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Element with unknown VR "ZZ" — should fall back to short-length UN
      unknown_data = <<0xAB, 0xCD>>

      unknown_elem =
        <<0x09, 0x00, 0x10, 0x00, "ZZ", byte_size(unknown_data)::little-16>> <> unknown_data

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> unknown_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0009, 0x0010}) == unknown_data
    end
  end

  describe "file meta reading error propagation" do
    test "propagates error from malformed file meta element" do
      group_length = <<0x02, 0x00, 0x00, 0x00, "UL", 4::little-16, 100::little-32>>
      truncated_meta = <<0x02, 0x00, 0x10, 0x00, "UI", 50::little-16, "short">>

      binary = <<0::1024, "DICM">> <> group_length <> truncated_meta
      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "returns error when only 2 bytes follow preamble (peek_tag fail)" do
      binary = <<0::1024, "DICM", 0xAB, 0xCD>>
      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end
  end

  describe "deep error paths" do
    test "read_short_value catch-all with truncated length" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      # Short VR with only 1 byte for the 2-byte length field
      truncated = <<0x10, 0x00, 0x10, 0x00, "PN", 0xAB>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> truncated

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "sequence with truncated reserved+length header" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      # SQ followed by only 3 bytes (needs 6: 2 reserved + 4 length)
      truncated_sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0x00, 0x00, 0x00>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> truncated_sq

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "undefined-length sequence with < 8 bytes after last item" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner)::little-32>> <> inner
      # 3 trailing bytes — < 8, triggers items_until_delimiter guard
      # then < 4 bytes triggers read_all_elements guard (graceful stop)
      trailing = <<0x00, 0x00, 0x00>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> trailing

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "malformed item tag in defined-length sequence" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      garbage_item = <<0xAA, 0xBB, 0xCC, 0xDD, 4::little-32, 0x01, 0x02, 0x03, 0x04>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(garbage_item)::little-32>> <>
          garbage_item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "undefined-length item with 3 bytes content (< 4 guard)" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Item with undefined length containing exactly 3 bytes (no valid element or delimiter)
      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> <<0xAB, 0xCD, 0xEF>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
    end
  end

  describe "implicit VR sequences" do
    test "reads sequence via dictionary VR lookup in implicit VR" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.840.10008.1.2"))

      # In implicit VR: tag(4) + length(4) for all elements
      # ReferencedImageSequence (0008,1140) has VR=SQ in the dictionary

      # Inner element: ReferencedSOPClassUID (0008,1150) — VR=UI in dictionary
      inner_value = pad_to_even("1.2.840.10008.5.1.4.1.1.2")
      inner_elem = <<0x08, 0x00, 0x50, 0x11, byte_size(inner_value)::little-32>> <> inner_value

      # Item: tag(4) + length(4)
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem

      # Sequence: tag(4) + length(4)
      sq = <<0x08, 0x00, 0x40, 0x11, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq_value = DataSet.get(ds, {0x0008, 0x1140})
      assert is_list(seq_value)
      assert length(seq_value) == 1
    end

    test "reads unknown tag as UN in implicit VR" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.840.10008.1.2"))

      # Unknown tag (0009,0010) — not in dictionary, should default to UN
      unknown_data = <<"PRIVATE_DATA">>

      implicit_elem =
        <<0x09, 0x00, 0x10, 0x00, byte_size(unknown_data)::little-32>> <> unknown_data

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> implicit_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0009, 0x0010}) == unknown_data
    end
  end

  describe "encapsulated pixel data edge cases" do
    test "reads encapsulated pixel data with BOT and one fragment" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Pixel data with undefined length
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      # BOT (empty)
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      # One fragment
      frag_data = <<0xAB, 0xCD, 0xEF, 0x01>>
      frag = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data

      # Sequence delimiter
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> pixel_tag <> bot <> frag <> seq_delim

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      elem = Dicom.DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert elem.vr == :OB
      assert {:encapsulated, fragments} = elem.value
      # BOT + 1 data fragment = 2 fragments total
      assert length(fragments) == 2
    end

    test "returns error for encapsulated pixel data with junk after last fragment" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Pixel data with undefined length
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      # One fragment followed by junk (not a valid item/delimiter tag)
      frag_data = <<0x01, 0x02>>
      frag = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data

      # Garbage bytes (not item/delimiter) — malformed encapsulated value
      junk = <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> pixel_tag <> bot <> frag <> junk

      assert {:error, :invalid_encapsulated_pixel_data} = Dicom.P10.Reader.parse(binary)
    end

    test "returns error when encapsulated pixel data ends without a delimiter" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      frag_data = <<0x01, 0x02>>
      frag = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data

      # 3 trailing bytes — malformed truncation without a sequence delimiter
      trailing = <<0xAB, 0xCD, 0xEF>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> pixel_tag <> bot <> frag <> trailing

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "encapsulated pixel data with less than 8 bytes after last fragment" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      frag_data = <<0x01, 0x02>>
      frag = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> pixel_tag <> bot <> frag <> seq_delim

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      elem = Dicom.DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert {:encapsulated, fragments} = elem.value
      assert length(fragments) == 2
    end
  end

  describe "undefined-length sequence edge cases" do
    test "stops reading items when non-item/non-delimiter encountered" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # SQ with undefined length, one item, then unexpected data (not item or delimiter)
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner)::little-32>> <> inner

      # Non-item/non-delimiter bytes (looks like a regular element tag, not FFFE)
      non_item = <<0x00, 0x08, 0x00, 0x60, 0x00, 0x00, 0x00, 0x00>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> non_item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end
  end

  describe "item-level edge cases" do
    test "handles seq delimiter inside undefined-length item (defensive)" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Item with undefined length containing a seq delimiter tag inside it
      # This shouldn't happen per spec, but reader should be defensive
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      # Seq delimiter (FFFE,E0DD) appearing inside item — defensive handling
      seq_delim_inside = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner <> seq_delim_inside

      # Outer sequence delimiter
      outer_seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> outer_seq_delim

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "handles trailing padding inside undefined-length item" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      # Trailing padding tag (FFFC,FFFC) inside item
      padding_data = <<0, 0, 0, 0>>

      padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, byte_size(padding_data)::little-32>> <>
          padding_data

      # Item delimiter
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner <> padding <> item_delim

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> seq_delim

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "handles undefined-length item with only < 4 bytes before delimiter" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Empty item with undefined length, immediately followed by item delimiter
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> item_delim

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
      # Item should be empty
      [item_elements] = seq
      assert item_elements == %{}
    end

    test "propagates error from truncated element inside undefined-length item" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Item with undefined length containing a truncated element
      # Element header says 100 bytes value but only 2 available
      truncated_inner = <<0x08, 0x00, 0x60, 0x00, "CS", 100::little-16, "CT">>
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          truncated_inner <> item_delim

      sq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> sq_delim

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "propagates error from malformed element inside defined-length item" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Item with defined length containing a truncated element:
      # tag (4 bytes) + VR (2 bytes) = 6 bytes total — enough for peek_tag but not read_element
      item_content = <<0x10, 0x00, 0x10, 0x00, "PN">>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, byte_size(item_content)::little-32>> <> item_content

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      assert {:error, :unexpected_end} = Dicom.P10.Reader.parse(binary)
    end

    test "handles truncated trailing padding inside undefined-length item" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Inner element
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      # Truncated trailing padding: tag + VR but no reserved/length bytes
      truncated_padding = <<0xFC, 0xFF, 0xFC, 0xFF, "OB">>

      # Item with undefined length
      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner <> truncated_padding

      # Undefined-length sequence (no delimiter — the < 8 guard stops items reading)
      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "handles defined-length sequence with trailing bytes < 8 after items" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Item with inner element
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner)::little-32>> <> inner

      # Add 4 padding bytes after the item but within the sequence's defined length
      padding = <<0x00, 0x00, 0x00, 0x00>>

      # Sequence with defined length that includes item + padding
      seq_content = item <> padding

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(seq_content)::little-32>> <> seq_content

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "handles empty item with zero length" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Item with length 0
      item = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
      [item_elements] = seq
      assert item_elements == %{}
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
end
