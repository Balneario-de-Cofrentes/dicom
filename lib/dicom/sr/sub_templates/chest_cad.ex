defmodule Dicom.SR.SubTemplates.ChestCAD do
  @moduledoc """
  Sub-templates for Chest CAD reports (TID 4101-4104).

  Covers:
  - TID 4101 Findings Summary
  - TID 4102 Composite Feature (grouping multiple single findings)
  - TID 4104 Single Image Finding (with spatial coords and confidence)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Scoord2D}

  @doc """
  TID 4101 -- Findings Summary.

  Returns a CONTAINER summarizing CAD processing results.

  Options:
  - `:findings` (required) -- list of String.t() or Code.t() findings
  """
  @spec findings_summary(keyword()) :: ContentItem.t()
  def findings_summary(opts) when is_list(opts) do
    findings = Keyword.fetch!(opts, :findings)

    children = map_findings(findings)

    ContentItem.container(Codes.findings_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4102 -- Composite Feature.

  Returns a CONTAINER grouping multiple single image findings that represent
  a single anatomical finding (e.g. a nodule visible across multiple images).

  Options:
  - `:tracking_id` (required) -- String.t() feature identifier
  - `:single_findings` (required) -- list of ContentItem.t() from `single_finding/1`
  """
  @spec composite_finding(keyword()) :: ContentItem.t()
  def composite_finding(opts) when is_list(opts) do
    tracking_id = Keyword.fetch!(opts, :tracking_id)
    single_findings = Keyword.fetch!(opts, :single_findings)

    children =
      [
        ContentItem.text(Codes.tracking_identifier(), tracking_id,
          relationship_type: "HAS OBS CONTEXT"
        )
      ] ++ single_findings

    ContentItem.container(Codes.composite_feature(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4104 -- Single Image Finding.

  Returns a CONTAINER for a single finding in one image, with optional
  spatial coordinates, confidence, and rendering intent.

  Options:
  - `:finding_type` (required) -- Code.t() (nodule, mass, lung_opacity, etc.)
  - `:scoord` (optional) -- Scoord2D.t() spatial coordinates
  - `:probability` (optional) -- number() probability of malignancy (0-100)
  - `:rendering_intent` (optional) -- :required | :not_for_presentation
  """
  @spec single_finding(keyword()) :: ContentItem.t()
  def single_finding(opts) when is_list(opts) do
    finding_type = Keyword.fetch!(opts, :finding_type)

    children =
      [
        ContentItem.code(Codes.finding(), finding_type, relationship_type: "CONTAINS")
      ]
      |> maybe_add_scoord(opts[:scoord])
      |> maybe_add_probability(opts[:probability])
      |> maybe_add_rendering_intent(opts[:rendering_intent])

    ContentItem.container(Codes.single_image_finding(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Private Helpers --

  defp map_findings(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  defp maybe_add_scoord(items, nil), do: items

  defp maybe_add_scoord(items, %Scoord2D{} = scoord) do
    items ++ [ContentItem.scoord(Codes.image_region(), scoord, relationship_type: "CONTAINS")]
  end

  defp maybe_add_probability(items, nil), do: items

  defp maybe_add_probability(items, probability) when is_number(probability) do
    items ++
      [
        ContentItem.num(
          Codes.probability_of_malignancy(),
          probability,
          Codes.percent(),
          relationship_type: "CONTAINS"
        )
      ]
  end

  defp maybe_add_rendering_intent(items, nil), do: items

  defp maybe_add_rendering_intent(items, :required) do
    items ++
      [
        ContentItem.code(Codes.rendering_intent(), Codes.presentation_required(),
          relationship_type: "CONTAINS"
        )
      ]
  end

  defp maybe_add_rendering_intent(items, :not_for_presentation) do
    items ++
      [
        ContentItem.code(Codes.rendering_intent(), Codes.not_for_presentation(),
          relationship_type: "CONTAINS"
        )
      ]
  end
end
