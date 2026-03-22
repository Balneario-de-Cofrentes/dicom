defmodule Dicom.SR.SubTemplates.CardiacCatheterization do
  @moduledoc """
  TID 3800 Cardiac Catheterization Sub-Templates.

  Provides reusable builders for the structural components of a cardiac
  catheterization report:

  - Procedure section (access site, catheters, PCI with stent/vessel)
  - PCI procedure sub-container
  - LV findings (ejection fraction, LVEDP, wall motion)
  - Coronary findings (vessel container with per-vessel findings)
  - Individual vessel finding (stenosis + TIMI flow)
  - Adverse outcomes

  These sub-templates are used by
  `Dicom.SR.Templates.CardiacCatheterizationReport` and can be composed
  independently for programmatic SR document construction.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- Procedure Section (TID ~3200) ------------------------------------------

  @doc """
  Builds a procedure section container with access site, catheters, and PCI.

  ## Options

    * `:access_site` -- access site as `Code.t()` or `String.t()`
    * `:catheters` -- list of catheter types (`Code.t()` or `String.t()`)
    * `:pci` -- PCI procedure map (see `pci_procedure/1`)

  Returns a CONTAINER content item with concept Current Procedure Descriptions.
  """
  @spec procedure_section(keyword()) :: ContentItem.t()
  def procedure_section(opts \\ []) do
    children =
      []
      |> add_access_site(opts[:access_site])
      |> add_catheters(Keyword.get(opts, :catheters, []))
      |> add_pci(opts[:pci])

    ContentItem.container(Codes.current_procedure_descriptions(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- PCI Procedure ----------------------------------------------------------

  @doc """
  Builds a PCI procedure sub-container with stent and vessel information.

  ## Options

    * `:stent_placed` -- stent type as `Code.t()` or `String.t()`
    * `:vessel` -- target vessel as `Code.t()`

  Returns a CONTAINER content item with concept PCI Procedure.
  """
  @spec pci_procedure(keyword()) :: ContentItem.t()
  def pci_procedure(opts \\ []) do
    children =
      []
      |> add_stent(opts[:stent_placed])
      |> add_vessel_modifier(opts[:vessel])

    ContentItem.container(Codes.pci_procedure(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- LV Findings ------------------------------------------------------------

  @doc """
  Builds an LV findings container with ejection fraction, LVEDP, and wall motion.

  ## Options

    * `:ef` -- ejection fraction (number, percent)
    * `:lvedp` -- left ventricular end-diastolic pressure (number, mmHg)
    * `:wall_motion` -- wall motion as `Code.t()` or `String.t()`

  Returns a CONTAINER content item with concept LV Findings.
  """
  @spec lv_findings(keyword()) :: ContentItem.t()
  def lv_findings(opts \\ []) do
    children =
      []
      |> add_ef(opts[:ef])
      |> add_lvedp(opts[:lvedp])
      |> add_wall_motion(opts[:wall_motion])

    ContentItem.container(Codes.lv_findings(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Coronary Findings ------------------------------------------------------

  @doc """
  Builds a coronary findings container with individual vessel findings.

  ## Options

    * `:vessels` -- list of keyword options for `vessel_finding/1`

  Returns a CONTAINER content item with concept Coronary Findings.
  """
  @spec coronary_findings(keyword()) :: ContentItem.t()
  def coronary_findings(opts \\ []) do
    vessels = Keyword.get(opts, :vessels, [])

    children = Enum.map(vessels, &vessel_finding/1)

    ContentItem.container(Codes.coronary_findings(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Vessel Finding ---------------------------------------------------------

  @doc """
  Builds a single vessel finding container with stenosis and TIMI flow.

  ## Options

    * `:vessel` (required) -- vessel Code.t() (e.g. `Codes.left_anterior_descending_artery()`)
    * `:stenosis` -- percent stenosis (number)
    * `:timi_flow` -- TIMI flow grade as `Code.t()` or `String.t()`

  Returns a CONTAINER content item using the vessel code as concept.
  """
  @spec vessel_finding(keyword()) :: ContentItem.t()
  def vessel_finding(opts) when is_list(opts) do
    vessel = Keyword.fetch!(opts, :vessel)

    children =
      []
      |> add_stenosis(opts[:stenosis])
      |> add_timi_flow(opts[:timi_flow])

    ContentItem.container(vessel,
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Adverse Outcomes -------------------------------------------------------

  @doc """
  Builds a list of adverse outcome content items.

  Each outcome may be a `Code.t()` or a `String.t()` and is wrapped as a
  finding content item. Returns an empty list when given no outcomes.

  ## Options

    * `:outcomes` -- list of `Code.t()` or `String.t()` values

  """
  @spec adverse_outcomes(keyword()) :: [ContentItem.t()]
  def adverse_outcomes(opts \\ []) do
    outcomes = Keyword.get(opts, :outcomes, [])

    Enum.map(outcomes, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- Private helpers --------------------------------------------------------

  defp add_access_site(items, nil), do: items

  defp add_access_site(items, %Code{} = code) do
    items ++ [ContentItem.code(Codes.access_site(), code, relationship_type: "CONTAINS")]
  end

  defp add_access_site(items, text) when is_binary(text) do
    items ++ [ContentItem.text(Codes.access_site(), text, relationship_type: "CONTAINS")]
  end

  defp add_catheters(items, []), do: items

  defp add_catheters(items, catheters) do
    items ++
      Enum.map(catheters, fn
        %Code{} = code ->
          ContentItem.code(Codes.catheter_type(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.catheter_type(), text, relationship_type: "CONTAINS")
      end)
  end

  defp add_pci(items, nil), do: items

  defp add_pci(items, pci_opts) when is_list(pci_opts) do
    items ++ [pci_procedure(pci_opts)]
  end

  defp add_stent(items, nil), do: items

  defp add_stent(items, %Code{} = code) do
    items ++ [ContentItem.code(Codes.stent_placed(), code, relationship_type: "CONTAINS")]
  end

  defp add_stent(items, text) when is_binary(text) do
    items ++ [ContentItem.text(Codes.stent_placed(), text, relationship_type: "CONTAINS")]
  end

  defp add_vessel_modifier(items, nil), do: items

  defp add_vessel_modifier(items, %Code{} = code) do
    items ++ [ContentItem.code(Codes.finding_site(), code, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_ef(items, nil), do: items

  defp add_ef(items, value) when is_number(value) do
    items ++
      [
        ContentItem.num(Codes.lv_ejection_fraction(), value, Codes.percent(),
          relationship_type: "CONTAINS"
        )
      ]
  end

  defp add_lvedp(items, nil), do: items

  defp add_lvedp(items, value) when is_number(value) do
    items ++
      [
        ContentItem.num(Codes.lv_end_diastolic_pressure(), value, Codes.mmhg(),
          relationship_type: "CONTAINS"
        )
      ]
  end

  defp add_wall_motion(items, nil), do: items

  defp add_wall_motion(items, %Code{} = code) do
    items ++
      [ContentItem.code(Codes.wall_motion_abnormality(), code, relationship_type: "CONTAINS")]
  end

  defp add_wall_motion(items, text) when is_binary(text) do
    items ++
      [ContentItem.text(Codes.wall_motion_abnormality(), text, relationship_type: "CONTAINS")]
  end

  defp add_stenosis(items, nil), do: items

  defp add_stenosis(items, value) when is_number(value) do
    items ++
      [
        ContentItem.num(Codes.coronary_stenosis(), value, Codes.percent(),
          relationship_type: "CONTAINS"
        )
      ]
  end

  defp add_timi_flow(items, nil), do: items

  defp add_timi_flow(items, %Code{} = code) do
    items ++ [ContentItem.code(Codes.timi_flow_grade(), code, relationship_type: "CONTAINS")]
  end

  defp add_timi_flow(items, text) when is_binary(text) do
    items ++ [ContentItem.text(Codes.timi_flow_grade(), text, relationship_type: "CONTAINS")]
  end
end
