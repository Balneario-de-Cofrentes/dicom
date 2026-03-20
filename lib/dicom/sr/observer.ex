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

  @spec device(keyword()) :: [ContentItem.t()]
  def device(opts) when is_list(opts) do
    uid = Keyword.fetch!(opts, :uid)

    [
      ContentItem.code(Codes.observer_type(), Codes.device(),
        relationship_type: "HAS OBS CONTEXT"
      ),
      ContentItem.uidref(Codes.device_observer_uid(), uid, relationship_type: "HAS OBS CONTEXT")
    ]
    |> maybe_add_text(Codes.device_observer_name(), opts[:name])
    |> maybe_add_text(Codes.device_observer_manufacturer(), opts[:manufacturer])
    |> maybe_add_text(Codes.device_observer_model_name(), opts[:model_name])
    |> maybe_add_text(Codes.device_observer_serial_number(), opts[:serial_number])
  end

  defp maybe_add_text(items, _concept_name, nil), do: items

  defp maybe_add_text(items, concept_name, value) when is_binary(value) do
    items ++ [ContentItem.text(concept_name, value, relationship_type: "HAS OBS CONTEXT")]
  end
end
