defmodule Dicom.SR.Templates.ProcedureLog do
  @moduledoc """
  Builder for a practical TID 3001 Procedure Log document.

  A Procedure Log is an event-based SR document recording what happened during
  an interventional or imaging procedure. Each event is captured as a log entry
  with a timestamp, action type, and description.

  Structure:

      CONTAINER: Procedure Log
        +-- HAS CONCEPT MOD: Language (TID 1204)
        +-- HAS OBS CONTEXT: Observer Context (TID 1002)
        +-- HAS CONCEPT MOD: Procedure Reported (optional, repeating)
        +-- CONTAINS: Log Entry (repeating)
              +-- HAS CONCEPT MOD: Log Entry DateTime
              +-- CONTAINS: Procedure Action / Image Acquisition / Drug Administered
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, LogEntry, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    log_entries = Keyword.fetch!(opts, :log_entries)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(procedure_items(Keyword.get(opts, :procedure_reported, [])))
      |> add_optional(Enum.map(log_entries, &LogEntry.to_content_item/1))

    root = ContentItem.container(Codes.procedure_log(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3001",
        series_description: Keyword.get(opts, :series_description, "Procedure Log")
      )
    )
  end

  defp procedure_items(procedures) do
    procedures
    |> List.wrap()
    |> Enum.map(fn %Code{} = code ->
      ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
    end)
  end
end
