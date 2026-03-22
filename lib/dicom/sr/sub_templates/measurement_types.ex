defmodule Dicom.SR.SubTemplates.MeasurementTypes do
  @moduledoc """
  TID 1400-1420 Measurement Type Sub-Templates.

  Implements the measurement type sub-template hierarchy:

  - TID 1400 — Linear Measurement
  - TID 1401 — Area Measurement
  - TID 1402 — Volume Measurement
  - TID 1404 — Numeric Measurement
  - TID 1406 — Three Dimensional Linear Measurement
  - TID 1410 — Planar ROI Measurements and Qualitative Evaluations
  - TID 1411 — Volumetric ROI Measurements and Qualitative Evaluations
  - TID 1419 — ROI Measurements
  - TID 1420 — Measurements Derived From Multiple ROI Measurements

  These sub-templates provide typed measurement content items for SR
  documents, building on the base NUM content item type with appropriate
  concept names, units, and derivation modifiers.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 1404: Numeric Measurement (base) ---------------------------------

  @doc """
  Builds TID 1404 Numeric Measurement content items.

  This is the foundational numeric measurement template. All other
  measurement types (linear, area, volume, etc.) build on this pattern.

  ## Options

    * `:concept` — (required) measurement concept Code
    * `:value` — (required) numeric value
    * `:units` — (required) measurement units Code (UCUM)
    * `:qualifier` — numeric value qualifier Code (e.g., "Not a number")
    * `:derivation` — derivation Code (e.g., Mean, Standard Deviation)
    * `:method` — measurement method Code
    * `:finding_site` — anatomical finding site Code
    * `:equation` — equation or table (TEXT)
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec numeric_measurement(keyword()) :: [ContentItem.t()]
  def numeric_measurement(opts) when is_list(opts) do
    concept = Keyword.fetch!(opts, :concept)
    value = Keyword.fetch!(opts, :value)
    units = Keyword.fetch!(opts, :units)
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")
    qualifier = opts[:qualifier]

    children =
      []
      |> add_code_child(Codes.derivation(), opts[:derivation])
      |> add_code_child(Codes.measurement_method(), opts[:method])
      |> add_code_child(Codes.finding_site(), opts[:finding_site])
      |> add_text_child(Codes.equation_or_table(), opts[:equation])

    [
      ContentItem.num(concept, value, units,
        relationship_type: rel,
        qualifier: qualifier,
        children: children
      )
    ]
  end

  # -- TID 1400: Linear Measurement -----------------------------------------

  @doc """
  Builds TID 1400 Linear Measurement content items.

  A numeric measurement constrained to linear distance units.

  ## Options

  Same as `numeric_measurement/1`. The `:units` should be a linear
  distance unit (e.g., mm, cm, m from UCUM).

  """
  @spec linear_measurement(keyword()) :: [ContentItem.t()]
  def linear_measurement(opts), do: numeric_measurement(opts)

  # -- TID 1401: Area Measurement -------------------------------------------

  @doc """
  Builds TID 1401 Area Measurement content items.

  A numeric measurement constrained to area units.

  ## Options

  Same as `numeric_measurement/1`. The `:units` should be an area
  unit (e.g., mm2, cm2 from UCUM).

  """
  @spec area_measurement(keyword()) :: [ContentItem.t()]
  def area_measurement(opts), do: numeric_measurement(opts)

  # -- TID 1402: Volume Measurement -----------------------------------------

  @doc """
  Builds TID 1402 Volume Measurement content items.

  A numeric measurement constrained to volume units.

  ## Options

  Same as `numeric_measurement/1`. The `:units` should be a volume
  unit (e.g., mm3, cm3, mL from UCUM).

  """
  @spec volume_measurement(keyword()) :: [ContentItem.t()]
  def volume_measurement(opts), do: numeric_measurement(opts)

  # -- TID 1406: Three Dimensional Linear Measurement -----------------------

  @doc """
  Builds TID 1406 Three Dimensional Linear Measurement content items.

  A linear measurement for 3D spatial coordinates. Identical to TID 1400
  but semantically indicates the measurement was taken in 3D space
  (e.g., from SCOORD3D coordinates).

  ## Options

  Same as `numeric_measurement/1`.

  """
  @spec three_dimensional_linear_measurement(keyword()) :: [ContentItem.t()]
  def three_dimensional_linear_measurement(opts), do: numeric_measurement(opts)

  # -- TID 1410: Planar ROI Measurements and Qualitative Evaluations --------

  @doc """
  Builds TID 1410 Planar ROI Measurements and Qualitative Evaluations.

  Wraps one or more measurements (TID 1419) and qualitative evaluations
  for a planar region of interest.

  ## Options

    * `:measurements` — list of measurement keyword options (each passed
      to `numeric_measurement/1`)
    * `:evaluations` — list of `{concept, value}` Code tuples for
      qualitative evaluations
    * `:finding_site` — anatomical finding site Code applied to all items
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec planar_roi_measurements(keyword()) :: [ContentItem.t()]
  def planar_roi_measurements(opts) when is_list(opts) do
    measurements = Keyword.get(opts, :measurements, [])
    evaluations = Keyword.get(opts, :evaluations, [])
    site = opts[:finding_site]
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    measurement_items =
      Enum.flat_map(measurements, fn m_opts ->
        m_opts
        |> Keyword.put_new(:finding_site, site)
        |> Keyword.put_new(:relationship_type, rel)
        |> numeric_measurement()
      end)

    eval_items = build_evaluations(evaluations, site, rel)

    measurement_items ++ eval_items
  end

  # -- TID 1411: Volumetric ROI Measurements and Qualitative Evaluations ----

  @doc """
  Builds TID 1411 Volumetric ROI Measurements and Qualitative Evaluations.

  Same structure as TID 1410 but for volumetric regions of interest.

  ## Options

  Same as `planar_roi_measurements/1`.

  """
  @spec volumetric_roi_measurements(keyword()) :: [ContentItem.t()]
  def volumetric_roi_measurements(opts), do: planar_roi_measurements(opts)

  # -- TID 1419: ROI Measurements -------------------------------------------

  @doc """
  Builds TID 1419 ROI Measurements content items.

  A collection of numeric measurements for a region of interest.

  ## Options

    * `:measurements` — (required) list of measurement keyword options
      (each passed to `numeric_measurement/1`)
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec roi_measurements(keyword()) :: [ContentItem.t()]
  def roi_measurements(opts) when is_list(opts) do
    measurements = Keyword.fetch!(opts, :measurements)
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    Enum.flat_map(measurements, fn m_opts ->
      m_opts
      |> Keyword.put_new(:relationship_type, rel)
      |> numeric_measurement()
    end)
  end

  # -- TID 1420: Measurements Derived From Multiple ROI Measurements --------

  @doc """
  Builds TID 1420 Measurements Derived From Multiple ROI Measurements.

  Represents measurements that are computed from multiple ROI measurements
  (e.g., mean of multiple lesion diameters). Each measurement includes
  a derivation modifier indicating the statistical operation.

  ## Options

    * `:measurements` — (required) list of measurement keyword options;
      each should include a `:derivation` Code
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec derived_measurements(keyword()) :: [ContentItem.t()]
  def derived_measurements(opts) when is_list(opts) do
    measurements = Keyword.fetch!(opts, :measurements)
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    Enum.flat_map(measurements, fn m_opts ->
      m_opts
      |> Keyword.put_new(:relationship_type, rel)
      |> numeric_measurement()
    end)
  end

  # -- Private helpers -------------------------------------------------------

  defp build_evaluations(evaluations, site, rel) do
    Enum.map(evaluations, fn {concept, value} ->
      children =
        []
        |> add_code_child(Codes.finding_site(), site)

      ContentItem.code(concept, value,
        relationship_type: rel,
        children: children
      )
    end)
  end

  defp add_code_child(children, _concept, nil), do: children

  defp add_code_child(children, concept, %Code{} = code) do
    children ++ [ContentItem.code(concept, code, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_text_child(children, _concept, nil), do: children

  defp add_text_child(children, concept, text) when is_binary(text) do
    children ++ [ContentItem.text(concept, text, relationship_type: "HAS CONCEPT MOD")]
  end
end
