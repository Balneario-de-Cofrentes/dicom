defmodule Dicom.SR.Templates.VascularUltrasoundReport do
  @moduledoc """
  Builder for a practical TID 5100 Vascular Ultrasound Report document.

  The current builder covers the root title, language, observer context,
  procedure modifier, patient characteristics, vascular sections with
  measurements and qualitative assessments, optional graft sections,
  findings, impressions, and recommendations.
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
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional(
        optional_patient_characteristics(Keyword.get(opts, :patient_characteristics))
      )
      |> add_optional(Enum.map(Keyword.get(opts, :vascular_sections, []), &vascular_section/1))
      |> add_optional(Enum.map(Keyword.get(opts, :graft_sections, []), &graft_section/1))
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))
      |> add_optional(map_recommendations(Keyword.get(opts, :recommendations, [])))

    root = ContentItem.container(Codes.vascular_ultrasound_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "5100",
        series_description: Keyword.get(opts, :series_description, "Vascular Ultrasound Report")
      )
    )
  end

  defp vascular_section(section) do
    location = Map.fetch!(section, :location)
    measurements = Map.get(section, :measurements, [])
    assessments = Map.get(section, :assessments, [])

    children =
      [
        ContentItem.code(Codes.finding_site(), location, relationship_type: "HAS CONCEPT MOD")
      ]
      |> add_optional(optional_measurement_group(location, measurements))
      |> add_optional(Enum.map(assessments, &assessment_item/1))

    ContentItem.container(Codes.vascular_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp graft_section(section) do
    location = Map.fetch!(section, :location)
    measurements = Map.get(section, :measurements, [])
    assessments = Map.get(section, :assessments, [])

    children =
      [
        ContentItem.code(Codes.finding_site(), location, relationship_type: "HAS CONCEPT MOD")
      ]
      |> add_optional(optional_measurement_group(location, measurements))
      |> add_optional(Enum.map(assessments, &assessment_item/1))

    ContentItem.container(Codes.graft_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_measurement_group(_location, []), do: nil

  defp optional_measurement_group(%Code{meaning: meaning}, measurements) do
    tracking_id = "vascular:#{meaning}"

    MeasurementGroup.new(tracking_id, Dicom.UID.generate(),
      measurements: measurements,
      finding_sites: []
    )
    |> MeasurementGroup.to_content_item()
  end

  defp assessment_item(%Code{} = code) do
    ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_patient_characteristics(nil), do: nil
  defp optional_patient_characteristics([]), do: nil

  defp optional_patient_characteristics(characteristics) when is_list(characteristics) do
    children =
      Enum.map(characteristics, fn
        {name, %Code{} = value} ->
          ContentItem.code(name, value, relationship_type: "HAS OBS CONTEXT")

        {name, value} when is_binary(value) ->
          ContentItem.text(name, value, relationship_type: "HAS OBS CONTEXT")
      end)

    ContentItem.container(Codes.patient_characteristics(),
      relationship_type: "HAS OBS CONTEXT",
      children: children
    )
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
