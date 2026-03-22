defmodule Dicom.SR.SubTemplates.Echocardiography do
  @moduledoc """
  Sub-templates for Echocardiography reports (TID 5201-5240).

  Covers:
  - TID 5201 Patient Characteristics
  - TID 5202 Echo Section
  - TID 5203 Echo Measurement
  - TID 5204 Wall Motion Analysis
  - TID 5240 Myocardial Strain Analysis
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}

  @doc """
  TID 5201 -- Patient Characteristics.

  Returns a CONTAINER with body surface area, weight, and height measurements.

  Options:
  - `:measurements` (required) -- list of Measurement.t() (BSA, weight, height)
  """
  @spec patient_characteristics(keyword()) :: ContentItem.t()
  def patient_characteristics(opts) when is_list(opts) do
    measurements = Keyword.fetch!(opts, :measurements)

    children = Enum.map(measurements, &Measurement.to_content_item/1)

    ContentItem.container(Codes.patient_characteristics(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5202 -- Echo Section.

  Returns a CONTAINER grouping echo measurements for a specific cardiac
  structure (e.g. left ventricle, aortic valve).

  Options:
  - `:structure` (required) -- Code.t() identifying the cardiac structure
  - `:measurements` (optional) -- list of ContentItem.t() from `echo_measurement/1`
  - `:findings` (optional) -- list of String.t() or Code.t()
  """
  @spec echo_section(keyword()) :: ContentItem.t()
  def echo_section(opts) when is_list(opts) do
    structure = Keyword.fetch!(opts, :structure)

    children =
      [
        ContentItem.code(Codes.finding_site(), structure, relationship_type: "HAS CONCEPT MOD")
      ]
      |> append_items(Keyword.get(opts, :measurements, []))
      |> append_findings(Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.echo_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5203 -- Echo Measurement.

  Returns a NUM content item for a single echo measurement.
  This is a thin wrapper that delegates to `Measurement.to_content_item/1`.
  """
  @spec echo_measurement(Measurement.t()) :: ContentItem.t()
  def echo_measurement(%Measurement{} = measurement) do
    Measurement.to_content_item(measurement)
  end

  @doc """
  TID 5204 -- Wall Motion Analysis.

  Returns a CONTAINER with wall motion scores and regional assessments.

  Options:
  - `:wall_motion_score` (optional) -- Measurement.t() for the overall score
  - `:wall_motion_score_index` (optional) -- Measurement.t() for WMSI
  - `:regional_assessments` (optional) -- list of ContentItem.t() (code items for wall segments)
  """
  @spec wall_motion_analysis(keyword()) :: ContentItem.t()
  def wall_motion_analysis(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_measurement(opts[:wall_motion_score])
      |> maybe_add_measurement(opts[:wall_motion_score_index])
      |> append_items(Keyword.get(opts, :regional_assessments, []))

    ContentItem.container(Codes.wall_motion_score(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  Builds a regional wall motion assessment for a specific segment.

  Returns a CODE content item mapping a segment to a motion category
  (normal, hypokinesis, akinesis, dyskinesis).
  """
  @spec regional_wall_motion(Code.t(), Code.t()) :: ContentItem.t()
  def regional_wall_motion(%Code{} = segment, %Code{} = motion_category) do
    ContentItem.code(Codes.wall_motion_abnormality(), motion_category,
      relationship_type: "CONTAINS",
      children: [
        ContentItem.code(Codes.finding_site(), segment, relationship_type: "HAS CONCEPT MOD")
      ]
    )
  end

  @doc """
  TID 5240 -- Myocardial Strain Analysis.

  Returns a CONTAINER with global and optional regional strain measurements.

  Options:
  - `:global_strain` (required) -- Measurement.t() for GLS
  - `:regional_strains` (optional) -- list of Measurement.t() for regional segments
  """
  @spec myocardial_strain_analysis(keyword()) :: ContentItem.t()
  def myocardial_strain_analysis(opts) when is_list(opts) do
    global_strain = Keyword.fetch!(opts, :global_strain)

    children =
      [Measurement.to_content_item(global_strain)]
      |> append_measurements(Keyword.get(opts, :regional_strains, []))

    ContentItem.container(Codes.global_longitudinal_strain(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Private Helpers --

  defp append_items(items, more), do: items ++ more

  defp append_findings(items, findings) do
    items ++
      Enum.map(findings, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)
  end

  defp maybe_add_measurement(items, nil), do: items

  defp maybe_add_measurement(items, %Measurement{} = m) do
    items ++ [Measurement.to_content_item(m)]
  end

  defp append_measurements(items, measurement_list) do
    items ++ Enum.map(measurement_list, &Measurement.to_content_item/1)
  end
end
