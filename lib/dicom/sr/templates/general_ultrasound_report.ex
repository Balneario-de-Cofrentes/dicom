defmodule Dicom.SR.Templates.GeneralUltrasoundReport do
  @moduledoc """
  Builder for a practical TID 12000 General Ultrasound Report document.

  This builder covers the root document structure, observation context,
  procedure-reported modifiers, patient characteristics, measurement sections
  with anatomical locations, shear wave elastography, attenuation coefficient,
  and free-text findings/impressions/recommendations.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, MeasurementGroup, Observer}

  import Dicom.SR.Templates.Helpers

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
        optional_patient_characteristics(Keyword.get(opts, :patient_characteristics))
      )
      |> add_optional(
        Enum.map(Keyword.get(opts, :measurement_sections, []), &measurement_section_item/1)
      )
      |> add_optional(optional_elastography(Keyword.get(opts, :elastography)))
      |> add_optional(optional_attenuation(Keyword.get(opts, :attenuation)))
      |> add_optional(map_text_items(Codes.finding(), Keyword.get(opts, :findings, [])))
      |> add_optional(map_text_items(Codes.impression(), Keyword.get(opts, :impressions, [])))
      |> add_optional(
        map_text_items(Codes.recommendation(), Keyword.get(opts, :recommendations, []))
      )

    root = ContentItem.container(Codes.general_ultrasound_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "12000",
        series_description: Keyword.get(opts, :series_description, "General Ultrasound Report")
      )
    )
  end

  defp measurement_section_item(section) do
    location = Map.fetch!(section, :location)
    measurements = Map.get(section, :measurements, [])
    assessments = Map.get(section, :assessments, [])

    tracking_id = Map.get(section, :tracking_id, location.meaning)
    tracking_uid = Map.get(section, :tracking_uid, Dicom.UID.generate())

    group =
      MeasurementGroup.new(tracking_id, tracking_uid,
        measurements: measurements,
        finding_sites: [location],
        qualitative_evaluations: map_text_items(Codes.finding(), assessments)
      )

    ContentItem.container(Codes.measurement_section(),
      relationship_type: "CONTAINS",
      children: [MeasurementGroup.to_content_item(group)]
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_patient_characteristics(nil), do: nil
  defp optional_patient_characteristics([]), do: nil

  defp optional_patient_characteristics(characteristics) when is_list(characteristics) do
    children =
      Enum.map(characteristics, fn {concept, value} ->
        ContentItem.text(concept, value, relationship_type: "HAS OBS CONTEXT")
      end)

    ContentItem.container(Codes.patient_characteristics(),
      relationship_type: "HAS OBS CONTEXT",
      children: children
    )
  end

  defp optional_elastography(nil), do: nil

  defp optional_elastography(elastography) when is_map(elastography) do
    children =
      []
      |> add_optional(optional_measurement(elastography[:velocity]))
      |> add_optional(optional_measurement(elastography[:elasticity]))

    case children do
      [] -> nil
      _ -> children
    end
  end

  defp optional_attenuation(nil), do: nil

  defp optional_attenuation(%Measurement{} = measurement) do
    Measurement.to_content_item(measurement)
  end

  defp optional_measurement(nil), do: nil
  defp optional_measurement(%Measurement{} = m), do: Measurement.to_content_item(m)

  defp map_text_items(_concept, []), do: []

  defp map_text_items(concept, values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(concept, code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(concept, text, relationship_type: "CONTAINS")
    end)
  end
end
