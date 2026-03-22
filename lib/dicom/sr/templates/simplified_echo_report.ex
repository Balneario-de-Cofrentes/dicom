defmodule Dicom.SR.Templates.SimplifiedEchoReport do
  @moduledoc """
  Builder for a practical TID 5300 Simplified Echo Procedure Report document.

  The current builder covers the root title, observer context, pre-coordinated
  measurements (TID 5301), post-coordinated measurements (TID 5302), adhoc
  measurements (TID 5303), findings, and impressions.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, Observer}

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
        optional_measurement_section(
          Codes.pre_coordinated_measurements(),
          Keyword.get(opts, :pre_coordinated_measurements, [])
        )
      )
      |> add_optional(
        optional_measurement_section(
          Codes.post_coordinated_measurements(),
          Keyword.get(opts, :post_coordinated_measurements, [])
        )
      )
      |> add_optional(
        optional_measurement_section(
          Codes.adhoc_measurements(),
          Keyword.get(opts, :adhoc_measurements, [])
        )
      )
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))

    root = ContentItem.container(Codes.simplified_echo_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "5300",
        series_description:
          Keyword.get(opts, :series_description, "Simplified Echo Procedure Report")
      )
    )
  end

  defp optional_measurement_section(_concept, []), do: nil

  defp optional_measurement_section(concept, measurements) do
    ContentItem.container(concept,
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end

  defp map_findings(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  defp map_impressions(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
    end)
  end

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
