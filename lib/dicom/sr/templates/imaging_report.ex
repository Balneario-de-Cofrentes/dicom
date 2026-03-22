defmodule Dicom.SR.Templates.ImagingReport do
  @moduledoc """
  Builder for a TID 2006 Imaging Report With Conditional Radiation Exposure.

  Extension of a basic diagnostic imaging report that conditionally includes
  radiation exposure information when the modality involves ionizing radiation.

  Structure:

      CONTAINER: Diagnostic Imaging Report (root)
        +-- HAS CONCEPT MOD: Language
        +-- HAS OBS CONTEXT: Observer (person and/or device)
        +-- HAS CONCEPT MOD: Procedure Reported (1-n)
        +-- CONTAINS: Procedure Description (TEXT, optional)
        +-- CONTAINS: Findings (TEXT) -- report narrative
        +-- CONTAINS: Impression (TEXT/CODE, 0-n)
        +-- CONTAINS: Recommendation (TEXT/CODE, 0-n)
        +-- CONTAINS: CT Radiation Dose (CONTAINER, conditional on ionizing modality)
            +-- CONTAINS: Mean CTDIvol (NUM, optional)
            +-- CONTAINS: DLP (NUM, optional)

  SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.33 (Comprehensive SR Storage)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

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
      |> add_optional(
        Enum.map(List.wrap(Keyword.get(opts, :procedure_reported, [])), &procedure_item/1)
      )
      |> add_optional(optional_procedure_description(Keyword.get(opts, :procedure_description)))
      |> add_optional(optional_narrative(Keyword.get(opts, :narrative)))
      |> add_optional(map_text_or_code(Keyword.get(opts, :impressions, []), Codes.impression()))
      |> add_optional(
        map_text_or_code(Keyword.get(opts, :recommendations, []), Codes.recommendation())
      )
      |> add_optional(optional_radiation_exposure(Keyword.get(opts, :radiation_exposure)))

    root = ContentItem.container(Codes.imaging_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "2006",
        series_description: Keyword.get(opts, :series_description, "Imaging Report")
      )
    )
  end

  defp optional_procedure_description(nil), do: nil

  defp optional_procedure_description(description) when is_binary(description) do
    ContentItem.text(Codes.procedure_description(), description, relationship_type: "CONTAINS")
  end

  defp optional_narrative(nil), do: nil

  defp optional_narrative(text) when is_binary(text) do
    ContentItem.text(Codes.report_narrative(), text, relationship_type: "CONTAINS")
  end

  defp optional_radiation_exposure(nil), do: nil

  defp optional_radiation_exposure(opts) when is_list(opts) do
    children =
      []
      |> add_optional(optional_num(opts[:ctdivol], Codes.mean_ctdivol(), mgy_unit()))
      |> add_optional(optional_num(opts[:dlp], Codes.dlp(), mgy_cm_unit()))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.radiation_exposure(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  defp optional_num(nil, _concept, _unit), do: nil

  defp optional_num(value, concept, unit) do
    ContentItem.num(concept, value, unit, relationship_type: "CONTAINS")
  end

  defp mgy_unit, do: Code.new("mGy", "UCUM", "mGy")
  defp mgy_cm_unit, do: Code.new("mGy.cm", "UCUM", "mGy.cm")

  defp map_text_or_code(values, concept_code) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(concept_code, code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(concept_code, text, relationship_type: "CONTAINS")
    end)
  end
end
