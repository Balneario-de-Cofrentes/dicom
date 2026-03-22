defmodule Dicom.SR.Templates.BreastImagingReport do
  @moduledoc """
  Builder for a practical TID 4200 Breast Imaging Report document.

  This builder covers the root document structure, observation context,
  procedure-reported modifiers, breast composition (TID 4205), report
  narrative (TID 4202), findings (TID 4206), BI-RADS assessment (TID 4203),
  impressions, and recommendations.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    assessment = Keyword.fetch!(opts, :assessment)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(Keyword.get(opts, :procedure_reported)))
      |> add_optional(optional_breast_composition(Keyword.get(opts, :breast_composition)))
      |> add_optional(optional_narrative(Keyword.get(opts, :narrative)))
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional([assessment_item(assessment)])
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))
      |> add_optional(map_recommendations(Keyword.get(opts, :recommendations, [])))

    root = ContentItem.container(Codes.breast_imaging_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "4200",
        series_description: Keyword.get(opts, :series_description, "Breast Imaging Report")
      )
    )
  end

  defp assessment_item(%Code{} = code) do
    ContentItem.code(Codes.overall_assessment(), code, relationship_type: "CONTAINS")
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_breast_composition(nil), do: nil

  defp optional_breast_composition(%Code{} = code) do
    ContentItem.code(Codes.breast_composition(), code, relationship_type: "CONTAINS")
  end

  defp optional_narrative(nil), do: nil

  defp optional_narrative(text) when is_binary(text) do
    ContentItem.text(Codes.narrative_summary(), text, relationship_type: "CONTAINS")
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

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
