defmodule Dicom.SR.MeasurementGroup do
  @moduledoc """
  A measurement group suitable for TID 1500-style content trees.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement, Reference}

  @enforce_keys [:tracking_id, :tracking_uid]
  defstruct [
    :tracking_id,
    :tracking_uid,
    :activity_session,
    :finding_category,
    finding_sites: [],
    source_images: [],
    measurements: [],
    qualitative_evaluations: []
  ]

  @type t :: %__MODULE__{
          tracking_id: String.t(),
          tracking_uid: String.t(),
          activity_session: String.t() | nil,
          finding_category: Code.t() | nil,
          finding_sites: [Code.t()],
          source_images: [Reference.t()],
          measurements: [Measurement.t()],
          qualitative_evaluations: [ContentItem.t()]
        }

  @spec new(String.t(), String.t(), keyword()) :: t()
  def new(tracking_id, tracking_uid, opts \\ [])
      when is_binary(tracking_id) and is_binary(tracking_uid) do
    %__MODULE__{
      tracking_id: tracking_id,
      tracking_uid: tracking_uid,
      activity_session: Keyword.get(opts, :activity_session),
      finding_category: Keyword.get(opts, :finding_category),
      finding_sites: Keyword.get(opts, :finding_sites, []),
      source_images: Keyword.get(opts, :source_images, []),
      measurements: Keyword.get(opts, :measurements, []),
      qualitative_evaluations: Keyword.get(opts, :qualitative_evaluations, [])
    }
  end

  @spec to_content_item(t()) :: ContentItem.t()
  def to_content_item(%__MODULE__{} = group) do
    children =
      []
      |> maybe_add_activity_session(group.activity_session)
      |> Kernel.++([
        ContentItem.text(Codes.tracking_identifier(), group.tracking_id,
          relationship_type: "HAS OBS CONTEXT"
        ),
        ContentItem.uidref(Codes.tracking_unique_identifier(), group.tracking_uid,
          relationship_type: "HAS OBS CONTEXT"
        )
      ])
      |> maybe_add_finding_category(group.finding_category)
      |> Kernel.++(Enum.map(group.finding_sites, &finding_site_item/1))
      |> Kernel.++(Enum.map(group.source_images, &source_image_item/1))
      |> Kernel.++(Enum.map(group.measurements, &Measurement.to_content_item/1))
      |> Kernel.++(group.qualitative_evaluations)

    ContentItem.container(Codes.measurement_group(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp maybe_add_activity_session(items, nil), do: items

  defp maybe_add_activity_session(items, activity_session) do
    items ++
      [
        ContentItem.text(Codes.activity_session(), activity_session,
          relationship_type: "HAS OBS CONTEXT"
        )
      ]
  end

  defp maybe_add_finding_category(items, nil), do: items

  defp maybe_add_finding_category(items, %Code{} = finding_category) do
    items ++
      [
        ContentItem.code(Codes.finding_category(), finding_category,
          relationship_type: "CONTAINS"
        )
      ]
  end

  defp finding_site_item(%Code{} = finding_site) do
    ContentItem.code(Codes.finding_site(), finding_site, relationship_type: "HAS CONCEPT MOD")
  end

  defp source_image_item(%Reference{} = reference) do
    ContentItem.image(Codes.source(), reference, relationship_type: "CONTAINS")
  end
end
