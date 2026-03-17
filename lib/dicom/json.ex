defmodule Dicom.Json do
  @moduledoc """
  DICOM JSON Model (PS3.18 Annex F.2).

  Encodes and decodes DICOM DataSets to/from the DICOM JSON model
  used by DICOMweb (STOW-RS, WADO-RS, QIDO-RS).

  Produces/consumes plain Elixir maps — any JSON library (Jason, Poison)
  can serialize the result to a JSON string.

  ## Examples

      # Encode a DataSet to a DICOM JSON map
      map = Dicom.Json.to_map(data_set)
      json_string = Jason.encode!(map)

      # Decode a DICOM JSON map back to a DataSet
      {:ok, data_set} = Dicom.Json.from_map(map)

  Reference: DICOM PS3.18 Annex F.2.
  """

  alias Dicom.{DataSet, DataElement, Value, VR}

  @string_vrs VR.string_vrs()
  @numeric_vrs VR.numeric_vrs()
  @binary_vrs VR.binary_vrs()

  # ── Encoder ───────────────────────────────────────────────────

  @doc """
  Converts a `Dicom.DataSet` to a DICOM JSON map.

  ## Options

  - `include_file_meta` — include group 0002 elements (default: `false`)
  - `bulk_data_uri` — `fn tag, vr -> url | nil end` to emit BulkDataURI
    instead of InlineBinary for binary VRs
  """
  @spec to_map(DataSet.t(), keyword()) :: map()
  def to_map(%DataSet{} = ds, opts \\ []) do
    include_meta = Keyword.get(opts, :include_file_meta, false)
    bulk_fn = Keyword.get(opts, :bulk_data_uri, nil)

    elements =
      if include_meta do
        Map.merge(ds.file_meta, ds.elements)
      else
        ds.elements
      end

    Map.new(elements, fn {tag, elem} ->
      {format_tag(tag), encode_element(tag, elem, bulk_fn)}
    end)
  end

  defp encode_element(tag, %DataElement{vr: vr, value: value}, bulk_fn) do
    base = %{"vr" => Atom.to_string(vr)}
    encode_value(base, tag, vr, value, bulk_fn)
  end

  defp encode_value(base, _tag, _vr, nil, _bulk_fn), do: base
  defp encode_value(base, _tag, _vr, "", _bulk_fn), do: base

  defp encode_value(base, _tag, :PN, value, _bulk_fn) when is_binary(value) do
    Map.put(base, "Value", [encode_pn(value)])
  end

  defp encode_value(base, _tag, :SQ, items, _bulk_fn) when is_list(items) do
    Map.put(base, "Value", Enum.map(items, &encode_item/1))
  end

  defp encode_value(base, _tag, :AT, value, _bulk_fn) when is_binary(value) do
    <<group::little-16, element::little-16>> = value
    hex = format_tag({group, element})
    Map.put(base, "Value", [hex])
  end

  defp encode_value(base, _tag, :AT, {group, element}, _bulk_fn) do
    hex = format_tag({group, element})
    Map.put(base, "Value", [hex])
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn)
       when vr in @string_vrs and is_binary(value) do
    Map.put(base, "Value", [String.trim_trailing(value)])
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn)
       when vr in @numeric_vrs and is_binary(value) do
    decoded = Value.decode(value, vr)
    values = if is_list(decoded), do: decoded, else: [decoded]
    Map.put(base, "Value", values)
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn)
       when vr in @numeric_vrs and is_number(value) do
    Map.put(base, "Value", [value])
  end

  defp encode_value(base, tag, vr, value, bulk_fn)
       when vr in @binary_vrs and is_binary(value) do
    if bulk_fn do
      case bulk_fn.(tag, vr) do
        nil -> Map.put(base, "InlineBinary", Base.encode64(value))
        uri -> Map.put(base, "BulkDataURI", uri)
      end
    else
      Map.put(base, "InlineBinary", Base.encode64(value))
    end
  end

  defp encode_value(base, _tag, _vr, value, _bulk_fn) when is_binary(value) do
    Map.put(base, "Value", [value])
  end

  defp encode_value(base, _tag, _vr, _value, _bulk_fn), do: base

  defp encode_pn(value) do
    case String.split(value, "=") do
      [alphabetic] ->
        %{"Alphabetic" => alphabetic}

      [alphabetic, ideographic] ->
        %{"Alphabetic" => alphabetic, "Ideographic" => ideographic}

      [alphabetic, ideographic, phonetic | _] ->
        %{"Alphabetic" => alphabetic, "Ideographic" => ideographic, "Phonetic" => phonetic}
    end
  end

  defp encode_item(item) when is_map(item) do
    Map.new(item, fn {tag, elem} ->
      {format_tag(tag), encode_element(tag, elem, nil)}
    end)
  end

  # ── Decoder ───────────────────────────────────────────────────

  @doc """
  Decodes a DICOM JSON map into a `Dicom.DataSet`.

  Returns `{:ok, data_set}` or `{:error, reason}`.
  """
  @spec from_map(map()) :: {:ok, DataSet.t()} | {:error, term()}
  def from_map(json) when is_map(json) do
    Enum.reduce_while(json, {:ok, DataSet.new()}, fn {tag_hex, elem_map}, {:ok, ds} ->
      with {:ok, tag} <- parse_tag_hex(tag_hex),
           {:ok, vr} <- parse_vr(elem_map),
           {:ok, value} <- decode_value(vr, elem_map) do
        elem = DataElement.new(tag, vr, value)
        {group, _} = tag

        ds =
          if group == 0x0002 do
            %{ds | file_meta: Map.put(ds.file_meta, tag, elem)}
          else
            %{ds | elements: Map.put(ds.elements, tag, elem)}
          end

        {:cont, {:ok, ds}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp parse_tag_hex(hex) when is_binary(hex) and byte_size(hex) == 8 do
    with {group, ""} <- Integer.parse(String.slice(hex, 0, 4), 16),
         {element, ""} <- Integer.parse(String.slice(hex, 4, 4), 16) do
      {:ok, {group, element}}
    else
      _ -> {:error, {:invalid_tag, hex}}
    end
  end

  defp parse_tag_hex(hex), do: {:error, {:invalid_tag, hex}}

  defp parse_vr(%{"vr" => vr_str}) do
    VR.from_binary(vr_str)
  end

  defp parse_vr(_), do: {:error, :missing_vr}

  defp decode_value(:PN, %{"Value" => [pn_map | _]}) when is_map(pn_map) do
    value = decode_pn(pn_map)
    {:ok, value}
  end

  defp decode_value(:SQ, %{"Value" => items}) when is_list(items) do
    decoded_items = Enum.map(items, &decode_item/1)
    {:ok, decoded_items}
  end

  defp decode_value(:AT, %{"Value" => [hex | _]}) when is_binary(hex) do
    with {:ok, {group, element}} <- parse_tag_hex(hex) do
      {:ok, <<group::little-16, element::little-16>>}
    end
  end

  defp decode_value(vr, %{"Value" => [value | _]})
       when vr in @string_vrs and is_binary(value) do
    {:ok, value}
  end

  defp decode_value(vr, %{"Value" => [value | _]})
       when vr in @numeric_vrs and is_number(value) do
    {:ok, Value.encode(value, vr)}
  end

  defp decode_value(vr, %{"InlineBinary" => b64})
       when vr in @binary_vrs and is_binary(b64) do
    case Base.decode64(b64) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_base64}
    end
  end

  defp decode_value(_vr, %{"BulkDataURI" => uri}) when is_binary(uri) do
    {:ok, uri}
  end

  defp decode_value(_vr, %{"Value" => _} = _elem_map) do
    {:ok, nil}
  end

  defp decode_value(_vr, _elem_map) do
    {:ok, nil}
  end

  defp decode_pn(pn_map) do
    alpha = Map.get(pn_map, "Alphabetic", "")
    ideo = Map.get(pn_map, "Ideographic")
    phonetic = Map.get(pn_map, "Phonetic")

    cond do
      phonetic -> "#{alpha}=#{ideo}=#{phonetic}"
      ideo -> "#{alpha}=#{ideo}"
      true -> alpha
    end
  end

  defp decode_item(item_map) when is_map(item_map) do
    Map.new(item_map, fn {tag_hex, elem_map} ->
      {:ok, tag} = parse_tag_hex(tag_hex)
      {:ok, vr} = parse_vr(elem_map)
      {:ok, value} = decode_value(vr, elem_map)
      {tag, DataElement.new(tag, vr, value)}
    end)
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp format_tag({group, element}) do
    g = group |> Integer.to_string(16) |> String.pad_leading(4, "0") |> String.upcase()
    e = element |> Integer.to_string(16) |> String.pad_leading(4, "0") |> String.upcase()
    "#{g}#{e}"
  end
end
