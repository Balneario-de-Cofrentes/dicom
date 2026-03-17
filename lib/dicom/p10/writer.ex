defmodule Dicom.P10.Writer do
  @moduledoc """
  DICOM P10 file writer.

  Serializes a `Dicom.DataSet` to DICOM Part 10 binary format.
  File Meta Information is always written in Explicit VR Little Endian.

  Auto-populates required Type 1 File Meta elements per PS3.10 Section 7.1:
  - (0002,0000) File Meta Information Group Length
  - (0002,0001) File Meta Information Version
  - (0002,0012) Implementation Class UID

  Reference: DICOM PS3.10 Section 7.
  """

  alias Dicom.{DataElement, DataSet, TransferSyntax, VR}

  @implementation_class_uid "1.2.826.0.1.3680043.10.1137"
  @implementation_version_name "DICOM_EX_0.1.0"

  @required_meta_tags [
    {0x0002, 0x0002},
    {0x0002, 0x0003},
    {0x0002, 0x0010}
  ]

  @doc """
  Validates that a data set contains all required File Meta Information elements.

  Required Type 1 elements per PS3.10 Section 7.1:
  - (0002,0002) Media Storage SOP Class UID
  - (0002,0003) Media Storage SOP Instance UID
  - (0002,0010) Transfer Syntax UID
  """
  @spec validate_file_meta(DataSet.t()) :: :ok | {:error, {:missing_required_meta, Dicom.Tag.t()}}
  def validate_file_meta(%DataSet{file_meta: file_meta}) do
    Enum.reduce_while(@required_meta_tags, :ok, fn tag, :ok ->
      if Map.has_key?(file_meta, tag) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_required_meta, tag}}}
      end
    end)
  end

  @doc """
  Serializes a data set to P10 binary.
  """
  @spec serialize(DataSet.t()) :: {:ok, binary()}
  def serialize(%DataSet{} = data_set) do
    preamble = Dicom.P10.FileMeta.preamble()
    file_meta = ensure_required_meta(data_set.file_meta)

    # Encode all file meta elements except group length first
    meta_without_group_length = Map.delete(file_meta, {0x0002, 0x0000})
    meta_binary = encode_elements(meta_without_group_length, :explicit, :little)

    # Compute and prepend group length
    group_length_elem =
      DataElement.new({0x0002, 0x0000}, :UL, <<byte_size(meta_binary)::little-32>>)

    group_length_binary = encode_element(group_length_elem, :explicit, :little)

    # Encode main data set
    transfer_syntax_uid = TransferSyntax.extract_uid(file_meta)
    {vr_encoding, endianness} = TransferSyntax.encoding(transfer_syntax_uid)
    data_set_binary = encode_elements(data_set.elements, vr_encoding, endianness)

    # Deflate if transfer syntax requires it (PS3.5 Section 10)
    final_data_set =
      if transfer_syntax_uid == Dicom.UID.deflated_explicit_vr_little_endian() do
        :zlib.compress(data_set_binary)
      else
        data_set_binary
      end

    {:ok, preamble <> group_length_binary <> meta_binary <> final_data_set}
  end

  defp ensure_required_meta(file_meta) do
    file_meta
    |> ensure_meta_element({0x0002, 0x0001}, :OB, <<0x00, 0x01>>)
    |> ensure_meta_element({0x0002, 0x0012}, :UI, @implementation_class_uid)
    |> ensure_meta_element({0x0002, 0x0013}, :SH, @implementation_version_name)
  end

  defp ensure_meta_element(file_meta, tag, vr, default_value) do
    Map.put_new(file_meta, tag, DataElement.new(tag, vr, default_value))
  end

  defp encode_elements(elements, vr_encoding, endianness) do
    elements
    |> Map.values()
    |> Enum.sort_by(& &1.tag)
    |> Enum.map(&encode_element(&1, vr_encoding, endianness))
    |> IO.iodata_to_binary()
  end

  # Explicit VR: Sequence
  defp encode_element(
         %DataElement{tag: {group, element}, vr: :SQ, value: items},
         :explicit,
         :little
       )
       when is_list(items) do
    tag_bytes = <<group::little-16, element::little-16>>
    items_binary = encode_sequence_items(items, :explicit, :little)
    # Use defined length for sequences
    tag_bytes <> "SQ" <> <<0::16, byte_size(items_binary)::little-32>> <> items_binary
  end

  # Explicit VR: Encapsulated pixel data
  defp encode_element(
         %DataElement{tag: {group, element}, vr: vr, value: {:encapsulated, fragments}},
         :explicit,
         :little
       ) do
    tag_bytes = <<group::little-16, element::little-16>>
    vr_bytes = VR.to_binary(vr)
    fragments_binary = encode_encapsulated_fragments(fragments)
    seq_delim = <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

    tag_bytes <> vr_bytes <> <<0::16, 0xFFFFFFFF::little-32>> <> fragments_binary <> seq_delim
  end

  # Explicit VR: Normal element
  defp encode_element(
         %DataElement{tag: {group, element}, vr: vr, value: value},
         :explicit,
         :little
       ) do
    tag_bytes = <<group::little-16, element::little-16>>
    vr_bytes = VR.to_binary(vr)
    value_binary = to_binary(value)
    padded_value = VR.pad_value(value_binary, vr)

    if VR.long_length?(vr) do
      tag_bytes <> vr_bytes <> <<0::16, byte_size(padded_value)::little-32>> <> padded_value
    else
      tag_bytes <> vr_bytes <> <<byte_size(padded_value)::little-16>> <> padded_value
    end
  end

  # Implicit VR: Sequence
  defp encode_element(
         %DataElement{tag: {group, element}, vr: :SQ, value: items},
         :implicit,
         :little
       )
       when is_list(items) do
    items_binary = encode_sequence_items(items, :implicit, :little)
    <<group::little-16, element::little-16, byte_size(items_binary)::little-32>> <> items_binary
  end

  # Implicit VR: Normal element
  defp encode_element(
         %DataElement{tag: {group, element}, vr: vr, value: value},
         :implicit,
         :little
       ) do
    value_binary = to_binary(value)
    padded_value = VR.pad_value(value_binary, vr)
    <<group::little-16, element::little-16, byte_size(padded_value)::little-32>> <> padded_value
  end

  defp encode_sequence_items(items, vr_enc, endian) do
    items
    |> Enum.map(&encode_sequence_item(&1, vr_enc, endian))
    |> IO.iodata_to_binary()
  end

  defp encode_sequence_item(item_elements, vr_enc, endian) when is_map(item_elements) do
    item_binary = encode_elements(item_elements, vr_enc, endian)
    # Item tag + defined length
    <<0xFE, 0xFF, 0x00, 0xE0, byte_size(item_binary)::little-32>> <> item_binary
  end

  defp encode_encapsulated_fragments(fragments) do
    fragments
    |> Enum.map(fn fragment ->
      <<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment)::little-32>> <> fragment
    end)
    |> IO.iodata_to_binary()
  end

  defp to_binary(value) when is_binary(value), do: value
  defp to_binary(value) when is_integer(value), do: <<value::little-32>>
  defp to_binary(value), do: to_string(value)
end
