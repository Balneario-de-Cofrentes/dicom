defmodule Dicom.SR.Measurement do
  @moduledoc """
  A reusable numeric SR measurement.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Reference, Scoord2D}

  @enforce_keys [:name, :value, :units]
  defstruct [
    :name,
    :value,
    :units,
    qualifier: nil,
    children: [],
    source_images: [],
    finding_sites: [],
    source_regions: []
  ]

  @type t :: %__MODULE__{
          name: Code.t(),
          value: number() | String.t(),
          units: Code.t(),
          qualifier: Code.t() | nil,
          children: [ContentItem.t()],
          source_images: [Reference.t()],
          finding_sites: [Code.t()],
          source_regions: [Scoord2D.t()]
        }

  @spec new(Code.t(), number() | String.t(), Code.t(), keyword()) :: t()
  def new(%Code{} = name, value, %Code{} = units, opts \\ []) do
    %__MODULE__{
      name: name,
      value: value,
      units: units,
      qualifier: Keyword.get(opts, :qualifier),
      children: Keyword.get(opts, :children, []),
      source_images: Keyword.get(opts, :source_images, []),
      finding_sites: Keyword.get(opts, :finding_sites, []),
      source_regions: Keyword.get(opts, :source_regions, [])
    }
  end

  @spec to_content_item(t()) :: ContentItem.t()
  def to_content_item(%__MODULE__{} = measurement) do
    children =
      measurement.children ++
        Enum.map(measurement.finding_sites, fn site ->
          ContentItem.code(Codes.finding_site(), site, relationship_type: "HAS CONCEPT MOD")
        end) ++
        Enum.map(measurement.source_regions, fn region ->
          ContentItem.scoord(Codes.image_region(), region, relationship_type: "INFERRED FROM")
        end) ++
        Enum.map(measurement.source_images, fn reference ->
          ContentItem.image(Codes.source(), reference, relationship_type: "INFERRED FROM")
        end)

    ContentItem.num(measurement.name, measurement.value, measurement.units,
      relationship_type: "CONTAINS",
      qualifier: measurement.qualifier,
      children: children
    )
  end
end
