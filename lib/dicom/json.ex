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

      # Resolve BulkDataURI references during decode
      {:ok, data_set} =
        Dicom.Json.from_map(map,
          bulk_data_resolver: fn _tag, _vr, uri ->
            File.read(uri)
          end
        )

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
    instead of InlineBinary for binary VRs. For encapsulated pixel data, the
    URI or inline payload represents the full DICOM Value Field, including the
    Basic Offset Table item, fragment items, and sequence delimiter.
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

    elements
    |> Enum.reject(fn {{_group, element}, _elem} -> element == 0x0000 end)
    |> Map.new(fn {tag, elem} ->
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
    values =
      value
      |> split_multi_string()
      |> Enum.map(&encode_pn/1)

    Map.put(base, "Value", values)
  end

  defp encode_value(base, _tag, :SQ, items, bulk_fn) when is_list(items) do
    Map.put(base, "Value", Enum.map(items, &encode_item(&1, bulk_fn)))
  end

  defp encode_value(base, _tag, :AT, value, _bulk_fn) when is_binary(value) do
    values =
      for <<group::little-16, element::little-16 <- value>> do
        format_tag({group, element})
      end

    Map.put(base, "Value", values)
  end

  defp encode_value(base, _tag, :AT, {group, element}, _bulk_fn) do
    hex = format_tag({group, element})
    Map.put(base, "Value", [hex])
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn)
       when vr in @string_vrs and is_binary(value) do
    values =
      value
      |> split_multi_string()
      |> Enum.map(&String.trim_trailing/1)

    Map.put(base, "Value", values)
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
    encode_binary_value(base, tag, vr, value, bulk_fn)
  end

  defp encode_value(base, tag, vr, {:encapsulated, fragments}, bulk_fn)
       when vr in @binary_vrs and is_list(fragments) do
    base
    |> encode_binary_value(tag, vr, serialize_encapsulated_value(fragments), bulk_fn)
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

  defp encode_binary_value(base, tag, vr, value, bulk_fn) do
    if bulk_fn do
      case bulk_fn.(tag, vr) do
        nil -> Map.put(base, "InlineBinary", Base.encode64(value))
        uri -> Map.put(base, "BulkDataURI", uri)
      end
    else
      Map.put(base, "InlineBinary", Base.encode64(value))
    end
  end

  defp encode_item(item, bulk_fn) when is_map(item) do
    Map.new(item, fn {tag, elem} ->
      {format_tag(tag), encode_element(tag, elem, bulk_fn)}
    end)
  end

  defp serialize_encapsulated_value(fragments) do
    fragments_iodata =
      Enum.map(fragments, fn fragment ->
        [<<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment)::little-32>>, fragment]
      end)

    IO.iodata_to_binary([fragments_iodata, <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>])
  end

  # ── Decoder ───────────────────────────────────────────────────

  @doc """
  Decodes a DICOM JSON map into a `Dicom.DataSet`.

  ## Options

  - `bulk_data_resolver` — `fn tag, vr, uri -> {:ok, binary} | {:error, reason} end`
    used to resolve `BulkDataURI` entries during decode. Without a resolver,
    `BulkDataURI` returns an error instead of being stored as element bytes.
  - `transfer_syntax_uid` — transfer syntax context for interpreting Pixel Data
    binary payloads. When omitted, group `0002` Transfer Syntax UID from the
    JSON map is used if present.

  Returns `{:ok, data_set}` or `{:error, reason}`.
  """
  @spec from_map(map(), keyword()) :: {:ok, DataSet.t()} | {:error, term()}
  def from_map(json, opts \\ []) when is_map(json) do
    opts = put_transfer_syntax_uid(opts, json)

    Enum.reduce_while(json, {:ok, DataSet.new()}, fn {tag_hex, elem_map}, {:ok, ds} ->
      with {:ok, tag} <- parse_tag_hex(tag_hex),
           {:ok, vr} <- parse_vr(elem_map),
           {:ok, value} <- decode_value(tag, vr, elem_map, opts) do
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

  defp decode_value(tag, vr, elem_map, opts) do
    with :ok <- validate_single_value_representation(tag, elem_map) do
      case elem_map do
        %{"Value" => values} ->
          decode_json_value(tag, vr, values, opts)

        %{"InlineBinary" => value} ->
          decode_inline_binary(tag, vr, value, opts)

        %{"BulkDataURI" => value} ->
          decode_bulk_data_uri(tag, vr, value, opts)

        _ ->
          {:ok, nil}
      end
    end
  end

  defp decode_json_value(_tag, :PN, [], _opts), do: {:ok, nil}

  defp decode_json_value(tag, :PN, pn_values, _opts) when is_list(pn_values) do
    Enum.reduce_while(pn_values, {:ok, []}, fn
      pn_map, {:ok, acc} when is_map(pn_map) ->
        {:cont, {:ok, [decode_pn(pn_map) | acc]}}

      _value, _acc ->
        {:halt, {:error, {:invalid_value, tag, :PN, :expected_person_name_components}}}
    end)
    |> case do
      {:ok, decoded} -> {:ok, decoded |> Enum.reverse() |> Enum.join("\\")}
      {:error, _} = error -> error
    end
  end

  defp decode_json_value(tag, :PN, _value, _opts) do
    {:error, {:invalid_value, tag, :PN, :expected_value_array}}
  end

  defp decode_json_value(_tag, :SQ, [], _opts), do: {:ok, []}

  defp decode_json_value(_tag, :SQ, items, opts) when is_list(items) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case decode_item(item, opts) do
        {:ok, decoded_item} -> {:cont, {:ok, [decoded_item | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, decoded_items} -> {:ok, Enum.reverse(decoded_items)}
      {:error, _} = error -> error
    end
  end

  defp decode_json_value(tag, :SQ, _value, _opts) do
    {:error, {:invalid_value, tag, :SQ, :expected_value_array}}
  end

  defp decode_json_value(_tag, :AT, [], _opts), do: {:ok, nil}

  defp decode_json_value(tag, :AT, values, _opts) when is_list(values) do
    Enum.reduce_while(values, {:ok, <<>>}, fn
      hex, {:ok, acc} when is_binary(hex) ->
        with {:ok, {group, element}} <- parse_tag_hex(hex) do
          {:cont, {:ok, <<acc::binary, group::little-16, element::little-16>>}}
        else
          {:error, _} = error -> {:halt, error}
        end

      _value, _acc ->
        {:halt, {:error, {:invalid_value, tag, :AT, :expected_tag_hex}}}
    end)
  end

  defp decode_json_value(tag, :AT, _value, _opts) do
    {:error, {:invalid_value, tag, :AT, :expected_value_array}}
  end

  defp decode_json_value(_tag, vr, [], _opts) when vr in @string_vrs, do: {:ok, nil}

  defp decode_json_value(tag, vr, values, _opts)
       when vr in @string_vrs and is_list(values) do
    if Enum.all?(values, &is_binary/1) do
      {:ok, Enum.join(values, "\\")}
    else
      {:error, {:invalid_value, tag, vr, :expected_string_values}}
    end
  end

  defp decode_json_value(tag, vr, _value, _opts) when vr in @string_vrs do
    {:error, {:invalid_value, tag, vr, :expected_value_array}}
  end

  defp decode_json_value(_tag, vr, [], _opts) when vr in @numeric_vrs, do: {:ok, nil}

  defp decode_json_value(tag, vr, values, _opts)
       when vr in @numeric_vrs and is_list(values) do
    if Enum.all?(values, &is_number/1) do
      {:ok, IO.iodata_to_binary(Enum.map(values, &Value.encode(&1, vr)))}
    else
      {:error, {:invalid_value, tag, vr, :expected_numeric_values}}
    end
  end

  defp decode_json_value(tag, vr, _value, _opts) when vr in @numeric_vrs do
    {:error, {:invalid_value, tag, vr, :expected_value_array}}
  end

  defp decode_json_value(tag, vr, _value, _opts) when vr in @binary_vrs do
    {:error, {:invalid_value, tag, vr, :expected_binary_representation}}
  end

  defp decode_json_value(_tag, _vr, [], _opts), do: {:ok, nil}

  defp decode_json_value(tag, vr, values, _opts) when is_list(values) do
    if Enum.all?(values, &is_binary/1) do
      {:ok, Enum.join(values, "\\")}
    else
      {:error, {:invalid_value, tag, vr, :expected_string_values}}
    end
  end

  defp decode_json_value(tag, vr, _value, _opts) do
    {:error, {:invalid_value, tag, vr, :expected_value_array}}
  end

  defp decode_inline_binary(tag, vr, b64, opts) when vr in @binary_vrs and is_binary(b64) do
    case Base.decode64(b64) do
      {:ok, binary} -> normalize_binary_value(tag, binary, opts)
      :error -> {:error, {:invalid_value, tag, vr, :invalid_base64}}
    end
  end

  defp decode_inline_binary(tag, vr, _value, _opts) do
    {:error, {:invalid_value, tag, vr, :expected_inline_binary}}
  end

  defp decode_bulk_data_uri(tag, vr, uri, opts) when vr in @binary_vrs and is_binary(uri) do
    case Keyword.get(opts, :bulk_data_resolver) do
      nil ->
        {:error, {:unresolved_bulk_data_uri, tag, vr, uri}}

      resolver when is_function(resolver, 3) ->
        case resolver.(tag, vr, uri) do
          {:ok, binary} when is_binary(binary) -> normalize_binary_value(tag, binary, opts)
          {:error, reason} -> {:error, {:bulk_data_resolution_failed, tag, vr, uri, reason}}
          other -> {:error, {:invalid_bulk_data_resolution, tag, vr, uri, other}}
        end

      other ->
        {:error, {:invalid_bulk_data_resolver, other}}
    end
  end

  defp decode_bulk_data_uri(tag, vr, _value, _opts) do
    {:error, {:invalid_value, tag, vr, :expected_bulk_data_uri}}
  end

  defp validate_single_value_representation(tag, elem_map) do
    reps =
      Enum.count(
        ["Value", "InlineBinary", "BulkDataURI"],
        &Map.has_key?(elem_map, &1)
      )

    if reps > 1 do
      {:error, {:multiple_value_representations, tag}}
    else
      :ok
    end
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

  defp split_multi_string(value) do
    String.split(value, "\\")
  end

  defp normalize_binary_value({0x7FE0, 0x0010} = tag, binary, opts) do
    case Keyword.get(opts, :transfer_syntax_uid) do
      uid when is_binary(uid) ->
        if Dicom.TransferSyntax.compressed?(uid) do
          case parse_encapsulated_value(binary) do
            {:ok, fragments} -> {:ok, {:encapsulated, fragments}}
            :error -> {:error, {:invalid_encapsulated_pixel_data, tag, uid}}
          end
        else
          {:ok, binary}
        end

      _ ->
        {:ok, binary}
    end
  end

  defp normalize_binary_value(_tag, binary, _opts), do: {:ok, binary}

  defp parse_encapsulated_value(binary) do
    case parse_encapsulated_fragments(binary, []) do
      {:ok, fragments, <<>>} when fragments != [] -> {:ok, fragments}
      _ -> :error
    end
  end

  defp parse_encapsulated_fragments(
         <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32, rest::binary>>,
         acc
       ) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp parse_encapsulated_fragments(
         <<0xFE, 0xFF, 0x00, 0xE0, length::little-32, rest::binary>>,
         acc
       )
       when byte_size(rest) >= length do
    <<fragment::binary-size(length), remaining::binary>> = rest
    parse_encapsulated_fragments(remaining, [fragment | acc])
  end

  defp parse_encapsulated_fragments(_, _acc), do: :error

  defp put_transfer_syntax_uid(opts, json) do
    case Keyword.has_key?(opts, :transfer_syntax_uid) do
      true ->
        opts

      false ->
        case Map.get(json, "00020010") do
          %{"vr" => "UI", "Value" => [uid | _]} when is_binary(uid) ->
            Keyword.put(opts, :transfer_syntax_uid, String.trim(uid))

          _ ->
            opts
        end
    end
  end

  defp decode_item(item_map, opts) when is_map(item_map) do
    Enum.reduce_while(item_map, {:ok, %{}}, fn {tag_hex, elem_map}, {:ok, acc} ->
      with {:ok, tag} <- parse_tag_hex(tag_hex),
           {:ok, vr} <- parse_vr(elem_map),
           {:ok, value} <- decode_value(tag, vr, elem_map, opts) do
        {:cont, {:ok, Map.put(acc, tag, DataElement.new(tag, vr, value))}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp decode_item(_item_map, _opts), do: {:error, :invalid_sequence_item}

  # ── Helpers ───────────────────────────────────────────────────

  defp format_tag({group, element}) do
    g = group |> Integer.to_string(16) |> String.pad_leading(4, "0") |> String.upcase()
    e = element |> Integer.to_string(16) |> String.pad_leading(4, "0") |> String.upcase()
    "#{g}#{e}"
  end
end
