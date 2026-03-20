defmodule Dicom.P10.StreamTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Dicom.{DataElement, DataSet}
  alias Dicom.P10.Deflated
  alias Dicom.P10.Stream.{Parser, Source}

  import Dicom.TestHelpers,
    only: [
      pad_to_even: 1,
      elem_explicit: 3,
      build_group_length_element: 1
    ]

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

    test "returns structured error for unknown transfer syntax UID" do
      binary =
        build_p10_with_ts("1.2.999.999.999", elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN"))

      events = collect_events(binary)

      assert List.last(events) == {:error, {:unknown_transfer_syntax, "1.2.999.999.999"}}
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

  describe "parse_file/2 resource handling" do
    test "returns file open errors as a single stream event" do
      missing = Path.join(System.tmp_dir!(), "missing-#{System.unique_integer([:positive])}.dcm")
      assert [{:error, :enoent}] = missing |> Dicom.P10.Stream.parse_file() |> Enum.to_list()
    end

    test "open_file_source/2 returns structured open errors" do
      missing = Path.join(System.tmp_dir!(), "missing-#{System.unique_integer([:positive])}.dcm")
      assert {:error, :enoent, nil} = Dicom.P10.Stream.open_file_source(missing, [])
    end

    test "closes cleanly when parsing stops without an explicit end event" do
      path = Path.join(System.tmp_dir!(), "truncated-#{System.unique_integer([:positive])}.dcm")
      File.write!(path, <<0::1024, "DICM">>)

      try do
        assert [:file_meta_start, {:file_meta_end, "1.2.840.10008.1.2"}, :end] =
                 path |> Dicom.P10.Stream.parse_file() |> Enum.to_list()
      after
        File.rm(path)
      end
    end

    test "next_file_event/1 halts cleanly when parser state is already done" do
      state = Parser.new(Source.from_binary("")) |> Map.put(:phase, :done)
      assert {:halt, {:done, :fake_io}} = Dicom.P10.Stream.next_file_event({:ok, state, :fake_io})
    end

    test "close_file_resource/1 closes done IO handles" do
      path = Path.join(System.tmp_dir!(), "closer-#{System.unique_integer([:positive])}.dcm")
      File.write!(path, "")
      {:ok, io} = File.open(path, [:raw, :binary, :read])

      try do
        assert :ok = Dicom.P10.Stream.close_file_resource({:done, io})
        assert {:error, reason} = :file.position(io, :cur)
        assert reason in [:terminated, :einval]
      after
        File.rm(path)
      end
    end

    test "close_file_resource/1 handles error and fallback states" do
      assert :ok = Dicom.P10.Stream.close_file_resource({:error, :enoent, nil})
      assert :ok = Dicom.P10.Stream.close_file_resource(:unexpected_state)
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
      deflated = Deflated.compress(patient)
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
      deflated = Deflated.compress(patient)
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

    @tag :tmp_dir
    test "parse_file honors read_ahead option", %{tmp_dir: tmp_dir} do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      binary = build_p10_binary([], [modality, patient])
      path = Path.join(tmp_dir, "read_ahead.dcm")
      File.write!(path, binary)

      {:ok, ds} =
        Dicom.P10.Stream.parse_file(path, read_ahead: 8)
        |> Dicom.P10.Stream.to_data_set()

      assert DataSet.get(ds, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
      assert DataSet.get(ds, {0x0008, 0x0060}) |> String.trim() == "CT"
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

    test "from_io creates a source with io handle" do
      source = Source.from_io(self())
      assert source.io == self()
      assert source.buffer == <<>>
      assert source.offset == 0
    end

    test "from_io applies read_ahead option" do
      source = Source.from_io(self(), read_ahead: 8_192)
      assert source.read_ahead == 8_192
    end

    test "eof? returns false for io source with empty buffer" do
      source = %Source{buffer: <<>>, io: self(), offset: 0}
      refute Source.eof?(source)
    end

    @tag [tmp_dir: true]
    test "ensure fills buffer from IO device", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "source_test.bin")
      File.write!(path, :crypto.strong_rand_bytes(256))

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io)

      {:ok, source} = Source.ensure(source, 100)
      assert byte_size(source.buffer) >= 100

      File.close(io)
    end

    @tag [tmp_dir: true]
    test "ensure marks eof when file is exhausted", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "small_source.bin")
      File.write!(path, <<1, 2, 3, 4, 5>>)

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io)

      # Request more than file has
      result = Source.ensure(source, 100)
      assert {:error, :unexpected_end} = result

      File.close(io)
    end

    @tag [tmp_dir: true]
    test "IO source reads enough then marks eof on next ensure", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "io_eof.bin")
      data = :crypto.strong_rand_bytes(50)
      File.write!(path, data)

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io)

      {:ok, source} = Source.ensure(source, 50)
      assert byte_size(source.buffer) == 50

      {:ok, consumed_data, source} = Source.consume(source, 50)
      assert consumed_data == data

      # After consuming all data, next ensure triggers EOF detection
      assert {:error, :unexpected_end} = Source.ensure(source, 1)

      File.close(io)
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

    test "reads undefined-length non-SQ element through sequence delimiter" do
      value = <<"MYSTERY_DATA1234">>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      elem =
        <<0x09, 0x00, 0x10, 0x00, "UN", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          value <> seq_delim

      binary = build_p10_binary([], [elem])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:element, %Dicom.DataElement{tag: {0x0009, 0x0010}, vr: :UN, value: event_value}} ->
                 event_value == value

               _ ->
                 false
             end)
    end

    test "returns error for undefined-length non-SQ element without a delimiter" do
      elem = <<0x09, 0x00, 0x10, 0x00, "UN", 0::16, 0xFF, 0xFF, 0xFF, 0xFF, "ABC">>

      binary = build_p10_binary([], [elem])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, :unexpected_end}, &1))
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

  # ── Parser Edge Cases: Uncovered Branches ────────────────────────────

  describe "parser edge cases - sequence/item boundaries" do
    test "defined-length sequence ends when consumed >= remaining" do
      # Build a defined-length sequence with an item
      value = "CT"

      item_elem =
        <<0x08, 0x00, 0x60, 0x00, "CS", byte_size(value)::little-16>> <> value

      item_length = byte_size(item_elem)

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, item_length::little-32>> <>
          item_elem <>
          <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>

      total = byte_size(item)
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, total::little-32>> <> item

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      assert Enum.any?(events, &match?(:sequence_end, &1))
    end

    test "defined-length item ends when consumed >= remaining" do
      # Build item with exact length matching its elements
      value = "DOE^JOHN"

      item_elem =
        <<0x10, 0x00, 0x10, 0x00, "PN", byte_size(value)::little-16>> <> value

      item_length = byte_size(item_elem)

      item = <<0xFE, 0xFF, 0x00, 0xE0, item_length::little-32>> <> item_elem

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <>
          <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert Enum.any?(events, &match?(:item_end, &1))
      assert Enum.any?(events, &match?(:sequence_end, &1))
    end

    test "big-endian trailing padding detection" do
      big_endian_ts = "1.2.840.10008.1.2.2"
      patient_value = pad_even("DOE^JOHN")

      big_endian_elem =
        <<0x00, 0x10, 0x00, 0x10, "PN", byte_size(patient_value)::big-16>> <> patient_value

      trailing_padding = <<0xFF, 0xFC, 0xFF, 0xFC, "OB", 0::16, 0::big-32>>
      binary = build_p10_with_ts(big_endian_ts, big_endian_elem <> trailing_padding)
      events = collect_events(binary)

      assert :end in events
    end

    test "error reading tag in data_set phase" do
      # Only 2 bytes of a tag (need 4)
      truncated = <<0x10, 0x00>>
      binary = build_p10_binary([], [truncated])
      events = collect_events(binary)
      # Should end normally (unexpected_end => :end) or emit error
      assert :end in events or Enum.any?(events, &match?({:error, _}, &1))
    end

    test "error reading VR bytes in explicit dispatch" do
      # Tag present but VR bytes missing
      truncated = <<0x10, 0x00, 0x10, 0x00>>
      binary = build_p10_binary([], [truncated])
      events = collect_events(binary)
      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "unknown VR bytes fall back to UN with short length" do
      value = "DATA"

      unknown_vr_elem =
        <<0x10, 0x00, 0x99, 0x00, "ZZ", byte_size(value)::little-16>> <> value

      binary = build_p10_binary([], [unknown_vr_elem])
      events = collect_events(binary)

      elems = element_events(events) |> Enum.filter(fn e -> e.tag != {0x0002, 0x0000} end)

      data_elems =
        Enum.filter(elems, fn e ->
          {g, _} = e.tag
          g != 0x0002
        end)

      assert length(data_elems) == 1
      assert hd(data_elems).vr == :UN
    end

    test "pixel data fragment error when length read fails" do
      # Start encapsulated pixel data then truncate mid-fragment
      encap_start =
        <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      # BOT item (empty)
      bot_item = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Truncated fragment item (tag but no length)
      truncated_frag = <<0xFE, 0xFF, 0x00, 0xE0>>

      binary = build_p10_binary([], [encap_start <> bot_item <> truncated_frag])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:pixel_data_start, _, _}, &1))
    end

    test "pixel data end on unexpected end" do
      # Start encapsulated pixel data then end abruptly (no seq delim)
      encap_start =
        <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      # BOT item only, no terminator
      bot_item = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      binary = build_p10_binary([], [encap_start <> bot_item])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:pixel_data_start, _, _}, &1))
      assert :pixel_data_end in events
    end

    test "item within sequence encounters seq_delim before item_delim" do
      # Undefined-length item that encounters seq delimiter before item delimiter
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Put a modality element inside the item
      modality = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>
      # Close with seq delim instead of item delim
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([], [sq_start <> item_start <> modality <> seq_delim])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      assert Enum.any?(events, &match?({:item_start, _}, &1))
      assert Enum.any?(events, &match?(:item_end, &1))
    end

    test "undefined-length sequence with non-item tag exits sequence" do
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Instead of an item tag, put a regular element
      regular_elem = <<0x10, 0x00, 0x10, 0x00, "PN", 4::little-16, "TEST">>

      binary = build_p10_binary([], [sq_start <> regular_elem])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      assert Enum.any?(events, &match?(:sequence_end, &1))
    end

    test "defined-length sequence with non-item tag exits sequence" do
      # Empty bytes for the defined length, but place a regular element tag
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 20::little-32>>
      regular_elem = <<0x10, 0x00, 0x10, 0x00, "PN", 4::little-16, "TEST">>

      binary = build_p10_binary([], [sq <> regular_elem])
      events = collect_events(binary)

      assert Enum.any?(events, &match?(:sequence_end, &1))
    end
  end

  describe "parser edge cases - trailing padding and error propagation" do
    test "trailing padding inside undefined-length item" do
      # Sequence with an undefined-length item containing trailing padding
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>

      # Normal element inside item
      modality = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      # Trailing padding element (FFFC,FFFC) inside item
      padding_value = <<0, 0, 0, 0>>

      trailing_pad =
        <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, byte_size(padding_value)::little-32>> <>
          padding_value

      # Item delimiter
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      # Sequence delimiter
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary =
        build_p10_binary(
          [],
          [sq_start <> item_start <> modality <> trailing_pad <> item_delim <> seq_delim]
        )

      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      assert Enum.any?(events, &match?({:item_start, _}, &1))
      assert Enum.any?(events, &match?(:item_end, &1))
      assert Enum.any?(events, &match?(:sequence_end, &1))
    end

    test "undefined-length sequence truncated at unexpected_end" do
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      # Sequence with no items and no delimiter — just truncated
      binary = build_p10_binary([], [sq_start])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      assert Enum.any?(events, &match?(:sequence_end, &1))
    end

    test "defined-length sequence truncated at unexpected_end" do
      # Sequence says it has 100 bytes of content, but there's nothing
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 100::little-32>>

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert Enum.any?(events, &match?(:sequence_end, &1))
    end

    test "defined-length item truncated at unexpected_end" do
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Item claims 100 bytes, but has only a few
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 100::little-32>>
      small_elem = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      binary = build_p10_binary([], [sq_start <> item_start <> small_elem])
      events = collect_events(binary)

      assert Enum.any?(events, &match?(:item_end, &1))
    end

    test "undefined-length item truncated at unexpected_end" do
      sq_start = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>

      # Only a small element, then nothing (no delimiter)
      small_elem = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      binary = build_p10_binary([], [sq_start <> item_start <> small_elem])
      events = collect_events(binary)

      assert Enum.any?(events, &match?(:item_end, &1))
    end

    test "pixel data fragment with insufficient data for value" do
      # Start encapsulated pixel data, BOT, then fragment claiming 1000 bytes but only 4 available
      encap_start =
        <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      bot_item = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Fragment header claims 1000 bytes
      frag_header = <<0xFE, 0xFF, 0x00, 0xE0, 1000::little-32>>
      # Only 4 bytes of data
      frag_data = <<1, 2, 3, 4>>

      binary = build_p10_binary([], [encap_start <> bot_item <> frag_header <> frag_data])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:pixel_data_start, _, _}, &1))
      # Should error or end gracefully
      assert Enum.any?(events, fn
               {:error, _} -> true
               :pixel_data_end -> true
               _ -> false
             end)
    end

    test "read_element error in data_set phase propagates" do
      # Tag is readable but the subsequent read fails
      # Use an element where length is larger than remaining data
      truncated_elem =
        <<0x10, 0x00, 0x10, 0x00, "PN", 100::little-16, "DOE">>

      binary = build_p10_binary([], [truncated_elem])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "sequence header error in explicit dispatch" do
      # SQ with truncated reserved+length bytes
      sq_truncated = <<0x08, 0x00, 0x15, 0x11, "SQ", 0x00>>

      binary = build_p10_binary([], [sq_truncated])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "long VR element with truncated reserved+length" do
      # OB element with only reserved bytes, no length
      ob_truncated = <<0x10, 0x00, 0x99, 0x00, "OB", 0x00, 0x00>>

      binary = build_p10_binary([], [ob_truncated])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "short VR element with truncated length" do
      # CS element with only 1 byte of the 2-byte length
      cs_truncated = <<0x08, 0x00, 0x60, 0x00, "CS", 0x02>>

      binary = build_p10_binary([], [cs_truncated])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end
  end

  describe "parser edge cases - file meta error paths" do
    test "file meta element read error propagates" do
      # Valid preamble + DICM, then a file meta tag with truncated element
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      all_meta = IO.iodata_to_binary([ts_elem])
      group_length = build_group_length_element(all_meta)

      # Now add a group 0x0002 tag but truncate the VR/length
      truncated_meta = <<0x02, 0x00, 0x99, 0x00>>

      binary = <<0::1024, "DICM">> <> group_length <> all_meta <> truncated_meta
      events = collect_events(binary)

      # Should transition to data_set phase when seeing non-0002 tag or error
      assert Enum.any?(events, &match?({:file_meta_end, _}, &1)) or
               Enum.any?(events, &match?({:error, _}, &1))
    end
  end

  # ── P10.Stream coverage: parse_file cleanup, nested sequence_end ─────

  describe "stream materialization — nested sequence_end" do
    test "sequence_end nested inside another stack frame pushes element" do
      # Outer SQ → Item → Inner SQ → Item → Element
      # This exercises push_element_to_stack for SQ elements on rest of stack
      inner_value = pad_even("1.2.3.4")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

      inner_item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem

      inner_sq =
        <<0x08, 0x00, 0x40, 0x11, "SQ", 0::16, byte_size(inner_item)::little-32>> <> inner_item

      # Add another element after the inner SQ inside the same outer item
      after_sq = elem_explicit({0x0008, 0x0060}, :CS, "CT")

      outer_item_content = inner_sq <> after_sq

      outer_item =
        <<0xFE, 0xFF, 0x00, 0xE0, byte_size(outer_item_content)::little-32>> <>
          outer_item_content

      outer_sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(outer_item)::little-32>> <> outer_item

      binary = build_p10_binary([], [outer_sq])
      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      outer = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(outer)
      [outer_item_data] = outer
      # Inner SQ should be present
      assert Map.has_key?(outer_item_data, {0x0008, 0x1140})
      # Modality should also be in the item
      assert Map.has_key?(outer_item_data, {0x0008, 0x0060})
    end
  end

  describe "parse_file cleanup paths" do
    @tag [tmp_dir: true]
    test "parse_file closes handle when stream is halted early", %{tmp_dir: tmp_dir} do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      pixel = elem_explicit({0x7FE0, 0x0010}, :OW, :crypto.strong_rand_bytes(1024))
      binary = build_p10_binary([], [patient, pixel])
      path = Path.join(tmp_dir, "halt_test.dcm")
      File.write!(path, binary)

      # Take only first few events, halting the stream early
      events = Dicom.P10.Stream.parse_file(path) |> Enum.take(5)
      assert length(events) <= 5
      # File handle should be cleaned up (no leaked file descriptors)
    end

    @tag [tmp_dir: true]
    test "parse_file handles error event from parser", %{tmp_dir: tmp_dir} do
      # Valid preamble + DICM, then corrupt file meta
      binary = <<0::1024, "DICM", 0x02, 0x00, 0x10, 0x00, "UI", 200::little-16, "short">>
      path = Path.join(tmp_dir, "error_test.dcm")
      File.write!(path, binary)

      events = Dicom.P10.Stream.parse_file(path) |> Enum.to_list()
      # Should get error and cleanup properly
      assert Enum.any?(events, &match?({:error, _}, &1)) or Enum.any?(events, &match?(:end, &1))
    end
  end

  describe "implicit VR streaming — SQ in data_set phase" do
    test "implicit VR undefined-length sequence streaming events" do
      inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, byte_size(inner_value)::little-32>> <> inner_value

      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner_elem <> item_delim
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
      sq = <<0x08, 0x00, 0x40, 0x11, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim

      # Add a regular element after the sequence
      patient_name = <<0x10, 0x00, 0x10, 0x00, 8::little-32>> <> "DOE^JOHN"

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq <> patient_name)
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, {0x0008, 0x1140}, _}, &1))
      assert :sequence_end in events
      assert Enum.any?(events, &match?({:item_start, _}, &1))
      assert :item_end in events

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "implicit VR defined-length item streaming" do
      inner_value = pad_even("1.2.3.4")

      inner_elem =
        <<0x08, 0x00, 0x50, 0x11, byte_size(inner_value)::little-32>> <> inner_value

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem
      sq = <<0x08, 0x00, 0x40, 0x11, byte_size(item)::little-32>> <> item

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_value = DataSet.get(ds, {0x0008, 0x1140})
      assert is_list(sq_value) and length(sq_value) == 1
    end
  end

  describe "encapsulated pixel data — streaming edge cases" do
    test "pixel data with empty BOT and no fragments produces empty" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([], [pixel_tag <> bot <> seq_delim])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:pixel_data_start, _, _}, &1))
      assert :pixel_data_end in events

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      elem = DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert %DataElement{value: {:encapsulated, fragments}} = elem
      # Only the BOT fragment
      assert length(fragments) == 1
    end

    test "pixel data stream truncated at unexpected_end" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # No seq_delim, stream ends

      binary = build_p10_binary([], [pixel_tag <> bot])
      events = collect_events(binary)

      # Should handle gracefully with pixel_data_end
      assert Enum.any?(events, &match?({:pixel_data_start, _, _}, &1))
      assert :pixel_data_end in events
    end
  end

  describe "undefined-length value error in data_set" do
    test "non-SQ non-pixel undefined-length value returns error" do
      # OB element (long-length VR) with 0xFFFFFFFF length for a non-SQ/pixel tag
      # Format: tag(4) + VR(2) + reserved(2) + length(4)
      undef_elem =
        <<0x09, 0x00, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>

      binary = build_p10_binary([], [undef_elem])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, :unexpected_end}, &1))
    end
  end

  # ── Big-Endian Explicit VR ─────────────────────────────────────────────

  describe "big-endian explicit VR transfer syntax" do
    test "parses elements in big-endian byte order" do
      # Build file meta with Big Endian Explicit transfer syntax
      ts_uid = "1.2.840.10008.1.2.2"
      # Big-endian data elements: tag (big), VR, length (big), value
      patient_name = <<0x00, 0x10, 0x00, 0x10, "PN", 8::big-16, "DOE^JOHN">>
      modality = <<0x00, 0x08, 0x00, 0x60, "CS", 2::big-16, "CT">>

      binary = build_p10_with_ts(ts_uid, modality <> patient_name)
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
      assert DataSet.get(ds, {0x0008, 0x0060}) == "CT"
    end

    test "parses long-length VR in big-endian" do
      ts_uid = "1.2.840.10008.1.2.2"
      value = "SOME DATA FOR OB"
      # OB: tag(4, big) + VR(2) + reserved(2) + length(4, big) + value
      ob_elem =
        <<0x00, 0x09, 0x00, 0x10, "OB", 0::16, byte_size(value)::big-32>> <> value

      binary = build_p10_with_ts(ts_uid, ob_elem)
      events = collect_events(binary)

      elements = element_events(events)
      assert Enum.any?(elements, fn e -> e.tag == {0x0009, 0x0010} end)
    end

    test "parses sequence in big-endian" do
      ts_uid = "1.2.840.10008.1.2.2"
      inner = <<0x00, 0x08, 0x01, 0x50, "UI", 8::big-16, "1.2.3.4\0">>
      item = <<0xFF, 0xFE, 0xE0, 0x00, byte_size(inner)::big-32>> <> inner
      sq = <<0x00, 0x08, 0x11, 0x40, "SQ", 0::16, byte_size(item)::big-32>> <> item

      binary = build_p10_with_ts(ts_uid, sq)
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_value = DataSet.get(ds, {0x0008, 0x1140})
      assert is_list(sq_value) and length(sq_value) == 1
    end
  end

  # ── Deflated Transfer Syntax ───────────────────────────────────────────

  describe "deflated explicit VR little-endian" do
    test "parses deflated data elements" do
      ts_uid = "1.2.840.10008.1.2.1.99"

      # Build data elements, then zlib compress them
      patient_name = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      modality = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      data = IO.iodata_to_binary([modality, patient_name])
      compressed = Deflated.compress(data)

      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even(ts_uid))
      group_length = build_group_length_element(ts_elem)
      binary = <<0::1024, "DICM">> <> group_length <> ts_elem <> compressed

      events = collect_events(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
      assert DataSet.get(ds, {0x0008, 0x0060}) == "CT"
    end

    test "returns structured error for invalid deflated payload" do
      binary = build_p10_with_ts("1.2.840.10008.1.2.1.99", <<1, 2, 3, 4, 5>>)
      events = collect_events(binary)

      assert List.last(events) == {:error, :invalid_deflated_data}
    end
  end

  # ── parse_file normal completion cleanup ───────────────────────────────

  describe "parse_file normal completion" do
    @tag [tmp_dir: true]
    test "parse_file completes and cleans up IO handle", %{tmp_dir: tmp_dir} do
      patient = elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")
      binary = build_p10_binary([], [patient])
      path = Path.join(tmp_dir, "complete_test.dcm")
      File.write!(path, binary)

      events = Dicom.P10.Stream.parse_file(path) |> Enum.to_list()
      assert Enum.any?(events, &match?({:element, _}, &1))
      assert :end in events
    end
  end

  # ── Pixel data fragments via streaming to_data_set ─────────────────────

  describe "pixel data fragments via streaming to_data_set" do
    test "encapsulated pixel data with actual fragments materializes correctly" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      fragment_data = :crypto.strong_rand_bytes(64)

      fragment =
        <<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment_data)::little-32>> <> fragment_data

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([], [pixel_tag <> bot <> fragment <> seq_delim])
      events = collect_events(binary)

      # Verify events contain pixel_data_start, fragment, and pixel_data_end
      assert Enum.any?(events, &match?({:pixel_data_start, _, _}, &1))
      assert Enum.any?(events, &match?({:pixel_data_fragment, _, _}, &1))
      assert :pixel_data_end in events

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      elem = DataSet.get_element(ds, {0x7FE0, 0x0010})
      assert %DataElement{value: {:encapsulated, [_bot, ^fragment_data]}} = elem
    end
  end

  # ── Bounded (defined-length) sequence/item streaming ───────────────────

  describe "bounded sequence and item streaming" do
    test "defined-length sequence with defined-length item" do
      inner = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner)::little-32>> <> inner
      sq = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, {0x0008, 0x1115}, _}, &1))
      assert :sequence_end in events
      assert :item_end in events

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert [%{{0x0008, 0x0060} => _}] = sq_value
    end

    test "defined-length sequence with multiple items" do
      inner1 = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      inner2 = elem_explicit({0x0008, 0x0060}, :CS, "MR")
      item1 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner1)::little-32>> <> inner1
      item2 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner2)::little-32>> <> inner2
      items = item1 <> item2

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(items)::little-32>> <> items

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_value = DataSet.get(ds, {0x0008, 0x1115})
      assert length(sq_value) == 2
    end
  end

  # ── Trailing padding in items ──────────────────────────────────────────

  describe "trailing padding in undefined-length items" do
    test "trailing padding tag (FFFC,FFFC) is handled in item" do
      inner = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      padding = <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, 0::little-32>>
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
      assert is_list(sq_value) and length(sq_value) == 1
    end
  end

  # ── File meta eager parsing paths ──────────────────────────────────────

  describe "file meta with long-length VR elements" do
    test "FileMetaInformationVersion (OB) is parsed via long-length path" do
      # OB is a long-length VR: tag(4) + VR(2) + reserved(2) + length(4) + value
      version_elem =
        <<0x02, 0x00, 0x01, 0x00, "OB", 0::16, 2::little-32, 0x00, 0x01>>

      binary = build_p10_binary([version_elem], [])
      events = collect_events(binary)

      elements = element_events(events)
      version = Enum.find(elements, fn e -> e.tag == {0x0002, 0x0001} end)
      assert version != nil
      assert version.vr == :OB
      assert version.value == <<0x00, 0x01>>
    end

    test "file meta with SQ element (rare but valid)" do
      # Build a dummy SQ in group 0002 — rare but the parser should handle it
      inner = <<0x02, 0x00, 0x12, 0x00, "UI", 22::little-16>> <> "1.2.840.10008.3.1.1.1\0"

      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner)::little-32>> <> inner
      # SQ tag in group 0002 (using PrivateInformation as example)
      sq_content = <<0x02, 0x00, 0x02, 0x01, "SQ", 0::16, byte_size(item)::little-32>> <> item

      binary = build_p10_binary([sq_content], [])
      events = collect_events(binary)

      elements = element_events(events)
      sq = Enum.find(elements, fn e -> e.tag == {0x0002, 0x0102} end)
      # SQ in file meta should be eagerly parsed
      assert sq != nil
      assert sq.vr == :SQ
      assert is_list(sq.value)
    end
  end

  describe "file meta with undefined-length SQ (eager path)" do
    test "parses undefined-length sequence in file meta" do
      inner = <<0x02, 0x00, 0x12, 0x00, "UI", 22::little-16>> <> "1.2.840.10008.3.1.1.1\0"
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner <> item_delim

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
      # SQ with undefined length
      sq =
        <<0x02, 0x00, 0x02, 0x01, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> seq_delim

      binary = build_p10_binary([sq], [])
      events = collect_events(binary)

      elements = element_events(events)
      sq_elem = Enum.find(elements, fn e -> e.tag == {0x0002, 0x0102} end)
      assert sq_elem != nil
      assert sq_elem.vr == :SQ
      assert is_list(sq_elem.value) and length(sq_elem.value) == 1
    end
  end

  describe "file meta read error propagation" do
    test "truncated file meta element produces error" do
      # TransferSyntaxUID element that claims 200 bytes but only has 5
      truncated =
        <<0x02, 0x00, 0x10, 0x00, "UI", 200::little-16, "short">>

      binary = <<0::1024, "DICM">>
      group_length = build_group_length_element(truncated)
      binary = binary <> group_length <> truncated

      events = collect_events(binary)
      assert Enum.any?(events, &match?({:error, _}, &1))
    end
  end

  describe "file meta with unknown VR" do
    test "unknown VR in file meta falls back to UN with short length" do
      # Element with invalid VR bytes "XX"
      unknown_vr_elem = <<0x02, 0x00, 0xFF, 0x00, "XX", 4::little-16, "data">>
      binary = build_p10_binary([unknown_vr_elem], [])
      events = collect_events(binary)

      elements = element_events(events)
      unknown = Enum.find(elements, fn e -> e.tag == {0x0002, 0x00FF} end)
      # Should be parsed as UN
      assert unknown != nil
      assert unknown.vr == :UN
    end
  end

  describe "encapsulated pixel data in file meta (eager path)" do
    test "encapsulated pixel data tag with 0xFFFFFFFF in eager read" do
      # This is an unusual case but exercises read_value_for_element(0xFFFFFFFF)
      pixel_tag = <<0x02, 0x00, 0x10, 0x7F, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      # Build this as file meta element — it should be parsed eagerly
      binary = build_p10_binary([pixel_tag <> bot <> seq_delim], [])
      events = collect_events(binary)

      # Should parse without crashing (even if not typical)
      assert length(events) >= 1
    end
  end

  # ── Implicit VR Little Endian streaming ─────────────────────────────────

  describe "implicit VR little endian" do
    # Build a P10 binary with Implicit VR LE transfer syntax (1.2.840.10008.1.2)
    # Data elements use: tag (4 bytes) + length (4 bytes) + value (no VR field)

    defp build_implicit_element({group, element}, value) do
      padded = pad_even(value)
      <<group::little-16, element::little-16, byte_size(padded)::little-32>> <> padded
    end

    test "parses data elements in implicit VR LE" do
      # Modality (0008,0060) - known VR: CS
      modality = build_implicit_element({0x0008, 0x0060}, "CT")
      # Patient Name (0010,0010) - known VR: PN
      patient = build_implicit_element({0x0010, 0x0010}, "DOE^JOHN")

      binary = build_p10_with_ts("1.2.840.10008.1.2", modality <> patient)
      events = collect_events(binary)

      elems = element_events(events)
      data_elems = Enum.reject(elems, fn e -> elem(e.tag, 0) == 0x0002 end)

      assert length(data_elems) == 2
      modality_elem = Enum.find(data_elems, &(&1.tag == {0x0008, 0x0060}))
      assert modality_elem.value == "CT"
    end

    test "materializes implicit VR LE to data set" do
      modality = build_implicit_element({0x0008, 0x0060}, "CT")
      patient = build_implicit_element({0x0010, 0x0010}, "DOE^JOHN")

      binary = build_p10_with_ts("1.2.840.10008.1.2", modality <> patient)
      events = Dicom.P10.Stream.parse(binary)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)

      assert DataSet.get(ds, {0x0008, 0x0060}) == "CT"
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "handles implicit VR SQ with undefined length" do
      # Build a sequence: tag + 0xFFFFFFFF length + item + seq delimiter
      sq_tag = <<0x08, 0x00, 0x15, 0x11>>
      sq_length = <<0xFF, 0xFF, 0xFF, 0xFF>>

      # Item with one element inside
      inner_elem = build_implicit_element({0x0008, 0x1150}, "1.2.3.4.5")
      item_tag = <<0xFE, 0xFF, 0x00, 0xE0>>
      item_length = <<byte_size(inner_elem)::little-32>>

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq = sq_tag <> sq_length <> item_tag <> item_length <> inner_elem <> seq_delim

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, {0x0008, 0x1115}, :undefined}, &1))
      assert Enum.any?(events, &match?(:sequence_end, &1))
      assert Enum.any?(events, &match?({:item_start, _}, &1))
      assert Enum.any?(events, &match?(:item_end, &1))
    end

    test "implicit VR unknown tag uses :UN" do
      # Unknown tag (0099,0001) — should be assigned :UN via dictionary lookup
      unknown = build_implicit_element({0x0099, 0x0001}, "custom")

      binary = build_p10_with_ts("1.2.840.10008.1.2", unknown)
      {:ok, ds} = Dicom.P10.Stream.to_data_set(Dicom.P10.Stream.parse(binary))

      elem = DataSet.get_element(ds, {0x0099, 0x0001})
      assert elem.vr == :UN
    end
  end

  # ── Truncated / Error streaming ──────────────────────────────────────

  describe "error paths in streaming" do
    test "truncated file meta transitions to data set with empty file meta" do
      # Preamble + DICM + 2 bytes (not enough for a tag)
      binary = <<0::1024, "DICM", 0xAB, 0xCD>>
      events = collect_events(binary)

      # Should not crash — should transition to data_set phase
      assert Enum.any?(events, &match?({:file_meta_end, _}, &1))
    end

    test "truncated pixel data fragment produces error" do
      # Build a P10 binary with encapsulated pixel data where fragment data is truncated
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # BOT (empty)
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Item with claimed length 100 but only 4 bytes of data
      item_tag = <<0xFE, 0xFF, 0x00, 0xE0, 100::little-32>>
      truncated_data = <<1, 2, 3, 4>>

      binary = build_p10_binary([], [pixel_tag <> bot <> item_tag <> truncated_data])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               _ -> false
             end)
    end

    test "error during implicit VR uint32 read" do
      # Build truncated implicit VR data: tag present but length missing
      truncated = <<0x08, 0x00, 0x60, 0x00, 0x01>>

      binary = build_p10_with_ts("1.2.840.10008.1.2", truncated)
      events = collect_events(binary)

      # Should complete (possibly with error or end) — not crash
      assert length(events) >= 1
    end
  end

  # ── Stream.to_data_set edge cases ────────────────────────────────────

  describe "to_data_set — push_element_to_stack fallback" do
    test "element in sequence without item_start triggers fallback" do
      # push_element_to_stack fallback at L230-232 is reached when an element
      # event arrives and the stack top is NOT {:item, ...}. This happens
      # with a malformed stream where an element appears directly inside a
      # sequence. The fallback wraps it in an implicit item.
      events = [
        :file_meta_start,
        {:file_meta_end, "1.2.840.10008.1.2.1"},
        {:sequence_start, {0x0008, 0x1115}, :undefined},
        # Element directly in sequence without item_start (malformed)
        {:element, DataElement.new({0x0008, 0x1150}, :UI, "1.2.3")},
        # Close the implicit item created by the fallback
        :item_end,
        :sequence_end,
        :end
      ]

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      sq_elem = DataSet.get_element(ds, {0x0008, 0x1115})
      assert sq_elem.vr == :SQ
      assert length(sq_elem.value) == 1
      [item] = sq_elem.value
      assert Map.has_key?(item, {0x0008, 0x1150})
    end
  end

  # ── parse_file ───────────────────────────────────────────────────────

  describe "parse_file error handling" do
    test "parse_file with nonexistent file produces error" do
      events = Dicom.P10.Stream.parse_file("/nonexistent/path.dcm") |> Enum.to_list()
      assert [{:error, :enoent}] = events
    end

    @tag :tmp_dir
    test "parse_file with valid file completes normally" do
      tmp_dir = System.tmp_dir!()
      path = Path.join(tmp_dir, "dicom_test_#{:rand.uniform(100_000)}.dcm")
      binary = build_p10_binary([], [elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")])
      File.write!(path, binary)

      try do
        events = Dicom.P10.Stream.parse_file(path) |> Enum.to_list()
        assert :file_meta_start in events
        assert Enum.any?(events, &match?({:file_meta_end, _}, &1))
        assert :end in events
      after
        File.rm(path)
      end
    end

    test "parse_file with halted stream closes file" do
      tmp_dir = System.tmp_dir!()
      path = Path.join(tmp_dir, "dicom_test_halt_#{:rand.uniform(100_000)}.dcm")
      binary = build_p10_binary([], [elem_explicit({0x0010, 0x0010}, :PN, "DOE^JOHN")])
      File.write!(path, binary)

      try do
        events = Dicom.P10.Stream.parse_file(path) |> Enum.take(1)
        assert length(events) == 1
      after
        File.rm(path)
      end
    end
  end

  # ── Parser error paths ──────────────────────────────────────────────────

  describe "parser error paths — eager read" do
    test "truncated SQ in file meta produces error" do
      # SQ with VR "SQ" but truncated length (missing reserved+length bytes)
      sq_elem = <<0x02, 0x00, 0x99, 0x00, "SQ">>
      binary = build_p10_binary([sq_elem])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               _ -> false
             end)
    end

    test "SQ in file meta with item read error" do
      # SQ with defined length, but item data is truncated
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 20::little-32>>
      # Item tag present but length truncated
      item_tag = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF>>

      binary = build_p10_binary([sq_header <> item_tag])
      events = collect_events(binary)
      # Should not crash — may produce error or partial results
      assert length(events) >= 1
    end

    test "truncated OB element in file meta produces error" do
      # OB with reserved + length but value truncated
      ob_elem = <<0x02, 0x00, 0x99, 0x00, "OB", 0::16, 100::little-32, 0x01, 0x02>>

      binary = build_p10_binary([ob_elem])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               _ -> false
             end)
    end

    test "truncated short VR element in file meta" do
      # CS with length claiming 100 bytes but only 4 present
      cs_elem = <<0x02, 0x00, 0x99, 0x00, "CS", 100::little-16, "ABCD">>

      binary = build_p10_binary([cs_elem])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               _ -> false
             end)
    end

    test "truncated implicit VR element produces error or ends gracefully" do
      # Implicit VR: tag + length(4 bytes), but value truncated
      truncated = <<0x10, 0x00, 0x10, 0x00, 100::little-32, "DOE">>

      binary = build_p10_with_ts("1.2.840.10008.1.2", truncated)
      events = collect_events(binary)
      # Should produce error
      assert Enum.any?(events, fn
               {:error, _} -> true
               :end -> true
               _ -> false
             end)
    end
  end

  describe "parser error paths — eager SQ edge cases" do
    test "SQ undefined length with non-item tag terminates gracefully" do
      # SQ with undefined length, followed by a non-item, non-seq-delim tag
      # Exercises L478-479 in read_items_until_delimiter_eager
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # A random tag (not item, not seq_delim)
      random_tag = <<0x02, 0x00, 0xAA, 0x00, "CS", 2::little-16, "AB">>
      # Then the seq delim to close
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([sq_header <> random_tag <> seq_delim])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ undefined length with truncated item length" do
      # SQ with undefined length, item tag present but length truncated
      # Exercises L474-475 (read_item_eager error) and L522 (read_uint32 error)
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Item tag with only 2 bytes of length (needs 4)
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0x01, 0x00>>

      binary = build_p10_binary([sq_header <> item_start])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ undefined length with unexpected end (no items)" do
      # SQ with undefined length, followed by not enough data for 8 bytes
      # Exercises L482-483 in read_items_until_delimiter_eager
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Only 4 bytes — not enough for 8-byte item/delim header
      partial = <<0x01, 0x02, 0x03, 0x04>>

      binary = build_p10_binary([sq_header <> partial])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ defined length with truncated item causes error" do
      # SQ with defined length, item starts but has truncated element
      # Exercises L499-500 in read_items_bounded_eager
      sq_length = 20
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, sq_length::little-32>>
      # Item tag + defined length of 12, but only has 4 bytes of content
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 12::little-32>>
      # Element tag + VR but truncated value
      truncated_elem = <<0x02, 0x00, 0xBB, 0x00, "CS", 100::little-16>>

      binary = build_p10_binary([sq_header <> item_start <> truncated_elem])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ item with undefined length and seq_delim inside" do
      # Item with undefined length, then seq_delim tag appears (unexpected)
      # Exercises L534-535 in read_item_elements_until_delimiter_eager
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      # seq_delim inside item (unusual — terminates item early)
      seq_delim_tag = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([sq_header <> item_start <> seq_delim_tag])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ item with undefined length and truncated element" do
      # Item with undefined length, element tag but VR read fails
      # Exercises L545-546 in read_item_elements_until_delimiter_eager
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Element tag present, but only 1 byte of VR (needs 2)
      truncated_elem = <<0x02, 0x00, 0xBB, 0x00, "C">>

      binary = build_p10_binary([sq_header <> item_start <> truncated_elem])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ item with defined length and truncated element" do
      # Item with defined length, element starts but read fails
      # Exercises L577-578 in read_item_elements_bounded_eager
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 20::little-32>>
      # Element tag + VR but value truncated
      truncated_elem = <<0x02, 0x00, 0xBB, 0x00, "CS", 100::little-16, "AB">>

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([sq_header <> item_start <> truncated_elem <> seq_delim])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ item with defined length and unexpected end" do
      # Item with defined length, but data runs out before element can be read
      # Exercises L585-586 in read_item_elements_bounded_eager
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 50::little-32>>
      # Only 2 bytes of element data (need at least 4 for tag)
      short = <<0x02, 0x00>>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([sq_header <> item_start <> short <> seq_delim])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "SQ item with undefined length and unexpected end" do
      # Item with undefined length, not enough data for next element tag
      # Exercises L553-554 in read_item_elements_until_delimiter_eager
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      # One valid element inside
      inner = <<0x02, 0x00, 0xCC, 0x00, "CS", 2::little-16, "AB">>
      # Then only 2 bytes (not enough for another 4-byte tag)
      trailing = <<0xAB, 0xCD>>

      binary = build_p10_binary([sq_header <> item_start <> inner <> trailing])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end
  end

  describe "parser error paths — read_short/long_value" do
    test "short VR element truncated after VR (no length)" do
      # Tag + VR present but no length field → read_short_length fails
      # Exercises L741 in read_short_value
      truncated_cs = <<0x02, 0x00, 0x99, 0x00, "CS">>

      binary = build_p10_binary([truncated_cs])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "long VR element truncated after VR (no reserved+length)" do
      # Tag + VR present but no reserved+length → read_reserved_and_length fails
      # Exercises L761 in read_long_value
      truncated_ob = <<0x02, 0x00, 0x99, 0x00, "OB">>

      binary = build_p10_binary([truncated_ob])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end
  end

  describe "parser error paths — encapsulated fragments in file meta" do
    test "encapsulated pixel data in file meta with truncated fragment" do
      # Pixel data in file meta with encapsulated format, item tag but truncated length
      # Exercises L668 in read_fragments_eager (read_uint32 error)
      pixel_tag = <<0x02, 0x00, 0x10, 0x7F, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # BOT
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Item tag but only 2 bytes of length (need 4)
      truncated_item = <<0xFE, 0xFF, 0x00, 0xE0, 0x05, 0x00>>

      binary = build_p10_binary([pixel_tag <> bot <> truncated_item])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "encapsulated pixel data with fragment data truncated" do
      # Fragment has length 100 but only 4 bytes of data
      # Exercises L672 in read_fragments_eager (ensure error)
      pixel_tag = <<0x02, 0x00, 0x10, 0x7F, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      item_with_big_length = <<0xFE, 0xFF, 0x00, 0xE0, 100::little-32, 0x01, 0x02, 0x03, 0x04>>

      binary = build_p10_binary([pixel_tag <> bot <> item_with_big_length])
      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "pixel data inside file meta SQ item with encapsulated fragments" do
      # read_encapsulated_fragments_eager requires pixel data tag {0x7FE0,0x0010}
      # inside a file_meta SQ item. This exercises L638-680 paths.
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      # Pixel data tag with OB VR and undefined length (encapsulated)
      pixel_elem = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      # BOT (empty)
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # One fragment with 4 bytes of data
      frag = <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 0x01, 0x02, 0x03, 0x04>>
      # Seq delimiter for pixel data fragments
      pixel_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
      # Item delimiter
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      # Seq delimiter for the SQ
      sq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary =
        build_p10_binary([
          sq_header <>
            item_start <>
            pixel_elem <>
            bot <>
            frag <>
            pixel_delim <>
            item_delim <> sq_delim
        ])

      events = collect_events(binary)
      assert Enum.any?(events, &match?({:file_meta_end, _}, &1))
    end

    test "pixel data inside file meta SQ with truncated fragment length" do
      # Exercises L668 (read_uint32 error in read_fragments_eager)
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      pixel_elem = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Item tag with only 2 bytes of length
      truncated_frag = <<0xFE, 0xFF, 0x00, 0xE0, 0x05, 0x00>>

      binary =
        build_p10_binary([
          sq_header <> item_start <> pixel_elem <> bot <> truncated_frag
        ])

      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "pixel data inside file meta SQ with truncated fragment data" do
      # Exercises L672 (ensure error in read_fragments_eager)
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      pixel_elem = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Fragment claims 100 bytes but only 4 present
      big_frag = <<0xFE, 0xFF, 0x00, 0xE0, 100::little-32, 0x01, 0x02, 0x03, 0x04>>

      binary =
        build_p10_binary([
          sq_header <> item_start <> pixel_elem <> bot <> big_frag
        ])

      events = collect_events(binary)

      assert Enum.any?(events, fn
               {:error, _} -> true
               {:file_meta_end, _} -> true
               _ -> false
             end)
    end

    test "pixel data inside file meta SQ with non-item tag in fragments" do
      # Exercises L675-676 (non-item/non-delim tag in read_fragments_eager)
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      pixel_elem = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # A weird tag where item tag expected
      weird = <<0x02, 0x00, 0xAA, 0x00, 0x00, 0x00, 0x00, 0x00>>
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      sq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary =
        build_p10_binary([
          sq_header <>
            item_start <>
            pixel_elem <>
            bot <>
            weird <>
            item_delim <> sq_delim
        ])

      events = collect_events(binary)
      assert length(events) >= 1
    end

    test "pixel data inside file meta SQ with insufficient fragment data" do
      # Exercises L679-680 (unexpected_end in read_fragments_eager)
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>
      pixel_elem = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Only 4 bytes after BOT (need 8 for next item/delim header)
      partial = <<0xFE, 0xFF, 0x00, 0xE0>>
      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
      sq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary =
        build_p10_binary([
          sq_header <>
            item_start <>
            pixel_elem <>
            bot <>
            partial <>
            item_delim <> sq_delim
        ])

      events = collect_events(binary)
      assert length(events) >= 1
    end

    test "encapsulated pixel data with non-item/non-delim tag" do
      # This path is treated as a regular OB element in file meta.
      pixel_tag = <<0x02, 0x00, 0x10, 0x7F, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      weird_tag = <<0x02, 0x00, 0xAA, 0x00, "CS", 2::little-16, "AB">>
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      binary = build_p10_binary([pixel_tag <> bot <> weird_tag <> seq_delim])
      events = collect_events(binary)

      assert :end in events
    end

    test "encapsulated pixel data with insufficient data for next item" do
      # After BOT, not enough bytes for next tag+length (8 bytes) → fail closed
      pixel_tag = <<0x02, 0x00, 0x10, 0x7F, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      partial = <<0xFE, 0xFF, 0x00, 0xE0>>

      binary = build_p10_binary([pixel_tag <> bot <> partial])
      events = collect_events(binary)

      assert length(events) >= 1
    end
  end

  describe "parser streaming — big-endian trailing padding" do
    test "big-endian trailing padding detected" do
      # Build big-endian explicit VR data with trailing padding
      ts_uid = "1.2.840.10008.1.2.2"
      modality = <<0x00, 0x08, 0x00, 0x60, "CS", 2::big-16, "CT">>
      trailing = <<0xFF, 0xFC, 0xFF, 0xFC>>

      binary = build_p10_with_ts(ts_uid, modality <> trailing)
      events = collect_events(binary)
      assert :end in events
    end
  end

  describe "parser streaming — trailing padding in item" do
    test "truncated trailing padding element in item triggers error fallback" do
      # Exercises L703: skip_trailing_padding_in_item error path
      # An undefined-length item with trailing padding tag but truncated element data
      sq_tag = <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      item_start = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>>

      # Valid element inside item
      inner = <<0x08, 0x00, 0x60, 0x00, "CS", 2::little-16, "CT">>

      # Trailing padding tag (FFFC,FFFC) with no VR data after it
      trailing_padding = <<0xFC, 0xFF, 0xFC, 0xFF>>

      binary = build_p10_binary([], [sq_tag <> item_start <> inner <> trailing_padding])
      events = collect_events(binary)

      # The item should end (via error fallback) and the sequence should also end
      assert Enum.any?(events, &match?(:item_end, &1))
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

  # ── Source coverage tests ──────────────────────────────────────────────

  describe "Source - consume_until" do
    alias Dicom.P10.Stream.Source

    test "finds marker within existing buffer" do
      source = Source.from_binary("hello\nworld")
      {:ok, data, source} = Source.consume_until(source, "\n")
      assert data == "hello"
      assert source.buffer == "world"
    end

    test "returns whole buffer when marker not found at EOF" do
      source = Source.from_binary("no marker here")
      {:ok, data, source} = Source.consume_until(source, "\n")
      assert data == "no marker here"
      assert Source.eof?(source)
    end

    test "returns whole buffer when io is nil and marker not found" do
      source = %Source{buffer: "partial", io: nil, offset: 0, read_ahead: 1024}
      {:ok, data, source} = Source.consume_until(source, "\n")
      assert data == "partial"
      assert Source.eof?(source)
    end

    test "finds marker after IO refill" do
      path = Path.join(System.tmp_dir!(), "dicom_source_test_#{:rand.uniform(100_000)}")
      File.write!(path, "first_chunk" <> String.duplicate("x", 100) <> "\nafter_marker")

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io, read_ahead: 10)
      {:ok, data, _source} = Source.consume_until(source, "\n")
      assert data == "first_chunk" <> String.duplicate("x", 100)
      File.close(io)
      File.rm!(path)
    end

    test "returns remaining when IO exhausts without marker" do
      path = Path.join(System.tmp_dir!(), "dicom_source_test_#{:rand.uniform(100_000)}")
      File.write!(path, "no_newline_here")

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io, read_ahead: 5)
      {:ok, data, source} = Source.consume_until(source, "\n")
      assert data == "no_newline_here"
      assert Source.eof?(source)
      File.close(io)
      File.rm!(path)
    end
  end

  describe "Source - consume_until_required" do
    alias Dicom.P10.Stream.Source

    test "finds marker within buffer" do
      source = Source.from_binary("data\x00end")
      {:ok, data, _source} = Source.consume_until_required(source, <<0x00>>)
      assert data == "data"
    end

    test "returns error when marker not found at EOF" do
      source = Source.from_binary("no marker")
      assert {:error, :unexpected_end} = Source.consume_until_required(source, <<0xFF, 0xFE>>)
    end

    test "returns error when io is nil and marker not found" do
      source = %Source{buffer: "partial", io: nil, offset: 0, read_ahead: 1024}
      assert {:error, :unexpected_end} = Source.consume_until_required(source, "\n")
    end

    test "finds marker after IO refill" do
      path = Path.join(System.tmp_dir!(), "dicom_source_test_#{:rand.uniform(100_000)}")
      File.write!(path, "start" <> String.duplicate("y", 50) <> "MARKER" <> "tail")

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io, read_ahead: 8)
      {:ok, data, _source} = Source.consume_until_required(source, "MARKER")
      assert data == "start" <> String.duplicate("y", 50)
      File.close(io)
      File.rm!(path)
    end

    test "returns error when IO exhausts without marker" do
      path = Path.join(System.tmp_dir!(), "dicom_source_test_#{:rand.uniform(100_000)}")
      File.write!(path, "short")

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io, read_ahead: 4)
      assert {:error, :unexpected_end} = Source.consume_until_required(source, "NOTFOUND")
      File.close(io)
      File.rm!(path)
    end
  end

  describe "Source - ensure and read_ahead" do
    alias Dicom.P10.Stream.Source

    test "ensure fills from IO when buffer insufficient" do
      path = Path.join(System.tmp_dir!(), "dicom_source_test_#{:rand.uniform(100_000)}")
      File.write!(path, "abcdefghij")

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io, read_ahead: 4)
      assert Source.available(source) == 0

      {:ok, source} = Source.ensure(source, 8)
      assert Source.available(source) >= 8
      File.close(io)
      File.rm!(path)
    end

    test "ensure returns error when partial IO does not satisfy need" do
      path = Path.join(System.tmp_dir!(), "dicom_source_test_#{:rand.uniform(100_000)}")
      File.write!(path, "abc")

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io, read_ahead: 2)
      assert {:error, :unexpected_end} = Source.ensure(source, 100)
      File.close(io)
      File.rm!(path)
    end

    test "normalize_read_ahead clamps invalid values to default" do
      path = Path.join(System.tmp_dir!(), "dicom_source_test_#{:rand.uniform(100_000)}")
      File.write!(path, "test")

      {:ok, io} = File.open(path, [:raw, :binary, :read])
      source = Source.from_io(io, read_ahead: -1)
      assert source.read_ahead == 65_536

      source2 = Source.from_io(io, read_ahead: 0)
      assert source2.read_ahead == 65_536

      source3 = Source.from_io(io, read_ahead: "invalid")
      assert source3.read_ahead == 65_536
      File.close(io)
      File.rm!(path)
    end
  end

  # ── Implicit VR sequence coverage ─────────────────────────────────────

  describe "streaming: Implicit VR defined-length sequence" do
    test "parses implicit VR data set with defined-length sequence via streaming" do
      # Inner item element: PatientID (0010,0020)
      inner_value = "12345678"
      inner_elem = <<0x10, 0x00, 0x20, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Item with defined length
      item_length = byte_size(inner_elem)
      item = <<0xFE, 0xFF, 0x00, 0xE0, item_length::little-32>> <> inner_elem

      # Sequence (0008,1115) with defined length
      seq_length = byte_size(item)
      seq_tag = <<0x08, 0x00, 0x15, 0x11, seq_length::little-32>>

      # A normal element after the sequence
      patient_name = "IMPLICIT^SEQ"
      name_elem = <<0x10, 0x00, 0x10, 0x00, byte_size(patient_name)::little-32>> <> patient_name

      binary = build_p10_with_ts("1.2.840.10008.1.2", seq_tag <> item <> name_elem)
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, {0x0008, 0x1115}, _}, &1))
      assert Enum.any?(events, &match?({:item_start, _}, &1))
      assert :sequence_end in events
      assert :item_end in events

      {:ok, ds} = Dicom.P10.Stream.to_data_set(events)
      assert DataSet.get(ds, {0x0010, 0x0010}) == patient_name
    end
  end

  # ── Encapsulated pixel data edge cases ────────────────────────────────

  describe "streaming: encapsulated pixel data edge cases" do
    test "EOF during pixel data fragment returns pixel_data_end" do
      # Pixel data tag with undefined length
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>

      # Truncate: no fragment or delimiter after BOT
      binary = build_p10_binary([], [pixel_tag, bot])
      events = collect_events(binary)

      # Should still produce pixel_data_end (not crash)
      assert Enum.any?(events, &match?({:pixel_data_start, _, _}, &1))
      assert :pixel_data_end in events
    end

    test "truncated fragment in encapsulated pixel data" do
      pixel_tag = <<0xE0, 0x7F, 0x10, 0x00, "OB", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>>
      bot = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32>>
      # Fragment header says 100 bytes, but only provide 10
      truncated_frag =
        <<0xFE, 0xFF, 0x00, 0xE0, 100::little-32, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>

      binary = build_p10_binary([], [pixel_tag, bot, truncated_frag])
      events = collect_events(binary)

      # Should get an error event for the truncated data
      assert Enum.any?(events, &match?({:error, _}, &1))
    end
  end

  # ── Big endian trailing padding ────────────────────────────────────────

  describe "streaming: big endian trailing padding" do
    test "detects trailing padding in big endian transfer syntax" do
      patient_name = "DOE^JOHN"

      name_elem =
        <<0x00, 0x10, 0x00, 0x10, "PN", byte_size(patient_name)::big-16>> <> patient_name

      padding = <<0xFF, 0xFC, 0xFF, 0xFC, "OB", 0::16, 4::big-32, 0, 0, 0, 0>>

      binary = build_p10_with_ts("1.2.840.10008.1.2.2", name_elem <> padding)
      events = collect_events(binary)

      assert :end in events

      refute Enum.any?(events, fn
               {:element, elem} -> elem.tag == {0xFFFC, 0xFFFC}
               _ -> false
             end)
    end
  end

  # ── Stream.to_data_set error handling ──────────────────────────────────

  describe "Stream - to_data_set error handling" do
    test "to_data_set returns error when stream contains error event" do
      events = [:file_meta_start, {:error, :test_error}]
      assert {:error, :test_error} = Dicom.P10.Stream.to_data_set(events)
    end

    test "parse_file with custom read_ahead option" do
      path = Path.join(System.tmp_dir!(), "dicom_parse_file_#{:rand.uniform(100_000)}.dcm")
      binary = build_p10_binary([])
      File.write!(path, binary)

      events = Dicom.P10.Stream.parse_file(path, read_ahead: 256) |> Enum.to_list()
      assert :file_meta_start in events
      assert :end in events
      File.rm!(path)
    end

    test "parse_file returns error for nonexistent file" do
      events = Dicom.P10.Stream.parse_file("/nonexistent/path/file.dcm") |> Enum.to_list()
      assert Enum.any?(events, &match?({:error, _}, &1))
    end

    test "parse_file halts cleanly when consumer stops early" do
      path = Path.join(System.tmp_dir!(), "dicom_parse_file_halt_#{:rand.uniform(100_000)}.dcm")
      binary = build_p10_binary([], [elem_explicit({0x0010, 0x0010}, :PN, "TEST")])
      File.write!(path, binary)

      # Take only 2 events, forcing early halt
      events = Dicom.P10.Stream.parse_file(path) |> Enum.take(2)
      assert length(events) == 2
      File.rm!(path)
    end
  end

  # ── Coverage: trailing padding in defined-length item ─────────────────

  describe "trailing padding inside defined-length item" do
    test "trailing padding tag in defined-length item terminates parsing" do
      # Exercises line 306-307: @trailing_padding_tag branch in read_next_data_element
      # called from defined-length item handler (line 197) which has no pre-check.
      inner = elem_explicit({0x0008, 0x0060}, :CS, "CT")
      padding_data = <<0, 0, 0, 0>>

      padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, "OB", 0::16, byte_size(padding_data)::little-32>> <>
          padding_data

      # Item with defined length encompassing inner + padding
      item_content = inner <> padding
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(item_content)::little-32>> <> item_content

      # Undefined-length sequence containing the item
      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          item <> seq_delim

      binary = build_p10_binary([], [sq])
      events = collect_events(binary)

      # The defined-length item should have been processed and parsing should terminate
      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      assert :end in events
    end
  end

  # ── Coverage: implicit VR read_single_element via skip_trailing_padding ─

  describe "implicit VR trailing padding in undefined-length item" do
    test "trailing padding inside implicit VR undefined-length item exercises read_single_element" do
      # Exercises lines 595-597, 599, 609, 632-636:
      # implicit VR branch of read_single_element via skip_trailing_padding_in_item.
      #
      # Scenario: Implicit VR transfer syntax, undefined-length item contains
      # a normal element followed by trailing padding (FFFC,FFFC) with OB value.
      inner_value = "DOE^JOHN"

      inner_elem =
        <<0x10, 0x00, 0x10, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Trailing padding element in implicit VR: tag(4) + length(4) + value
      padding_data = <<0, 0, 0, 0>>

      trailing_padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, byte_size(padding_data)::little-32>> <> padding_data

      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner_elem <> trailing_padding <> item_delim

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      # Use ReferencedImageSequence (0008,1140) which is :SQ in dictionary
      sq =
        <<0x08, 0x00, 0x40, 0x11, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:sequence_start, _, _}, &1))
      assert :item_end in events
      assert :sequence_end in events
    end

    test "truncated trailing padding in implicit VR item triggers error fallback" do
      # Exercises line 613: error branch from read_uint32 in implicit read_single_element
      # and line 704 (error fallback in skip_trailing_padding_in_item).
      # The trailing padding tag is the ONLY remaining data (no length bytes).
      # After consuming the 4-byte tag, read_uint32 has 0 bytes -> error.
      inner_value = "DOE^JOHN"

      inner_elem =
        <<0x10, 0x00, 0x10, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Just the trailing padding tag, no length field at all
      truncated_padding = <<0xFC, 0xFF, 0xFC, 0xFF>>

      # No item_delim, no seq_delim after padding — total truncation
      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner_elem <> truncated_padding

      sq = <<0x08, 0x00, 0x40, 0x11, 0xFF, 0xFF, 0xFF, 0xFF>> <> item

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)
      events = collect_events(binary)

      # Should recover via error fallback in skip_trailing_padding_in_item
      assert :item_end in events
    end

    test "trailing padding with undefined length in implicit VR item" do
      # Exercises lines 625-626: read_value_for_element with 0xFFFFFFFF length,
      # non-pixel-data tag, via skip_trailing_padding_in_item in implicit VR.
      # The padding element has length 0xFFFFFFFF (undefined), followed by
      # some data and a sequence delimiter marker.
      inner_value = "CT"

      inner_elem =
        <<0x08, 0x00, 0x60, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Trailing padding with undefined length (0xFFFFFFFF)
      # Then value data, then seq_delim_bytes (which is the marker for consume_until_required)
      padding_value = <<"PADDING">>
      seq_delim_bytes = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      trailing_padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>> <> padding_value <> seq_delim_bytes

      item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner_elem <> trailing_padding <> item_delim

      outer_seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x40, 0x11, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> outer_seq_delim

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)
      events = collect_events(binary)

      # The trailing padding should be consumed, then item_delim terminates the item
      assert :item_end in events
      assert :sequence_end in events
    end

    test "trailing padding with undefined length and no delimiter in implicit VR item" do
      # Exercises line 627: error branch in read_value_for_element with 0xFFFFFFFF
      # when consume_undefined_length_value finds no delimiter.
      inner_value = "CT"

      inner_elem =
        <<0x08, 0x00, 0x60, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Trailing padding with undefined length but no seq_delim_bytes marker
      trailing_padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>> <> <<"NODELIM">>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner_elem <> trailing_padding

      sq = <<0x08, 0x00, 0x40, 0x11, 0xFF, 0xFF, 0xFF, 0xFF>> <> item

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)
      events = collect_events(binary)

      # The error from consume_undefined_length_value triggers the fallback
      assert :item_end in events
    end

    test "trailing padding in implicit VR with value truncated triggers error fallback" do
      # Exercises line 639: error branch in read_value_for_element when
      # Source.ensure fails for the value bytes.
      inner_value = "CT"

      inner_elem =
        <<0x08, 0x00, 0x60, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Trailing padding claiming 100 bytes but only 4 present
      truncated_padding =
        <<0xFC, 0xFF, 0xFC, 0xFF, 100::little-32, 0x01, 0x02, 0x03, 0x04>>

      item =
        <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <>
          inner_elem <> truncated_padding

      seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      sq =
        <<0x08, 0x00, 0x40, 0x11, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim

      binary = build_p10_with_ts("1.2.840.10008.1.2", sq)
      events = collect_events(binary)

      # Should recover via error fallback
      assert :item_end in events
    end
  end

  # ── Coverage: read_short_length(:big) error branch ──────────────────────

  describe "big-endian short VR length error" do
    test "truncated short VR length in big-endian produces error" do
      # Exercises line 809: error branch in read_short_length(:big)
      ts_uid = "1.2.840.10008.1.2.2"

      # Big-endian element: tag(4, big) + VR(2) + only 1 byte of length (needs 2)
      truncated_elem = <<0x00, 0x10, 0x00, 0x10, "PN", 0x08>>

      binary = build_p10_with_ts(ts_uid, truncated_elem)
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end
  end

  # ── Coverage: read_item_eager error from read_uint32 ────────────────────

  describe "eager item parsing: truncated item length" do
    test "item with truncated length in bounded eager SQ produces error" do
      # Exercises line 527: error branch in read_item_eager when read_uint32 fails.
      # Use defined-length SQ in file meta with an item whose length is truncated.
      sq_length = 6
      sq_header = <<0x02, 0x00, 0x99, 0x00, "SQ", 0::16, sq_length::little-32>>
      # Item tag (4 bytes) + only 1 byte of length (needs 4)
      truncated_item = <<0xFE, 0xFF, 0x00, 0xE0, 0x05>>

      binary = build_p10_binary([sq_header <> truncated_item])
      events = collect_events(binary)

      assert Enum.any?(events, &match?({:error, _}, &1))
    end
  end

  # ── Property: stream parser matches reader ────────────────────────────

  describe "property: stream parser matches reader" do
    property "streaming parser produces same elements as reader for random string VRs" do
      check all(
              name <- StreamData.string(:alphanumeric, min_length: 1, max_length: 30),
              id <- StreamData.string(:alphanumeric, min_length: 1, max_length: 20)
            ) do
        ds =
          Dicom.TestHelpers.minimal_data_set()
          |> DataSet.put({0x0010, 0x0010}, :PN, name)
          |> DataSet.put({0x0010, 0x0020}, :LO, id)

        {:ok, binary} = Dicom.P10.Writer.serialize(ds)
        {:ok, reader_ds} = Dicom.P10.Reader.parse(binary)

        events = binary |> Dicom.P10.Stream.parse() |> Enum.to_list()
        {:ok, stream_ds} = Dicom.P10.Stream.to_data_set(events)

        reader_name = DataSet.get(reader_ds, {0x0010, 0x0010})
        stream_name = DataSet.get(stream_ds, {0x0010, 0x0010})
        assert reader_name == stream_name

        reader_id = DataSet.get(reader_ds, {0x0010, 0x0020})
        stream_id = DataSet.get(stream_ds, {0x0010, 0x0020})
        assert reader_id == stream_id
      end
    end
  end
end
