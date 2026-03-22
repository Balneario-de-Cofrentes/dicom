defmodule Dicom.SR.Templates.Helpers do
  @moduledoc false

  alias Dicom.SR.{Code, Codes, ContentItem, Observer}

  def add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)

  def observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  def map_findings(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  def map_impressions(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
    end)
  end

  def map_recommendations(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.recommendation(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.recommendation(), text, relationship_type: "CONTAINS")
    end)
  end

  def procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end
end
