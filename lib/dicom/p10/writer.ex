defmodule Dicom.P10.Writer do
  @moduledoc """
  DICOM P10 file writer.

  Serializes a `Dicom.DataSet` to DICOM Part 10 binary format.
  File Meta Information is always written in Explicit VR Little Endian.

  Reference: DICOM PS3.10 Section 7.
  """

  alias Dicom.{DataElement, DataSet, VR}

  @doc """
  Serializes a data set to P10 binary.
  """
  @spec serialize(DataSet.t()) :: {:ok, binary()} | {:error, term()}
  def serialize(%DataSet{} = data_set) do
    preamble = Dicom.P10.FileMeta.preamble()
    file_meta_binary = encode_elements(data_set.file_meta, :explicit, :little)
    transfer_syntax_uid = extract_transfer_syntax(data_set)
    {vr_encoding, endianness} = encoding_for(transfer_syntax_uid)
    data_set_binary = encode_elements(data_set.elements, vr_encoding, endianness)

    {:ok, preamble <> file_meta_binary <> data_set_binary}
  end

  defp encode_elements(elements, vr_encoding, endianness) do
    elements
    |> Map.values()
    |> Enum.sort_by(& &1.tag)
    |> Enum.map(&encode_element(&1, vr_encoding, endianness))
    |> IO.iodata_to_binary()
  end

  defp encode_element(
         %DataElement{tag: {group, element}, vr: vr, value: value},
         :explicit,
         :little
       ) do
    tag_bytes = <<group::little-16, element::little-16>>
    vr_bytes = VR.to_binary(vr)
    value_binary = to_binary(value)

    if VR.long_length?(vr) do
      tag_bytes <> vr_bytes <> <<0::16, byte_size(value_binary)::little-32>> <> value_binary
    else
      tag_bytes <> vr_bytes <> <<byte_size(value_binary)::little-16>> <> value_binary
    end
  end

  defp encode_element(%DataElement{tag: {group, element}, value: value}, :implicit, :little) do
    value_binary = to_binary(value)
    <<group::little-16, element::little-16, byte_size(value_binary)::little-32>> <> value_binary
  end

  defp to_binary(value) when is_binary(value), do: value
  defp to_binary(value) when is_integer(value), do: <<value::little-32>>
  defp to_binary(value), do: to_string(value)

  defp extract_transfer_syntax(%DataSet{file_meta: file_meta}) do
    case Map.get(file_meta, Dicom.Tag.transfer_syntax_uid()) do
      %DataElement{value: uid} -> String.trim_trailing(uid, <<0>>)
      nil -> Dicom.UID.implicit_vr_little_endian()
    end
  end

  defp encoding_for(uid) do
    cond do
      uid == Dicom.UID.implicit_vr_little_endian() -> {:implicit, :little}
      uid == Dicom.UID.explicit_vr_big_endian() -> {:explicit, :big}
      true -> {:explicit, :little}
    end
  end
end
