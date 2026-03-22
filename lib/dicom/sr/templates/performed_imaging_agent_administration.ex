defmodule Dicom.SR.Templates.PerformedImagingAgentAdministration do
  @moduledoc """
  Builder for a practical TID 11020 Performed Imaging Agent Administration document.

  This builder covers the root document structure, observation context,
  agent information (TID 11002), performed administration activity (TID 11003)
  with actual volumes and timing, adverse events (TID 11021), and
  consumables (TID 11005).
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    agent_name = Keyword.fetch!(opts, :agent_name)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(agent_information_items(agent_name, opts))
      |> add_optional(administration_activity_items(opts))
      |> add_optional(adverse_event_items(opts[:adverse_events]))
      |> add_optional(consumable_items(opts[:consumables]))

    root = ContentItem.container(Codes.performed_imaging_agent_admin(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "11020",
        series_description:
          Keyword.get(opts, :series_description, "Performed Imaging Agent Administration")
      )
    )
  end

  defp agent_information_items(agent_name, opts) do
    children =
      [
        ContentItem.text(Codes.imaging_agent(), agent_name, relationship_type: "CONTAINS")
      ]
      |> add_optional(optional_concentration(opts[:concentration]))
      |> add_optional(optional_route(opts[:route]))

    [
      ContentItem.container(Codes.imaging_agent(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  defp administration_activity_items(opts) do
    children =
      []
      |> add_optional(optional_num(Codes.actual_dose(), opts[:dose]))
      |> add_optional(optional_num(Codes.actual_volume(), opts[:volume]))
      |> add_optional(optional_num(Codes.flow_rate(), opts[:flow_rate]))
      |> add_optional(optional_datetime(Codes.start_datetime(), opts[:start_time]))
      |> add_optional(optional_datetime(Codes.end_datetime(), opts[:end_time]))
      |> add_optional(optional_injection_site(opts[:injection_site]))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.actual_dose(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  defp adverse_event_items(nil), do: nil
  defp adverse_event_items([]), do: nil

  defp adverse_event_items(events) when is_list(events) do
    Enum.map(events, fn
      %Code{} = code ->
        ContentItem.code(Codes.adverse_event(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.adverse_event(), text, relationship_type: "CONTAINS")
    end)
  end

  defp consumable_items(nil), do: nil
  defp consumable_items([]), do: nil

  defp consumable_items(items) when is_list(items) do
    Enum.map(items, fn text when is_binary(text) ->
      ContentItem.text(Codes.consumable(), text, relationship_type: "CONTAINS")
    end)
  end

  defp optional_concentration(nil), do: nil

  defp optional_concentration({value, %Code{} = units}) do
    ContentItem.num(Codes.agent_concentration(), value, units, relationship_type: "CONTAINS")
  end

  defp optional_route(nil), do: nil

  defp optional_route(%Code{} = route) do
    ContentItem.code(Codes.route_of_administration(), route, relationship_type: "CONTAINS")
  end

  defp optional_num(_concept, nil), do: nil

  defp optional_num(concept, {value, %Code{} = units}) do
    ContentItem.num(concept, value, units, relationship_type: "CONTAINS")
  end

  defp optional_datetime(_concept, nil), do: nil

  defp optional_datetime(concept, value) do
    ContentItem.datetime(concept, value, relationship_type: "CONTAINS")
  end

  defp optional_injection_site(nil), do: nil

  defp optional_injection_site(site) when is_binary(site) do
    ContentItem.text(Codes.injection_site(), site, relationship_type: "CONTAINS")
  end

  defp optional_injection_site(%Code{} = site) do
    ContentItem.code(Codes.injection_site(), site, relationship_type: "CONTAINS")
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
