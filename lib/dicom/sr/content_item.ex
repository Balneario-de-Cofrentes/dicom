defmodule Dicom.SR.ContentItem do
  @moduledoc """
  A reusable SR content item with relationship and child content.
  """

  alias Dicom.{DataElement, Tag}
  alias Dicom.SR.Code

  @type value_type ::
          :container
          | :code
          | :text
          | :num
          | :uidref
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
  defp encode_value_type(:pname), do: "PNAME"

  defp normalize_numeric_value(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_numeric_value(value) when is_float(value) do
    value
    |> :erlang.float_to_binary(decimals: 12, compact: true)
    |> String.trim_trailing(".0")
  end

  defp normalize_numeric_value(value) when is_binary(value), do: value
end
