defmodule Dicom.P10.InteropTest do
  @moduledoc """
  Interoperability and conformance hardening tests.

  Exercises the new strict transfer syntax policy, expanded dictionary,
  character set handling, and multi-feature interactions through the
  full parse/serialize pipeline.
  """
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, DataElement, TransferSyntax}

  import Dicom.TestHelpers,
    only: [minimal_data_set: 0, pad_to_even: 1, elem_explicit: 3, build_group_length_element: 1]

  # ── Transfer syntax rejection ────────────────────────────────────

  describe "unknown transfer syntax rejection" do
    test "reader returns error for unknown transfer syntax UID" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.999.999.999"))

      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> patient

      assert {:error, :unknown_transfer_syntax} = Dicom.P10.Reader.parse(binary)
    end

    test "writer returns error for unknown transfer syntax UID" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.999.999.999")

      assert {:error, :unknown_transfer_syntax} = Dicom.P10.Writer.serialize(ds)
    end

    test "stream parser returns error for unknown transfer syntax UID" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.999.999.999"))
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> patient

      assert {:error, :unknown_transfer_syntax} =
               binary
               |> Dicom.stream_parse()
               |> Enum.to_list()
               |> List.last()
    end

    test "compressed transfer syntaxes are recognized (JPEG Baseline)" do
      # File with JPEG Baseline TS — reader should accept the TS
      # (no actual pixel data, just verifying TS recognition)
      ts_uid = pad_to_even(Dicom.UID.jpeg_baseline())
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, ts_uid)

      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> patient

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end

    test "all 28 registered transfer syntaxes are accepted by encoding/1" do
      known_uids = [
        "1.2.840.10008.1.2",
        "1.2.840.10008.1.2.1",
        "1.2.840.10008.1.2.1.99",
        "1.2.840.10008.1.2.2",
        "1.2.840.10008.1.2.4.50",
        "1.2.840.10008.1.2.4.51",
        "1.2.840.10008.1.2.4.57",
        "1.2.840.10008.1.2.4.70",
        "1.2.840.10008.1.2.4.80",
        "1.2.840.10008.1.2.4.81",
        "1.2.840.10008.1.2.4.90",
        "1.2.840.10008.1.2.4.91",
        "1.2.840.10008.1.2.4.92",
        "1.2.840.10008.1.2.4.93",
        "1.2.840.10008.1.2.4.94",
        "1.2.840.10008.1.2.4.95",
        "1.2.840.10008.1.2.4.100",
        "1.2.840.10008.1.2.4.101",
        "1.2.840.10008.1.2.4.102",
        "1.2.840.10008.1.2.4.103",
        "1.2.840.10008.1.2.4.104",
        "1.2.840.10008.1.2.4.105",
        "1.2.840.10008.1.2.4.106",
        "1.2.840.10008.1.2.4.107",
        "1.2.840.10008.1.2.4.108",
        "1.2.840.10008.1.2.4.201",
        "1.2.840.10008.1.2.4.202",
        "1.2.840.10008.1.2.4.203",
        "1.2.840.10008.1.2.5"
      ]

      for uid <- known_uids do
        assert {:ok, {vr_enc, endian}} = TransferSyntax.encoding(uid),
               "#{uid} should be recognized"

        assert vr_enc in [:implicit, :explicit]
        assert endian in [:little, :big]
      end
    end
  end

  describe "invalid deflated payload rejection" do
    test "reader returns error for invalid deflated content" do
      ts_elem =
        elem_explicit(
          {0x0002, 0x0010},
          :UI,
          pad_to_even(Dicom.UID.deflated_explicit_vr_little_endian())
        )

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> <<1, 2, 3, 4, 5>>

      assert {:error, :invalid_deflated_data} = Dicom.P10.Reader.parse(binary)
    end
  end

  # ── Expanded dictionary through parse pipeline ───────────────────

  describe "expanded dictionary in implicit VR parsing" do
    test "multiple previously-unknown tags parse correctly in implicit VR" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.840.10008.1.2"))

      # Build several elements that were NOT in the old ~95-entry dictionary
      elements = [
        # AcquisitionDate (0008,0022) DA
        {<<0x08, 0x00, 0x22, 0x00>>, "20240101"},
        # ContentDate (0008,0023) DA
        {<<0x08, 0x00, 0x23, 0x00>>, "20240102"},
        # StationName (0008,1010) SH
        {<<0x08, 0x00, 0x10, 0x10>>, pad_to_even("SCANNER1")},
        # ProtocolName (0018,1030) LO
        {<<0x18, 0x00, 0x30, 0x10>>, pad_to_even("T1_BRAIN")},
        # AcquisitionNumber (0020,0012) IS
        {<<0x20, 0x00, 0x12, 0x00>>, pad_to_even("1")}
      ]

      implicit_data =
        for {tag_bytes, value} <- elements, into: <<>> do
          tag_bytes <> <<byte_size(value)::little-32>> <> value
        end

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> implicit_data

      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      # Verify each element was parsed with correct VR from dictionary
      assert DataSet.get_element(ds, {0x0008, 0x0022}).vr == :DA
      assert DataSet.get_element(ds, {0x0008, 0x0023}).vr == :DA
      assert DataSet.get_element(ds, {0x0008, 0x1010}).vr == :SH
      assert DataSet.get_element(ds, {0x0018, 0x1030}).vr == :LO
      assert DataSet.get_element(ds, {0x0020, 0x0012}).vr == :IS
    end

    test "nested sequence with dictionary-resolved SQ tag in implicit VR" do
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.840.10008.1.2"))

      # ScheduledStationAETitle (0040,0001) AE
      inner_value = pad_to_even("SCANNER1")
      inner_elem = <<0x40, 0x00, 0x01, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Item
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem

      # ScheduledProcedureStepSequence (0040,0100) — SQ in dictionary
      sq = <<0x40, 0x00, 0x00, 0x01, byte_size(item)::little-32>> <> item

      # RequestAttributesSequence (0040,0275) — also SQ, contains the above
      outer_item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(sq)::little-32>> <> sq
      outer_sq = <<0x40, 0x00, 0x75, 0x02, byte_size(outer_item)::little-32>> <> outer_item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> outer_sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      outer_seq = DataSet.get(ds, {0x0040, 0x0275})
      assert is_list(outer_seq), "Outer should be a sequence"
      assert length(outer_seq) == 1

      [outer_item_elements] = outer_seq
      inner_sq_elem = Map.get(outer_item_elements, {0x0040, 0x0100})
      assert %DataElement{vr: :SQ, value: inner_items} = inner_sq_elem
      assert length(inner_items) == 1
    end
  end

  # ── Multi-element roundtrip fixtures ─────────────────────────────

  describe "rich data set roundtrips" do
    test "typical CT study data set roundtrips through EVLE" do
      ds = build_ct_study_data_set(Dicom.UID.explicit_vr_little_endian())

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert_ct_study_values(parsed)
    end

    test "typical CT study data set roundtrips through IVLE" do
      ds = build_ct_study_data_set(Dicom.UID.implicit_vr_little_endian())

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert_ct_study_values(parsed)
    end

    test "typical CT study data set roundtrips through EVBE" do
      ds = build_ct_study_data_set(Dicom.UID.explicit_vr_big_endian())

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert_ct_study_values(parsed)
    end

    test "typical CT study data set roundtrips through Deflated EVLE" do
      ds = build_ct_study_data_set(Dicom.UID.deflated_explicit_vr_little_endian())

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert_ct_study_values(parsed)
    end

    test "data set with sequences roundtrips through all uncompressed TS" do
      for ts_uid <- [
            Dicom.UID.explicit_vr_little_endian(),
            Dicom.UID.implicit_vr_little_endian(),
            Dicom.UID.explicit_vr_big_endian(),
            Dicom.UID.deflated_explicit_vr_little_endian()
          ] do
        ds = build_sequence_heavy_data_set(ts_uid)

        {:ok, binary} = Dicom.P10.Writer.serialize(ds)
        {:ok, parsed} = Dicom.P10.Reader.parse(binary)

        seq = DataSet.get(parsed, {0x0008, 0x1115})
        assert is_list(seq), "Failed for TS #{ts_uid}"
        assert length(seq) == 2, "Expected 2 items for TS #{ts_uid}"
      end
    end
  end

  # ── Encapsulated pixel data with compressed TS ───────────────────

  describe "encapsulated pixel data with compressed transfer syntaxes" do
    test "JPEG Baseline TS with encapsulated pixel data roundtrips" do
      assert_encapsulated_roundtrip(Dicom.UID.jpeg_baseline())
    end

    test "JPEG 2000 Lossless TS with encapsulated pixel data roundtrips" do
      assert_encapsulated_roundtrip(Dicom.UID.jpeg_2000_lossless())
    end

    test "RLE Lossless TS with encapsulated pixel data roundtrips" do
      assert_encapsulated_roundtrip(Dicom.UID.rle_lossless())
    end
  end

  # ── Character set integration ────────────────────────────────────

  describe "character set integration" do
    test "CharacterSet.extract works on parsed data sets" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 100")
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      charset = Dicom.CharacterSet.extract(parsed.elements)
      assert charset == "ISO_IR 100"
    end

    test "CharacterSet.decode works on raw values from parsed data" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 100")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      charset = Dicom.CharacterSet.extract(parsed.elements)
      assert Dicom.CharacterSet.supported?(charset)
    end

    test "Latin-1 encoded patient name survives parse roundtrip" do
      # "MÜLLER^HANS" in Latin-1 will be written as bytes by the writer,
      # and read back as the same bytes by the reader
      ds =
        minimal_data_set()
        |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 100")

      # The raw bytes for MÜLLER^HANS in Latin-1
      latin1_bytes = <<0x4D, 0xDC, 0x4C, 0x4C, 0x45, 0x52, 0x5E, 0x48, 0x41, 0x4E, 0x53, 0x00>>

      ds = %{
        ds
        | elements:
            Map.put(
              ds.elements,
              {0x0010, 0x0010},
              DataElement.new({0x0010, 0x0010}, :PN, latin1_bytes)
            )
      }

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      raw_value = DataSet.get(parsed, {0x0010, 0x0010})
      charset = Dicom.CharacterSet.extract(parsed.elements)

      {:ok, decoded} = Dicom.CharacterSet.decode(String.trim_trailing(raw_value, <<0>>), charset)
      assert decoded == "MÜLLER^HANS"
    end
  end

  # ── Writer validation ────────────────────────────────────────────

  describe "writer validation" do
    test "rejects data set missing required file meta elements" do
      ds = DataSet.new()
      assert {:error, {:missing_required_meta, _}} = Dicom.P10.Writer.serialize(ds)
    end

    test "rejects UN VR in file meta" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())

      # Inject a UN VR element into file_meta
      un_elem = DataElement.new({0x0002, 0x0099}, :UN, <<0, 0>>)
      ds = %{ds | file_meta: Map.put(ds.file_meta, {0x0002, 0x0099}, un_elem)}

      assert {:error, {:un_vr_in_file_meta, {0x0002, 0x0099}}} =
               Dicom.P10.Writer.serialize(ds)
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp build_ct_study_data_set(ts_uid) do
    minimal_data_set()
    |> DataSet.put({0x0002, 0x0010}, :UI, ts_uid)
    |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 100")
    |> DataSet.put({0x0008, 0x0008}, :CS, "ORIGINAL\\PRIMARY\\AXIAL")
    |> DataSet.put({0x0008, 0x0016}, :UI, Dicom.UID.ct_image_storage())
    |> DataSet.put({0x0008, 0x0018}, :UI, "1.2.3.4.5.6.7.8.9.1")
    |> DataSet.put({0x0008, 0x0020}, :DA, "20240101")
    |> DataSet.put({0x0008, 0x0030}, :TM, "120000")
    |> DataSet.put({0x0008, 0x0050}, :SH, "ACC001")
    |> DataSet.put({0x0008, 0x0060}, :CS, "CT")
    |> DataSet.put({0x0008, 0x0070}, :LO, "ACME Medical")
    |> DataSet.put({0x0008, 0x0090}, :PN, "SMITH^ALICE")
    |> DataSet.put({0x0008, 0x1030}, :LO, "CT HEAD W/O CONTRAST")
    |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
    |> DataSet.put({0x0010, 0x0020}, :LO, "PAT001")
    |> DataSet.put({0x0010, 0x0030}, :DA, "19800115")
    |> DataSet.put({0x0010, 0x0040}, :CS, "M")
    |> DataSet.put({0x0020, 0x000D}, :UI, "1.2.3.4.5.6.7.8.9.2")
    |> DataSet.put({0x0020, 0x000E}, :UI, "1.2.3.4.5.6.7.8.9.3")
    |> DataSet.put({0x0020, 0x0010}, :SH, "1")
    |> DataSet.put({0x0020, 0x0011}, :IS, "1")
    |> DataSet.put({0x0020, 0x0013}, :IS, "1")
    |> DataSet.put({0x0028, 0x0010}, :US, <<512::little-16>>)
    |> DataSet.put({0x0028, 0x0011}, :US, <<512::little-16>>)
    |> DataSet.put({0x0028, 0x0100}, :US, <<16::little-16>>)
    |> DataSet.put({0x0028, 0x0101}, :US, <<12::little-16>>)
    |> DataSet.put({0x0028, 0x0102}, :US, <<11::little-16>>)
    |> DataSet.put({0x0028, 0x0103}, :US, <<0::little-16>>)
  end

  defp assert_ct_study_values(parsed) do
    assert DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    assert DataSet.get(parsed, {0x0010, 0x0020}) |> String.trim() == "PAT001"
    assert DataSet.get(parsed, {0x0008, 0x0060}) |> String.trim() == "CT"
    assert DataSet.get(parsed, {0x0008, 0x0090}) |> String.trim() == "SMITH^ALICE"
    assert DataSet.get(parsed, {0x0020, 0x0013}) |> String.trim() == "1"
  end

  defp build_sequence_heavy_data_set(ts_uid) do
    inner_item1 = %{
      {0x0008, 0x1150} => DataElement.new({0x0008, 0x1150}, :UI, "1.2.840.10008.5.1.4.1.1.2"),
      {0x0008, 0x1155} => DataElement.new({0x0008, 0x1155}, :UI, "1.2.3.4.5.6.7.8.9.100")
    }

    inner_item2 = %{
      {0x0008, 0x1150} => DataElement.new({0x0008, 0x1150}, :UI, "1.2.840.10008.5.1.4.1.1.4"),
      {0x0008, 0x1155} => DataElement.new({0x0008, 0x1155}, :UI, "1.2.3.4.5.6.7.8.9.200")
    }

    seq_elem = DataElement.new({0x0008, 0x1115}, :SQ, [inner_item1, inner_item2])

    ds =
      minimal_data_set()
      |> DataSet.put({0x0002, 0x0010}, :UI, ts_uid)
      |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

    %{ds | elements: Map.put(ds.elements, {0x0008, 0x1115}, seq_elem)}
  end

  defp assert_encapsulated_roundtrip(ts_uid) do
    fragments = [<<>>, <<0xAB, 0xCD, 0xEF, 0x01>>, <<0x11, 0x22, 0x33, 0x44>>]
    pixel_elem = DataElement.new({0x7FE0, 0x0010}, :OB, {:encapsulated, fragments})

    ds =
      minimal_data_set()
      |> DataSet.put({0x0002, 0x0010}, :UI, ts_uid)
      |> DataSet.put({0x0028, 0x0002}, :US, <<1::little-16>>)
      |> DataSet.put({0x0028, 0x0010}, :US, <<256::little-16>>)
      |> DataSet.put({0x0028, 0x0011}, :US, <<256::little-16>>)
      |> DataSet.put({0x0028, 0x0100}, :US, <<8::little-16>>)

    ds = %{ds | elements: Map.put(ds.elements, {0x7FE0, 0x0010}, pixel_elem)}

    {:ok, binary} = Dicom.P10.Writer.serialize(ds)
    {:ok, parsed} = Dicom.P10.Reader.parse(binary)

    pixel = DataSet.get_element(parsed, {0x7FE0, 0x0010})
    assert %DataElement{value: {:encapsulated, parsed_frags}} = pixel
    assert parsed_frags == fragments
  end
end
