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

  @compile {:inline, encode_tag: 2, encode_u32: 2, encode_u16: 2, ensure_meta_element: 4}

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
    with :ok <- validate_required_tags(file_meta),
         :ok <- validate_no_un_vr(file_meta),
         :ok <- validate_private_information(file_meta) do
      :ok
    end
  end

  defp validate_required_tags(file_meta) do
    Enum.reduce_while(@required_meta_tags, :ok, fn tag, :ok ->
      if Map.has_key?(file_meta, tag) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_required_meta, tag}}}
      end
    end)
  end

  # PS3.10 Section 7.1: UN VR is prohibited in File Meta Information
  defp validate_no_un_vr(file_meta) do
    case Enum.find(file_meta, fn {_tag, %DataElement{vr: vr}} -> vr == :UN end) do
      {tag, _} -> {:error, {:un_vr_in_file_meta, tag}}
      nil -> :ok
    end
  end

  # PS3.10 Section 7.1: (0002,0102) is Type 1C — required if (0002,0100) present
  defp validate_private_information(file_meta) do
    if Map.has_key?(file_meta, {0x0002, 0x0102}) and not Map.has_key?(file_meta, {0x0002, 0x0100}) do
      {:error, {:missing_private_information_creator, {0x0002, 0x0102}}}
    else
      :ok
    end
  end

  @doc """
  Serializes a data set to P10 binary.
  """
  @spec serialize(DataSet.t()) :: {:ok, binary()} | {:error, term()}
  def serialize(%DataSet{} = data_set) do
    preamble = Dicom.P10.FileMeta.preamble()
    file_meta = ensure_required_meta(data_set.file_meta)

    with :ok <- validate_file_meta(%{data_set | file_meta: file_meta}) do
      # Encode all file meta elements except group length first (as iodata)
      meta_without_group_length = Map.delete(file_meta, {0x0002, 0x0000})
      meta_iodata = encode_elements(meta_without_group_length, :explicit, :little)

      # Compute and prepend group length (iolist_size avoids intermediate binary)
      group_length_elem =
        DataElement.new({0x0002, 0x0000}, :UL, <<:erlang.iolist_size(meta_iodata)::little-32>>)

      group_length_iodata = encode_element(group_length_elem, :explicit, :little)

      # Encode main data set (as iodata)
      transfer_syntax_uid = TransferSyntax.extract_uid(file_meta)
      {vr_encoding, endianness} = TransferSyntax.encoding(transfer_syntax_uid)
      data_set_iodata = encode_elements(data_set.elements, vr_encoding, endianness)

      # Deflate if transfer syntax requires it (PS3.5 Section 10)
      final_data_set =
        if transfer_syntax_uid == Dicom.UID.deflated_explicit_vr_little_endian() do
          :zlib.compress(data_set_iodata)
        else
          data_set_iodata
        end

      {:ok, IO.iodata_to_binary([preamble, group_length_iodata, meta_iodata, final_data_set])}
    end
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

  # Returns iodata — no intermediate binary allocation. Single IO.iodata_to_binary at serialize/1.
  defp encode_elements(elements, vr_encoding, endianness) do
    elements
    |> Enum.sort()
    |> Enum.map(fn {_tag, elem} -> encode_element(elem, vr_encoding, endianness) end)
  end

  # Explicit VR: Sequence (LE and BE)
  defp encode_element(
         %DataElement{tag: tag, vr: :SQ, value: items},
         :explicit,
         endian
       )
       when is_list(items) do
    items_iodata = encode_sequence_items(items, :explicit, endian)

    [
      encode_tag(tag, endian),
      "SQ",
      <<0::16>>,
      encode_u32(:erlang.iolist_size(items_iodata), endian),
      items_iodata
    ]
  end

  # Explicit VR: Encapsulated pixel data (LE only per DICOM standard)
  defp encode_element(
         %DataElement{tag: tag, vr: vr, value: {:encapsulated, fragments}},
         :explicit,
         :little
       ) do
    vr_bytes = VR.to_binary(vr)
    fragments_iodata = encode_encapsulated_fragments(fragments)

    [
      encode_tag(tag, :little),
      vr_bytes,
      <<0::16, 0xFFFFFFFF::little-32>>,
      fragments_iodata,
      <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
    ]
  end

  # Explicit VR: Normal element (LE and BE)
  defp encode_element(
         %DataElement{tag: tag, vr: vr, value: value},
         :explicit,
         endian
       ) do
    tag_bytes = encode_tag(tag, endian)
    vr_bytes = VR.to_binary(vr)
    padded_value = value |> Dicom.Value.encode(vr, endian) |> VR.pad_value(vr)

    if VR.long_length?(vr) do
      [tag_bytes, vr_bytes, <<0::16>>, encode_u32(byte_size(padded_value), endian), padded_value]
    else
      [tag_bytes, vr_bytes, encode_u16(byte_size(padded_value), endian), padded_value]
    end
  end

  # Implicit VR: Sequence
  defp encode_element(
         %DataElement{tag: tag, vr: :SQ, value: items},
         :implicit,
         :little
       )
       when is_list(items) do
    items_iodata = encode_sequence_items(items, :implicit, :little)

    [
      encode_tag(tag, :little),
      encode_u32(:erlang.iolist_size(items_iodata), :little),
      items_iodata
    ]
  end

  # Implicit VR: Normal element
  defp encode_element(
         %DataElement{tag: tag, vr: vr, value: value},
         :implicit,
         :little
       ) do
    padded_value = value |> Dicom.Value.encode(vr, :little) |> VR.pad_value(vr)

    [encode_tag(tag, :little), encode_u32(byte_size(padded_value), :little), padded_value]
  end

  defp encode_sequence_items(items, vr_enc, endian) do
    Enum.map(items, &encode_sequence_item(&1, vr_enc, endian))
  end

  defp encode_sequence_item(item_elements, vr_enc, endian) when is_map(item_elements) do
    item_iodata = encode_elements(item_elements, vr_enc, endian)

    [
      encode_tag({0xFFFE, 0xE000}, endian),
      encode_u32(:erlang.iolist_size(item_iodata), endian),
      item_iodata
    ]
  end

  defp encode_encapsulated_fragments(fragments) do
    Enum.map(fragments, fn fragment ->
      [<<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment)::little-32>>, fragment]
    end)
  end

  # Endian-aware binary encoding helpers

  defp encode_tag({group, element}, :little), do: <<group::little-16, element::little-16>>
  defp encode_tag({group, element}, :big), do: <<group::big-16, element::big-16>>

  defp encode_u32(value, :little), do: <<value::little-32>>
  defp encode_u32(value, :big), do: <<value::big-32>>

  defp encode_u16(value, :little), do: <<value::little-16>>
  defp encode_u16(value, :big), do: <<value::big-16>>

end
