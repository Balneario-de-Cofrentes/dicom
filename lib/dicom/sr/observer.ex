defmodule Dicom.SR.Observer do
  @moduledoc """
  Observation context helpers for SR documents.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  @spec language(Code.t()) :: ContentItem.t()
  def language(%Code{} = language_code) do
    ContentItem.code(
      Codes.language_of_content_item_and_descendants(),
      language_code,
      relationship_type: "HAS CONCEPT MOD"
    )
  end

  @spec person(String.t()) :: [ContentItem.t()]
  def person(name) when is_binary(name) do
    [
      ContentItem.code(Codes.observer_type(), Codes.person(),
        relationship_type: "HAS OBS CONTEXT"
      ),
      ContentItem.pname(Codes.person_observer_name(), name, relationship_type: "HAS OBS CONTEXT")
    ]
  end
end
