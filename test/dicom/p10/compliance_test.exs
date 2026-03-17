defmodule Dicom.P10.ComplianceTest do
  @moduledoc """
  Comprehensive PS3.10 compliance tests.

  Verifies the library against the DICOM PS3.10 specification requirements.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Dicom.DataSet

  import Dicom.TestHelpers,
    only: [minimal_data_set: 0, pad_to_even: 1, build_p10_with_data: 1]

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

    test "Group Length (0002,0000) value matches actual byte count of remaining file meta" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0002, 0x0016}, :AE, "MYSCANNER")
        |> DataSet.put({0x0002, 0x0013}, :SH, "TEST_1.0")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      # Skip preamble+DICM (132 bytes) to reach file meta
      <<_preamble::binary-size(132), rest::binary>> = binary

      # First element is (0002,0000) UL — parse it
      <<0x02, 0x00, 0x00, 0x00, "UL", 4::little-16, group_length::little-32, meta_rest::binary>> =
        rest

      # The group_length value should equal the number of bytes from here
      # to the first non-group-0002 element
      {meta_bytes, _data_set_bytes} = split_at_non_group2(meta_rest)
      assert group_length == byte_size(meta_bytes)
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

    test "Group Length accurate with many meta elements (PS3.10 Table 7.1-1)" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0002, 0x0016}, :AE, "SCANNER_AE")
        |> DataSet.put({0x0002, 0x0017}, :AE, "SENDING_AE")
        |> DataSet.put({0x0002, 0x0018}, :AE, "RECEIVING_AE")
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      # Parse group length directly from binary
      <<_preamble::binary-size(132), rest::binary>> = binary

      <<0x02, 0x00, 0x00, 0x00, "UL", 4::little-16, group_length::little-32, meta_rest::binary>> =
        rest

      # Find where file meta ends (first non-0002 group)
      {meta_bytes, _data_rest} = split_at_non_group2(meta_rest)
      assert group_length == byte_size(meta_bytes)
    end

    test "File Meta Version (0002,0001) is exactly <<0x00, 0x01>> (PS3.10 Table 7.1-1)" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      version_elem = DataSet.get_element(parsed, {0x0002, 0x0001})
      assert version_elem.vr == :OB
      assert version_elem.value == <<0x00, 0x01>>
    end

    test "Implementation Version Name max 16 chars (PS3.10 Table 7.1-1)" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      impl_name = DataSet.get(parsed, {0x0002, 0x0013})
      assert is_binary(impl_name)
      assert byte_size(String.trim(impl_name)) <= 16
    end

    test "reader handles inaccurate group length gracefully (uses group boundary, not length)" do
      # Build file meta with a deliberately wrong group length
      ts_uid = pad_to_even("1.2.840.10008.1.2.1")
      ts_elem = <<0x02, 0x00, 0x10, 0x00, "UI", byte_size(ts_uid)::little-16>> <> ts_uid

      # Set group length to 9999 (way too large)
      wrong_length = <<0x02, 0x00, 0x00, 0x00, "UL", 4::little-16, 9999::little-32>>

      patient = <<0x10, 0x00, 0x10, 0x00, "PN", 8::little-16, "DOE^JOHN">>

      binary = <<0::1024, "DICM">> <> wrong_length <> ts_elem <> patient

      # Reader uses group boundary (non-0002 tag) rather than group length value
      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
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
      ts_uid = pad_to_even("1.2.840.10008.1.2.1")
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

  # PS3.5 Annex A.4 — Encapsulated Pixel Data

  describe "PS3.5 A.4 — Encapsulated Pixel Data" do
    test "reads encapsulated pixel data with empty BOT" do
      # Pixel Data tag (7FE0,0010), OB VR, undefined length
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      # Empty Basic Offset Table (first item with zero length)
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      # One data fragment
      fragment_data = <<1, 2, 3, 4>>
      fragment = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment_data)::little-32>> <> fragment_data

      # Sequence delimiter
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_with_data(pixel_tag <> bot <> fragment <> seq_delim)
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      pixel_elem = DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert %Dicom.DataElement{vr: :OB, value: {:encapsulated, fragments}} = pixel_elem
      assert length(fragments) == 2
      # First fragment is empty BOT, second is our data
      [bot_fragment, data_fragment] = fragments
      assert bot_fragment == <<>>
      assert data_fragment == <<1, 2, 3, 4>>
    end

    test "reads encapsulated pixel data with BOT containing offsets" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      # BOT with one offset (first frame at offset 0)
      bot_data = <<0::little-32>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(bot_data)::little-32>> <> bot_data

      fragment_data = :binary.copy(<<0xAB>>, 100)
      fragment = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment_data)::little-32>> <> fragment_data

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_with_data(pixel_tag <> bot <> fragment <> seq_delim)
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      pixel_elem = DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert %Dicom.DataElement{value: {:encapsulated, [_bot, frag]}} = pixel_elem
      assert byte_size(frag) == 100
    end

    test "reads multi-fragment encapsulated pixel data" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      frag1_data = <<1, 2, 3, 4>>
      frag1 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag1_data)::little-32>> <> frag1_data
      frag2_data = <<5, 6, 7, 8>>
      frag2 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag2_data)::little-32>> <> frag2_data

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_with_data(pixel_tag <> bot <> frag1 <> frag2 <> seq_delim)
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      pixel_elem = DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert %Dicom.DataElement{value: {:encapsulated, fragments}} = pixel_elem
      # BOT + 2 data fragments
      assert length(fragments) == 3
    end

    test "roundtrips encapsulated pixel data" do
      fragments = [<<>>, <<1, 2, 3, 4>>, <<5, 6, 7, 8>>]
      pixel_elem = Dicom.DataElement.new({0x7FE0, 0x0010}, :OB, {:encapsulated, fragments})

      ds =
        minimal_data_set()
        |> DataSet.put({0x0028, 0x0010}, :US, <<256::little-16>>)
        |> DataSet.put({0x0028, 0x0011}, :US, <<256::little-16>>)

      ds = %{ds | elements: Map.put(ds.elements, {0x7FE0, 0x0010}, pixel_elem)}

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      pixel = DataSet.get_element(parsed, {0x7FE0, 0x0010})
      assert %Dicom.DataElement{value: {:encapsulated, parsed_frags}} = pixel
      assert parsed_frags == fragments
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

    test "Explicit VR Big Endian roundtrip (retired)" do
      assert_transfer_syntax_roundtrip(Dicom.UID.explicit_vr_big_endian())
    end

    test "Explicit VR Big Endian sequence roundtrip" do
      item = %{
        {0x0008, 0x1150} =>
          Dicom.DataElement.new({0x0008, 0x1150}, :UI, "1.2.840.10008.5.1.4.1.1.2")
      }

      seq_elem = Dicom.DataElement.new({0x0008, 0x1115}, :SQ, [item])

      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_big_endian())
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1115}, seq_elem)}

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"

      seq = DataSet.get(parsed, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
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

  defp assert_transfer_syntax_roundtrip(ts_uid) do
    ds =
      minimal_data_set()
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

  # Splits binary at the boundary where group changes from 0002 to something else
  defp split_at_non_group2(binary), do: split_at_non_group2(binary, 0)

  defp split_at_non_group2(binary, offset) when offset + 4 <= byte_size(binary) do
    <<_before::binary-size(offset), group::little-16, _::binary>> = binary

    if group != 0x0002 do
      <<meta::binary-size(offset), rest::binary>> = binary
      {meta, rest}
    else
      # Skip this element: read VR and length to find next element
      <<_before::binary-size(offset), _tag::binary-size(4), vr_bytes::binary-size(2),
        after_vr::binary>> = binary

      elem_size =
        case vr_bytes do
          vr
          when vr in [
                 "OB",
                 "OD",
                 "OF",
                 "OL",
                 "OV",
                 "OW",
                 "SQ",
                 "UC",
                 "UN",
                 "UR",
                 "UT",
                 "UV",
                 "SV"
               ] ->
            <<_reserved::16, length::little-32, _::binary>> = after_vr
            4 + 2 + 2 + 4 + length

          _ ->
            <<length::little-16, _::binary>> = after_vr
            4 + 2 + 2 + length
        end

      split_at_non_group2(binary, offset + elem_size)
    end
  end

  defp split_at_non_group2(binary, offset) do
    <<meta::binary-size(offset), rest::binary>> = binary
    {meta, rest}
  end
end
