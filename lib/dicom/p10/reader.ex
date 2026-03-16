defmodule Dicom.P10.Reader do
  @moduledoc """
  DICOM P10 file reader.

  Parses a binary DICOM P10 stream into a `Dicom.DataSet`. Handles the
  preamble, File Meta Information, and the main data set with support
  for both Implicit VR and Explicit VR Little Endian transfer syntaxes.

  Reference: DICOM PS3.10 Section 7, PS3.5 Section 7.1.
  """

  alias Dicom.{DataElement, DataSet, VR}

  @doc """
  Parses a complete DICOM P10 binary into a `DataSet`.
  """
  @spec parse(binary()) :: {:ok, DataSet.t()} | {:error, term()}
  def parse(binary) when is_binary(binary) do
    with {:ok, rest} <- Dicom.P10.FileMeta.skip_preamble(binary),
         {:ok, file_meta, rest} <- read_file_meta(rest),
         transfer_syntax_uid = extract_transfer_syntax(file_meta),
         {:ok, elements} <- read_data_set(rest, transfer_syntax_uid) do
      {:ok, %DataSet{file_meta: file_meta, elements: elements}}
    end
  end

  # File Meta Information is always Explicit VR Little Endian.
  # Group 0002 elements end when we hit a non-0002 group.
  defp read_file_meta(binary) do
    read_elements_while(binary, :explicit, :little, fn {group, _} -> group == 0x0002 end, %{})
  end

  defp read_data_set(binary, transfer_syntax_uid) do
    {vr_encoding, endianness} = encoding_for(transfer_syntax_uid)
    read_all_elements(binary, vr_encoding, endianness, %{})
  end

  defp read_elements_while(<<>>, _vr_enc, _endian, _pred, acc) do
    {:ok, acc, <<>>}
  end

  defp read_elements_while(binary, vr_enc, endian, pred, acc) do
    case peek_tag(binary, endian) do
      {:ok, tag} ->
        if pred.(tag) do
          case read_element(binary, vr_enc, endian) do
            {:ok, element, rest} ->
              read_elements_while(rest, vr_enc, endian, pred, Map.put(acc, element.tag, element))

            {:error, _} = error ->
              error
          end
        else
          {:ok, acc, binary}
        end

      {:error, _} = error ->
        error
    end
  end

  defp read_all_elements(<<>>, _vr_enc, _endian, acc), do: {:ok, acc}

  defp read_all_elements(binary, _vr_enc, _endian, acc) when byte_size(binary) < 4 do
    {:ok, acc}
  end

  defp read_all_elements(binary, vr_enc, endian, acc) do
    case read_element(binary, vr_enc, endian) do
      {:ok, element, rest} ->
        read_all_elements(rest, vr_enc, endian, Map.put(acc, element.tag, element))

      {:error, _} = error ->
        error
    end
  end

  defp peek_tag(<<group::little-16, element::little-16, _rest::binary>>, :little) do
    {:ok, {group, element}}
  end

  defp peek_tag(<<group::big-16, element::big-16, _rest::binary>>, :big) do
    {:ok, {group, element}}
  end

  defp peek_tag(_, _), do: {:error, :unexpected_end}

  # Explicit VR Little Endian
  defp read_element(
         <<group::little-16, element::little-16, vr_bytes::binary-size(2), rest::binary>>,
         :explicit,
         :little
       ) do
    tag = {group, element}

    case VR.from_binary(vr_bytes) do
      {:ok, vr} ->
        if VR.long_length?(vr) do
          read_long_value(rest, tag, vr, :little)
        else
          read_short_value(rest, tag, vr, :little)
        end

      {:error, :unknown_vr} ->
        # Treat as UN with short length
        read_short_value(rest, tag, :UN, :little)
    end
  end

  # Implicit VR Little Endian
  defp read_element(
         <<group::little-16, element::little-16, length::little-32, rest::binary>>,
         :implicit,
         :little
       ) do
    tag = {group, element}
    vr = lookup_implicit_vr(tag)
    read_value_by_length(rest, tag, vr, length)
  end

  defp read_element(_, _, _), do: {:error, :unexpected_end}

  # Short value: 2-byte length (Explicit VR, non-long VRs)
  defp read_short_value(<<length::little-16, rest::binary>>, tag, vr, :little) do
    read_value_by_length(rest, tag, vr, length)
  end

  defp read_short_value(_, _, _, _), do: {:error, :unexpected_end}

  # Long value: 2 reserved bytes + 4-byte length (Explicit VR, long VRs)
  defp read_long_value(<<_reserved::16, length::little-32, rest::binary>>, tag, vr, :little) do
    read_value_by_length(rest, tag, vr, length)
  end

  defp read_long_value(_, _, _, _), do: {:error, :unexpected_end}

  # Undefined length (0xFFFFFFFF) — skip for now, treat as empty
  defp read_value_by_length(rest, tag, vr, 0xFFFFFFFF) do
    # TODO: handle sequence/item delimitation for undefined length
    {:ok, DataElement.new(tag, vr, <<>>), rest}
  end

  defp read_value_by_length(binary, tag, vr, length) when byte_size(binary) >= length do
    <<value::binary-size(length), rest::binary>> = binary
    {:ok, DataElement.new(tag, vr, value), rest}
  end

  defp read_value_by_length(_, _, _, _), do: {:error, :unexpected_end}

  defp extract_transfer_syntax(file_meta) do
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

  defp lookup_implicit_vr(tag) do
    case Dicom.Dictionary.Registry.lookup(tag) do
      {:ok, _name, vr, _vm} -> vr
      :error -> :UN
    end
  end
end
