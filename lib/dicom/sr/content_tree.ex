defmodule Dicom.SR.ContentTree do
  @moduledoc """
  Reconstructs a `Dicom.SR.ContentItem` tree from a parsed `Dicom.DataSet`.

  This module provides the read (deserialization) path for SR documents,
  complementing the write path in `Dicom.SR.ContentItem.to_root_elements/1`
  and `Dicom.SR.Document.to_data_set/1`.

  ## Usage

      {:ok, data_set} = Dicom.parse(p10_binary)
      {:ok, root} = Dicom.SR.ContentTree.from_data_set(data_set)
      root.value_type  #=> :container
      root.children    #=> [%ContentItem{}, ...]

  Reference: DICOM PS3.3 Section C.17.3 (SR Document Content Module).
  """

  alias Dicom.{DataSet, Tag, Value}
  alias Dicom.SR.{Code, ContentItem, Reference, Scoord2D, Scoord3D}

  @doc """
  Reconstructs the root `ContentItem` tree from a parsed DICOM SR data set.

  The data set must contain at least a Value Type (0040,A040) and
  Concept Name Code Sequence (0040,A043) at the top level. Child items
  are recursively extracted from the Content Sequence (0040,A730).

  Returns `{:ok, root_item}` on success, or `{:error, reason}` if
  required attributes are missing or malformed.
  """
  @spec from_data_set(DataSet.t()) :: {:ok, ContentItem.t()} | {:error, term()}
  def from_data_set(%DataSet{} = ds) do
    with {:ok, value_type} <- extract_value_type(ds),
         {:ok, concept_name} <- extract_concept_name(ds) do
      item = build_item(value_type, concept_name, nil, ds)
      {:ok, item}
    end
  end

  @doc """
  Reconstructs a `ContentItem` tree from a sequence item map.

  Sequence items are represented as maps of `{group, element} => DataElement`
  after parsing. This function is used internally to process Content Sequence
  children and can also be used directly when working with raw sequence items.
  """
  @spec from_sequence_item(map()) :: {:ok, ContentItem.t()} | {:error, term()}
  def from_sequence_item(item) when is_map(item) do
    with {:ok, value_type} <- extract_value_type_from_item(item),
         {:ok, concept_name} <- extract_concept_name_from_item(item) do
      relationship_type = get_item_value(item, Tag.relationship_type())
      {:ok, build_item(value_type, concept_name, relationship_type, item)}
    end
  end

  # -- Value Type Extraction --------------------------------------------------

  defp extract_value_type(%DataSet{} = ds) do
    case DataSet.get(ds, Tag.value_type()) do
      nil -> {:error, :missing_value_type}
      raw -> decode_value_type(raw)
    end
  end

  defp extract_value_type_from_item(item) do
    case get_item_value(item, Tag.value_type()) do
      nil -> {:error, :missing_value_type}
      raw -> decode_value_type(raw)
    end
  end

  defp decode_value_type(raw) when is_binary(raw) do
    case String.trim(raw) do
      "CONTAINER" -> {:ok, :container}
      "CODE" -> {:ok, :code}
      "TEXT" -> {:ok, :text}
      "NUM" -> {:ok, :num}
      "UIDREF" -> {:ok, :uidref}
      "IMAGE" -> {:ok, :image}
      "COMPOSITE" -> {:ok, :composite}
      "SCOORD" -> {:ok, :scoord}
      "SCOORD3D" -> {:ok, :scoord3d}
      "DATE" -> {:ok, :date}
      "TIME" -> {:ok, :time}
      "DATETIME" -> {:ok, :datetime}
      "PNAME" -> {:ok, :pname}
      other -> {:error, {:unsupported_value_type, other}}
    end
  end

  # -- Concept Name Extraction ------------------------------------------------

  defp extract_concept_name(%DataSet{} = ds) do
    case DataSet.get(ds, Tag.concept_name_code_sequence()) do
      [item | _] -> code_from_item(item)
      _ -> {:error, :missing_concept_name}
    end
  end

  defp extract_concept_name_from_item(item) do
    case get_item_value(item, Tag.concept_name_code_sequence()) do
      [code_item | _] -> code_from_item(code_item)
      _ -> {:error, :missing_concept_name}
    end
  end

  # -- Item Building ----------------------------------------------------------

  defp build_item(:container, concept_name, relationship_type, source) do
    continuity = get_value(source, Tag.continuity_of_content())
    children = extract_children(source)

    %ContentItem{
      value_type: :container,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      continuity_of_content: trim_or_nil(continuity),
      children: children
    }
  end

  defp build_item(:text, concept_name, relationship_type, source) do
    text_value = get_value(source, Tag.text_value())

    %ContentItem{
      value_type: :text,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: trim_or_nil(text_value),
      children: extract_children(source)
    }
  end

  defp build_item(:code, concept_name, relationship_type, source) do
    code_value = extract_code_value(source)

    %ContentItem{
      value_type: :code,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: code_value,
      children: extract_children(source)
    }
  end

  defp build_item(:num, concept_name, relationship_type, source) do
    num_value = extract_numeric_value(source)

    %ContentItem{
      value_type: :num,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: num_value,
      children: extract_children(source)
    }
  end

  defp build_item(:uidref, concept_name, relationship_type, source) do
    uid = get_value(source, Tag.uid_value())

    %ContentItem{
      value_type: :uidref,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: trim_uid(uid),
      children: extract_children(source)
    }
  end

  defp build_item(:image, concept_name, relationship_type, source) do
    reference = extract_reference(source)

    %ContentItem{
      value_type: :image,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: reference,
      children: extract_children(source)
    }
  end

  defp build_item(:composite, concept_name, relationship_type, source) do
    reference = extract_reference(source)

    %ContentItem{
      value_type: :composite,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: reference,
      children: extract_children(source)
    }
  end

  defp build_item(:scoord, concept_name, relationship_type, source) do
    scoord = extract_scoord(source)

    %ContentItem{
      value_type: :scoord,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: scoord,
      children: extract_children(source)
    }
  end

  defp build_item(:scoord3d, concept_name, relationship_type, source) do
    scoord3d = extract_scoord3d(source)

    %ContentItem{
      value_type: :scoord3d,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: scoord3d,
      children: extract_children(source)
    }
  end

  defp build_item(:date, concept_name, relationship_type, source) do
    date_value = get_value(source, Tag.sr_date())

    %ContentItem{
      value_type: :date,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: trim_or_nil(date_value),
      children: extract_children(source)
    }
  end

  defp build_item(:time, concept_name, relationship_type, source) do
    time_value = get_value(source, Tag.sr_time())

    %ContentItem{
      value_type: :time,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: trim_or_nil(time_value),
      children: extract_children(source)
    }
  end

  defp build_item(:datetime, concept_name, relationship_type, source) do
    dt_value = get_value(source, Tag.sr_datetime())

    %ContentItem{
      value_type: :datetime,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: trim_or_nil(dt_value),
      children: extract_children(source)
    }
  end

  defp build_item(:pname, concept_name, relationship_type, source) do
    person_name = get_value(source, Tag.person_name_value())

    %ContentItem{
      value_type: :pname,
      concept_name: concept_name,
      relationship_type: trim_or_nil(relationship_type),
      value: trim_or_nil(person_name),
      children: extract_children(source)
    }
  end

  # -- Children Extraction ----------------------------------------------------

  defp extract_children(%DataSet{} = ds) do
    case DataSet.get(ds, Tag.content_sequence()) do
      items when is_list(items) -> Enum.map(items, &item_to_content_item/1)
      _ -> []
    end
  end

  defp extract_children(item) when is_map(item) do
    case get_item_value(item, Tag.content_sequence()) do
      items when is_list(items) -> Enum.map(items, &item_to_content_item/1)
      _ -> []
    end
  end

  defp item_to_content_item(item) do
    {:ok, content_item} = from_sequence_item(item)
    content_item
  end

  # -- Code Extraction --------------------------------------------------------

  @spec code_from_item(map()) :: {:ok, Code.t()} | {:error, term()}
  defp code_from_item(item) when is_map(item) do
    value = get_item_value(item, Tag.code_value())
    scheme = get_item_value(item, Tag.coding_scheme_designator())
    meaning = get_item_value(item, Tag.code_meaning())

    case {trim_or_nil(value), trim_or_nil(scheme), trim_or_nil(meaning)} do
      {nil, _, _} ->
        {:error, :missing_code_value}

      {_, nil, _} ->
        {:error, :missing_coding_scheme_designator}

      {_, _, nil} ->
        {:error, :missing_code_meaning}

      {v, s, m} ->
        version = trim_or_nil(get_item_value(item, Tag.coding_scheme_version()))
        opts = if version, do: [scheme_version: version], else: []
        {:ok, Code.new(v, s, m, opts)}
    end
  end

  defp extract_code_value(source) do
    case get_sequence(source, Tag.concept_code_sequence()) do
      [item | _] ->
        {:ok, code} = code_from_item(item)
        code

      _ ->
        nil
    end
  end

  # -- Numeric Value Extraction -----------------------------------------------

  defp extract_numeric_value(source) do
    case get_sequence(source, Tag.measured_value_sequence()) do
      [mv_item | _] ->
        numeric_value = trim_or_nil(get_item_value(mv_item, Tag.numeric_value()))
        units = extract_units(mv_item)
        qualifier = extract_qualifier(mv_item)

        %{numeric_value: numeric_value, units: units, qualifier: qualifier}

      _ ->
        nil
    end
  end

  defp extract_units(mv_item) do
    case get_item_value(mv_item, Tag.measurement_units_code_sequence()) do
      [units_item | _] ->
        {:ok, code} = code_from_item(units_item)
        code

      _ ->
        nil
    end
  end

  defp extract_qualifier(source) do
    case get_sequence(source, Tag.numeric_value_qualifier_code_sequence()) do
      [item | _] ->
        {:ok, code} = code_from_item(item)
        code

      _ ->
        nil
    end
  end

  # -- Reference Extraction ---------------------------------------------------

  defp extract_reference(source) do
    case get_sequence(source, Tag.referenced_sop_sequence()) do
      [ref_item | _] ->
        sop_class_uid = trim_uid(get_item_value(ref_item, Tag.referenced_sop_class_uid()))
        sop_instance_uid = trim_uid(get_item_value(ref_item, Tag.referenced_sop_instance_uid()))
        frame_numbers = extract_frame_numbers(ref_item)
        segment_numbers = extract_segment_numbers(ref_item)
        purpose = extract_purpose(source)

        Reference.new(sop_class_uid, sop_instance_uid,
          frame_numbers: frame_numbers,
          segment_numbers: segment_numbers,
          purpose: purpose
        )

      _ ->
        nil
    end
  end

  defp extract_frame_numbers(ref_item) do
    case get_item_value(ref_item, Tag.referenced_frame_number()) do
      nil -> []
      value when is_binary(value) -> parse_integer_string(value)
      value when is_integer(value) -> [value]
      values when is_list(values) -> values
    end
  end

  defp parse_integer_string(value) do
    value
    |> String.split("\\")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.to_integer/1)
  end

  defp extract_segment_numbers(ref_item) do
    case get_item_value(ref_item, Tag.referenced_segment_number()) do
      nil -> []
      value when is_integer(value) -> [value]
      values when is_list(values) -> values
      value when is_binary(value) -> decode_us(value)
    end
  end

  defp decode_us(binary) when rem(byte_size(binary), 2) == 0 do
    case Value.decode(binary, :US) do
      value when is_integer(value) -> [value]
      values when is_list(values) -> values
    end
  end

  defp extract_purpose(source) do
    case get_sequence(source, Tag.purpose_of_reference_code_sequence()) do
      [item | _] ->
        {:ok, code} = code_from_item(item)
        code

      _ ->
        nil
    end
  end

  # -- SCOORD Extraction ------------------------------------------------------

  defp extract_scoord(source) do
    graphic_type = trim_or_nil(get_value(source, Tag.graphic_type()))
    graphic_data = extract_graphic_data(source)
    reference = extract_reference(source)

    Scoord2D.new(reference, graphic_type, graphic_data)
  end

  defp extract_graphic_data(source) do
    case get_value(source, Tag.graphic_data()) do
      values when is_list(values) -> values
      value when is_binary(value) -> decode_fl(value)
      nil -> []
    end
  end

  defp decode_fl(binary) when rem(byte_size(binary), 4) == 0 do
    case Value.decode(binary, :FL) do
      values when is_list(values) -> values
      value when is_number(value) -> [value]
    end
  end

  # -- SCOORD3D Extraction ----------------------------------------------------

  defp extract_scoord3d(source) do
    graphic_type = trim_or_nil(get_value(source, Tag.graphic_type()))
    graphic_data = extract_graphic_data_fd(source)

    frame_of_reference_uid =
      trim_uid(get_value(source, Tag.referenced_frame_of_reference_uid()) || "")

    Scoord3D.new(graphic_type, graphic_data, frame_of_reference_uid)
  end

  defp extract_graphic_data_fd(source) do
    case get_value(source, Tag.graphic_data()) do
      values when is_list(values) -> values
      value when is_binary(value) -> decode_fd(value)
      nil -> []
    end
  end

  defp decode_fd(binary) when rem(byte_size(binary), 8) == 0 do
    case Value.decode(binary, :FD) do
      values when is_list(values) -> values
      value when is_number(value) -> [value]
    end
  end

  # -- Value Access Helpers ---------------------------------------------------

  defp get_value(%DataSet{} = ds, tag), do: DataSet.get(ds, tag)
  defp get_value(item, tag) when is_map(item), do: get_item_value(item, tag)

  defp get_item_value(item, tag) when is_map(item) do
    case Map.get(item, tag) do
      %{value: value} -> value
      _ -> nil
    end
  end

  defp get_sequence(%DataSet{} = ds, tag) do
    case DataSet.get(ds, tag) do
      items when is_list(items) -> items
      _ -> nil
    end
  end

  defp get_sequence(item, tag) when is_map(item) do
    case get_item_value(item, tag) do
      items when is_list(items) -> items
      _ -> nil
    end
  end

  defp trim_or_nil(nil), do: nil
  defp trim_or_nil(value) when is_binary(value), do: String.trim(value)

  # UIDs may contain trailing null bytes (0x00) after parsing from P10 binary.
  # This trims both null bytes and spaces to produce a clean UID string.
  defp trim_uid(value) when is_binary(value) do
    value
    |> String.trim_trailing(<<0>>)
    |> String.trim()
  end
end
