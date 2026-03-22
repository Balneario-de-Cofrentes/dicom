defmodule Dicom.SR.Templates.Helpers do
  @moduledoc false

  alias Dicom.SR.{Code, Codes, ContentItem, ContextGroup, Observer}

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

  @doc """
  Validates a code against a context group, raising on non-extensible rejection.

  Returns the code unchanged if valid. Raises `ArgumentError` if the code is not
  a member of a non-extensible CID. Unknown CIDs are silently passed through.
  """
  @spec validate_code!(Code.t(), non_neg_integer(), String.t()) :: Code.t()
  def validate_code!(%Code{} = code, cid, field_name) when is_integer(cid) do
    case ContextGroup.validate(code, cid) do
      :ok ->
        code

      {:ok, :extensible} ->
        code

      {:error, :not_in_cid} ->
        raise ArgumentError,
              "#{field_name}: code #{code.scheme_designator}:#{code.value} " <>
                "is not a member of CID #{cid}"

      {:error, :unknown_cid} ->
        code
    end
  end
end
