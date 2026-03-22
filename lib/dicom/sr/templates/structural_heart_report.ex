defmodule Dicom.SR.Templates.StructuralHeartReport do
  @moduledoc """
  Builder for a practical TID 5320 Structural Heart Measurement Report document.

  The current builder covers the root title, procedure modifier, observer
  context, annular measurement sections, device measurement sections,
  findings, and impressions. Designed for structural heart procedures
  such as TAVR, MitraClip, and similar interventions.
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
      |> add_optional(
        optional_measurement_section(
          Codes.annular_measurements(),
          Keyword.get(opts, :annular_measurements, [])
        )
      )
      |> add_optional(
        optional_measurement_section(
          Codes.device_measurements(),
          Keyword.get(opts, :device_measurements, [])
        )
      )
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))

    root = ContentItem.container(Codes.structural_heart_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "5320",
        series_description:
          Keyword.get(opts, :series_description, "Structural Heart Measurement Report")
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_measurement_section(_concept, []), do: nil

  defp optional_measurement_section(concept, measurements) do
    ContentItem.container(concept,
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end
end
