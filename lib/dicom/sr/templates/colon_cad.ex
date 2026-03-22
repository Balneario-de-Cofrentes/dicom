defmodule Dicom.SR.Templates.ColonCAD do
  @moduledoc """
  Builder for a TID 4120 Colon CAD Document Root.

  Computer-aided detection document for virtual colonoscopy polyp detection.
  Used to report CAD processing results, including detected polyp candidates
  with their size, anatomical location, and detection confidence.

  Structure:

      CONTAINER: Colon CAD Report (root)
        +-- HAS CONCEPT MOD: Language
        +-- HAS OBS CONTEXT: Observer (device, required for CAD)
        +-- CONTAINS: Image Library (optional, TID 1600)
        +-- CONTAINS: CAD Processing and Findings Summary (CONTAINER)
        |     +-- CONTAINS: Finding (TEXT/CODE, 0-n)
        +-- CONTAINS: Single Image Finding (CONTAINER, 0-n, repeating)
              +-- CONTAINS: Polyp (CODE) -- finding type
              +-- CONTAINS: Nodule size (NUM) -- polyp size in mm
              +-- CONTAINS: Colon (CODE) -- colonic segment
              +-- CONTAINS: Detection confidence (NUM, optional)

  SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.33 (Comprehensive SR Storage)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, ImageLibrary, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    device_opts = Keyword.fetch!(opts, :observer_device)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(Observer.device(device_opts))
      |> add_optional(optional_person_observer(opts[:observer_name]))
      |> add_optional(optional_image_library(Keyword.get(opts, :image_library, [])))
      |> add_optional(optional_findings_summary(Keyword.get(opts, :findings_summary, [])))
      |> add_optional(Enum.map(Keyword.get(opts, :polyp_findings, []), &polyp_finding_item/1))

    root = ContentItem.container(Codes.colon_cad_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "4120",
        series_description: Keyword.get(opts, :series_description, "Colon CAD Report")
      )
    )
  end

  defp optional_person_observer(nil), do: nil
  defp optional_person_observer(name) when is_binary(name), do: Observer.person(name)

  defp optional_image_library([]), do: nil

  defp optional_image_library(references) do
    ImageLibrary.build(references)
  end

  defp optional_findings_summary([]), do: nil

  defp optional_findings_summary(findings) do
    ContentItem.container(Codes.cad_processing_and_findings_summary(),
      relationship_type: "CONTAINS",
      children: map_findings(findings)
    )
  end

  defp polyp_finding_item(polyp) do
    children =
      []
      |> add_optional(
        ContentItem.code(Codes.finding(), Map.get(polyp, :finding_type, Codes.polyp_candidate()),
          relationship_type: "CONTAINS"
        )
      )
      |> add_optional(optional_polyp_size(polyp[:size_mm]))
      |> add_optional(optional_colonic_segment(polyp[:segment]))
      |> add_optional(optional_confidence(polyp[:confidence]))

    ContentItem.container(Codes.single_image_finding(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_polyp_size(nil), do: nil

  defp optional_polyp_size(size_mm) do
    ContentItem.num(Codes.polyp_size(), size_mm, mm_unit(), relationship_type: "CONTAINS")
  end

  defp optional_colonic_segment(nil), do: nil

  defp optional_colonic_segment(%Code{} = segment) do
    ContentItem.code(Codes.colonic_segment(), segment, relationship_type: "CONTAINS")
  end

  defp optional_confidence(nil), do: nil

  defp optional_confidence(value) do
    ContentItem.num(Codes.detection_confidence(), value, percent_unit(),
      relationship_type: "CONTAINS"
    )
  end

  defp mm_unit, do: Code.new("mm", "UCUM", "mm")
  defp percent_unit, do: Code.new("%", "UCUM", "%")
end
