defmodule Dicom.SR.SubTemplates.Hemodynamics do
  @moduledoc """
  TID 3501-3560 Hemodynamic Sub-Templates.

  Implements the hemodynamic measurement sub-template hierarchy used by
  catheterization hemodynamic reports:

  - TID 3501 -- Hemodynamic Measurement Group
  - TID 3504 -- Arterial Pressure Measurement
  - TID 3505 -- Atrial Pressure Measurement
  - TID 3506 -- Venous Pressure Measurement
  - TID 3507 -- Ventricular Pressure Measurement
  - TID 3508 -- Pressure Gradient Measurement
  - TID 3509 -- Blood Velocity Measurement
  - TID 3510 -- Vital Signs
  - TID 3515 -- Cardiac Output
  - TID 3520 -- Clinical Context
  - TID 3530 -- Acquisition Context
  - TID 3550 -- Pressure Waveform
  - TID 3560 -- Derived Hemodynamic Measurements

  These sub-templates are referenced by TID 3500 Hemodynamic Report for
  recording hemodynamic data acquired during cardiac catheterization.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 3501: Hemodynamic Measurement Group --------------------------------

  @doc """
  Builds TID 3501 Hemodynamic Measurement Group content items.

  A container grouping related hemodynamic measurements with optional
  clinical and acquisition context.

  ## Options

    * `:concept` -- group concept Code (default: Hemodynamic Measurements)
    * `:clinical_context` -- clinical context options (keyword, see `clinical_context/1`)
    * `:acquisition_context` -- acquisition context options (keyword, see `acquisition_context/1`)
    * `:measurements` -- list of child content items (pressure, velocity, etc.)
    * `:relationship_type` -- relationship type (default: "CONTAINS")

  """
  @spec hemodynamic_measurement_group(keyword()) :: [ContentItem.t()]
  def hemodynamic_measurement_group(opts \\ []) do
    concept = opts[:concept] || Codes.hemodynamic_measurements()
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    children =
      []
      |> add_items(clinical_context_items(opts[:clinical_context]))
      |> add_items(acquisition_context_items(opts[:acquisition_context]))
      |> add_items(opts[:measurements] || [])

    [
      ContentItem.container(concept,
        relationship_type: rel,
        children: children
      )
    ]
  end

  # -- TID 3504: Arterial Pressure Measurement -------------------------------

  @doc """
  Builds TID 3504 Arterial Pressure Measurement content items.

  ## Options

    * `:systolic` -- systolic pressure (number)
    * `:diastolic` -- diastolic pressure (number)
    * `:mean` -- mean pressure (number)
    * `:units` -- pressure units Code (default: mmHg)
    * `:finding_site` -- measurement site Code

  """
  @spec arterial_pressure(keyword()) :: [ContentItem.t()]
  def arterial_pressure(opts \\ []) do
    units = opts[:units] || Codes.mmhg()
    site = opts[:finding_site]

    []
    |> add_pressure_num(Codes.systolic_blood_pressure(), opts[:systolic], units, site)
    |> add_pressure_num(Codes.diastolic_blood_pressure(), opts[:diastolic], units, site)
    |> add_pressure_num(Codes.mean_blood_pressure(), opts[:mean], units, site)
  end

  # -- TID 3505: Atrial Pressure Measurement ---------------------------------

  @doc """
  Builds TID 3505 Atrial Pressure Measurement content items.

  ## Options

    * `:mean` -- mean atrial pressure (number)
    * `:a_wave` -- a-wave pressure (number)
    * `:v_wave` -- v-wave pressure (number)
    * `:units` -- pressure units Code (default: mmHg)
    * `:finding_site` -- measurement site Code

  """
  @spec atrial_pressure(keyword()) :: [ContentItem.t()]
  def atrial_pressure(opts \\ []) do
    units = opts[:units] || Codes.mmhg()
    site = opts[:finding_site]
    a_wave_code = Code.new("122106", "DCM", "A-wave Pressure")
    v_wave_code = Code.new("122107", "DCM", "V-wave Pressure")

    []
    |> add_pressure_num(Codes.mean_blood_pressure(), opts[:mean], units, site)
    |> add_pressure_num(a_wave_code, opts[:a_wave], units, site)
    |> add_pressure_num(v_wave_code, opts[:v_wave], units, site)
  end

  # -- TID 3506: Venous Pressure Measurement ---------------------------------

  @doc """
  Builds TID 3506 Venous Pressure Measurement content items.

  ## Options

    * `:mean` -- mean venous pressure (number)
    * `:units` -- pressure units Code (default: mmHg)
    * `:finding_site` -- measurement site Code

  """
  @spec venous_pressure(keyword()) :: [ContentItem.t()]
  def venous_pressure(opts \\ []) do
    units = opts[:units] || Codes.mmhg()
    site = opts[:finding_site]

    []
    |> add_pressure_num(Codes.mean_blood_pressure(), opts[:mean], units, site)
  end

  # -- TID 3507: Ventricular Pressure Measurement ----------------------------

  @doc """
  Builds TID 3507 Ventricular Pressure Measurement content items.

  ## Options

    * `:systolic` -- peak systolic pressure (number)
    * `:end_diastolic` -- end-diastolic pressure (number)
    * `:units` -- pressure units Code (default: mmHg)
    * `:finding_site` -- measurement site Code

  """
  @spec ventricular_pressure(keyword()) :: [ContentItem.t()]
  def ventricular_pressure(opts \\ []) do
    units = opts[:units] || Codes.mmhg()
    site = opts[:finding_site]
    edp_code = Codes.lv_end_diastolic_pressure()

    []
    |> add_pressure_num(Codes.systolic_blood_pressure(), opts[:systolic], units, site)
    |> add_pressure_num(edp_code, opts[:end_diastolic], units, site)
  end

  # -- TID 3508: Pressure Gradient Measurement -------------------------------

  @doc """
  Builds TID 3508 Pressure Gradient Measurement content items.

  ## Options

    * `:peak` -- peak pressure gradient (number)
    * `:mean` -- mean pressure gradient (number)
    * `:units` -- pressure units Code (default: mmHg)
    * `:finding_site` -- measurement site Code

  """
  @spec pressure_gradient(keyword()) :: [ContentItem.t()]
  def pressure_gradient(opts \\ []) do
    units = opts[:units] || Codes.mmhg()
    site = opts[:finding_site]
    peak_code = Code.new("122171", "DCM", "Peak Gradient")

    []
    |> add_pressure_num(peak_code, opts[:peak], units, site)
    |> add_pressure_num(Codes.mean_gradient(), opts[:mean], units, site)
  end

  # -- TID 3509: Blood Velocity Measurement ----------------------------------

  @doc """
  Builds TID 3509 Blood Velocity Measurement content items.

  ## Options

    * `:peak_systolic` -- peak systolic velocity (number)
    * `:end_diastolic` -- end diastolic velocity (number)
    * `:units` -- velocity units Code
    * `:finding_site` -- measurement site Code

  """
  @spec blood_velocity(keyword()) :: [ContentItem.t()]
  def blood_velocity(opts \\ []) do
    units = opts[:units] || Code.new("cm/s", "UCUM", "centimeters per second")
    site = opts[:finding_site]

    []
    |> add_pressure_num(Codes.peak_systolic_velocity(), opts[:peak_systolic], units, site)
    |> add_pressure_num(Codes.end_diastolic_velocity(), opts[:end_diastolic], units, site)
  end

  # -- TID 3510: Vital Signs ------------------------------------------------

  @doc """
  Builds TID 3510 Vital Signs content items.

  ## Options

    * `:heart_rate` -- heart rate (number)
    * `:heart_rate_units` -- units for heart rate
    * `:systolic_bp` -- systolic blood pressure (number)
    * `:diastolic_bp` -- diastolic blood pressure (number)
    * `:mean_bp` -- mean blood pressure (number)
    * `:bp_units` -- units for blood pressure (default: mmHg)
    * `:body_weight` -- body weight (number)
    * `:weight_units` -- units for body weight
    * `:body_height` -- body height (number)
    * `:height_units` -- units for body height
    * `:body_surface_area` -- body surface area (number)
    * `:bsa_units` -- units for BSA

  """
  @spec vital_signs(keyword()) :: [ContentItem.t()]
  def vital_signs(opts \\ []) do
    bp_units = opts[:bp_units] || Codes.mmhg()

    []
    |> add_num_item(Codes.heart_rate(), opts[:heart_rate], opts[:heart_rate_units])
    |> add_num_item(Codes.systolic_blood_pressure(), opts[:systolic_bp], bp_units)
    |> add_num_item(Codes.diastolic_blood_pressure(), opts[:diastolic_bp], bp_units)
    |> add_num_item(Codes.mean_blood_pressure(), opts[:mean_bp], bp_units)
    |> add_num_item(Codes.body_weight(), opts[:body_weight], opts[:weight_units])
    |> add_num_item(Codes.body_height(), opts[:body_height], opts[:height_units])
    |> add_num_item(Codes.body_surface_area(), opts[:body_surface_area], opts[:bsa_units])
  end

  # -- TID 3515: Cardiac Output ----------------------------------------------

  @doc """
  Builds TID 3515 Cardiac Output content items.

  ## Options

    * `:cardiac_output` -- cardiac output value (number)
    * `:cardiac_output_units` -- units for cardiac output
    * `:stroke_volume` -- stroke volume (number)
    * `:stroke_volume_units` -- units for stroke volume
    * `:ejection_fraction` -- ejection fraction (number)
    * `:method` -- measurement method Code

  """
  @spec cardiac_output(keyword()) :: [ContentItem.t()]
  def cardiac_output(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.measurement_method(), opts[:method])

    items =
      []
      |> add_num_item_with_children(
        Codes.cardiac_output(),
        opts[:cardiac_output],
        opts[:cardiac_output_units],
        children
      )
      |> add_num_item(Codes.stroke_volume(), opts[:stroke_volume], opts[:stroke_volume_units])
      |> add_num_item(Codes.ejection_fraction(), opts[:ejection_fraction], Codes.percent())

    items
  end

  # -- TID 3520: Clinical Context --------------------------------------------

  @doc """
  Builds TID 3520 Clinical Context content items.

  ## Options

    * `:patient_state` -- patient state Code
    * `:clinical_info` -- clinical information text
    * `:history` -- patient history text

  """
  @spec clinical_context(keyword()) :: [ContentItem.t()]
  def clinical_context(opts \\ []) do
    []
    |> add_code_item(Codes.patient_state(), opts[:patient_state])
    |> add_text_item(Codes.clinical_information(), opts[:clinical_info])
    |> add_text_item(Codes.history(), opts[:history])
  end

  # -- TID 3530: Acquisition Context -----------------------------------------

  @doc """
  Builds TID 3530 Acquisition Context content items.

  ## Options

    * `:datetime` -- acquisition datetime string
    * `:description` -- acquisition description (TEXT)

  """
  @spec acquisition_context(keyword()) :: [ContentItem.t()]
  def acquisition_context(opts \\ []) do
    []
    |> add_datetime_item(Codes.start_datetime(), opts[:datetime])
    |> add_text_item(Codes.procedure_description(), opts[:description])
  end

  # -- TID 3550: Pressure Waveform ------------------------------------------

  @doc """
  Builds TID 3550 Pressure Waveform content items.

  ## Options

    * `:waveform_type` -- waveform type Code
    * `:finding_site` -- measurement site Code
    * `:description` -- waveform description (TEXT)

  """
  @spec pressure_waveform(keyword()) :: [ContentItem.t()]
  def pressure_waveform(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.finding_site(), opts[:finding_site])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    type = opts[:waveform_type] || Codes.pressure_gradient()

    [
      ContentItem.container(type,
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3560: Derived Hemodynamic Measurements ---------------------------

  @doc """
  Builds TID 3560 Derived Hemodynamic Measurements content items.

  ## Options

    * `:measurements` -- list of measurement keyword options, each with
      `:concept`, `:value`, `:units`, and optional `:derivation`
    * `:relationship_type` -- relationship type (default: "CONTAINS")

  """
  @spec derived_hemodynamic_measurements(keyword()) :: [ContentItem.t()]
  def derived_hemodynamic_measurements(opts \\ []) do
    measurements = Keyword.get(opts, :measurements, [])
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    items =
      Enum.flat_map(measurements, fn m_opts ->
        concept = Keyword.fetch!(m_opts, :concept)
        value = Keyword.fetch!(m_opts, :value)
        units = Keyword.fetch!(m_opts, :units)

        children =
          []
          |> add_code_child(Codes.derivation(), m_opts[:derivation])

        [
          ContentItem.num(concept, value, units,
            relationship_type: rel,
            children: children
          )
        ]
      end)

    case items do
      [] ->
        []

      _ ->
        [
          ContentItem.container(Codes.derived_hemodynamic_measurements(),
            relationship_type: rel,
            children: items
          )
        ]
    end
  end

  # -- Private helpers -------------------------------------------------------

  defp add_items(items, []), do: items
  defp add_items(items, more), do: items ++ more

  defp clinical_context_items(nil), do: []
  defp clinical_context_items(opts), do: clinical_context(opts)

  defp acquisition_context_items(nil), do: []
  defp acquisition_context_items(opts), do: acquisition_context(opts)

  defp add_pressure_num(items, _concept, nil, _units, _site), do: items

  defp add_pressure_num(items, concept, value, units, site) when is_number(value) do
    children =
      []
      |> add_code_child(Codes.finding_site(), site)

    items ++
      [
        ContentItem.num(concept, value, units,
          relationship_type: "CONTAINS",
          children: children
        )
      ]
  end

  defp add_num_item(items, _concept, nil, _units), do: items

  defp add_num_item(items, concept, value, nil) when is_number(value) do
    no_units = Code.new("1", "UCUM", "no units")
    items ++ [ContentItem.num(concept, value, no_units, relationship_type: "CONTAINS")]
  end

  defp add_num_item(items, concept, value, %Code{} = units) when is_number(value) do
    items ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
  end

  defp add_num_item_with_children(items, _concept, nil, _units, _children), do: items

  defp add_num_item_with_children(items, concept, value, nil, children) when is_number(value) do
    no_units = Code.new("1", "UCUM", "no units")

    items ++
      [
        ContentItem.num(concept, value, no_units,
          relationship_type: "CONTAINS",
          children: children
        )
      ]
  end

  defp add_num_item_with_children(items, concept, value, %Code{} = units, children)
       when is_number(value) do
    items ++
      [
        ContentItem.num(concept, value, units,
          relationship_type: "CONTAINS",
          children: children
        )
      ]
  end

  defp add_code_item(items, _concept, nil), do: items

  defp add_code_item(items, concept, %Code{} = code) do
    items ++ [ContentItem.code(concept, code, relationship_type: "CONTAINS")]
  end

  defp add_text_item(items, _concept, nil), do: items

  defp add_text_item(items, concept, text) when is_binary(text) do
    items ++ [ContentItem.text(concept, text, relationship_type: "CONTAINS")]
  end

  defp add_datetime_item(items, _concept, nil), do: items

  defp add_datetime_item(items, concept, datetime) when is_binary(datetime) do
    items ++ [ContentItem.datetime(concept, datetime, relationship_type: "CONTAINS")]
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
