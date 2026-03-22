defmodule Dicom.SR.SubTemplates.RadiationDose do
  @moduledoc """
  Sub-templates for Radiation Dose reports (TID 10001-10013, 10021, 10030, 10040).

  Covers reusable building blocks shared across all five radiation dose templates:
  - TID 10012 CT Accumulated Dose Data
  - TID 10013 CT Irradiation Event Data
  - TID 10002 Accumulated X-Ray Dose Data
  - TID 10003 Irradiation Event X-Ray Data
  - Irradiation Event UID (shared reference item)
  - Generic dose measurement builder
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 10012: CT Accumulated Dose Data ------------------------------------

  @doc """
  TID 10012 -- CT Accumulated Dose Data.

  Returns a CONTAINER with CT accumulated dose measurements (total DLP).

  Options:
  - `:total_dlp` (optional) -- number, total dose-length product in mGy.cm
  """
  @spec ct_accumulated_dose(keyword()) :: ContentItem.t()
  def ct_accumulated_dose(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_dose(opts[:total_dlp], Codes.ct_dose_length_product_total(), Codes.mgy_cm())

    ContentItem.container(Codes.ct_accumulated_dose_data(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- TID 10013: CT Irradiation Event Data -----------------------------------

  @doc """
  TID 10013 -- CT Irradiation Event Data.

  Returns a CONTAINER with per-event CT dose metrics.

  Options:
  - `:irradiation_event_uid` (optional) -- String.t(), UID for this event
  - `:ct_acquisition_type` (optional) -- Code.t() (e.g. helical, axial, stationary)
  - `:ctdi_vol` (optional) -- number, CTDIvol in mGy
  - `:dlp` (optional) -- number, dose-length product in mGy.cm
  - `:scanning_length` (optional) -- number, in mm
  - `:mean_ctdi_vol` (optional) -- number, mean CTDIvol in mGy
  - `:phantom_type` (optional) -- Code.t() (e.g. body_phantom, head_phantom)
  """
  @spec ct_irradiation_event(keyword()) :: ContentItem.t()
  def ct_irradiation_event(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_uid(opts[:irradiation_event_uid])
      |> maybe_add_code(opts[:ct_acquisition_type], Codes.ct_acquisition_type())
      |> maybe_add_dose(opts[:ctdi_vol], Codes.ctdi_vol(), Codes.mgy())
      |> maybe_add_dose(opts[:dlp], Codes.dlp(), Codes.mgy_cm())
      |> maybe_add_dose(opts[:scanning_length], Codes.scanning_length(), Codes.millimeter())
      |> maybe_add_dose(opts[:mean_ctdi_vol], Codes.mean_ctdi_vol(), Codes.mgy())
      |> maybe_add_code(opts[:phantom_type], Codes.phantom_type())

    ContentItem.container(Codes.ct_irradiation_event_data(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- TID 10002: Accumulated X-Ray Dose Data ---------------------------------

  @doc """
  TID 10002 -- Accumulated X-Ray Dose Data.

  Returns a CONTAINER with accumulated projection X-ray dose measurements.

  Options:
  - `:total_dap` (optional) -- number, total dose area product in Gy.m2
  - `:fluoro_dap` (optional) -- number, fluoroscopy DAP in Gy.m2
  - `:acquisition_dap` (optional) -- number, acquisition DAP in Gy.m2
  - `:total_fluoro_time` (optional) -- number, in seconds
  - `:total_number_of_radiographic_frames` (optional) -- number, pulse count
  """
  @spec xray_accumulated_dose(keyword()) :: ContentItem.t()
  def xray_accumulated_dose(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_dose(opts[:total_dap], Codes.dose_area_product(), Codes.gy_cm2())
      |> maybe_add_dose(opts[:fluoro_dap], Codes.fluoro_dose_area_product(), Codes.gy_cm2())
      |> maybe_add_dose(
        opts[:acquisition_dap],
        Codes.acquisition_dose_area_product(),
        Codes.gy_cm2()
      )
      |> maybe_add_dose(opts[:total_fluoro_time], Codes.total_fluoro_time(), Codes.seconds())
      |> maybe_add_dose(
        opts[:total_number_of_radiographic_frames],
        Codes.total_number_of_radiographic_frames(),
        Codes.pulses()
      )

    ContentItem.container(Codes.accumulated_xray_dose(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- TID 10003: Irradiation Event X-Ray Data --------------------------------

  @doc """
  TID 10003 -- Irradiation Event X-Ray Data.

  Returns a CONTAINER with per-event projection X-ray dose metrics.

  Options:
  - `:irradiation_event_uid` (optional) -- String.t(), UID for this event
  - `:datetime_started` (optional) -- String.t(), DICOM DT of irradiation start
  - `:dose_rp` (optional) -- number, dose at reference point in mGy
  - `:dap` (optional) -- number, dose area product in Gy.m2
  - `:kvp` (optional) -- number, peak kilovoltage in kV
  - `:tube_current` (optional) -- number, tube current in mA
  - `:exposure_time` (optional) -- number, exposure time in seconds
  """
  @spec xray_irradiation_event(keyword()) :: ContentItem.t()
  def xray_irradiation_event(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_uid(opts[:irradiation_event_uid])
      |> maybe_add_datetime(opts[:datetime_started])
      |> maybe_add_dose(opts[:dose_rp], Codes.dose_rp(), Codes.mgy())
      |> maybe_add_dose(opts[:dap], Codes.dose_area_product(), Codes.gy_cm2())
      |> maybe_add_dose(opts[:kvp], Codes.kvp(), Codes.kilovolt())
      |> maybe_add_dose(opts[:tube_current], Codes.tube_current(), Codes.milliampere())
      |> maybe_add_dose(opts[:exposure_time], Codes.exposure_time(), Codes.seconds())

    ContentItem.container(Codes.irradiation_event_xray_data(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Shared Builders --------------------------------------------------------

  @doc """
  Builds a UIDREF content item for an Irradiation Event UID.

  Returns a single content item referencing the given UID string.
  """
  @spec irradiation_event_uid(String.t()) :: ContentItem.t()
  def irradiation_event_uid(uid) when is_binary(uid) do
    ContentItem.uidref(Codes.irradiation_event_uid(), uid, relationship_type: "CONTAINS")
  end

  @doc """
  Generic dose NUM builder.

  Builds a NUM content item for a dose measurement with the given concept code,
  numeric value, and unit code.
  """
  @spec dose_measurement(Code.t(), number(), Code.t()) :: ContentItem.t()
  def dose_measurement(%Code{} = concept, value, %Code{} = units) when is_number(value) do
    ContentItem.num(concept, value, units, relationship_type: "CONTAINS")
  end

  # -- Private Helpers --------------------------------------------------------

  defp maybe_add_dose(children, nil, _concept, _units), do: children

  defp maybe_add_dose(children, value, concept, units) when is_number(value) do
    children ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
  end

  defp maybe_add_uid(children, nil), do: children

  defp maybe_add_uid(children, uid) when is_binary(uid) do
    children ++
      [ContentItem.uidref(Codes.irradiation_event_uid(), uid, relationship_type: "CONTAINS")]
  end

  defp maybe_add_code(children, nil, _concept), do: children

  defp maybe_add_code(children, %Code{} = value, concept) do
    children ++ [ContentItem.code(concept, value, relationship_type: "CONTAINS")]
  end

  defp maybe_add_datetime(children, nil), do: children

  defp maybe_add_datetime(children, dt) when is_binary(dt) do
    children ++
      [ContentItem.datetime(Codes.datetime_started(), dt, relationship_type: "CONTAINS")]
  end
end
