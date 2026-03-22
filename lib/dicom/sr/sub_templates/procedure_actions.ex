defmodule Dicom.SR.SubTemplates.ProcedureActions do
  @moduledoc """
  TID 3100-3115 Procedure Log Action Sub-Templates.

  Implements the procedure action sub-template hierarchy used by
  catheterization and interventional procedure logs:

  - TID 3100 -- Procedure Action
  - TID 3101 -- Image Acquisition
  - TID 3102 -- Waveform Acquisition
  - TID 3103 -- Referenced Object
  - TID 3104 -- Consumables
  - TID 3105 -- Lesion Properties
  - TID 3106 -- Drugs/Contrast Agent Administration
  - TID 3107 -- Device Used
  - TID 3108 -- Intervention
  - TID 3109 -- Measurements
  - TID 3110 -- Impressions
  - TID 3111 -- Percutaneous Entry
  - TID 3112 -- Specimen Obtained
  - TID 3113 -- Patient Support
  - TID 3114 -- Patient Assessment
  - TID 3115 -- ECG ST Assessment

  These sub-templates are referenced by TID 3001 Procedure Log to record
  time-stamped actions that occur during catheterization procedures.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 3100: Procedure Action ---------------------------------------------

  @doc """
  Builds TID 3100 Procedure Action content items.

  A container representing a single action during a procedure, with an
  optional datetime stamp and nested action-specific content.

  ## Options

    * `:action_type` -- (required) action type Code (e.g., Image Acquisition)
    * `:datetime` -- action datetime string
    * `:description` -- action description (TEXT)
    * `:children` -- additional child content items

  """
  @spec procedure_action(keyword()) :: [ContentItem.t()]
  def procedure_action(opts) when is_list(opts) do
    action_type = Keyword.fetch!(opts, :action_type)
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    children =
      []
      |> add_datetime_child(Codes.log_entry_datetime(), opts[:datetime])
      |> add_text_child(Codes.procedure_description(), opts[:description])
      |> add_items(opts[:children] || [])

    [
      ContentItem.container(action_type,
        relationship_type: rel,
        children: children
      )
    ]
  end

  # -- TID 3101: Image Acquisition -------------------------------------------

  @doc """
  Builds TID 3101 Image Acquisition content items.

  ## Options

    * `:datetime` -- acquisition datetime
    * `:description` -- description of the acquired image (TEXT)
    * `:modality` -- imaging modality Code
    * `:target` -- anatomical target Code

  """
  @spec image_acquisition(keyword()) :: [ContentItem.t()]
  def image_acquisition(opts \\ []) do
    children =
      []
      |> add_datetime_child(Codes.log_entry_datetime(), opts[:datetime])
      |> add_text_child(Codes.procedure_description(), opts[:description])
      |> add_code_child(Codes.modality(), opts[:modality])
      |> add_code_child(Codes.finding_site(), opts[:target])

    [
      ContentItem.container(Codes.image_acquisition(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3102: Waveform Acquisition ----------------------------------------

  @doc """
  Builds TID 3102 Waveform Acquisition content items.

  ## Options

    * `:datetime` -- acquisition datetime
    * `:description` -- waveform description (TEXT)
    * `:waveform_type` -- type of waveform Code

  """
  @spec waveform_acquisition(keyword()) :: [ContentItem.t()]
  def waveform_acquisition(opts \\ []) do
    children =
      []
      |> add_datetime_child(Codes.log_entry_datetime(), opts[:datetime])
      |> add_text_child(Codes.procedure_description(), opts[:description])
      |> add_code_child(Codes.waveform_annotation(), opts[:waveform_type])

    [
      ContentItem.container(Codes.waveform_reference(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3103: Referenced Object -------------------------------------------

  @doc """
  Builds TID 3103 Referenced Object content items.

  ## Options

    * `:uid` -- referenced SOP Instance UID
    * `:description` -- object description (TEXT)

  """
  @spec referenced_object(keyword()) :: [ContentItem.t()]
  def referenced_object(opts \\ []) do
    children =
      []
      |> add_uidref_child(Codes.original_source(), opts[:uid])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.original_source(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3104: Consumables ------------------------------------------------

  @doc """
  Builds TID 3104 Consumables content items.

  ## Options

    * `:consumable` -- consumable type Code
    * `:quantity` -- quantity used (number, with `:quantity_units`)
    * `:quantity_units` -- units for quantity
    * `:description` -- consumable description (TEXT)

  """
  @spec consumables(keyword()) :: [ContentItem.t()]
  def consumables(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.consumable(), opts[:consumable])
      |> add_num_child(Codes.actual_volume(), opts[:quantity], opts[:quantity_units])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.consumable_used(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3105: Lesion Properties -------------------------------------------

  @doc """
  Builds TID 3105 Lesion Properties content items.

  ## Options

    * `:lesion_type` -- lesion type Code
    * `:severity` -- lesion severity Code
    * `:finding_site` -- anatomical site Code
    * `:description` -- lesion description (TEXT)

  """
  @spec lesion_properties(keyword()) :: [ContentItem.t()]
  def lesion_properties(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.lesion(), opts[:lesion_type])
      |> add_code_child(Codes.stenosis_severity(), opts[:severity])
      |> add_code_child(Codes.finding_site(), opts[:finding_site])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.lesion(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3106: Drugs/Contrast Agent Administration -------------------------

  @doc """
  Builds TID 3106 Drugs/Contrast Agent Administration content items.

  ## Options

    * `:drug` -- drug or contrast agent Code
    * `:dose` -- administered dose (number, with `:dose_units`)
    * `:dose_units` -- units for dose
    * `:route` -- route of administration Code
    * `:datetime` -- administration datetime

  """
  @spec drugs_contrast(keyword()) :: [ContentItem.t()]
  def drugs_contrast(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.drug_administered(), opts[:drug])
      |> add_num_child(Codes.actual_dose(), opts[:dose], opts[:dose_units])
      |> add_code_child(Codes.route_of_administration(), opts[:route])
      |> add_datetime_child(Codes.administration_datetime(), opts[:datetime])

    [
      ContentItem.container(Codes.drug_administered(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3107: Device Used ------------------------------------------------

  @doc """
  Builds TID 3107 Device Used content items.

  ## Options

    * `:device_type` -- device type Code
    * `:device_name` -- device name (TEXT)
    * `:description` -- device description (TEXT)

  """
  @spec device_used(keyword()) :: [ContentItem.t()]
  def device_used(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.device(), opts[:device_type])
      |> add_text_child(Codes.device_observer_name(), opts[:device_name])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.device(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3108: Intervention ------------------------------------------------

  @doc """
  Builds TID 3108 Intervention content items.

  ## Options

    * `:intervention_type` -- intervention type Code
    * `:finding_site` -- anatomical site Code
    * `:description` -- intervention description (TEXT)
    * `:datetime` -- intervention datetime

  """
  @spec intervention(keyword()) :: [ContentItem.t()]
  def intervention(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.finding_site(), opts[:finding_site])
      |> add_text_child(Codes.procedure_description(), opts[:description])
      |> add_datetime_child(Codes.log_entry_datetime(), opts[:datetime])

    type = opts[:intervention_type] || Codes.procedure_action()

    [
      ContentItem.container(type,
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3109: Measurements -----------------------------------------------

  @doc """
  Builds TID 3109 Measurements content items.

  Wraps numeric measurements taken during a procedure action.

  ## Options

    * `:measurements` -- list of measurement keyword options, each with
      `:concept`, `:value`, `:units`
    * `:finding_site` -- anatomical site Code (shared across all measurements)

  """
  @spec measurements(keyword()) :: [ContentItem.t()]
  def measurements(opts \\ []) do
    site = opts[:finding_site]
    items = Keyword.get(opts, :measurements, [])

    Enum.flat_map(items, fn m_opts ->
      concept = Keyword.fetch!(m_opts, :concept)
      value = Keyword.fetch!(m_opts, :value)
      units = Keyword.fetch!(m_opts, :units)

      children =
        []
        |> add_code_child(Codes.finding_site(), Keyword.get(m_opts, :finding_site, site))

      [
        ContentItem.num(concept, value, units,
          relationship_type: "CONTAINS",
          children: children
        )
      ]
    end)
  end

  # -- TID 3110: Impressions ------------------------------------------------

  @doc """
  Builds TID 3110 Impressions content items.

  ## Options

    * `:impressions` -- list of impression text strings

  """
  @spec impressions(keyword()) :: [ContentItem.t()]
  def impressions(opts \\ []) do
    items = Keyword.get(opts, :impressions, [])

    Enum.map(items, fn text ->
      ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- TID 3111: Percutaneous Entry ------------------------------------------

  @doc """
  Builds TID 3111 Percutaneous Entry content items.

  ## Options

    * `:access_site` -- access site Code
    * `:catheter_type` -- catheter type Code
    * `:description` -- entry description (TEXT)

  """
  @spec percutaneous_entry(keyword()) :: [ContentItem.t()]
  def percutaneous_entry(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.access_site(), opts[:access_site])
      |> add_code_child(Codes.catheter_type(), opts[:catheter_type])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.access_site(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3112: Specimen Obtained -------------------------------------------

  @doc """
  Builds TID 3112 Specimen Obtained content items.

  ## Options

    * `:specimen_type` -- specimen type Code
    * `:finding_site` -- specimen collection site Code
    * `:description` -- specimen description (TEXT)

  """
  @spec specimen_obtained(keyword()) :: [ContentItem.t()]
  def specimen_obtained(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.specimen_type(), opts[:specimen_type])
      |> add_code_child(Codes.finding_site(), opts[:finding_site])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.specimen_type(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3113: Patient Support ---------------------------------------------

  @doc """
  Builds TID 3113 Patient Support content items.

  ## Options

    * `:patient_state` -- patient state Code
    * `:description` -- patient support description (TEXT)

  """
  @spec patient_support(keyword()) :: [ContentItem.t()]
  def patient_support(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.patient_state(), opts[:patient_state])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.patient_state(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3114: Patient Assessment ------------------------------------------

  @doc """
  Builds TID 3114 Patient Assessment content items.

  ## Options

    * `:heart_rate` -- heart rate (number, with `:heart_rate_units`)
    * `:heart_rate_units` -- units for heart rate
    * `:systolic_bp` -- systolic blood pressure (number, with `:bp_units`)
    * `:diastolic_bp` -- diastolic blood pressure (number, with `:bp_units`)
    * `:bp_units` -- units for blood pressure measurements

  """
  @spec patient_assessment(keyword()) :: [ContentItem.t()]
  def patient_assessment(opts \\ []) do
    bp_units = opts[:bp_units]

    []
    |> add_num_child(Codes.heart_rate(), opts[:heart_rate], opts[:heart_rate_units])
    |> add_num_child(Codes.systolic_blood_pressure(), opts[:systolic_bp], bp_units)
    |> add_num_child(Codes.diastolic_blood_pressure(), opts[:diastolic_bp], bp_units)
  end

  # -- TID 3115: ECG ST Assessment -------------------------------------------

  @doc """
  Builds TID 3115 ECG ST Assessment content items.

  ## Options

    * `:lead` -- ECG lead Code
    * `:st_segment` -- ST segment value (number, with `:st_units`)
    * `:st_units` -- units for ST segment measurement
    * `:description` -- assessment description (TEXT)

  """
  @spec ecg_st_assessment(keyword()) :: [ContentItem.t()]
  def ecg_st_assessment(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.finding_site(), opts[:lead])
      |> add_num_child(Codes.ecg_global_measurements(), opts[:st_segment], opts[:st_units])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.ecg_global_measurements(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- Private helpers -------------------------------------------------------

  defp add_items(items, []), do: items
  defp add_items(items, more), do: items ++ more

  defp add_code_child(children, _concept, nil), do: children

  defp add_code_child(children, concept, %Code{} = code) do
    children ++ [ContentItem.code(concept, code, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_text_child(children, _concept, nil), do: children

  defp add_text_child(children, concept, text) when is_binary(text) do
    children ++ [ContentItem.text(concept, text, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_uidref_child(children, _concept, nil), do: children

  defp add_uidref_child(children, concept, uid) when is_binary(uid) do
    children ++ [ContentItem.uidref(concept, uid, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, _concept, nil, _units), do: children

  defp add_num_child(children, concept, value, nil) when is_number(value) do
    no_units = Code.new("1", "UCUM", "no units")
    children ++ [ContentItem.num(concept, value, no_units, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, concept, value, %Code{} = units) when is_number(value) do
    children ++ [ContentItem.num(concept, value, units, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_datetime_child(children, _concept, nil), do: children

  defp add_datetime_child(children, concept, datetime) when is_binary(datetime) do
    children ++
      [ContentItem.datetime(concept, datetime, relationship_type: "HAS CONCEPT MOD")]
  end
end
