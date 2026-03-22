defmodule Dicom.SR.SubTemplates.CardiovascularAnalysis do
  @moduledoc """
  Sub-templates for CT/MR Cardiovascular Analysis reports (TID 3900-3926).

  Covers:
  - TID 3905 Calcium Scoring (Agatston, volume, mass)
  - TID 3902 Vascular Analysis (vessel segments with stenosis, plaque, measurements)
  - TID 3920 Ventricular Analysis (EF, EDV, ESV, stroke volume, myocardial mass)
  - TID 3926 Perfusion Analysis (findings)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}

  @doc """
  TID 3905 -- Calcium Scoring.

  Returns a CONTAINER with Agatston score, volume score, and mass score as
  optional NUM items.

  Options:
  - `:agatston` (optional) -- number, Agatston score value
  - `:volume` (optional) -- number, volume score in cubic millimeters
  - `:mass` (optional) -- number, mass score in milligrams
  """
  @spec calcium_scoring(keyword()) :: ContentItem.t()
  def calcium_scoring(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_num(Codes.calcium_score(), opts[:agatston], Codes.agatston_unit())
      |> maybe_add_num(Codes.calcium_volume_score(), opts[:volume], Codes.cubic_millimeter())
      |> maybe_add_num(Codes.calcium_mass_score(), opts[:mass], Codes.milligram())

    ContentItem.container(Codes.calcium_scoring_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3902 -- Vascular Analysis.

  Returns a CONTAINER grouping individual vessel analyses.

  Options:
  - `:vessels` (required) -- list of ContentItem.t() from `vessel_analysis/1`
  """
  @spec vascular_analysis(keyword()) :: ContentItem.t()
  def vascular_analysis(opts) when is_list(opts) do
    vessels = Keyword.fetch!(opts, :vessels)

    ContentItem.container(Codes.vascular_analysis_section(),
      relationship_type: "CONTAINS",
      children: vessels
    )
  end

  @doc """
  Builds a single vessel analysis within TID 3902.

  Returns a CONTAINER (Measurement Group) with vessel segment, stenosis severity,
  plaque type, and optional measurements.

  Options:
  - `:segment` (required) -- Code.t() identifying the vessel segment
  - `:stenosis` (optional) -- Code.t() severity of stenosis
  - `:plaque_type` (optional) -- Code.t() type of plaque
  - `:measurements` (optional) -- list of Measurement.t()
  """
  @spec vessel_analysis(keyword()) :: ContentItem.t()
  def vessel_analysis(opts) when is_list(opts) do
    segment = Keyword.fetch!(opts, :segment)

    children =
      [ContentItem.code(Codes.vessel_segment(), segment, relationship_type: "CONTAINS")]
      |> maybe_add_code(Codes.stenosis_severity(), opts[:stenosis])
      |> maybe_add_code(Codes.plaque_type(), opts[:plaque_type])
      |> append_measurements(Keyword.get(opts, :measurements, []))

    ContentItem.container(Codes.measurement_group(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3920 -- Ventricular Analysis.

  Returns a CONTAINER with ejection fraction, end-diastolic volume,
  end-systolic volume, stroke volume, and myocardial mass as optional
  NUM items.

  Options:
  - `:ejection_fraction` (optional) -- number, EF in percent
  - `:edv` (optional) -- number, end-diastolic volume in mL
  - `:esv` (optional) -- number, end-systolic volume in mL
  - `:stroke_volume` (optional) -- number, stroke volume in mL
  - `:myocardial_mass` (optional) -- number, myocardial mass in grams
  """
  @spec ventricular_analysis(keyword()) :: ContentItem.t()
  def ventricular_analysis(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_num(Codes.ejection_fraction(), opts[:ejection_fraction], Codes.percent())
      |> maybe_add_num(Codes.end_diastolic_volume(), opts[:edv], Codes.milliliter())
      |> maybe_add_num(Codes.end_systolic_volume(), opts[:esv], Codes.milliliter())
      |> maybe_add_num(Codes.stroke_volume(), opts[:stroke_volume], Codes.milliliter())
      |> maybe_add_num(Codes.myocardial_mass(), opts[:myocardial_mass], Codes.grams())

    ContentItem.container(Codes.ventricular_analysis_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3926 -- Perfusion Analysis.

  Returns a CONTAINER with perfusion findings.

  Options:
  - `:findings` (optional) -- list of String.t() or Code.t() findings
  """
  @spec perfusion_analysis(keyword()) :: ContentItem.t()
  def perfusion_analysis(opts) when is_list(opts) do
    children = append_findings([], Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.perfusion_analysis_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Private Helpers --

  defp maybe_add_num(items, _concept, nil, _units), do: items

  defp maybe_add_num(items, concept, value, units) do
    items ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
  end

  defp maybe_add_code(items, _concept, nil), do: items

  defp maybe_add_code(items, concept, %Code{} = value) do
    items ++ [ContentItem.code(concept, value, relationship_type: "CONTAINS")]
  end

  defp append_measurements(items, measurements) do
    items ++ Enum.map(measurements, &Measurement.to_content_item/1)
  end

  defp append_findings(items, findings) do
    items ++
      Enum.map(findings, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)
  end
end
