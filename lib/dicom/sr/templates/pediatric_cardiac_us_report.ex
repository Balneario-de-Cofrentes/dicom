defmodule Dicom.SR.Templates.PediatricCardiacUSReport do
  @moduledoc """
  Builder for a practical TID 5220 Pediatric, Fetal and Congenital Cardiac
  Ultrasound Report document.

  The current builder covers the normative root title, procedure modifier,
  observer context, patient characteristics, cardiac measurement sections
  (pre-coordinated and post-coordinated), summary, findings, and impressions.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, MeasurementGroup, Observer}

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
      |> add_optional(
        optional_patient_characteristics(Keyword.get(opts, :patient_characteristics, []))
      )
      |> add_optional(optional_cardiac_measurements(Keyword.get(opts, :cardiac_sections, [])))
      |> add_optional(optional_summary(Keyword.get(opts, :summary, [])))
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))

    root = ContentItem.container(Codes.pediatric_cardiac_us_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "5220",
        series_description:
          Keyword.get(
            opts,
            :series_description,
            "Pediatric Cardiac Ultrasound Report"
          )
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_patient_characteristics([]), do: nil

  defp optional_patient_characteristics(characteristics) do
    children =
      Enum.map(characteristics, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.patient_characteristics(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_cardiac_measurements([]), do: nil

  defp optional_cardiac_measurements(sections) do
    Enum.map(sections, fn section ->
      measurements = Map.get(section, :measurements, [])
      findings = Map.get(section, :findings, [])

      MeasurementGroup.new(
        Map.fetch!(section, :name),
        Dicom.UID.generate(),
        activity_session: Map.fetch!(section, :name),
        measurements: measurements,
        qualitative_evaluations: map_findings(findings)
      )
      |> MeasurementGroup.to_content_item()
    end)
  end

  defp optional_summary([]), do: nil

  defp optional_summary(values) do
    children =
      Enum.map(values, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end
end
