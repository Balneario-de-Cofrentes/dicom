defmodule Dicom.SR.LogEntry do
  @moduledoc """
  A single log entry for a TID 3001 Procedure Log document.

  Each entry captures an event that occurred during an interventional or
  imaging procedure: its timestamp, the type of action, and a description.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  @enforce_keys [:datetime, :action_type, :description]
  defstruct [
    :datetime,
    :action_type,
    :description,
    details: []
  ]

  @type action_type :: :image_acquisition | :drug_administered | :measurement | :text

  @type t :: %__MODULE__{
          datetime: DateTime.t() | NaiveDateTime.t() | String.t(),
          action_type: action_type(),
          description: String.t() | Code.t(),
          details: keyword()
        }

  @spec new(
          DateTime.t() | NaiveDateTime.t() | String.t(),
          action_type(),
          String.t() | Code.t(),
          keyword()
        ) :: t()
  def new(datetime, action_type, description, details \\ [])
      when action_type in [:image_acquisition, :drug_administered, :measurement, :text] do
    %__MODULE__{
      datetime: datetime,
      action_type: action_type,
      description: description,
      details: details
    }
  end

  @spec to_content_item(t()) :: ContentItem.t()
  def to_content_item(%__MODULE__{} = entry) do
    children =
      [
        ContentItem.datetime(Codes.log_entry_datetime(), entry.datetime,
          relationship_type: "HAS CONCEPT MOD"
        ),
        action_item(entry.action_type, entry.description)
      ]
      |> add_optional(detail_items(entry.details))

    ContentItem.container(Codes.log_entry(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp action_item(action_type, %Code{} = description) do
    ContentItem.code(action_type_code(action_type), description, relationship_type: "CONTAINS")
  end

  defp action_item(action_type, description) when is_binary(description) do
    ContentItem.text(action_type_code(action_type), description, relationship_type: "CONTAINS")
  end

  defp action_type_code(:image_acquisition), do: Codes.image_acquisition()
  defp action_type_code(:drug_administered), do: Codes.drug_administered()
  defp action_type_code(:measurement), do: Codes.procedure_action()
  defp action_type_code(:text), do: Codes.procedure_action()

  defp detail_items(details) do
    Enum.map(details, fn
      {:consumable, %Code{} = code} ->
        ContentItem.code(Codes.consumable_used(), code, relationship_type: "CONTAINS")

      {:consumable, text} when is_binary(text) ->
        ContentItem.text(Codes.consumable_used(), text, relationship_type: "CONTAINS")
    end)
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
