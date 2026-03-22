defmodule Dicom.SR.ContentItem do
  @moduledoc """
  A reusable SR content item with relationship and child content.
  """

  alias Dicom.{DataElement, Tag, Value}
  alias Dicom.SR.{Code, Reference, Scoord2D, Scoord3D, Tcoord}

  @type value_type ::
          :container
          | :code
          | :text
          | :num
          | :uidref
          | :image
          | :composite
          | :scoord
          | :scoord3d
          | :tcoord
          | :date
          | :time
          | :datetime
          | :pname

  @type t :: %__MODULE__{
          value_type: value_type(),
          concept_name: Code.t(),
          relationship_type: String.t() | nil,
          value: term(),
          children: [t()],
          continuity_of_content: String.t() | nil
        }

  @enforce_keys [:value_type, :concept_name]
  defstruct [
    :value_type,
    :concept_name,
    :relationship_type,
    :value,
    children: [],
    continuity_of_content: nil
  ]

  @spec container(Code.t(), keyword()) :: t()
  def container(%Code{} = concept_name, opts \\ []) do
    %__MODULE__{
      value_type: :container,
      concept_name: concept_name,
      relationship_type: Keyword.get(opts, :relationship_type),
      continuity_of_content: Keyword.get(opts, :continuity_of_content, "SEPARATE"),
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec code(Code.t(), Code.t(), keyword()) :: t()
  def code(%Code{} = concept_name, %Code{} = value, opts \\ []) do
    %__MODULE__{
      value_type: :code,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec text(Code.t(), String.t(), keyword()) :: t()
  def text(%Code{} = concept_name, value, opts \\ [])
      when is_binary(value) do
    %__MODULE__{
      value_type: :text,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec num(Code.t(), number() | String.t(), Code.t(), keyword()) :: t()
  def num(%Code{} = concept_name, value, %Code{} = units, opts \\ []) do
    %__MODULE__{
      value_type: :num,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: %{
        numeric_value: normalize_numeric_value(value),
        units: units,
        qualifier: Keyword.get(opts, :qualifier)
      },
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec uidref(Code.t(), String.t(), keyword()) :: t()
  def uidref(%Code{} = concept_name, value, opts \\ [])
      when is_binary(value) do
    %__MODULE__{
      value_type: :uidref,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec image(Code.t(), Reference.t(), keyword()) :: t()
  def image(%Code{} = concept_name, %Reference{} = value, opts \\ []) do
    %__MODULE__{
      value_type: :image,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec composite(Code.t(), Reference.t(), keyword()) :: t()
  def composite(%Code{} = concept_name, %Reference{} = value, opts \\ []) do
    %__MODULE__{
      value_type: :composite,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec scoord(Code.t(), Scoord2D.t(), keyword()) :: t()
  def scoord(%Code{} = concept_name, %Scoord2D{} = value, opts \\ []) do
    %__MODULE__{
      value_type: :scoord,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec scoord3d(Code.t(), Scoord3D.t(), keyword()) :: t()
  def scoord3d(%Code{} = concept_name, %Scoord3D{} = value, opts \\ []) do
    %__MODULE__{
      value_type: :scoord3d,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec tcoord(Code.t(), Tcoord.t(), keyword()) :: t()
  def tcoord(%Code{} = concept_name, %Tcoord{} = value, opts \\ []) do
    %__MODULE__{
      value_type: :tcoord,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec date(Code.t(), Date.t() | String.t(), keyword()) :: t()
  def date(%Code{} = concept_name, value, opts \\ []) do
    %__MODULE__{
      value_type: :date,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: normalize_date(value),
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec time(Code.t(), Time.t() | String.t(), keyword()) :: t()
  def time(%Code{} = concept_name, value, opts \\ []) do
    %__MODULE__{
      value_type: :time,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: normalize_time(value),
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec datetime(Code.t(), DateTime.t() | NaiveDateTime.t() | String.t(), keyword()) :: t()
  def datetime(%Code{} = concept_name, value, opts \\ []) do
    %__MODULE__{
      value_type: :datetime,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: normalize_datetime(value),
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec pname(Code.t(), String.t(), keyword()) :: t()
  def pname(%Code{} = concept_name, value, opts \\ [])
      when is_binary(value) do
    %__MODULE__{
      value_type: :pname,
      concept_name: concept_name,
      relationship_type: Keyword.fetch!(opts, :relationship_type),
      value: value,
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec to_item(t()) :: map()
  def to_item(%__MODULE__{} = item) do
    encode_item(item, false)
  end

  @spec to_root_elements(t()) :: map()
  def to_root_elements(%__MODULE__{} = item) do
    encode_item(item, true)
  end

  defp encode_item(%__MODULE__{children: children} = item, root?) when is_list(children) do
    base =
      %{
        Tag.value_type() =>
          DataElement.new(Tag.value_type(), :CS, encode_value_type(item.value_type)),
        Tag.concept_name_code_sequence() =>
          DataElement.new(Tag.concept_name_code_sequence(), :SQ, [Code.to_item(item.concept_name)])
      }
      |> maybe_put_relationship(item.relationship_type, root?)
      |> put_value(item)

    if children == [] do
      base
    else
      Map.put(
        base,
        Tag.content_sequence(),
        DataElement.new(Tag.content_sequence(), :SQ, Enum.map(children, &to_item/1))
      )
    end
  end

  defp maybe_put_relationship(base, nil, true), do: base

  defp maybe_put_relationship(_base, nil, false) do
    raise ArgumentError, "non-root SR content items require a relationship_type"
  end

  defp maybe_put_relationship(base, relationship_type, _root?) do
    Map.put(
      base,
      Tag.relationship_type(),
      DataElement.new(Tag.relationship_type(), :CS, relationship_type)
    )
  end

  defp put_value(base, %__MODULE__{value_type: :container, continuity_of_content: continuity}) do
    Map.put(
      base,
      Tag.continuity_of_content(),
      DataElement.new(Tag.continuity_of_content(), :CS, continuity || "SEPARATE")
    )
  end

  defp put_value(base, %__MODULE__{value_type: :code, value: %Code{} = code}) do
    Map.put(
      base,
      Tag.concept_code_sequence(),
      DataElement.new(Tag.concept_code_sequence(), :SQ, [Code.to_item(code)])
    )
  end

  defp put_value(base, %__MODULE__{value_type: :text, value: text}) do
    Map.put(base, Tag.text_value(), DataElement.new(Tag.text_value(), :UT, text))
  end

  defp put_value(base, %__MODULE__{value_type: :uidref, value: uid}) do
    Map.put(base, Tag.uid_value(), DataElement.new(Tag.uid_value(), :UI, uid))
  end

  defp put_value(base, %__MODULE__{value_type: value_type, value: %Reference{} = reference})
       when value_type in [:image, :composite] do
    base
    |> Map.put(
      Tag.referenced_sop_sequence(),
      DataElement.new(Tag.referenced_sop_sequence(), :SQ, [reference_item(reference)])
    )
    |> maybe_put_reference_purpose(reference.purpose)
  end

  defp put_value(base, %__MODULE__{value_type: :scoord, value: %Scoord2D{} = scoord}) do
    base
    |> Map.put(
      Tag.graphic_type(),
      DataElement.new(Tag.graphic_type(), :CS, scoord.graphic_type)
    )
    |> Map.put(
      Tag.graphic_data(),
      DataElement.new(Tag.graphic_data(), :FL, scoord.graphic_data)
    )
    |> Map.put(
      Tag.referenced_sop_sequence(),
      DataElement.new(Tag.referenced_sop_sequence(), :SQ, [reference_item(scoord.reference)])
    )
    |> maybe_put_reference_purpose(scoord.reference.purpose)
  end

  defp put_value(base, %__MODULE__{value_type: :scoord3d, value: %Scoord3D{} = scoord3d}) do
    base
    |> Map.put(
      Tag.graphic_type(),
      DataElement.new(Tag.graphic_type(), :CS, scoord3d.graphic_type)
    )
    |> Map.put(
      Tag.graphic_data(),
      DataElement.new(Tag.graphic_data(), :FD, scoord3d.graphic_data)
    )
    |> Map.put(
      Tag.referenced_frame_of_reference_uid(),
      DataElement.new(
        Tag.referenced_frame_of_reference_uid(),
        :UI,
        scoord3d.frame_of_reference_uid
      )
    )
  end

  defp put_value(base, %__MODULE__{value_type: :tcoord, value: %Tcoord{} = tcoord}) do
    base
    |> Map.put(
      Tag.temporal_range_type(),
      DataElement.new(Tag.temporal_range_type(), :CS, tcoord.temporal_range_type)
    )
    |> put_tcoord_reference(tcoord)
  end

  defp put_value(base, %__MODULE__{value_type: :date, value: date_str}) do
    Map.put(base, Tag.sr_date(), DataElement.new(Tag.sr_date(), :DA, date_str))
  end

  defp put_value(base, %__MODULE__{value_type: :time, value: time_str}) do
    Map.put(base, Tag.sr_time(), DataElement.new(Tag.sr_time(), :TM, time_str))
  end

  defp put_value(base, %__MODULE__{value_type: :datetime, value: dt_str}) do
    Map.put(base, Tag.sr_datetime(), DataElement.new(Tag.sr_datetime(), :DT, dt_str))
  end

  defp put_value(base, %__MODULE__{value_type: :pname, value: person_name}) do
    Map.put(
      base,
      Tag.person_name_value(),
      DataElement.new(Tag.person_name_value(), :PN, person_name)
    )
  end

  defp put_value(base, %__MODULE__{value_type: :num, value: value}) do
    measurement_item =
      %{
        Tag.numeric_value() => DataElement.new(Tag.numeric_value(), :DS, value.numeric_value),
        Tag.measurement_units_code_sequence() =>
          DataElement.new(
            Tag.measurement_units_code_sequence(),
            :SQ,
            [Code.to_item(value.units)]
          )
      }
      |> maybe_put_numeric_qualifier(value.qualifier)

    Map.put(
      base,
      Tag.measured_value_sequence(),
      DataElement.new(Tag.measured_value_sequence(), :SQ, [measurement_item])
    )
  end

  defp maybe_put_numeric_qualifier(base, nil), do: base

  defp maybe_put_numeric_qualifier(base, %Code{} = qualifier) do
    Map.put(
      base,
      Tag.numeric_value_qualifier_code_sequence(),
      DataElement.new(
        Tag.numeric_value_qualifier_code_sequence(),
        :SQ,
        [Code.to_item(qualifier)]
      )
    )
  end

  defp encode_value_type(:container), do: "CONTAINER"
  defp encode_value_type(:code), do: "CODE"
  defp encode_value_type(:text), do: "TEXT"
  defp encode_value_type(:num), do: "NUM"
  defp encode_value_type(:uidref), do: "UIDREF"
  defp encode_value_type(:image), do: "IMAGE"
  defp encode_value_type(:composite), do: "COMPOSITE"
  defp encode_value_type(:scoord), do: "SCOORD"
  defp encode_value_type(:scoord3d), do: "SCOORD3D"
  defp encode_value_type(:tcoord), do: "TCOORD"
  defp encode_value_type(:date), do: "DATE"
  defp encode_value_type(:time), do: "TIME"
  defp encode_value_type(:datetime), do: "DATETIME"
  defp encode_value_type(:pname), do: "PNAME"

  defp maybe_put_reference_purpose(base, nil), do: base

  defp maybe_put_reference_purpose(base, %Code{} = purpose) do
    Map.put(
      base,
      Tag.purpose_of_reference_code_sequence(),
      DataElement.new(Tag.purpose_of_reference_code_sequence(), :SQ, [Code.to_item(purpose)])
    )
  end

  defp reference_item(%Reference{} = reference) do
    %{
      Tag.referenced_sop_class_uid() =>
        DataElement.new(Tag.referenced_sop_class_uid(), :UI, reference.sop_class_uid),
      Tag.referenced_sop_instance_uid() =>
        DataElement.new(Tag.referenced_sop_instance_uid(), :UI, reference.sop_instance_uid)
    }
    |> maybe_put_reference_frames(reference.frame_numbers)
    |> maybe_put_reference_segments(reference.segment_numbers)
  end

  defp maybe_put_reference_frames(item, []), do: item

  defp maybe_put_reference_frames(item, frame_numbers) do
    Map.put(
      item,
      Tag.referenced_frame_number(),
      DataElement.new(
        Tag.referenced_frame_number(),
        :IS,
        Enum.map_join(frame_numbers, "\\", &Integer.to_string/1)
      )
    )
  end

  defp maybe_put_reference_segments(item, []), do: item

  defp maybe_put_reference_segments(item, segment_numbers) do
    Map.put(
      item,
      Tag.referenced_segment_number(),
      DataElement.new(Tag.referenced_segment_number(), :US, segment_numbers)
    )
  end

  defp normalize_numeric_value(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_numeric_value(value) when is_float(value) do
    value
    |> :erlang.float_to_binary([:compact, decimals: 12])
    |> String.trim_trailing(".0")
  end

  defp normalize_numeric_value(value) when is_binary(value), do: value

  defp put_tcoord_reference(base, %Tcoord{sample_positions: positions})
       when positions != [] do
    Map.put(
      base,
      Tag.referenced_sample_positions(),
      DataElement.new(Tag.referenced_sample_positions(), :UL, positions)
    )
  end

  defp put_tcoord_reference(base, %Tcoord{time_offsets: offsets})
       when offsets != [] do
    Map.put(
      base,
      Tag.referenced_time_offsets(),
      DataElement.new(
        Tag.referenced_time_offsets(),
        :DS,
        Enum.map_join(offsets, "\\", &to_string/1)
      )
    )
  end

  defp put_tcoord_reference(base, %Tcoord{datetime_values: datetimes})
       when datetimes != [] do
    Map.put(
      base,
      Tag.referenced_datetime(),
      DataElement.new(Tag.referenced_datetime(), :DT, Enum.join(datetimes, "\\"))
    )
  end

  defp normalize_date(%Date{} = date), do: Value.from_date(date)
  defp normalize_date(value) when is_binary(value), do: value

  defp normalize_time(%Time{} = time), do: Value.from_time(time)
  defp normalize_time(value) when is_binary(value), do: value

  defp normalize_datetime(%DateTime{} = dt), do: Value.from_datetime(dt)
  defp normalize_datetime(%NaiveDateTime{} = ndt), do: Value.from_datetime(ndt)
  defp normalize_datetime(value) when is_binary(value), do: value
end
