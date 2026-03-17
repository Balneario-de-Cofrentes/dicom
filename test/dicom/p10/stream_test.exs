defmodule Dicom.P10.StreamTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataElement, DataSet}

  import Dicom.TestHelpers,
    only: [pad_to_even: 1, elem_explicit: 3, build_group_length_element: 1]

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp build_p10_binary(file_meta_elements, data_elements \\ []) do
    ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
    all_meta = IO.iodata_to_binary([ts_elem | file_meta_elements])
    group_length = build_group_length_element(all_meta)
    data = IO.iodata_to_binary(data_elements)
    <<0::1024, "DICM">> <> group_length <> all_meta <> data
  end

  defp build_p10_with_ts(ts_uid, data_binary) do
    ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even(ts_uid))
    group_length = build_group_length_element(ts_elem)
    <<0::1024, "DICM">> <> group_length <> ts_elem <> data_binary
  end

  defp collect_events(binary) do
    binary |> Dicom.P10.Stream.parse() |> Enum.to_list()
  end

  defp element_events(events) do
    Enum.flat_map(events, fn
      {:element, elem} -> [elem]
      _ -> []
    end)
  end

  defp pad_even(value) when rem(byte_size(value), 2) == 1, do: value <> <<0>>
  defp pad_even(value), do: value

  # ── Preamble / File Meta ────────────────────────────────────────────────

  describe "preamble and file meta" do
    test "rejects binary without DICM prefix" do
      events = collect_events(<<"not dicom">>)
      assert [{:error, :unexpected_end}] = events
    end

    test "rejects binary shorter than 132 bytes" do
      events = collect_events(<<0::128>>)
      assert [{:error, :unexpected_end}] = events
    end

    test "rejects binary with correct length but no DICM magic" do
      events = collect_events(<<0::1024, "XXXX">>)
      assert [{:error, :invalid_preamble}] = events
    end

    test "emits :file_meta_start as first event for valid P10" do
      binary = build_p10_binary([])
      [first | _] = collect_events(binary)
      assert first == :file_meta_start
    end

    test "emits file meta elements between :file_meta_start and :file_meta_end" do
      binary = build_p10_binary([])
      events = collect_events(binary)

      assert :file_meta_start in events
      assert Enum.any?(events, &match?({:file_meta_end, _}, &1))

      # The transfer syntax element should be emitted
      meta_elements = element_events(events)
      meta_tags = Enum.map(meta_elements, & &1.tag)
      assert {0x0002, 0x0010} in meta_tags
    end

    test "file_meta_end carries the transfer syntax UID" do
      binary = build_p10_binary([])
      events = collect_events(binary)

      file_meta_end =
        Enum.find(events, fn
          {:file_meta_end, _} -> true
          _ -> false
        end)

      assert {:file_meta_end, ts_uid} = file_meta_end
      assert String.starts_with?(ts_uid, "1.2.840.10008.1.2")
    end

    test "emits multiple file meta elements" do
      version_elem = elem_explicit({0x0002, 0x0001}, :OB, <<0, 1>>)
      binary = build_p10_binary([version_elem])
      events = collect_events(binary)

      meta_elements = element_events(events)
      meta_tags = Enum.map(meta_elements, & &1.tag)

      assert {0x0002, 0x0010} in meta_tags
      assert {0x0002, 0x0001} in meta_tags
    end

    test "group 0002 tags appear only in file_meta, not in data set elements" do
      binary = build_p10_binary([])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      for {tag, _} <- ds.elements do
        {group, _} = tag
        refute group == 0x0002
      end
    end
  end

  # ── Data Set Elements (Explicit VR LE) ─────────────────────────────────

  describe "data set elements (Explicit VR Little Endian)" do
    test "parses a minimal valid P10 binary" do
      binary = build_p10_binary([])
      events = collect_events(binary)
      assert :end in events
    end

    test "parses data set elements after file meta" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      binary = build_p10_binary([], [patient])
      events = collect_events(binary)

      data_elements =
        Enum.filter(element_events(events), fn elem ->
          {group, _} = elem.tag
          group != 0x0002
        end)

      assert length(data_elements) == 1
      assert hd(data_elements).tag == {0x0010, 0x0010}
    end

    test "handles elements with zero length" do
      empty = elem_explicit({0x0010, 0x0010}, :PN, "")
      binary = build_p10_binary([], [empty])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == ""
    end

    test "parses multiple data elements" do
      patient_name = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      patient_id = elem_explicit({0x0010, 0x0020}, :LO, "PAT001")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      binary = build_p10_binary([], [modality, patient_name, patient_id])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
      assert DataSet.get(ds, {0x0010, 0x0020}) |> String.trim() == "PAT001"
      assert DataSet.get(ds, {0x0008, 0x0060}) |> String.trim() == "CT"
    end

    test "handles long VR elements (OB, OW, etc.)" do
      pixel_data = :crypto.strong_rand_bytes(256)
      pixel_elem = elem_explicit({0x7FE0, 0x0010}, :OW, pixel_data)
      binary = build_p10_binary([], [pixel_elem])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x7FE0, 0x0010}) == pixel_data
    end

    test "emits :end as last event" do
      binary = build_p10_binary([])
      events = collect_events(binary)
      assert List.last(events) == :end
    end
  end

  # ── Implicit VR Little Endian ──────────────────────────────────────────

  describe "Implicit VR Little Endian" do
    test "parses implicit VR data set" do
      patient_name_value = "DOE^JOHN"

      implicit_element =
        <<0x10, 0x00, 0x10, 0x00, byte_size(patient_name_value)::little-32>> <>
          patient_name_value

      binary = build_p10_with_ts("1.2.840.10008.1.2", implicit_element)
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "looks up VR from dictionary for implicit elements" do
      # Rows (0028,0010) should be US
      rows_value = <<512::little-16>>

      implicit_rows =
        <<0x28, 0x00, 0x10, 0x00, byte_size(rows_value)::little-32>> <> rows_value

      binary = build_p10_with_ts("1.2.840.10008.1.2", implicit_rows)
      events = collect_events(binary)

      data_elements =
        Enum.filter(element_events(events), fn elem ->
          {group, _} = elem.tag
          group != 0x0002
        end)

      [rows_elem] = data_elements
      assert rows_elem.vr == :US
    end
  end

  # ── Explicit VR Big Endian (Retired) ───────────────────────────────────

  describe "Explicit VR Big Endian (retired)" do
    test "parses big endian data set" do
      patient_name_value = "DOE^JOHN"

      big_endian_elem =
        <<0x00, 0x10, 0x00, 0x10, "PN", byte_size(patient_name_value)::big-16>> <>
          patient_name_value

      binary = build_p10_with_ts("1.2.840.10008.1.2.2", big_endian_elem)
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end
  end

  # ── Deflated Explicit VR Little Endian ─────────────────────────────────

  describe "Deflated Explicit VR Little Endian" do
    test "parses deflated data set" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      deflated = :zlib.compress(patient)
      binary = build_p10_with_ts("1.2.840.10008.1.2.1.99", deflated)

      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end
  end

  # ── Trailing Padding ───────────────────────────────────────────────────

  describe "trailing padding (FFFC,FFFC)" do
    test "stops at trailing padding in Explicit VR LE" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      padding_data = <<0, 0, 0, 0>>

      padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, byte_size(padding_data)::little-32>> <>
          padding_data

      binary = build_p10_binary([], [patient, padding])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
      refute Map.has_key?(ds.elements, {0xFFFC, 0xFFFC})
    end

    test "stops at trailing padding in big endian" do
      patient_value = "DOE^JOHN"

      big_elem =
        <<0x00, 0x10, 0x00, 0x10, "PN", byte_size(patient_value)::big-16>> <> patient_value

      padding_data = <<0, 0, 0, 0>>

      padding =
        <<0xFF, 0xFC, 0xFF, 0xFC, "OB", 0::16, byte_size(padding_data)::big-32>> <>
          padding_data

      binary = build_p10_with_ts("1.2.840.10008.1.2.2", big_elem <> padding)
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end
  end

  # ── Sequences ──────────────────────────────────────────────────────────

  describe "sequences (SQ)" do
    test "emits sequence_start/end events for defined-length sequence" do
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, {0x0008, 0x1115}, _}, &1))
      assert :sequence_end in events
    end

    test "emits item_start/end events" do
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:item_start, _}, &1))
      assert :item_end in events
    end

    test "materializes defined-length sequence via to_data_set" do
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(sq_value)
      assert length(sq_value) == 1
      [item_data] = sq_value
      assert Map.has_key?(item_data, {0x0008, 0x1150})
    end

    test "handles undefined-length sequence with delimiter" do
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert length(sq_value) == 1
    end

    test "handles undefined-length items with item delimiter" do
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner_elem <> item_delim
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert length(sq_value) == 1
    end

    test "handles empty sequence (zero length)" do
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0::little-32>>
      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert sq_value == []
    end

    test "handles empty item (zero defined length)" do
      empty_item = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(empty_item)::little-32>> <> empty_item
      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert length(sq_value) == 1
      [item] = sq_value
      assert item == %{}
    end

    test "handles empty undefined-length item (delimiter only)" do
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      empty_item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> item_delim
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          empty_item <> seq_delim

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert length(sq_value) == 1
      [item] = sq_value
      assert item == %{}
    end

    test "handles multiple items in a sequence" do
      inner1 = pad_even("1.2.840.10008.5.1.4.1.1.2")
      elem1 = <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner1)::little-16>> <> inner1
      item1 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(elem1)::little-32>> <> elem1

      inner2 = pad_even("1.2.840.10008.5.1.4.1.1.4")
      elem2 = <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner2)::little-16>> <> inner2
      item2 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(elem2)::little-32>> <> elem2

      items = item1 <> item2
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(items)::little-32>> <> items

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert length(sq_value) == 2
    end

    test "handles nested sequences" do
      inner_value = pad_even("1.2.3.4")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      inner_item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem

      inner_sq =
        <<0x08, 0x00, 0x40, 0x11, "SQ", 0::16, byte_size(inner_item)::little-32>> <> inner_item

      outer_item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_sq)::little-32>> <> inner_sq

      outer_sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(outer_item)::little-32>> <> outer_item

      binary = build_p10_binary([], [outer_sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      outer = DataSet.get(ds, {0x0008, 0x1115})
      assert length(outer) == 1
      [outer_item_data] = outer
      inner = Map.get(outer_item_data, {0x0008, 0x1140})
      assert %DataElement{vr: :SQ, value: inner_items} = inner
      assert length(inner_items) == 1
    end
  end

  # ── Encapsulated Pixel Data ────────────────────────────────────────────

  describe "encapsulated pixel data" do
    test "emits pixel_data_start/fragment/end events" do
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      frag_data = :crypto.strong_rand_bytes(64)
      fragment = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      pixel_data = pixel_tag <> bot <> fragment <> seq_delim

      binary = build_p10_binary([], [pixel_data])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:pixel_data_start, {0x7FE0, 0x0010}, :OB}, &1))
      assert Enum.any?(events, &match?({:pixel_data_fragment, _, _}, &1))
      assert :pixel_data_end in events
    end

    test "materializes encapsulated pixel data via to_data_set" do
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      frag1 = :crypto.strong_rand_bytes(32)
      fragment1 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag1)::little-32>> <> frag1
      frag2 = :crypto.strong_rand_bytes(48)
      fragment2 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag2)::little-32>> <> frag2
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      pixel_data = pixel_tag <> bot <> fragment1 <> fragment2 <> seq_delim

      binary = build_p10_binary([], [pixel_data])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      elem = DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert %DataElement{vr: :OB, value: {:encapsulated, fragments}} = elem
      # BOT + 2 fragments = 3
      assert length(fragments) == 3
    end

    test "pixel data fragment indices are sequential" do
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      frag_data = <<0xAB, 0xCD>>
      fragment = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      binary = build_p10_binary([], [pixel_tag <> bot <> fragment <> fragment <> seq_delim])
      events = collect_events(binary)

      indices =
        events
        |> Enum.flat_map(fn
          {:pixel_data_fragment, idx, _} -> [idx]
          _ -> []
        end)

      assert indices == [0, 1, 2]
    end
  end

  # ── Error Handling ─────────────────────────────────────────────────────

  describe "error handling" do
    test "truncated element value" do
      truncated = <<0x10, 0x00, 0x10, 0x00, "PN", 100::little-16, "DOE^">>
      binary = build_p10_binary([], [truncated])
      events = collect_events(binary)
      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "truncated after tag bytes" do
      truncated = <<0x10, 0x00, 0x10, 0x00>>
      binary = build_p10_binary([], [truncated])
      events = collect_events(binary)
      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "truncated long-value VR header" do
      truncated = <<0x10, 0x00, 0x10, 0x00, "OB", 0::16>>
      binary = build_p10_binary([], [truncated])
      events = collect_events(binary)
      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "truncated encapsulated fragment" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      truncated_frag = <<0xFE, 0xFF, 0x00, 0xE0, 100::little-32, 0xAB, 0xCD>>

      binary = build_p10_binary([], [pixel_tag <> bot <> truncated_frag])
      events = collect_events(binary)
      assert Enum.any?(events, &match?({:error, _}, &1))
    end
  end

  # ── Graceful EOF ───────────────────────────────────────────────────────

  describe "graceful EOF handling" do
    test "empty data set produces :end event" do
      binary = build_p10_binary([])
      events = collect_events(binary)
      assert :end in events
    end

    test "trailing bytes fewer than a tag are ignored" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      # 3 trailing bytes, not enough for a tag
      data = patient <> <<0, 0, 0>>
      binary = build_p10_binary([], [data])
      events = collect_events(binary)
      # Should still get the patient element and :end
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end
  end

  # ── Stream Composability ───────────────────────────────────────────────

  describe "stream composability" do
    test "filter elements by tag group" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      binary = build_p10_binary([], [modality, patient])

      patient_tags =
        binary
        |> Dicom.P10.Stream.parse()
        |> Stream.filter(fn
          {:element, %{tag: {0x0010, _}}} -> true
          _ -> false
        end)
        |> Enum.map(fn {:element, elem} -> elem.tag end)

      assert patient_tags == [{0x0010, 0x0010}]
    end

    test "take_while can stop early" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      # Large pixel data that shouldn't be read
      pixel_data = :crypto.strong_rand_bytes(1024)
      pixel_elem = elem_explicit({0x7FE0, 0x0010}, :OW, pixel_data)
      binary = build_p10_binary([], [patient, pixel_elem])

      early_events =
        binary
        |> Dicom.P10.Stream.parse()
        |> Enum.take_while(fn
          {:element, %{tag: {0x7FE0, _}}} -> false
          _ -> true
        end)

      # Should NOT include pixel data
      refute Enum.any?(early_events, fn
               {:element, %{tag: {0x7FE0, _}}} -> true
               _ -> false
             end)
    end

    test "collect tags only via map" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      binary = build_p10_binary([], [modality, patient])

      all_tags =
        binary
        |> Dicom.P10.Stream.parse()
        |> Stream.filter(&match?({:element, _}, &1))
        |> Enum.map(fn {:element, elem} -> elem.tag end)

      assert {0x0010, 0x0010} in all_tags
      assert {0x0008, 0x0060} in all_tags
    end

    test "count elements via reduce" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      binary = build_p10_binary([], [modality, patient])

      count =
        binary
        |> Dicom.P10.Stream.parse()
        |> Enum.count(fn
          {:element, %{tag: {g, _}}} when g != 0x0002 -> true
          _ -> false
        end)

      assert count == 2
    end
  end

  # ── Convenience Functions ──────────────────────────────────────────────

  describe "Dicom.stream_parse/1" do
    test "delegates to Dicom.P10.Stream.parse/1" do
      binary = build_p10_binary([])
      events = Dicom.stream_parse(binary) |> Enum.to_list()
      assert :file_meta_start in events
      assert :end in events
    end
  end

  # ── to_data_set Equivalence ────────────────────────────────────────────

  describe "to_data_set equivalence with Reader.parse" do
    test "simple data set matches Reader output" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      patient_id = elem_explicit({0x0010, 0x0020}, :LO, "PAT001")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      binary = build_p10_binary([], [modality, patient, patient_id])

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "data set with sequence matches Reader output" do
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      binary = build_p10_binary([], [sq, patient])

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "data set with encapsulated pixel data matches Reader output" do
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      frag_data = :crypto.strong_rand_bytes(64)
      fragment = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      pixel_data = pixel_tag <> bot <> fragment <> seq_delim

      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      binary = build_p10_binary([], [patient, pixel_data])

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "implicit VR data set matches Reader output" do
      patient_name_value = "DOE^JOHN"

      implicit_element =
        <<0x10, 0x00, 0x10, 0x00, byte_size(patient_name_value)::little-32>> <>
          patient_name_value

      binary = build_p10_with_ts("1.2.840.10008.1.2", implicit_element)

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "big endian data set matches Reader output" do
      patient_value = "DOE^JOHN"

      big_elem =
        <<0x00, 0x10, 0x00, 0x10, "PN", byte_size(patient_value)::big-16>> <> patient_value

      binary = build_p10_with_ts("1.2.840.10008.1.2.2", big_elem)

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "deflated data set matches Reader output" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      deflated = :zlib.compress(patient)
      binary = build_p10_with_ts("1.2.840.10008.1.2.1.99", deflated)

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "roundtrip written data set through streaming parser" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> DataSet.put({0x0010, 0x0020}, :LO, "PAT001")
        |> DataSet.put({0x0008, 0x0060}, :CS, "CT")

      {:ok, binary} = Dicom.write(ds)
      {:ok, reader_ds} = Dicom.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end
  end

  # ── Property-Based Tests ───────────────────────────────────────────────

  describe "property: streaming parser equivalence" do
    test "to_data_set(stream_parse(bin)) == Reader.parse(bin) for random elements" do
      for _ <- 1..50 do
        num_elements = Enum.random(1..10)

        elements =
          for _ <- 1..num_elements do
            group = Enum.random([0x0008, 0x0010, 0x0018, 0x0020, 0x0028])
            element = Enum.random(0x0001..0x00FF)
            vr = Enum.random([:PN, :LO, :SH, :CS, :DA, :TM, :DS, :IS, :AE, :AS])
            value_len = Enum.random(0..32) * 2
            value = :crypto.strong_rand_bytes(value_len)

            # Sanitize to printable ASCII
            value =
              value
              |> :binary.bin_to_list()
              |> Enum.map(fn b -> rem(b, 95) + 32 end)
              |> :binary.list_to_bin()

            value = pad_even(value)
            tag_bin = <<group::little-16, element::little-16>>
            vr_str = Atom.to_string(vr)
            tag_bin <> vr_str <> <<byte_size(value)::little-16>> <> value
          end

        data = IO.iodata_to_binary(elements)
        binary = build_p10_binary([], [data])

        {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
        {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

        assert_data_sets_equal(reader_ds, stream_ds)
      end
    end
  end

  # ── File I/O ───────────────────────────────────────────────────────────

  describe "parse_file/1" do
    @tag :tmp_dir
    test "parses a DICOM file from disk", %{tmp_dir: tmp_dir} do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      binary = build_p10_binary([], [patient])
      path = Path.join(tmp_dir, "test.dcm")
      File.write!(path, binary)

      events = Dicom.P10.Stream.parse_file(path) |> Enum.to_list()
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end

    @tag :tmp_dir
    test "parse_file equivalence with Reader for file on disk", %{tmp_dir: tmp_dir} do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      binary = build_p10_binary([], [modality, patient])
      path = Path.join(tmp_dir, "test2.dcm")
      File.write!(path, binary)

      {:ok, reader_ds} = Dicom.parse_file(path)
      {:ok, stream_ds} = Dicom.P10.Stream.parse_file(path) |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "parse_file returns error for nonexistent file" do
      events = Dicom.P10.Stream.parse_file("/nonexistent/path.dcm") |> Enum.to_list()
      assert [{:error, :enoent}] = events
    end
  end

  # ── Implicit VR Sequence Streaming ────────────────────────────────────

  describe "implicit VR sequences via streaming state machine" do
    test "implicit VR defined-length sequence" do
      # ReferencedImageSequence (0008,1140) is known as SQ in dictionary
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, byte_size(inner_value)::little-32>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      # ReferencedImageSequence (0008,1140) - known as SQ
      sq = <<0x08, 0x00, 0x40, 0x11, byte_size(item)::little-32>> <> item

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end

    test "implicit VR undefined-length sequence" do
      # ReferencedImageSequence (0008,1140) is known as SQ in dictionary
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      # Referenced SOP Class UID (0008,1150) as implicit: tag + len + value
      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, byte_size(inner_value)::little-32>> <> inner_value

      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner_elem <> item_delim
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
      # ReferencedImageSequence (0008,1140) - known as SQ
      sq = <<0x08, 0x00, 0x40, 0x11, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)

      # Streaming parser handles this correctly
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()
      sq_value = DataSet.get(stream_ds, {0x0008, 0x1140})
      assert is_list(sq_value)
      assert length(sq_value) == 1
    end
  end

  # ── Big Endian Sequences ────────────────────────────────────────────────

  describe "big endian sequences" do
    test "big endian sequence with item" do
      inner_value = "DOE^JOHN"

      inner_elem =
        <<0x00, 0x10, 0x00, 0x10, "PN", byte_size(inner_value)::big-16>> <> inner_value

      # Item tags are always LE for BE transfer syntax per PS3.5 7.5
      # Actually, item tags follow transfer syntax byte ordering
      item = <<0xFF, 0xFE, 0xE0, 0x00, byte_size(inner_elem)::big-32>> <> inner_elem

      sq =
        <<0x00, 0x08, 0x11, 0x15, "SQ", 0::16, byte_size(item)::big-32>> <> item

      binary = build_p10_with_ts("1.2.840.10008.1.2.2", sq)

      {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end
  end

  # ── Source Module Edge Cases ────────────────────────────────────────────

  describe "Source module" do
    alias Dicom.P10.Stream.Source

    test "from_binary creates an eof source" do
      source = Source.from_binary(<<1, 2, 3>>)
      assert Source.available(source) == 3
      assert source.io == :eof
    end

    test "eof? returns true for exhausted binary source" do
      source = Source.from_binary(<<>>)
      assert Source.eof?(source)
    end

    test "eof? returns false for non-empty binary source" do
      source = Source.from_binary(<<1>>)
      refute Source.eof?(source)
    end

    test "bytes_consumed tracks consumption" do
      source = Source.from_binary(<<1, 2, 3, 4, 5>>)
      assert Source.bytes_consumed(source) == 0
      {:ok, _, source} = Source.consume(source, 3)
      assert Source.bytes_consumed(source) == 3
    end

    test "ensure returns error for nil io" do
      source = %Source{buffer: <<>>, io: nil, offset: 0}
      assert {:error, :unexpected_end} = Source.ensure(source, 1)
    end

    test "peek returns error when insufficient data" do
      source = Source.from_binary(<<1, 2>>)
      assert {:error, :unexpected_end} = Source.peek(source, 5)
    end

    test "ensure succeeds when buffer already has enough" do
      source = Source.from_binary(<<1, 2, 3, 4, 5>>)
      {:ok, ^source} = Source.ensure(source, 3)
    end

    test "ensure returns error for eof with insufficient data" do
      source = Source.from_binary(<<1, 2>>)
      assert {:error, :unexpected_end} = Source.ensure(source, 5)
    end
  end

  # ── Additional Error Paths ──────────────────────────────────────────────

  describe "additional parser error paths" do
    test "unknown VR in data set is treated as UN" do
      # Element with unknown VR "XX"
      unknown = <<0x09, 0x00, 0x10, 0x00, "XX", 4::little-16, "DATA">>
      binary = build_p10_binary([], [unknown])
      events = collect_events(binary)

      data_elements =
        Enum.filter(element_events(events), fn elem ->
          {group, _} = elem.tag
          group != 0x0002
        end)

      assert length(data_elements) == 1
      assert hd(data_elements).vr == :UN
    end

    test "file meta with empty binary after preamble transitions gracefully" do
      # Preamble + DICM + no file meta at all
      binary = <<0::1024, "DICM">>
      events = collect_events(binary)
      assert :file_meta_start in events
      # Should transition to data_set and emit end
      assert Enum.any?(events, &match?({:file_meta_end, _}, &1))
      assert :end in events
    end

    test "Dicom.stream_parse_file/2 delegates correctly" do
      # Test the convenience function on Dicom module
      events = Dicom.stream_parse_file("/nonexistent/path.dcm") |> Enum.to_list()
      assert [{:error, :enoent}] = events
    end

    test "long VR element with defined length in data set" do
      # OW element with defined (non-encapsulated) length
      data = :crypto.strong_rand_bytes(128)
      ow_elem = elem_explicit({0x7FE0, 0x0010}, :OW, data)
      binary = build_p10_binary([], [ow_elem])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      assert DataSet.get(ds, {0x7FE0, 0x0010}) == data
    end
  end

  # ── Writer Roundtrip Through Streaming ──────────────────────────────────

  describe "writer roundtrip through streaming" do
    test "roundtrip with sequences" do
      item = %{
        {0x0008, 0x1150} =>
          Dicom.DataElement.new({0x0008, 0x1150}, :UI, "1.2.840.10008.5.1.4.1.1.2")
      }

      seq_elem = Dicom.DataElement.new({0x0008, 0x1115}, :SQ, [item])

      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1115}, seq_elem)}

      {:ok, binary} = Dicom.write(ds)
      {:ok, reader_ds} = Dicom.parse(binary)
      {:ok, stream_ds} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      assert_data_sets_equal(reader_ds, stream_ds)
    end
  end

  # ── File Meta Eager Path (Sequences in File Meta) ─────────────────────

  describe "file meta eager parsing path" do
    test "defined-length SQ in file meta" do
      inner_value = pad_even("1.2.3.4")

      inner_elem =
        <<0x02, 0x00, 0x01, 0x01, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x02, 0x00, 0x00, 0x01, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = ds.file_meta[{0x0002, 0x0100}]
      assert sq_elem.vr == :SQ
      assert length(sq_elem.value) == 1
      [item_data] = sq_elem.value
      assert Map.has_key?(item_data, {0x0002, 0x0101})
    end

    test "undefined-length SQ in file meta" do
      inner_value = pad_even("1.2.3.4")

      inner_elem =
        <<0x02, 0x00, 0x01, 0x01, "UI", byte_size(inner_value)::little-16>> <> inner_value

      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner_elem <> item_delim
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
      sq = <<0x02, 0x00, 0x00, 0x01, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim

      binary = build_p10_binary([sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = ds.file_meta[{0x0002, 0x0100}]
      assert length(sq_elem.value) == 1
    end

    test "empty SQ (zero length) in file meta" do
      sq = <<0x02, 0x00, 0x00, 0x01, "SQ", 0::16, 0::little-32>>
      binary = build_p10_binary([sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = ds.file_meta[{0x0002, 0x0100}]
      assert sq_elem.value == []
    end

    test "file meta SQ with multiple bounded items" do
      inner1 = pad_even("1.2.3")
      elem1 = <<0x02, 0x00, 0x01, 0x01, "UI", byte_size(inner1)::little-16>> <> inner1
      item1 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(elem1)::little-32>> <> elem1

      inner2 = pad_even("4.5.6")
      elem2 = <<0x02, 0x00, 0x01, 0x01, "UI", byte_size(inner2)::little-16>> <> inner2
      item2 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(elem2)::little-32>> <> elem2

      items = item1 <> item2
      sq = <<0x02, 0x00, 0x00, 0x01, "SQ", 0::16, byte_size(items)::little-32>> <> items

      binary = build_p10_binary([sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = ds.file_meta[{0x0002, 0x0100}]
      assert length(sq_elem.value) == 2
    end

    test "file meta SQ with long VR inner element (OB)" do
      inner_data = :crypto.strong_rand_bytes(32)

      inner_elem =
        <<0x02, 0x00, 0x02, 0x01, "OB", 0::16, byte_size(inner_data)::little-32>> <> inner_data

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x02, 0x00, 0x00, 0x01, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = ds.file_meta[{0x0002, 0x0100}]
      [item_data] = sq_elem.value
      elem = Map.get(item_data, {0x0002, 0x0102})
      assert elem.vr == :OB
      assert elem.value == inner_data
    end

    test "file meta SQ with encapsulated pixel data inside item" do
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      frag_data = <<0xAB, 0xCD, 0xEF, 0x01>>
      fragment = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(frag_data)::little-32>> <> frag_data
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      pixel_elem =
        <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          bot <> fragment <> seq_delim

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(pixel_elem)::little-32>> <> pixel_elem
      sq = <<0x02, 0x00, 0x00, 0x01, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = ds.file_meta[{0x0002, 0x0100}]
      [item_data] = sq_elem.value
      pixel = Map.get(item_data, {0x7FE0, 0x0010})
      assert pixel.vr == :OB
      assert {:encapsulated, fragments} = pixel.value
      assert length(fragments) == 2
    end

    test "file meta SQ with unknown VR inner element" do
      inner_elem = <<0x02, 0x00, 0x03, 0x01, "XX", 4::little-16, "DATA">>
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x02, 0x00, 0x00, 0x01, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = ds.file_meta[{0x0002, 0x0100}]
      [item_data] = sq_elem.value
      elem = Map.get(item_data, {0x0002, 0x0103})
      assert elem.vr == :UN
    end
  end

  # ── Streaming Parser Edge Cases ─────────────────────────────────────

  describe "streaming parser edge cases" do
    test "file meta element read error (truncated)" do
      # Start of a file meta element but truncated before value
      truncated = <<0x02, 0x00, 0x01, 0x00, "UI", 100::little-16, "short">>

      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      all_meta = IO.iodata_to_binary([ts_elem, truncated])
      group_length = build_group_length_element(all_meta)
      binary = <<0::1024, "DICM">> <> group_length <> all_meta

      events = collect_events(binary)
      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "undefined-length sequence with unexpected tag" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      # Follow with a regular element instead of item or delimiter
      binary = build_p10_binary([], [sq_start <> patient])
      events = collect_events(binary)

      assert :sequence_end in events
    end

    test "undefined-length sequence truncated (EOF)" do
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # No items, no delimiter - just EOF
      binary = build_p10_binary([], [sq_start])
      events = collect_events(binary)

      assert :sequence_end in events
    end

    test "defined-length sequence with unexpected tag (not item)" do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      # SQ with defined length that contains a regular element instead of items
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(patient)::little-32>> <> patient

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert :sequence_end in events
    end

    test "defined-length sequence truncated (EOF)" do
      # SQ with defined length longer than available data
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 1000::little-32>>
      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert :sequence_end in events
    end

    test "seq_delim tag terminates undefined-length item" do
      inner = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      binary = build_p10_binary([], [sq_start <> item_start <> inner <> seq_delim])
      events = collect_events(binary)

      assert :item_end in events
      assert :sequence_end in events
    end

    test "trailing padding inside undefined-length item is skipped" do
      inner = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      padding_data = <<0, 0>>

      padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, byte_size(padding_data)::little-32>> <>
          padding_data

      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner <> padding <> item_delim

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> seq_delim

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert length(sq_value) == 1
    end

    test "undefined-length item truncated (EOF)" do
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      binary = build_p10_binary([], [sq_start <> item_start])
      events = collect_events(binary)

      assert :item_end in events
    end

    test "defined-length item truncated (EOF)" do
      item = <<0xFE, 0xFF, 0x00, 0xE0, 1000::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert :item_end in events
    end

    test "pixel data with unexpected tag terminates" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Put a non-item, non-seq_delim tag where next fragment should be
      random_tag = <<0x10, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00>>

      binary = build_p10_binary([], [pixel_tag <> bot <> random_tag])
      events = collect_events(binary)

      assert :pixel_data_end in events
    end

    test "pixel data truncated (EOF)" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      # Just BOT, then EOF (no seq_delim)
      binary = build_p10_binary([], [pixel_tag <> bot])
      events = collect_events(binary)

      assert :pixel_data_end in events
    end

    test "pixel data fragment length read error" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Item tag but truncated length
      truncated_frag = <<0xFE, 0xFF, 0x00, 0xE0, 0xAB>>

      binary = build_p10_binary([], [pixel_tag <> bot <> truncated_frag])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "item start length read error" do
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Item tag but truncated length (only 2 bytes of 4)
      truncated_item = <<0xFE, 0xFF, 0x00, 0xE0, 0xAB, 0xCD>>

      binary = build_p10_binary([], [sq_start <> truncated_item])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "unsupported undefined-length non-SQ element" do
      # A non-SQ, non-pixel-data element with undefined length (0xFFFFFFFF)
      # This is invalid per DICOM but the parser should error gracefully
      elem =
        <<0x09, 0x00, 0x10, 0x00, "UN", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      binary = build_p10_binary([], [elem])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, {:unsupported_undefined_length, _}} -> true
               _ -> false
             end)
    end

    test "deflated with empty buffer" do
      # File meta followed by empty deflated content
      binary = build_p10_with_ts("1.2.840.10008.1.2.1.99", <<>>)
      events = collect_events(binary)

      assert :file_meta_start in events
      assert Enum.any?(events, &match?({:file_meta_end, _}, &1))
    end

    test "implicit VR with unknown tag falls back to UN" do
      # Tag not in dictionary → VR becomes :UN
      unknown_tag_value = "DATA"

      implicit_elem =
        <<0x99, 0x00, 0x99, 0x00, byte_size(unknown_tag_value)::little-32>> <> unknown_tag_value

      binary = build_p10_with_ts("1.2.840.10008.1.2", implicit_elem)
      events = collect_events(binary)

      data_elements =
        Enum.filter(element_events(events), fn elem ->
          {group, _} = elem.tag
          group != 0x0002
        end)

      assert length(data_elements) == 1
      assert hd(data_elements).vr == :UN
    end
  end

  # ── to_data_set Error Propagation ────────────────────────────────────

  describe "to_data_set error propagation" do
    test "error event in stream propagates through to_data_set" do
      # Create a stream with an error event
      events = [:file_meta_start, {:error, :test_error}]
      assert {:error, :test_error} = Dicom.P10.Stream.to_data_set(events)
    end

    test "error in truncated binary propagates through to_data_set" do
      truncated = <<0x10, 0x00, 0x10, 0x00, "PN", 100::little-16, "DOE^">>
      binary = build_p10_binary([], [truncated])
      events = Dicom.P10.Stream.parse(binary)

      assert {:error, _reason} = Dicom.P10.Stream.to_data_set(events)
    end
  end

  # ── parse_file Cleanup Paths ─────────────────────────────────────────

  describe "parse_file cleanup" do
    @tag :tmp_dir
    test "file handle closed on early stream halt", %{tmp_dir: tmp_dir} do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      pixel_data = :crypto.strong_rand_bytes(4096)
      pixel_elem = elem_explicit({0x7FE0, 0x0010}, :OW, pixel_data)
      binary = build_p10_binary([], [patient, pixel_elem])
      path = Path.join(tmp_dir, "halt_test.dcm")
      File.write!(path, binary)

      # Only take first 3 events then halt
      events = Dicom.P10.Stream.parse_file(path) |> Enum.take(3)
      assert length(events) == 3
      # File should be closed properly (no error)
    end
  end

  # ── Assertion Helpers ──────────────────────────────────────────────────

  defp assert_data_sets_equal(ds1, ds2) do
    # Compare file meta
    assert map_size(ds1.file_meta) == map_size(ds2.file_meta),
           "file_meta size mismatch: #{map_size(ds1.file_meta)} vs #{map_size(ds2.file_meta)}"

    for {tag, elem1} <- ds1.file_meta do
      elem2 = Map.get(ds2.file_meta, tag)
      assert elem2 != nil, "missing file_meta tag #{Dicom.Tag.format(tag)} in stream result"
      assert_elements_equal(elem1, elem2, tag)
    end

    # Compare elements
    assert map_size(ds1.elements) == map_size(ds2.elements),
           "elements size mismatch: #{map_size(ds1.elements)} vs #{map_size(ds2.elements)}\n" <>
             "reader tags: #{inspect(Map.keys(ds1.elements) |> Enum.sort())}\n" <>
             "stream tags: #{inspect(Map.keys(ds2.elements) |> Enum.sort())}"

    for {tag, elem1} <- ds1.elements do
      elem2 = Map.get(ds2.elements, tag)
      assert elem2 != nil, "missing element tag #{Dicom.Tag.format(tag)} in stream result"
      assert_elements_equal(elem1, elem2, tag)
    end
  end

  defp assert_elements_equal(elem1, elem2, tag) do
    assert elem1.vr == elem2.vr,
           "VR mismatch for #{Dicom.Tag.format(tag)}: #{elem1.vr} vs #{elem2.vr}"

    assert elem1.value == elem2.value,
           "value mismatch for #{Dicom.Tag.format(tag)}: #{inspect(elem1.value)} vs #{inspect(elem2.value)}"
  end
end
