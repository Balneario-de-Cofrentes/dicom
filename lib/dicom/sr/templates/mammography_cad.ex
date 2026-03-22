defmodule Dicom.SR.Templates.MammographyCAD do
  @moduledoc """
  Builder for a practical TID 4000 Mammography CAD Document Root.

  Implements the top-level structure for Computer-Aided Detection/Diagnosis
  results in mammography. The builder covers the root container, device
  observer context, image library, overall impression (CAD processing and
  findings summary with detections/analyses performed), individual
  impression/recommendation sections, and breast composition.

  Structure:

      CONTAINER: Mammography CAD Report (root)
        +-- HAS CONCEPT MOD: Language (optional, defaults to en-US)
        +-- HAS OBS CONTEXT: Device Observer (required: uid, name)
        +-- CONTAINS: Image Library (optional, TID 4020)
        +-- CONTAINS: CAD Processing and Findings Summary (TID 4001)
        |     +-- CONTAINS: Successful Detections Performed (TID 4015)
        |     +-- CONTAINS: Successful Analyses Performed (TID 4016)
        +-- CONTAINS: Individual Impression/Recommendation (TID 4003, 0-n)
        |     +-- CONTAINS: Composite Feature (TID 4004, 0-n)
        |     +-- CONTAINS: Single Image Finding (TID 4006, 0-n)
        +-- CONTAINS: Breast Composition (TID 4007, optional)

  SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.50 (Mammography CAD SR Storage)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, ImageLibrary, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    device_observer = Keyword.fetch!(opts, :device_observer)
    detections_performed = Keyword.get(opts, :detections_performed, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(device_observer_items(device_observer))
      |> add_optional(optional_image_library(Keyword.get(opts, :image_library, [])))
      |> add_optional(
        optional_wrap(
          cad_processing_summary(detections_performed, Keyword.get(opts, :analyses_performed, []))
        )
      )
      |> add_optional(individual_impressions(Keyword.get(opts, :findings, [])))
      |> add_optional(optional_breast_composition(Keyword.get(opts, :breast_composition)))

    root = ContentItem.container(Codes.mammography_cad_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "4000",
        sop_class_uid: Dicom.UID.mammography_cad_sr_storage(),
        series_description: Keyword.get(opts, :series_description, "Mammography CAD Report")
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

  defp cad_processing_summary(detections_performed, analyses_performed) do
    children =
      Enum.map(detections_performed, fn %Code{} = code ->
        ContentItem.code(Codes.successful_detections_performed(), code,
          relationship_type: "CONTAINS"
        )
      end) ++
        Enum.map(analyses_performed, fn %Code{} = code ->
          ContentItem.code(Codes.successful_analyses_performed(), code,
            relationship_type: "CONTAINS"
          )
        end)

    if children == [] do
      nil
    else
      ContentItem.container(Codes.cad_processing_and_findings_summary(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  defp individual_impressions([]), do: []

  defp individual_impressions(findings) do
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

  defp optional_breast_composition(nil), do: nil

  defp optional_breast_composition(%Code{} = code) do
    ContentItem.code(Codes.breast_composition(), code, relationship_type: "CONTAINS")
  end

  defp optional_wrap(nil), do: nil
  defp optional_wrap(item), do: [item]

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
