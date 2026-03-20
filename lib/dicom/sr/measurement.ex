defmodule Dicom.SR.Measurement do
  @moduledoc """
  A reusable numeric SR measurement.
  """

  alias Dicom.SR.{Code, ContentItem}

  @enforce_keys [:name, :value, :units]
  defstruct [:name, :value, :units, qualifier: nil, children: []]

  @type t :: %__MODULE__{
          name: Code.t(),
          value: number() | String.t(),
          units: Code.t(),
          qualifier: Code.t() | nil,
          children: [ContentItem.t()]
        }

  @spec new(Code.t(), number() | String.t(), Code.t(), keyword()) :: t()
  def new(%Code{} = name, value, %Code{} = units, opts \\ []) do
    %__MODULE__{
      name: name,
      value: value,
      units: units,
      qualifier: Keyword.get(opts, :qualifier),
      children: Keyword.get(opts, :children, [])
    }
  end

  @spec to_content_item(t()) :: ContentItem.t()
  def to_content_item(%__MODULE__{} = measurement) do
    ContentItem.num(measurement.name, measurement.value, measurement.units,
      relationship_type: "CONTAINS",
      qualifier: measurement.qualifier,
      children: measurement.children
    )
  end
end
