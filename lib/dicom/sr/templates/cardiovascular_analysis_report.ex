defmodule Dicom.SR.Templates.CardiovascularAnalysisReport do
  @moduledoc """
  Builder for a practical TID 3900 CT/MR Cardiovascular Analysis Report document.

  The current builder covers the root title, observer context, procedure modifier,
  procedure summary, calcium scoring (TID 3905), vascular analysis (TID 3902),
  ventricular analysis (TID 3920), perfusion analysis (TID 3926),
  findings, impressions, recommendations, and report summary.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    procedure_reported = Keyword.get(opts, :procedure_reported)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional(optional_text_item(Codes.procedure_summary(), opts[:procedure_summary]))
      |> add_optional(optional_calcium_scoring(opts[:calcium_scoring]))
      |> add_optional(optional_vascular_analyses(opts[:vascular_analyses]))
      |> add_optional(optional_ventricular_analysis(opts[:ventricular_analysis]))
      |> add_optional(optional_perfusion_analysis(opts[:perfusion_analysis]))
      |> add_optional(map_items(Codes.finding(), opts[:findings]))
      |> add_optional(map_items(Codes.impression(), opts[:impressions]))
      |> add_optional(map_items(Codes.recommendation(), opts[:recommendations]))
      |> add_optional(optional_text_item(Codes.summary(), opts[:summary]))

    root =
      ContentItem.container(Codes.cardiovascular_analysis_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3900",
        series_description:
          Keyword.get(opts, :series_description, "CT/MR Cardiovascular Analysis Report")
      )
    )
  end

  # -- Calcium scoring (TID 3905) --

  defp optional_calcium_scoring(nil), do: nil

  defp optional_calcium_scoring(scoring) when is_map(scoring) do
    children =
      []
      |> add_optional(optional_num(Codes.calcium_score(), scoring[:agatston], agatston_units()))
      |> add_optional(
        optional_num(Codes.calcium_volume_score(), scoring[:volume], volume_units())
      )
      |> add_optional(optional_num(Codes.calcium_mass_score(), scoring[:mass], mass_units()))

    ContentItem.container(Codes.calcium_scoring_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Vascular analysis (TID 3902) --

  defp optional_vascular_analyses(nil), do: nil
  defp optional_vascular_analyses([]), do: nil

  defp optional_vascular_analyses(analyses) when is_list(analyses) do
    children = Enum.map(analyses, &vascular_vessel_item/1)

    ContentItem.container(Codes.vascular_analysis_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp vascular_vessel_item(vessel) when is_map(vessel) do
    children =
      []
      |> add_optional(optional_code_item(Codes.vessel_segment(), vessel[:segment]))
      |> add_optional(optional_code_item(Codes.stenosis_severity(), vessel[:stenosis]))
      |> add_optional(optional_code_item(Codes.plaque_type(), vessel[:plaque_type]))
      |> add_optional(vessel_measurements(vessel[:measurements]))

    ContentItem.container(Codes.measurement_group(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp vessel_measurements(nil), do: []
  defp vessel_measurements([]), do: []

  defp vessel_measurements(measurements) when is_list(measurements) do
    Enum.map(measurements, &Measurement.to_content_item/1)
  end

  # -- Ventricular analysis (TID 3920) --

  defp optional_ventricular_analysis(nil), do: nil

  defp optional_ventricular_analysis(analysis) when is_map(analysis) do
    children =
      []
      |> add_optional(
        optional_num(Codes.ejection_fraction(), analysis[:ejection_fraction], percent_units())
      )
      |> add_optional(
        optional_num(Codes.end_diastolic_volume(), analysis[:edv], milliliter_units())
      )
      |> add_optional(
        optional_num(Codes.end_systolic_volume(), analysis[:esv], milliliter_units())
      )
      |> add_optional(
        optional_num(Codes.stroke_volume(), analysis[:stroke_volume], milliliter_units())
      )
      |> add_optional(
        optional_num(Codes.myocardial_mass(), analysis[:myocardial_mass], gram_units())
      )

    ContentItem.container(Codes.ventricular_analysis_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Perfusion analysis (TID 3926) --

  defp optional_perfusion_analysis(nil), do: nil

  defp optional_perfusion_analysis(analysis) when is_map(analysis) do
    children = map_items(Codes.finding(), analysis[:findings])

    ContentItem.container(Codes.perfusion_analysis_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Shared helpers --

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_text_item(_concept, nil), do: nil

  defp optional_text_item(concept, text) when is_binary(text) do
    ContentItem.text(concept, text, relationship_type: "CONTAINS")
  end

  defp optional_num(_concept, nil, _units), do: nil

  defp optional_num(concept, value, units) do
    ContentItem.num(concept, value, units, relationship_type: "CONTAINS")
  end

  defp optional_code_item(_concept, nil), do: nil

  defp optional_code_item(concept, %Code{} = value) do
    ContentItem.code(concept, value, relationship_type: "CONTAINS")
  end

  defp map_items(_concept, nil), do: []
  defp map_items(_concept, []), do: []

  defp map_items(concept, values) when is_list(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(concept, code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(concept, text, relationship_type: "CONTAINS")
    end)
  end

  # -- UCUM unit codes --

  defp agatston_units, do: Code.new("1", "UCUM", "Agatston unit")
  defp volume_units, do: Code.new("mm3", "UCUM", "cubic millimeter")
  defp mass_units, do: Code.new("mg", "UCUM", "milligram")
  defp percent_units, do: Code.new("%", "UCUM", "percent")
  defp milliliter_units, do: Code.new("mL", "UCUM", "milliliter")
  defp gram_units, do: Code.new("g", "UCUM", "gram")
end
