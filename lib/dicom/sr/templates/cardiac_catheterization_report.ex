defmodule Dicom.SR.Templates.CardiacCatheterizationReport do
  @moduledoc """
  Builder for a practical TID 3800 Cardiac Catheterization Report document.

  The current builder covers the root document structure, observation context,
  procedure modifiers, patient history, patient presentation, procedure details
  (access site, catheters, PCI), findings (hemodynamic, LV, coronary), adverse
  outcomes, summary, and discharge summary.
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
      |> add_optional(optional_procedure_item(Keyword.get(opts, :procedure_reported)))
      |> add_optional(optional_history(Keyword.get(opts, :patient_history, [])))
      |> add_optional(optional_history(Keyword.get(opts, :patient_presentation, [])))
      |> add_optional(optional_procedure_section(Keyword.get(opts, :procedure)))
      |> add_optional(optional_findings_section(opts))
      |> add_optional(optional_adverse_outcomes(Keyword.get(opts, :adverse_outcomes, [])))
      |> add_optional(optional_text_section(Codes.conclusions(), Keyword.get(opts, :summary)))
      |> add_optional(
        optional_text_section(Codes.discharge_summary(), Keyword.get(opts, :discharge_summary))
      )
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))
      |> add_optional(map_recommendations(Keyword.get(opts, :recommendations, [])))

    root =
      ContentItem.container(Codes.cardiac_catheterization_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3800",
        series_description:
          Keyword.get(opts, :series_description, "Cardiac Catheterization Report")
      )
    )
  end

  # -- Procedure reported --

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  # -- Patient history / presentation --

  defp optional_history([]), do: nil

  defp optional_history(items) when is_list(items) do
    children =
      Enum.map(items, fn
        {concept, value} when is_binary(value) ->
          ContentItem.text(concept, value, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")

        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.history(),
      relationship_type: "HAS OBS CONTEXT",
      children: children
    )
  end

  # -- Procedure section --

  defp optional_procedure_section(nil), do: nil

  defp optional_procedure_section(procedure) when is_map(procedure) do
    children =
      []
      |> add_optional(optional_access_site(Map.get(procedure, :access_site)))
      |> add_optional(optional_catheters(Map.get(procedure, :catheters, [])))
      |> add_optional(optional_pci(Map.get(procedure, :pci)))

    ContentItem.container(Codes.current_procedure_descriptions(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_access_site(nil), do: nil

  defp optional_access_site(%Code{} = code) do
    ContentItem.code(Codes.access_site(), code, relationship_type: "CONTAINS")
  end

  defp optional_access_site(text) when is_binary(text) do
    ContentItem.text(Codes.access_site(), text, relationship_type: "CONTAINS")
  end

  defp optional_catheters([]), do: nil

  defp optional_catheters(catheters) when is_list(catheters) do
    Enum.map(catheters, fn
      %Code{} = code ->
        ContentItem.code(Codes.catheter_type(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.catheter_type(), text, relationship_type: "CONTAINS")
    end)
  end

  defp optional_pci(nil), do: nil

  defp optional_pci(pci) when is_map(pci) do
    children =
      []
      |> add_optional(optional_stent(Map.get(pci, :stent_placed)))
      |> add_optional(optional_pci_vessel(Map.get(pci, :vessel)))

    ContentItem.container(Codes.pci_procedure(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_stent(nil), do: nil

  defp optional_stent(%Code{} = code) do
    ContentItem.code(Codes.stent_placed(), code, relationship_type: "CONTAINS")
  end

  defp optional_stent(text) when is_binary(text) do
    ContentItem.text(Codes.stent_placed(), text, relationship_type: "CONTAINS")
  end

  defp optional_pci_vessel(nil), do: nil

  defp optional_pci_vessel(%Code{} = code) do
    ContentItem.code(Codes.finding_site(), code, relationship_type: "HAS CONCEPT MOD")
  end

  # -- Findings section --

  defp optional_findings_section(opts) do
    hemodynamic = Keyword.get(opts, :hemodynamic_findings, [])
    lv = Keyword.get(opts, :lv_findings)
    coronary = Keyword.get(opts, :coronary_findings, [])

    children =
      []
      |> add_optional(optional_hemodynamic_findings(hemodynamic))
      |> add_optional(optional_lv_findings(lv))
      |> add_optional(optional_coronary_findings(coronary))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.findings(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  defp optional_hemodynamic_findings([]), do: nil

  defp optional_hemodynamic_findings(measurements) when is_list(measurements) do
    ContentItem.container(Codes.hemodynamic_measurements(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end

  defp optional_lv_findings(nil), do: nil

  defp optional_lv_findings(lv) when is_map(lv) do
    children =
      []
      |> add_optional(optional_lv_ef(Map.get(lv, :ef)))
      |> add_optional(optional_lv_edp(Map.get(lv, :lvedp)))
      |> add_optional(optional_wall_motion(Map.get(lv, :wall_motion)))

    ContentItem.container(Codes.lv_findings(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_lv_ef(nil), do: nil

  defp optional_lv_ef(value) do
    ContentItem.num(Codes.lv_ejection_fraction(), value, Codes.percent(),
      relationship_type: "CONTAINS"
    )
  end

  defp optional_lv_edp(nil), do: nil

  defp optional_lv_edp(value) do
    ContentItem.num(Codes.lv_end_diastolic_pressure(), value, Codes.mmhg(),
      relationship_type: "CONTAINS"
    )
  end

  defp optional_wall_motion(nil), do: nil

  defp optional_wall_motion(%Code{} = code) do
    ContentItem.code(Codes.wall_motion_abnormality(), code, relationship_type: "CONTAINS")
  end

  defp optional_wall_motion(text) when is_binary(text) do
    ContentItem.text(Codes.wall_motion_abnormality(), text, relationship_type: "CONTAINS")
  end

  defp optional_coronary_findings([]), do: nil

  defp optional_coronary_findings(vessels) when is_list(vessels) do
    ContentItem.container(Codes.coronary_findings(),
      relationship_type: "CONTAINS",
      children: Enum.map(vessels, &vessel_finding/1)
    )
  end

  defp vessel_finding(vessel_map) when is_map(vessel_map) do
    vessel = Map.fetch!(vessel_map, :vessel)

    children =
      []
      |> add_optional(optional_stenosis(Map.get(vessel_map, :stenosis)))
      |> add_optional(optional_timi_flow(Map.get(vessel_map, :timi_flow)))

    ContentItem.container(vessel,
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_stenosis(nil), do: nil

  defp optional_stenosis(value) do
    ContentItem.num(Codes.coronary_stenosis(), value, Codes.percent(),
      relationship_type: "CONTAINS"
    )
  end

  defp optional_timi_flow(nil), do: nil

  defp optional_timi_flow(value) when is_binary(value) do
    ContentItem.text(Codes.timi_flow_grade(), value, relationship_type: "CONTAINS")
  end

  defp optional_timi_flow(%Code{} = code) do
    ContentItem.code(Codes.timi_flow_grade(), code, relationship_type: "CONTAINS")
  end

  # -- Adverse outcomes --

  defp optional_adverse_outcomes([]), do: nil

  defp optional_adverse_outcomes(outcomes) when is_list(outcomes) do
    Enum.map(outcomes, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- Text sections --

  defp optional_text_section(_concept, nil), do: nil

  defp optional_text_section(concept, text) when is_binary(text) do
    ContentItem.text(concept, text, relationship_type: "CONTAINS")
  end

  # -- Generic findings, impressions, recommendations --

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

  defp map_recommendations(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.recommendation(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.recommendation(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- Observer context --

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
