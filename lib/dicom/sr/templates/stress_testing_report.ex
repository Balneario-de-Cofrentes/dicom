defmodule Dicom.SR.Templates.StressTestingReport do
  @moduledoc """
  Builder for a practical TID 3300 Stress Testing Report document.

  The current builder covers the root title, procedure modifier, observer
  context, indications, procedure description, phase-oriented measurements,
  conclusions, and recommendations.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, MeasurementGroup, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    procedure_reported = Keyword.get(opts, :procedure_reported)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(Observer.person(observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional(map_findings(Keyword.get(opts, :indications, [])))
      |> add_optional(optional_procedure_description(Keyword.get(opts, :procedure_description)))
      |> add_optional(Enum.map(Keyword.get(opts, :phase_data, []), &phase_group/1))
      |> add_optional(map_impressions(Keyword.get(opts, :summary, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :conclusions, [])))
      |> add_optional(map_recommendations(Keyword.get(opts, :recommendations, [])))

    root = ContentItem.container(Codes.stress_testing_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3300",
        series_description: Keyword.get(opts, :series_description, "Stress Testing Report")
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_procedure_description(nil), do: nil

  defp optional_procedure_description(description) when is_binary(description) do
    ContentItem.text(Codes.procedure_description(), description, relationship_type: "CONTAINS")
  end

  defp phase_group(phase) do
    qualitative_evaluations =
      phase
      |> Map.get(:findings, [])
      |> map_findings()

    MeasurementGroup.new(
      Map.fetch!(phase, :name),
      Dicom.UID.generate(),
      activity_session: Map.fetch!(phase, :name),
      measurements: Map.get(phase, :measurements, []),
      qualitative_evaluations: qualitative_evaluations
    )
    |> MeasurementGroup.to_content_item()
  end

  defp map_findings(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  defp map_impressions(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
    end)
  end

  defp map_recommendations(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.recommendation(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.recommendation(), text, relationship_type: "CONTAINS")
    end)
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
