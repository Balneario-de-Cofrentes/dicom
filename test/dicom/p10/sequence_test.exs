defmodule Dicom.P10.SequenceTest do
  use ExUnit.Case, async: true

  alias Dicom.DataSet

  describe "reading sequences with defined length" do
    test "parses sequence with one item containing one element" do
      # Build: SQ element with defined length, one item with defined length
      binary = build_p10_with_sequence(build_defined_length_sequence())
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1

      [item] = seq
      assert is_map(item)
      assert Map.has_key?(item, {0x0008, 0x1150})
    end

    test "parses sequence with multiple items" do
      binary = build_p10_with_sequence(build_multi_item_sequence())
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert length(seq) == 2
    end

    test "parses empty sequence" do
      binary = build_p10_with_sequence(build_empty_sequence())
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert seq == []
    end
  end

  describe "reading sequences with undefined length" do
    test "parses undefined-length sequence with delimiter" do
      binary = build_p10_with_sequence(build_undefined_length_sequence())
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end

    test "parses undefined-length items with item delimiter" do
      binary = build_p10_with_sequence(build_undefined_length_items())
      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(ds, {0x0008, 0x1115})
      assert length(seq) == 1
    end
  end

  describe "writing sequences" do
    test "roundtrips a sequence through write and read" do
      # Build a data set with a sequence programmatically
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

      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1115}, seq_elem)}

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(parsed, {0x0008, 0x1115})
      assert is_list(seq)
      assert length(seq) == 1
    end
  end

  # Helper: build P10 binary with a sequence element in the data set
  defp build_p10_with_sequence(sequence_binary) do
    ts_uid = pad_even("1.2.840.10008.1.2.1")
    ts_elem = <<0x02, 0x00, 0x10, 0x00, "UI", byte_size(ts_uid)::little-16>> <> ts_uid

    group_length_value = <<byte_size(ts_elem)::little-32>>

    group_length =
      <<0x02, 0x00, 0x00, 0x00, "UL", byte_size(group_length_value)::little-16>> <>
        group_length_value

    <<0::1024, "DICM">> <> group_length <> ts_elem <> sequence_binary
  end

  # SQ with defined length, one item, one element
  defp build_defined_length_sequence do
    # Inner element: ReferencedSOPClassUID (0008,1150) UI
    inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

    inner_elem =
      <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

    # Item with defined length
    item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem

    # Sequence with defined length: tag (0008,1115), VR SQ, reserved, length
    <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(item)::little-32>> <> item
  end

  defp build_multi_item_sequence do
    inner_value1 = pad_even("1.2.840.10008.5.1.4.1.1.2")

    inner_elem1 =
      <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value1)::little-16>> <> inner_value1

    item1 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem1)::little-32>> <> inner_elem1

    inner_value2 = pad_even("1.2.840.10008.5.1.4.1.1.4")

    inner_elem2 =
      <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value2)::little-16>> <> inner_value2

    item2 = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem2)::little-32>> <> inner_elem2

    items = item1 <> item2
    <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, byte_size(items)::little-32>> <> items
  end

  defp build_empty_sequence do
    <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0::little-32>>
  end

  defp build_undefined_length_sequence do
    inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

    inner_elem =
      <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

    # Item with defined length
    item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem

    # Sequence delimiter
    seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

    # Sequence with undefined length (0xFFFFFFFF)
    <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim
  end

  defp build_undefined_length_items do
    inner_value = pad_even("1.2.840.10008.5.1.4.1.1.2")

    inner_elem =
      <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

    # Item with undefined length + item delimiter
    item_delim = <<0xFE, 0xFF, 0x0D, 0xE0, 0::little-32>>
    item = <<0xFE, 0xFF, 0x00, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF>> <> inner_elem <> item_delim

    # Sequence delimiter
    seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

    <<0x08, 0x00, 0x15, 0x11, "SQ", 0::16, 0xFF, 0xFF, 0xFF, 0xFF>> <> item <> seq_delim
  end

  defp pad_even(value) when rem(byte_size(value), 2) == 1, do: value <> <<0>>
  defp pad_even(value), do: value
end
