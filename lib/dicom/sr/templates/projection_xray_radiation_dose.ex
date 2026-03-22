defmodule Dicom.SR.Templates.ProjectionXRayRadiationDose do
  @moduledoc """
  Builder for a practical TID 10001 Projection X-Ray Radiation Dose Report.

  This builder covers the root document structure, observation context,
  procedure-reported modifier, accumulated X-Ray dose data (TID 10002),
  and irradiation event data (TID 10003).

  Reference: DICOM PS3.16 TID 10001.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    accumulated_dose = Keyword.fetch!(opts, :accumulated_dose)
    procedure_reported = Keyword.get(opts, :procedure_reported)
    irradiation_events = Keyword.get(opts, :irradiation_events, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional([accumulated_xray_dose_item(accumulated_dose)])
      |> add_optional(Enum.map(irradiation_events, &irradiation_event_item/1))

    root = ContentItem.container(Codes.xray_radiation_dose_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "10001",
        series_description: Keyword.get(opts, :series_description, "X-Ray Radiation Dose Report"),
        sop_class_uid:
          Keyword.get(opts, :sop_class_uid, Dicom.UID.xray_radiation_dose_sr_storage())
      )
    )
  end

  # TID 10002: Accumulated X-Ray Dose Data
  defp accumulated_xray_dose_item(dose) when is_map(dose) do
    children =
      []
      |> add_dose_num(:total_dap, Codes.dose_area_product(), Codes.gy_cm2(), dose)
      |> add_dose_num(:fluoro_dap, Codes.fluoro_dose_area_product(), Codes.gy_cm2(), dose)
      |> add_dose_num(
        :acquisition_dap,
        Codes.acquisition_dose_area_product(),
        Codes.gy_cm2(),
        dose
      )
      |> add_dose_num(:total_fluoro_time, Codes.total_fluoro_time(), Codes.seconds(), dose)
      |> add_dose_num(
        :total_number_of_radiographic_frames,
        Codes.total_number_of_radiographic_frames(),
        Codes.pulses(),
        dose
      )

    ContentItem.container(Codes.accumulated_xray_dose(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # TID 10003: Irradiation Event X-Ray Data
  defp irradiation_event_item(event) when is_map(event) do
    children =
      []
      |> add_event_uid(event)
      |> add_event_datetime(event)
      |> add_dose_num(:dose_rp, Codes.dose_rp(), Codes.mgy(), event)
      |> add_dose_num(:dap, Codes.dose_area_product(), Codes.gy_cm2(), event)
      |> add_dose_num(:kvp, Codes.kvp(), Codes.kilovolt(), event)
      |> add_dose_num(:tube_current, Codes.tube_current(), Codes.milliampere(), event)
      |> add_dose_num(:exposure_time, Codes.exposure_time(), Codes.seconds(), event)

    ContentItem.container(Codes.irradiation_event_xray_data(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp add_event_uid(children, event) do
    case Map.get(event, :irradiation_event_uid) do
      nil ->
        children

      uid ->
        children ++
          [ContentItem.uidref(Codes.irradiation_event_uid(), uid, relationship_type: "CONTAINS")]
    end
  end

  defp add_event_datetime(children, event) do
    case Map.get(event, :datetime_started) do
      nil ->
        children

      dt ->
        children ++
          [ContentItem.datetime(Codes.datetime_started(), dt, relationship_type: "CONTAINS")]
    end
  end

  defp add_dose_num(children, key, concept, units, data) do
    case Map.get(data, key) do
      nil -> children
      value -> children ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
    end
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end
end
