defmodule Dicom.SR.Templates.IVUSReport do
  @moduledoc """
  Builder for a practical TID 3250 IVUS (Intravascular Ultrasound) Report document.

  The current builder covers the root title, language modifier, observer context,
  procedure-reported modifier, vessel identification (TID 3251), lesion findings
  with measurements and qualitative assessments (TID 3252-3254), volume
  measurements (TID 3255), findings, and impressions.
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
      |> add_optional(Enum.map(Keyword.get(opts, :vessels, []), &vessel_item/1))
      |> add_optional(Enum.map(Keyword.get(opts, :lesions, []), &lesion_item/1))
      |> add_optional(optional_volume_measurements(Keyword.get(opts, :volume_measurements, [])))
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))

    root = ContentItem.container(Codes.ivus_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3250",
        series_description: Keyword.get(opts, :series_description, "IVUS Report")
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp vessel_item(vessel) when is_map(vessel) do
    name = Map.fetch!(vessel, :name)

    children =
      [ContentItem.code(Codes.vessel(), name, relationship_type: "HAS CONCEPT MOD")]
      |> add_optional(optional_vessel_branch(Map.get(vessel, :branch)))

    ContentItem.container(Codes.vessel(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_vessel_branch(nil), do: nil

  defp optional_vessel_branch(%Code{} = branch) do
    ContentItem.code(Codes.vessel_branch(), branch, relationship_type: "HAS CONCEPT MOD")
  end

  defp lesion_item(lesion) when is_map(lesion) do
    identifier = Map.fetch!(lesion, :identifier)
    measurements = Map.get(lesion, :measurements, [])
    assessments = Map.get(lesion, :assessments, [])

    children =
      [
        ContentItem.text(Codes.tracking_identifier(), identifier,
          relationship_type: "HAS OBS CONTEXT"
        )
      ]
      |> add_optional(Enum.map(measurements, &Measurement.to_content_item/1))
      |> add_optional(map_findings(assessments))

    ContentItem.container(Codes.lesion(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_volume_measurements([]), do: nil

  defp optional_volume_measurements(measurements) do
    ContentItem.container(Codes.imaging_measurements(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end
end
