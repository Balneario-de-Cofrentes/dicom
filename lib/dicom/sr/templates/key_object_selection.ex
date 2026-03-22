defmodule Dicom.SR.Templates.KeyObjectSelection do
  @moduledoc """
  Builder for a TID 2000 Key Object Selection document.

  KOS documents flag significant images within a study. The root container
  holds an observer context, a textual description explaining the selection,
  and one or more IMAGE references to the flagged instances.

  Structure:

      CONTAINER: Key Object Selection (root concept = "Of Interest" or rejection code)
        ├── HAS CONCEPT MOD: Language (optional, defaults to en-US)
        ├── HAS OBS CONTEXT: Observer (person and/or device)
        ├── CONTAINS: Key Object Description (TEXT) — reason for selection
        └── CONTAINS: IMAGE references (1-n) — the flagged images

  SOP Class UID: 1.2.840.10008.5.1.4.1.1.88.59 (Key Object Selection Document)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer, Reference}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    references = Keyword.fetch!(opts, :references)

    if references == [] do
      {:error, :no_references}
    else
      build_document(opts, observer_name, references)
    end
  end

  defp build_document(opts, observer_name, references) do
    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    title_code = Keyword.get(opts, :title_code, Codes.key_object_selection())

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_description(Keyword.get(opts, :description)))
      |> add_optional(image_items(references))

    root = ContentItem.container(title_code, children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "2000",
        sop_class_uid: Dicom.UID.key_object_selection_document_storage(),
        series_description: Keyword.get(opts, :series_description, "Key Object Selection")
      )
    )
  end

  defp optional_description(nil), do: nil

  defp optional_description(text) when is_binary(text) do
    ContentItem.text(Codes.key_object_description(), text, relationship_type: "CONTAINS")
  end

  defp image_items(references) do
    Enum.map(references, fn %Reference{} = reference ->
      ContentItem.image(Codes.source(), reference, relationship_type: "CONTAINS")
    end)
  end
end
