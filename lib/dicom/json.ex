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

  alias Dicom.{CharacterSet, DataSet, DataElement, PixelData, TransferSyntax, Value, VR}

  @string_vrs VR.string_vrs()
  @numeric_vrs VR.numeric_vrs()
  @binary_vrs VR.binary_vrs()
  @charset_sensitive_vrs [:LO, :LT, :PN, :SH, :ST, :UC, :UT]
  @single_value_string_vrs [:LT, :ST, :UC, :UR, :UT]

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

    charsets = CharacterSet.extract_all(elements)

    elements
    |> Enum.reject(fn {{_group, element}, _elem} -> element == 0x0000 end)
    |> Map.new(fn {tag, elem} ->
      {format_tag(tag), encode_element(tag, elem, bulk_fn, charsets)}
    end)
  end

  defp encode_element(tag, %DataElement{vr: vr, value: value}, bulk_fn, charsets) do
    base = %{"vr" => Atom.to_string(vr)}
    encode_value(base, tag, vr, value, bulk_fn, charsets)
  end

  defp encode_value(base, _tag, _vr, nil, _bulk_fn, _charset), do: base
  defp encode_value(base, _tag, _vr, "", _bulk_fn, _charset), do: base

  defp encode_value(base, _tag, :PN, value, _bulk_fn, charsets) when is_binary(value) do
    values =
      value
      |> decode_charset_text!(:PN, charsets)
      |> split_multi_string()
      |> Enum.map(&encode_pn/1)

    Map.put(base, "Value", values)
  end

  defp encode_value(base, _tag, :SQ, items, bulk_fn, charsets) when is_list(items) do
    Map.put(base, "Value", Enum.map(items, &encode_item(&1, bulk_fn, charsets)))
  end

  defp encode_value(base, _tag, :AT, value, _bulk_fn, _charset) when is_binary(value) do
    if rem(byte_size(value), 4) != 0 do
      raise ArgumentError, "invalid AT value length: expected a multiple of 4 bytes"
    end

    values =
      for <<group::little-16, element::little-16 <- value>> do
        format_tag({group, element})
      end

    Map.put(base, "Value", values)
  end

  defp encode_value(base, _tag, :AT, {group, element}, _bulk_fn, _charset)
       when group in 0..0xFFFF and element in 0..0xFFFF do
    hex = format_tag({group, element})
    Map.put(base, "Value", [hex])
  end

  defp encode_value(_base, _tag, :AT, _value, _bulk_fn, _charset) do
    raise ArgumentError, "invalid AT value: expected 16-bit tag tuple"
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn, charsets)
       when vr in @charset_sensitive_vrs and vr != :PN and is_binary(value) do
    text =
      value
      |> decode_charset_text!(vr, charsets)
      |> trim_string_padding(vr)

    Map.put(base, "Value", encode_string_values(vr, text))
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn, _charset)
       when vr in @string_vrs and is_binary(value) do
    values =
      value
      |> trim_string_padding(vr)
      |> then(&encode_string_values(vr, &1))

    Map.put(base, "Value", values)
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn, _charset)
       when vr in @numeric_vrs and is_binary(value) do
    decoded = Value.decode(value, vr)

    cond do
      is_list(decoded) and Enum.all?(decoded, &is_number/1) ->
        Map.put(base, "Value", decoded)

      is_number(decoded) ->
        Map.put(base, "Value", [decoded])

      true ->
        raise ArgumentError, "invalid binary value for numeric VR #{vr}"
    end
  end

  defp encode_value(base, _tag, vr, value, _bulk_fn, _charset)
       when vr in @numeric_vrs and is_number(value) do
    Map.put(base, "Value", [value])
  end

  defp encode_value(base, tag, vr, value, bulk_fn, _charset)
       when vr in @binary_vrs and is_binary(value) do
    encode_binary_value(base, tag, vr, value, bulk_fn)
  end

  defp encode_value(base, tag, vr, {:encapsulated, fragments}, bulk_fn, _charset)
       when vr in @binary_vrs and is_list(fragments) do
    base
    |> encode_binary_value(tag, vr, serialize_encapsulated_value(fragments), bulk_fn)
  end

  defp encode_value(base, _tag, _vr, value, _bulk_fn, _charset) when is_binary(value) do
    Map.put(base, "Value", [value])
  end

  defp encode_value(_base, _tag, vr, _value, _bulk_fn, _charset) do
    raise ArgumentError, "unsupported value for VR #{vr}"
  end

  defp encode_pn(value) do
    case String.split(value, "=") do
      [alphabetic] ->
        pn_component_map(alphabetic, nil, nil)

      [alphabetic, ideographic] ->
        pn_component_map(alphabetic, ideographic, nil)

      [alphabetic, ideographic, phonetic] ->
        pn_component_map(alphabetic, ideographic, phonetic)

      _ ->
        raise ArgumentError, "invalid PN value: expected at most 3 component groups"
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

  defp encode_item(item, bulk_fn, inherited_charsets) when is_map(item) do
    charsets =
      case CharacterSet.extract_all(item) do
        [] -> inherited_charsets
        item_charsets -> item_charsets
      end

    Map.new(item, fn {tag, elem} ->
      {format_tag(tag), encode_element(tag, elem, bulk_fn, charsets)}
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
  Returns `{:ok, data_set}` or `{:error, reason}`.
  """
  @spec from_map(map(), keyword()) :: {:ok, DataSet.t()} | {:error, term()}
  def from_map(json, opts \\ []) when is_map(json) do
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
    |> case do
      {:ok, ds} -> normalize_decoded_pixel_data(ds, opts)
      {:error, _} = error -> error
    end
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
        case decode_pn(tag, pn_map) do
          {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
          {:error, _} = error -> {:halt, error}
        end

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

  defp decode_json_value(tag, :DS, values, _opts) when is_list(values) do
    decode_decimal_string_values(tag, values)
  end

  defp decode_json_value(tag, :IS, values, _opts) when is_list(values) do
    decode_integer_string_values(tag, values)
  end

  defp decode_json_value(tag, vr, values, _opts)
       when vr in @string_vrs and is_list(values) do
    decode_string_values(tag, vr, values)
  end

  defp decode_json_value(tag, vr, _value, _opts) when vr in @string_vrs do
    {:error, {:invalid_value, tag, vr, :expected_value_array}}
  end

  defp decode_json_value(_tag, vr, [], _opts) when vr in @numeric_vrs, do: {:ok, nil}

  defp decode_json_value(tag, vr, values, _opts)
       when vr in @numeric_vrs and is_list(values) do
    encode_numeric_json_values(tag, vr, values)
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

  defp decode_pn(tag, pn_map) do
    alpha = Map.get(pn_map, "Alphabetic", "")
    ideo = Map.get(pn_map, "Ideographic")
    phonetic = Map.get(pn_map, "Phonetic")

    with :ok <- validate_pn_component_keys(pn_map),
         :ok <- validate_pn_component(alpha),
         :ok <- validate_pn_component(ideo),
         :ok <- validate_pn_component(phonetic) do
      cond do
        is_binary(phonetic) -> {:ok, "#{alpha}=#{ideo}=#{phonetic}"}
        is_binary(ideo) -> {:ok, "#{alpha}=#{ideo}"}
        true -> {:ok, alpha}
      end
    else
      :error ->
        {:error, {:invalid_value, tag, :PN, :expected_string_person_name_components}}
    end
  end

  defp split_multi_string(value) do
    String.split(value, "\\")
  end

  defp pn_component_map(alphabetic, ideographic, phonetic) do
    %{}
    |> maybe_put_pn_component("Alphabetic", alphabetic)
    |> maybe_put_pn_component("Ideographic", ideographic)
    |> maybe_put_pn_component("Phonetic", phonetic)
  end

  defp maybe_put_pn_component(map, _key, nil), do: map
  defp maybe_put_pn_component(map, _key, ""), do: map
  defp maybe_put_pn_component(map, key, value), do: Map.put(map, key, value)

  defp encode_string_values(vr, value) when vr in @single_value_string_vrs, do: [value]
  defp encode_string_values(_vr, value), do: split_multi_string(value)

  defp trim_string_padding(value, vr) when is_binary(value) do
    case vr do
      :UI -> String.trim_trailing(value, <<0>>)
      _ -> value
    end
  end

  defp validate_pn_component(nil), do: :ok
  defp validate_pn_component(value) when is_binary(value), do: :ok
  defp validate_pn_component(_value), do: :error

  defp validate_pn_component_keys(pn_map) when is_map(pn_map) do
    if Enum.all?(Map.keys(pn_map), &(&1 in ["Alphabetic", "Ideographic", "Phonetic"])) do
      :ok
    else
      :error
    end
  end

  defp decode_string_values(tag, vr, values) when vr in @single_value_string_vrs do
    case values do
      [value] when is_binary(value) -> {:ok, value}
      [_ | _] -> {:error, {:invalid_value, tag, vr, :expected_single_value_array}}
      _ -> {:error, {:invalid_value, tag, vr, :expected_string_values}}
    end
  end

  defp decode_string_values(tag, vr, values) do
    if Enum.all?(values, &is_binary/1) do
      {:ok, Enum.join(values, "\\")}
    else
      {:error, {:invalid_value, tag, vr, :expected_string_values}}
    end
  end

  defp decode_decimal_string_values(tag, values) do
    Enum.reduce_while(values, {:ok, []}, fn
      value, {:ok, acc} when is_binary(value) ->
        if valid_json_string_numeric_value?(value, :DS) do
          {:cont, {:ok, [value | acc]}}
        else
          {:halt, {:error, {:invalid_value, tag, :DS, :expected_number_or_string_values}}}
        end

      value, {:ok, acc} when is_number(value) ->
        {:cont, {:ok, [to_string(value) | acc]}}

      _value, _acc ->
        {:halt, {:error, {:invalid_value, tag, :DS, :expected_number_or_string_values}}}
    end)
    |> case do
      {:ok, decoded} -> {:ok, Enum.reverse(decoded) |> Enum.join("\\")}
      {:error, _} = error -> error
    end
  end

  defp decode_integer_string_values(tag, values) do
    Enum.reduce_while(values, {:ok, []}, fn
      value, {:ok, acc} when is_binary(value) ->
        if valid_json_string_numeric_value?(value, :IS) do
          {:cont, {:ok, [value | acc]}}
        else
          {:halt, {:error, {:invalid_value, tag, :IS, :expected_number_or_string_values}}}
        end

      value, {:ok, acc} when is_integer(value) ->
        {:cont, {:ok, [Integer.to_string(value) | acc]}}

      _value, _acc ->
        {:halt, {:error, {:invalid_value, tag, :IS, :expected_number_or_string_values}}}
    end)
    |> case do
      {:ok, decoded} -> {:ok, Enum.reverse(decoded) |> Enum.join("\\")}
      {:error, _} = error -> error
    end
  end

  defp encode_numeric_json_values(tag, vr, values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      try do
        encoded = Value.encode(value, vr)
        {:cont, {:ok, [encoded | acc]}}
      rescue
        ArgumentError ->
          {:halt, {:error, {:invalid_value, tag, vr, :expected_numeric_values}}}
      end
    end)
    |> case do
      {:ok, encoded} -> {:ok, encoded |> Enum.reverse() |> IO.iodata_to_binary()}
      {:error, _} = error -> error
    end
  end

  defp valid_json_string_numeric_value?(value, vr) when is_binary(value) do
    not String.contains?(value, "\\") and
      case Value.decode(value, vr) do
        decoded when is_binary(decoded) or is_list(decoded) -> false
        nil -> false
        _ -> true
      end
  end

  defp normalize_binary_value(_tag, binary, _opts), do: {:ok, binary}

  defp normalize_decoded_pixel_data(%DataSet{} = ds, opts) do
    transfer_syntax_uid =
      Keyword.get(opts, :transfer_syntax_uid) || TransferSyntax.extract_uid(ds.file_meta)

    case {transfer_syntax_uid, Map.get(ds.elements, {0x7FE0, 0x0010})} do
      {uid, %DataElement{vr: :OB, value: binary} = elem}
      when is_binary(uid) and is_binary(binary) ->
        if TransferSyntax.compressed?(uid) do
          case PixelData.parse_encapsulated_value_field(binary) do
            {:ok, fragments} ->
              normalized = %{elem | value: {:encapsulated, fragments}}
              {:ok, %{ds | elements: Map.put(ds.elements, {0x7FE0, 0x0010}, normalized)}}

            :error ->
              {:error, {:invalid_value, {0x7FE0, 0x0010}, :OB, :invalid_encapsulated_pixel_data}}
          end
        else
          {:ok, ds}
        end

      _ ->
        {:ok, ds}
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

  defp decode_charset_text!(value, vr, []) do
    if String.valid?(value) do
      value
    else
      case CharacterSet.decode(value, nil) do
        {:ok, decoded} ->
          decoded

        {:error, reason} ->
          raise ArgumentError, "invalid text value for VR #{vr}: #{inspect(reason)}"
      end
    end
  end

  defp decode_charset_text!(value, _vr, [_first, _second | _rest]) do
    if ascii_binary?(value) do
      value
    else
      raise ArgumentError, "multi-valued SpecificCharacterSet is not supported for JSON export"
    end
  end

  defp decode_charset_text!(value, vr, [charset]) do
    if preserve_utf8_value?(value, charset) do
      value
    else
      case CharacterSet.decode(value, charset) do
        {:ok, decoded} ->
          decoded

        {:error, reason} ->
          raise ArgumentError, "invalid text value for VR #{vr}: #{inspect(reason)}"
      end
    end
  end

  defp preserve_utf8_value?(value, _charset) when not is_binary(value), do: false

  defp preserve_utf8_value?(value, charset) do
    String.valid?(value) and
      case String.trim(charset) do
        "ISO_IR 13" -> not ascii_binary?(value)
        "ISO_IR 192" -> true
        "ISO_IR 6" -> ascii_binary?(value)
        "ISO 2022 IR 6" -> ascii_binary?(value)
        _ -> true
      end
  end

  defp ascii_binary?(value) when is_binary(value),
    do: Enum.all?(:binary.bin_to_list(value), &(&1 <= 0x7F))
end
