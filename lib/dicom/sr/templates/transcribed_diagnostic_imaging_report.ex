defmodule Dicom.SR.Templates.TranscribedDiagnosticImagingReport do
  @moduledoc """
  Builder for a TID 2005 Transcribed Diagnostic Imaging Report document.

  This template represents a simple text-based SR document for transcribed or
  dictated radiology reports. The root container holds observer context for the
  dictating physician, an optional transcriber, the procedure reported, and a
  free-text narrative of the report.

  Structure:

      CONTAINER: Radiology Study observation (narrative)
        +-- HAS CONCEPT MOD: Language (optional, defaults to en-US)
        +-- HAS OBS CONTEXT: Observer (person — dictating physician)
        +-- HAS OBS CONTEXT: Observer (person — transcriber, optional)
        +-- HAS CONCEPT MOD: Procedure Reported (optional)
        +-- CONTAINS: Narrative Summary (TEXT)
        +-- CONTAINS: Clinical Information (TEXT, optional)

  SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.11 (Basic Text SR Storage)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    narrative = Keyword.fetch!(opts, :narrative)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(Observer.person(observer_name))
      |> add_optional(optional_transcriber(opts[:transcriber_name]))
      |> add_optional(procedure_items(Keyword.get(opts, :procedure_reported, [])))
      |> add_optional([narrative_item(narrative)])
      |> add_optional(optional_clinical_information(opts[:clinical_information]))

    root =
      ContentItem.container(Codes.transcribed_diagnostic_imaging_report(),
        children: root_children
      )

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "2005",
        sop_class_uid: Dicom.UID.basic_text_sr_storage(),
        series_description:
          Keyword.get(opts, :series_description, "Transcribed Diagnostic Imaging Report")
      )
    )
  end

  defp narrative_item(text) when is_binary(text) do
    ContentItem.text(Codes.report_narrative(), text, relationship_type: "CONTAINS")
  end

  defp optional_transcriber(nil), do: nil

  defp optional_transcriber(name) when is_binary(name) do
    Observer.person(name)
  end

  defp procedure_items([]), do: nil

  defp procedure_items(procedures) do
    Enum.map(List.wrap(procedures), fn %Code{} = code ->
      ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
    end)
  end

  defp optional_clinical_information(nil), do: nil

  defp optional_clinical_information(text) when is_binary(text) do
    ContentItem.text(Codes.clinical_information(), text, relationship_type: "CONTAINS")
  end
end
