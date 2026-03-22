defmodule Dicom.SR.Templates.ChestCAD do
  @moduledoc """
  Builder for a practical TID 4100 Chest CAD Document Root.

  Implements the top-level structure for Computer-Aided Detection results in
  chest radiography. The builder covers the root container, device observer
  context, image library, findings summary, and individual findings with
  spatial coordinates and confidence scores.

  Structure:

      CONTAINER: Chest CAD Report (root)
        +-- HAS CONCEPT MOD: Language (optional, defaults to en-US)
        +-- HAS OBS CONTEXT: Device Observer (required: uid, name)
        +-- CONTAINS: Image Library (optional)
        +-- CONTAINS: Findings Summary (TID 4101)
        +-- CONTAINS: Composite Feature (TID 4102, 0-n)
        +-- CONTAINS: Single Image Finding (TID 4104, 0-n)
        |     +-- finding type (nodule, mass, etc.)
        |     +-- spatial coordinates
        |     +-- confidence score

  SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.65 (Chest CAD SR Storage)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, ImageLibrary, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    device_observer = Keyword.fetch!(opts, :device_observer)
    findings_summary = Keyword.get(opts, :findings_summary, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(device_observer_items(device_observer))
      |> add_optional(optional_image_library(Keyword.get(opts, :image_library, [])))
      |> add_optional(optional_wrap(build_findings_summary(findings_summary)))
      |> add_optional(build_findings(Keyword.get(opts, :findings, [])))

    root = ContentItem.container(Codes.chest_cad_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "4100",
        sop_class_uid: Dicom.UID.chest_cad_sr_storage(),
        series_description: Keyword.get(opts, :series_description, "Chest CAD Report")
      )
    )
  end

  defp device_observer_items(device_opts) when is_list(device_opts) do
    Observer.device(device_opts)
  end

  defp device_observer_items(%{} = device_opts) do
    Observer.device(
      uid: Map.fetch!(device_opts, :uid),
      name: Map.get(device_opts, :name),
      manufacturer: Map.get(device_opts, :manufacturer),
      model_name: Map.get(device_opts, :model_name),
      serial_number: Map.get(device_opts, :serial_number)
    )
  end

  defp optional_image_library([]), do: nil

  defp optional_image_library(references) do
    ImageLibrary.build(references)
  end

  defp build_findings_summary([]), do: nil

  defp build_findings_summary(summary_items) do
    children =
      Enum.map(summary_items, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.findings_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp build_findings([]), do: []

  defp build_findings(findings) do
    Enum.map(findings, &build_finding_container/1)
  end

  defp build_finding_container(finding) when is_map(finding) do
    children =
      []
      |> add_optional(build_finding_type(finding))
      |> add_optional(build_spatial_coords(finding))
      |> add_optional(build_probability(finding))
      |> add_optional(build_rendering_intent(finding))

    case Map.get(finding, :type) do
      :composite ->
        ContentItem.container(Codes.composite_feature(),
          relationship_type: "CONTAINS",
          children: children
        )

      _single ->
        ContentItem.container(Codes.single_image_finding(),
          relationship_type: "CONTAINS",
          children: children
        )
    end
  end

  defp build_finding_type(%{finding: %Code{} = code}) do
    ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")
  end

  defp build_finding_type(_), do: nil

  defp build_spatial_coords(%{scoord: scoord}) do
    ContentItem.scoord(Codes.image_region(), scoord, relationship_type: "CONTAINS")
  end

  defp build_spatial_coords(_), do: nil

  defp build_probability(%{probability: probability}) when is_number(probability) do
    ContentItem.num(
      Codes.probability_of_malignancy(),
      probability,
      Codes.percent(),
      relationship_type: "CONTAINS"
    )
  end

  defp build_probability(_), do: nil

  defp build_rendering_intent(%{rendering_intent: :required}) do
    ContentItem.code(Codes.rendering_intent(), Codes.presentation_required(),
      relationship_type: "CONTAINS"
    )
  end

  defp build_rendering_intent(%{rendering_intent: :not_for_presentation}) do
    ContentItem.code(Codes.rendering_intent(), Codes.not_for_presentation(),
      relationship_type: "CONTAINS"
    )
  end

  defp build_rendering_intent(_), do: nil

  defp optional_wrap(nil), do: nil
  defp optional_wrap(item), do: [item]
end
