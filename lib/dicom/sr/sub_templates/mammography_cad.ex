defmodule Dicom.SR.SubTemplates.MammographyCAD do
  @moduledoc """
  Sub-templates for Mammography CAD reports (TID 4001-4023).

  Covers:
  - TID 4001 Overall Impression
  - TID 4003 Individual Impression
  - TID 4004-4006 Composite/Single Finding
  - TID 4007 Breast Composition
  - TID 4014-4023 Algorithm, Operating Points, Image Quality
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement, Reference}

  @doc """
  TID 4001 -- Overall Assessment.

  Returns a CONTAINER with the overall CAD assessment for a breast.

  Options:
  - `:laterality` (required) -- Code.t() (right_breast or left_breast)
  - `:assessment` (required) -- String.t() or Code.t()
  - `:individual_impressions` (optional) -- list of ContentItem.t() from `individual_impression/1`
  """
  @spec overall_assessment(keyword()) :: ContentItem.t()
  def overall_assessment(opts) when is_list(opts) do
    laterality = Keyword.fetch!(opts, :laterality)
    assessment = Keyword.fetch!(opts, :assessment)

    children =
      [
        ContentItem.code(Codes.finding_site(), laterality, relationship_type: "HAS CONCEPT MOD"),
        assessment_item(assessment)
      ]
      |> append_items(Keyword.get(opts, :individual_impressions, []))

    ContentItem.container(Codes.overall_assessment(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4003 -- Individual Impression.

  Returns a CONTAINER with a single finding within a breast.

  Options:
  - `:finding_type` (required) -- Code.t() (calcification, mass, etc.)
  - `:probability` (optional) -- Measurement.t() probability of cancer
  - `:source_image` (optional) -- Reference.t() for the source image
  - `:findings` (optional) -- list of ContentItem.t() from `single_finding/1` or `composite_finding/1`
  """
  @spec individual_impression(keyword()) :: ContentItem.t()
  def individual_impression(opts) when is_list(opts) do
    finding_type = Keyword.fetch!(opts, :finding_type)

    children =
      [
        ContentItem.code(Codes.finding(), finding_type, relationship_type: "CONTAINS")
      ]
      |> maybe_add_probability(opts[:probability])
      |> maybe_add_source_image(opts[:source_image])
      |> append_items(Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.individual_impression(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4004 -- Composite Feature.

  Returns a CONTAINER grouping multiple single image findings.

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
  TID 4005-4006 -- Single Image Finding.

  Returns a CONTAINER for a finding in a single image.

  Options:
  - `:finding_type` (required) -- Code.t() (calcification, mass, etc.)
  - `:source_image` (optional) -- Reference.t()
  - `:measurements` (optional) -- list of Measurement.t()
  """
  @spec single_finding(keyword()) :: ContentItem.t()
  def single_finding(opts) when is_list(opts) do
    finding_type = Keyword.fetch!(opts, :finding_type)

    children =
      [
        ContentItem.code(Codes.finding(), finding_type, relationship_type: "CONTAINS")
      ]
      |> maybe_add_source_image(opts[:source_image])
      |> append_measurements(Keyword.get(opts, :measurements, []))

    ContentItem.container(Codes.single_image_finding(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4007 -- Breast Composition.

  Returns a CODE content item for breast density/composition.
  """
  @spec breast_composition(Code.t()) :: ContentItem.t()
  def breast_composition(%Code{} = density) do
    ContentItem.code(Codes.breast_composition(), density, relationship_type: "CONTAINS")
  end

  @doc """
  TID 4014 -- Algorithm Identification.

  Returns a CONTAINER with algorithm name, version, and optional parameters.

  Options:
  - `:name` (required) -- String.t()
  - `:version` (required) -- String.t()
  - `:parameters` (optional) -- String.t() free-text parameters description
  """
  @spec algorithm(keyword()) :: ContentItem.t()
  def algorithm(opts) when is_list(opts) do
    name = Keyword.fetch!(opts, :name)
    version = Keyword.fetch!(opts, :version)

    children =
      [
        ContentItem.text(Codes.algorithm_name(), name, relationship_type: "CONTAINS"),
        ContentItem.text(Codes.algorithm_version(), version, relationship_type: "CONTAINS")
      ]
      |> maybe_add_text(Codes.algorithm_parameters(), opts[:parameters])

    ContentItem.container(Codes.algorithm_name(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4019 -- CAD Operating Point.

  Returns a CONTAINER with sensitivity, specificity, and false positive rate.

  Options:
  - `:sensitivity` (optional) -- Measurement.t()
  - `:specificity` (optional) -- Measurement.t()
  - `:false_positive_rate` (optional) -- Measurement.t()
  """
  @spec operating_point(keyword()) :: ContentItem.t()
  def operating_point(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_measurement(opts[:sensitivity])
      |> maybe_add_measurement(opts[:specificity])
      |> maybe_add_measurement(opts[:false_positive_rate])

    ContentItem.container(Codes.cad_operating_point(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4023 -- Image Quality.

  Returns a CODE content item for image quality assessment.
  """
  @spec image_quality(Code.t()) :: ContentItem.t()
  def image_quality(%Code{} = quality) do
    ContentItem.code(Codes.image_quality(), quality, relationship_type: "CONTAINS")
  end

  # -- Private Helpers --

  defp assessment_item(%Code{} = code) do
    ContentItem.code(Codes.overall_assessment(), code, relationship_type: "CONTAINS")
  end

  defp assessment_item(text) when is_binary(text) do
    ContentItem.text(Codes.overall_assessment(), text, relationship_type: "CONTAINS")
  end

  defp maybe_add_probability(items, nil), do: items

  defp maybe_add_probability(items, %Measurement{} = m) do
    items ++ [Measurement.to_content_item(m)]
  end

  defp maybe_add_source_image(items, nil), do: items

  defp maybe_add_source_image(items, %Reference{} = ref) do
    items ++ [ContentItem.image(Codes.source(), ref, relationship_type: "CONTAINS")]
  end

  defp maybe_add_measurement(items, nil), do: items

  defp maybe_add_measurement(items, %Measurement{} = m) do
    items ++ [Measurement.to_content_item(m)]
  end

  defp maybe_add_text(items, _concept, nil), do: items

  defp maybe_add_text(items, concept, text) when is_binary(text) do
    items ++ [ContentItem.text(concept, text, relationship_type: "CONTAINS")]
  end

  defp append_items(items, more), do: items ++ more

  defp append_measurements(items, measurement_list) do
    items ++ Enum.map(measurement_list, &Measurement.to_content_item/1)
  end
end
