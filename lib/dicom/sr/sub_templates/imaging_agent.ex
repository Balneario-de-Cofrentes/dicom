defmodule Dicom.SR.SubTemplates.ImagingAgent do
  @moduledoc """
  Sub-templates for Imaging Agent Administration (TID 11002-11005, TID 11021).

  Shared building blocks for both Performed (TID 11020) and Planned (TID 11001)
  Imaging Agent Administration documents.

  Covers:
  - TID 11002 Agent Information
  - TID 11003 Administration Activity (performed and planned)
  - TID 11004 Patient Characteristics
  - TID 11005 Consumables
  - TID 11021 Adverse Events
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  @doc """
  TID 11002 -- Agent Information.

  Returns a CONTAINER with agent name and optional concentration and route.

  Options:
  - `:agent_name` (required) -- String.t() name of the imaging agent
  - `:concentration` (optional) -- {number(), Code.t()} value and units
  - `:route` (optional) -- Code.t() route of administration
  """
  @spec agent_information(keyword()) :: ContentItem.t()
  def agent_information(opts) when is_list(opts) do
    agent_name = Keyword.fetch!(opts, :agent_name)

    children =
      [ContentItem.text(Codes.imaging_agent(), agent_name, relationship_type: "CONTAINS")]
      |> maybe_add_concentration(opts[:concentration])
      |> maybe_add_route(opts[:route])

    ContentItem.container(Codes.imaging_agent(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 11003 -- Performed Administration Activity.

  Returns a CONTAINER with actual dose, volume, flow rate, timing,
  and injection site for a performed administration.

  Options:
  - `:dose` (optional) -- {number(), Code.t()}
  - `:volume` (optional) -- {number(), Code.t()}
  - `:flow_rate` (optional) -- {number(), Code.t()}
  - `:start_time` (optional) -- String.t() datetime
  - `:end_time` (optional) -- String.t() datetime
  - `:injection_site` (optional) -- String.t() or Code.t()
  """
  @spec performed_activity(keyword()) :: ContentItem.t() | nil
  def performed_activity(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_num(Codes.actual_dose(), opts[:dose])
      |> maybe_add_num(Codes.actual_volume(), opts[:volume])
      |> maybe_add_num(Codes.flow_rate(), opts[:flow_rate])
      |> maybe_add_datetime(Codes.start_datetime(), opts[:start_time])
      |> maybe_add_datetime(Codes.end_datetime(), opts[:end_time])
      |> maybe_add_injection_site(opts[:injection_site])

    if children == [] do
      nil
    else
      ContentItem.container(Codes.actual_dose(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  @doc """
  TID 11003 -- Planned Administration Activity.

  Returns a CONTAINER with planned dose, volume, and flow rate.

  Options:
  - `:dose` (optional) -- {number(), Code.t()}
  - `:volume` (optional) -- {number(), Code.t()}
  - `:flow_rate` (optional) -- {number(), Code.t()}
  """
  @spec planned_activity(keyword()) :: ContentItem.t() | nil
  def planned_activity(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_num(Codes.planned_dose(), opts[:dose])
      |> maybe_add_num(Codes.planned_volume(), opts[:volume])
      |> maybe_add_num(Codes.flow_rate(), opts[:flow_rate])

    if children == [] do
      nil
    else
      ContentItem.container(Codes.planned_dose(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  @doc """
  TID 11004 -- Patient Characteristics.

  Returns a CONTAINER with patient weight and kidney function for
  agent administration context.

  Options:
  - `:patient_weight` (optional) -- {number(), Code.t()}
  - `:kidney_function` (optional) -- {number(), Code.t()}
  """
  @spec patient_characteristics(keyword()) :: ContentItem.t() | nil
  def patient_characteristics(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_num(Codes.patient_weight(), opts[:patient_weight])
      |> maybe_add_num(Codes.kidney_function(), opts[:kidney_function])

    if children == [] do
      nil
    else
      ContentItem.container(Codes.patient_weight(),
        relationship_type: "HAS OBS CONTEXT",
        children: children
      )
    end
  end

  @doc """
  TID 11021 -- Adverse Events.

  Returns a list of TEXT or CODE content items for adverse events.
  """
  @spec adverse_events([String.t() | Code.t()]) :: [ContentItem.t()]
  def adverse_events(values) when is_list(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.adverse_event(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.adverse_event(), text, relationship_type: "CONTAINS")
    end)
  end

  @doc """
  TID 11005 -- Consumables.

  Returns a list of TEXT content items for consumables used during administration.
  """
  @spec consumables([String.t()]) :: [ContentItem.t()]
  def consumables(values) when is_list(values) do
    Enum.map(values, fn text when is_binary(text) ->
      ContentItem.text(Codes.consumable(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- Private Helpers --

  defp maybe_add_concentration(items, nil), do: items

  defp maybe_add_concentration(items, {value, %Code{} = units}) do
    items ++
      [ContentItem.num(Codes.agent_concentration(), value, units, relationship_type: "CONTAINS")]
  end

  defp maybe_add_route(items, nil), do: items

  defp maybe_add_route(items, %Code{} = route) do
    items ++
      [ContentItem.code(Codes.route_of_administration(), route, relationship_type: "CONTAINS")]
  end

  defp maybe_add_num(items, _concept, nil), do: items

  defp maybe_add_num(items, concept, {value, %Code{} = units}) do
    items ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
  end

  defp maybe_add_datetime(items, _concept, nil), do: items

  defp maybe_add_datetime(items, concept, value) do
    items ++ [ContentItem.datetime(concept, value, relationship_type: "CONTAINS")]
  end

  defp maybe_add_injection_site(items, nil), do: items

  defp maybe_add_injection_site(items, site) when is_binary(site) do
    items ++ [ContentItem.text(Codes.injection_site(), site, relationship_type: "CONTAINS")]
  end

  defp maybe_add_injection_site(items, %Code{} = site) do
    items ++ [ContentItem.code(Codes.injection_site(), site, relationship_type: "CONTAINS")]
  end
end
