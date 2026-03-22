defmodule Dicom.SR.Templates.PlannedImagingAgentAdministration do
  @moduledoc """
  Builder for a practical TID 11001 Planned Imaging Agent Administration document.

  This builder covers the root document structure, observation context,
  agent information (TID 11002), planned administration activity (TID 11003),
  and patient characteristics (TID 10024).
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
      |> add_optional(patient_characteristics_items(opts))

    root = ContentItem.container(Codes.planned_imaging_agent_admin(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "11001",
        series_description:
          Keyword.get(opts, :series_description, "Planned Imaging Agent Administration")
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
      |> add_optional(optional_num(Codes.planned_dose(), opts[:dose]))
      |> add_optional(optional_num(Codes.planned_volume(), opts[:volume]))
      |> add_optional(optional_num(Codes.flow_rate(), opts[:flow_rate]))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.planned_dose(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  defp patient_characteristics_items(opts) do
    children =
      []
      |> add_optional(optional_num(Codes.patient_weight(), opts[:patient_weight]))
      |> add_optional(optional_num(Codes.kidney_function(), opts[:kidney_function]))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.patient_weight(),
        relationship_type: "HAS OBS CONTEXT",
        children: children
      )
    end
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

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
