defmodule Dicom.SR.SubTemplates.ColonCAD do
  @moduledoc """
  Sub-templates for Colon CAD reports (TID 4121-4122).

  Covers:
  - TID 4121 Findings Summary (CAD processing results)
  - TID 4122 Polyp Finding (polyp candidate with size, segment, confidence)
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  @doc """
  TID 4121 -- Findings Summary.

  Returns a CONTAINER with the CAD processing and findings summary.

  Options:
  - `:findings` (required) -- list of String.t() or Code.t() findings
  """
  @spec findings_summary(keyword()) :: ContentItem.t()
  def findings_summary(opts) when is_list(opts) do
    findings = Keyword.fetch!(opts, :findings)

    children = map_findings(findings)

    ContentItem.container(Codes.cad_processing_and_findings_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 4122 -- Polyp Finding.

  Returns a CONTAINER for a detected polyp candidate with optional size,
  colonic segment, and detection confidence.

  Options:
  - `:finding_type` (optional) -- Code.t() (defaults to `Codes.polyp_candidate()`)
  - `:size_mm` (optional) -- number() polyp size in millimeters
  - `:segment` (optional) -- Code.t() colonic segment (cecum, ascending_colon, etc.)
  - `:confidence` (optional) -- number() detection confidence (0-100, percent)
  """
  @spec polyp_finding(keyword()) :: ContentItem.t()
  def polyp_finding(opts) when is_list(opts) do
    finding_type = Keyword.get(opts, :finding_type, Codes.polyp_candidate())

    children =
      [
        ContentItem.code(Codes.finding(), finding_type, relationship_type: "CONTAINS")
      ]
      |> maybe_add_size(opts[:size_mm])
      |> maybe_add_segment(opts[:segment])
      |> maybe_add_confidence(opts[:confidence])

    ContentItem.container(Codes.single_image_finding(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Private Helpers --

  defp map_findings(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  defp maybe_add_size(items, nil), do: items

  defp maybe_add_size(items, size_mm) when is_number(size_mm) do
    items ++
      [
        ContentItem.num(Codes.polyp_size(), size_mm, Codes.mm(), relationship_type: "CONTAINS")
      ]
  end

  defp maybe_add_segment(items, nil), do: items

  defp maybe_add_segment(items, %Code{} = segment) do
    items ++
      [ContentItem.code(Codes.colonic_segment(), segment, relationship_type: "CONTAINS")]
  end

  defp maybe_add_confidence(items, nil), do: items

  defp maybe_add_confidence(items, value) when is_number(value) do
    items ++
      [
        ContentItem.num(Codes.detection_confidence(), value, Codes.percent(),
          relationship_type: "CONTAINS"
        )
      ]
  end
end
