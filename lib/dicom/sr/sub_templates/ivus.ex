defmodule Dicom.SR.SubTemplates.IVUS do
  @moduledoc """
  Sub-templates for Intravascular Ultrasound (IVUS) reports (TID 3251-3255).

  Covers:
  - TID 3251 IVUS Vessel
  - TID 3252 IVUS Lesion
  - TID 3253 IVUS Measurements
  - TID 3254 Qualitative Assessments
  - TID 3255 IVUS Volume Measurement
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}

  @doc """
  TID 3251 -- IVUS Vessel.

  Returns a CONTAINER for an IVUS-assessed vessel with a finding site
  and optional lesion and measurement children.

  Options:
  - `:vessel` (required) -- Code.t() identifying the vessel
  - `:lesions` (optional) -- list of ContentItem.t() from `lesion/1`
  - `:measurements` (optional) -- list of ContentItem.t() from `measurements/1`
  """
  @spec vessel(keyword()) :: ContentItem.t()
  def vessel(opts) when is_list(opts) do
    vessel_code = Keyword.fetch!(opts, :vessel)

    children =
      [
        ContentItem.code(Codes.finding_site(), vessel_code, relationship_type: "HAS CONCEPT MOD")
      ]
      |> append_items(Keyword.get(opts, :lesions, []))
      |> append_items(Keyword.get(opts, :measurements, []))

    ContentItem.container(Codes.ivus_vessel(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3252 -- IVUS Lesion.

  Returns a CONTAINER describing a single IVUS lesion with quantitative
  measurements and qualitative assessments.

  Options:
  - `:tracking_id` (required) -- String.t() lesion identifier
  - `:measurements` (optional) -- list of Measurement.t()
  - `:qualitative_assessments` (optional) -- list of ContentItem.t() from `qualitative_assessment/2`
  """
  @spec lesion(keyword()) :: ContentItem.t()
  def lesion(opts) when is_list(opts) do
    tracking_id = Keyword.fetch!(opts, :tracking_id)

    children =
      [
        ContentItem.text(Codes.tracking_identifier(), tracking_id,
          relationship_type: "HAS OBS CONTEXT"
        )
      ]
      |> append_measurements(Keyword.get(opts, :measurements, []))
      |> append_items(Keyword.get(opts, :qualitative_assessments, []))

    ContentItem.container(Codes.ivus_lesion(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3253 -- IVUS Measurements.

  Returns a list of NUM content items for standard IVUS cross-sectional
  measurements (lumen area, vessel area, plaque area, plaque burden,
  stenosis, diameters).
  """
  @spec measurements([Measurement.t()]) :: [ContentItem.t()]
  def measurements(measurement_list) when is_list(measurement_list) do
    Enum.map(measurement_list, &Measurement.to_content_item/1)
  end

  @doc """
  TID 3254 -- Qualitative Assessment.

  Returns a CODE content item for a qualitative IVUS observation
  (plaque morphology, remodeling pattern, etc.).
  """
  @spec qualitative_assessment(Code.t(), Code.t()) :: ContentItem.t()
  def qualitative_assessment(%Code{} = concept, %Code{} = value) do
    ContentItem.code(concept, value, relationship_type: "CONTAINS")
  end

  @doc """
  TID 3255 -- IVUS Volume Measurement.

  Returns a CONTAINER with volumetric IVUS measurements over a
  segment (lumen volume, vessel volume, plaque volume).

  Options:
  - `:tracking_id` (required) -- String.t() segment identifier
  - `:measurements` (required) -- list of Measurement.t()
  """
  @spec volume_measurement(keyword()) :: ContentItem.t()
  def volume_measurement(opts) when is_list(opts) do
    tracking_id = Keyword.fetch!(opts, :tracking_id)
    volume_measurements = Keyword.fetch!(opts, :measurements)

    children =
      [
        ContentItem.text(Codes.tracking_identifier(), tracking_id,
          relationship_type: "HAS OBS CONTEXT"
        )
      ]
      |> append_measurements(volume_measurements)

    ContentItem.container(Codes.ivus_volume(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Private Helpers --

  defp append_items(items, more), do: items ++ more

  defp append_measurements(items, measurement_list) do
    items ++ Enum.map(measurement_list, &Measurement.to_content_item/1)
  end
end
