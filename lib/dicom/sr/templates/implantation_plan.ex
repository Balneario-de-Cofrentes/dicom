defmodule Dicom.SR.Templates.ImplantationPlan do
  @moduledoc """
  Builder for a TID 7000 Implantation Plan document.

  Orthopedic implant planning document that describes planned implants,
  measurements, and references to related implantation reports.

  Structure:

      CONTAINER: Implantation Plan SR Document (root)
        +-- HAS CONCEPT MOD: Language
        +-- HAS OBS CONTEXT: Observer (person and/or device)
        +-- HAS CONCEPT MOD: Procedure Reported (optional)
        +-- CONTAINS: Implant Template (COMPOSITE/TEXT, 0-n)
        +-- CONTAINS: Planning measurement (NUM, 0-n)
        +-- CONTAINS: Implantation Site (CODE, optional)
        +-- CONTAINS: Finding (TEXT/CODE, 0-n)
        +-- CONTAINS: Impression (TEXT/CODE, 0-n)
        +-- CONTAINS: Recommendation (TEXT/CODE, 0-n)

  SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.33 (Comprehensive SR Storage)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer, Reference}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(Keyword.get(opts, :procedure_reported)))
      |> add_optional(
        Enum.map(Keyword.get(opts, :implant_templates, []), &implant_template_item/1)
      )
      |> add_optional(
        Enum.map(Keyword.get(opts, :planning_measurements, []), &planning_measurement_item/1)
      )
      |> add_optional(optional_implantation_site(Keyword.get(opts, :implantation_site)))
      |> add_optional(map_text_or_code(Keyword.get(opts, :findings, []), Codes.finding()))
      |> add_optional(map_text_or_code(Keyword.get(opts, :impressions, []), Codes.impression()))
      |> add_optional(
        map_text_or_code(Keyword.get(opts, :recommendations, []), Codes.recommendation())
      )

    root = ContentItem.container(Codes.implantation_plan(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "7000",
        series_description: Keyword.get(opts, :series_description, "Implantation Plan")
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp implant_template_item(%Reference{} = reference) do
    ContentItem.composite(Codes.implant_template(), reference, relationship_type: "CONTAINS")
  end

  defp implant_template_item(description) when is_binary(description) do
    ContentItem.text(Codes.implant_template(), description, relationship_type: "CONTAINS")
  end

  defp planning_measurement_item(%{concept: concept, value: value, units: units} = measurement) do
    ContentItem.num(concept, value, units,
      relationship_type: "CONTAINS",
      qualifier: Map.get(measurement, :qualifier)
    )
  end

  defp optional_implantation_site(nil), do: nil

  defp optional_implantation_site(%Code{} = site) do
    ContentItem.code(Codes.implantation_site(), site, relationship_type: "CONTAINS")
  end

  defp map_text_or_code(values, concept_code) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(concept_code, code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(concept_code, text, relationship_type: "CONTAINS")
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
