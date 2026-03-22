defmodule Dicom.SR.SubTemplates.ECG do
  @moduledoc """
  TID 3702-3719 ECG Sub-Templates.

  Implements the ECG sub-template hierarchy used by ECG reports:

  - TID 3702 -- Prior ECG Study
  - TID 3704 -- Patient Characteristics (ECG)
  - TID 3708 -- Waveform Information
  - TID 3713 -- ECG Global Measurements
  - TID 3714 -- ECG Lead Measurements
  - TID 3715 -- Measurement Source
  - TID 3717 -- Qualitative ECG Analysis
  - TID 3719 -- ECG Summary

  These sub-templates are referenced by TID 3700 ECG Report for
  structured reporting of electrocardiographic findings.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 3702: Prior ECG Study ---------------------------------------------

  @doc """
  Builds TID 3702 Prior ECG Study content items.

  ## Options

    * `:study_uid` -- prior study instance UID
    * `:study_date` -- prior study date string
    * `:description` -- study description (TEXT)
    * `:findings` -- prior study findings (TEXT)

  """
  @spec prior_ecg_study(keyword()) :: [ContentItem.t()]
  def prior_ecg_study(opts \\ []) do
    children =
      []
      |> add_uidref_child(Codes.procedure_study_instance_uid(), opts[:study_uid])
      |> add_datetime_child(Codes.start_datetime(), opts[:study_date])
      |> add_text_child(Codes.procedure_description(), opts[:description])
      |> add_text_child(Codes.finding(), opts[:findings])

    [
      ContentItem.container(Codes.history(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3704: Patient Characteristics (ECG) -------------------------------

  @doc """
  Builds TID 3704 Patient Characteristics content items for ECG.

  ## Options

    * `:age` -- patient age (number, with `:age_units`)
    * `:age_units` -- units for age
    * `:sex` -- patient sex Code
    * `:heart_rate` -- heart rate (number, with `:heart_rate_units`)
    * `:heart_rate_units` -- units for heart rate
    * `:body_weight` -- body weight (number, with `:weight_units`)
    * `:weight_units` -- units for weight
    * `:body_height` -- body height (number, with `:height_units`)
    * `:height_units` -- units for height
    * `:clinical_info` -- clinical information text

  """
  @spec patient_characteristics(keyword()) :: [ContentItem.t()]
  def patient_characteristics(opts \\ []) do
    children =
      []
      |> add_num_child(Codes.subject_age(), opts[:age], opts[:age_units])
      |> add_code_child(Codes.subject_sex(), opts[:sex])
      |> add_num_child(Codes.heart_rate(), opts[:heart_rate], opts[:heart_rate_units])
      |> add_num_child(Codes.body_weight(), opts[:body_weight], opts[:weight_units])
      |> add_num_child(Codes.body_height(), opts[:body_height], opts[:height_units])
      |> add_text_child(Codes.clinical_information(), opts[:clinical_info])

    [
      ContentItem.container(Codes.patient_characteristics(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3708: Waveform Information ----------------------------------------

  @doc """
  Builds TID 3708 Waveform Information content items.

  ## Options

    * `:waveform_type` -- waveform type Code
    * `:signal_quality` -- signal quality Code
    * `:description` -- waveform description (TEXT)
    * `:filter_description` -- filter settings description (TEXT)

  """
  @spec waveform_information(keyword()) :: [ContentItem.t()]
  def waveform_information(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.waveform_annotation(), opts[:waveform_type])
      |> add_code_child(Codes.signal_quality(), opts[:signal_quality])
      |> add_text_child(Codes.procedure_description(), opts[:description])
      |> add_text_child(Codes.comment(), opts[:filter_description])

    [
      ContentItem.container(Codes.waveform_reference(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3713: ECG Global Measurements ------------------------------------

  @doc """
  Builds TID 3713 ECG Global Measurements content items.

  ## Options

    * `:heart_rate` -- heart rate (number, with `:heart_rate_units`)
    * `:heart_rate_units` -- units for heart rate
    * `:pr_interval` -- PR interval (number, with `:interval_units`)
    * `:qrs_duration` -- QRS duration (number, with `:interval_units`)
    * `:qt_interval` -- QT interval (number, with `:interval_units`)
    * `:qtc_interval` -- corrected QT interval (number, with `:interval_units`)
    * `:interval_units` -- units for interval measurements (default: ms)
    * `:qrs_axis` -- QRS axis (number, with `:axis_units`)
    * `:axis_units` -- units for axis measurements (default: degrees)
    * `:measurements` -- additional measurement content items

  """
  @spec global_measurements(keyword()) :: [ContentItem.t()]
  def global_measurements(opts \\ []) do
    interval_units = opts[:interval_units] || Codes.millisecond()
    axis_units = opts[:axis_units] || Codes.degrees()

    pr_code = Code.new("122168", "DCM", "PR Interval")
    qrs_code = Code.new("122169", "DCM", "QRS Duration")
    qt_code = Code.new("122170", "DCM", "QT Interval")
    qtc_code = Code.new("122171", "DCM", "QTc Interval")
    qrs_axis_code = Code.new("122167", "DCM", "QRS Axis")

    children =
      []
      |> add_num_child(Codes.heart_rate(), opts[:heart_rate], opts[:heart_rate_units])
      |> add_num_child(pr_code, opts[:pr_interval], interval_units)
      |> add_num_child(qrs_code, opts[:qrs_duration], interval_units)
      |> add_num_child(qt_code, opts[:qt_interval], interval_units)
      |> add_num_child(qtc_code, opts[:qtc_interval], interval_units)
      |> add_num_child(qrs_axis_code, opts[:qrs_axis], axis_units)
      |> add_items(opts[:measurements] || [])

    [
      ContentItem.container(Codes.ecg_global_measurements(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3714: ECG Lead Measurements --------------------------------------

  @doc """
  Builds TID 3714 ECG Lead Measurements content items.

  ## Options

    * `:lead` -- (required) lead identification Code
    * `:measurements` -- list of measurement keyword options, each with
      `:concept`, `:value`, `:units`
    * `:source` -- measurement source options (keyword, see `measurement_source/1`)

  """
  @spec lead_measurements(keyword()) :: [ContentItem.t()]
  def lead_measurements(opts \\ []) do
    measurement_items =
      Keyword.get(opts, :measurements, [])
      |> Enum.flat_map(fn m_opts ->
        concept = Keyword.fetch!(m_opts, :concept)
        value = Keyword.fetch!(m_opts, :value)
        units = Keyword.fetch!(m_opts, :units)

        [
          ContentItem.num(concept, value, units, relationship_type: "CONTAINS")
        ]
      end)

    children =
      []
      |> add_code_child(Codes.finding_site(), opts[:lead])
      |> add_items(source_items(opts[:source]))
      |> add_items(measurement_items)

    [
      ContentItem.container(Codes.ecg_lead_measurements(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3715: Measurement Source ------------------------------------------

  @doc """
  Builds TID 3715 Measurement Source content items.

  ## Options

    * `:source_type` -- measurement source type Code
    * `:description` -- source description (TEXT)

  """
  @spec measurement_source(keyword()) :: [ContentItem.t()]
  def measurement_source(opts \\ []) do
    []
    |> add_code_child(Codes.source(), opts[:source_type])
    |> add_text_child(Codes.procedure_description(), opts[:description])
  end

  # -- TID 3717: Qualitative ECG Analysis ------------------------------------

  @doc """
  Builds TID 3717 Qualitative ECG Analysis content items.

  ## Options

    * `:rhythm` -- rhythm finding Code
    * `:conduction` -- conduction finding Code
    * `:morphology` -- morphology finding Code
    * `:ischemia` -- ischemia finding Code
    * `:findings` -- list of additional finding Codes
    * `:description` -- narrative description (TEXT)

  """
  @spec qualitative_analysis(keyword()) :: [ContentItem.t()]
  def qualitative_analysis(opts \\ []) do
    rhythm_code = Code.new("122163", "DCM", "Rhythm")
    conduction_code = Code.new("122164", "DCM", "Conduction")
    morphology_code = Code.new("122165", "DCM", "Morphology")
    ischemia_code = Code.new("122166", "DCM", "Ischemia")

    additional =
      Keyword.get(opts, :findings, [])
      |> Enum.map(fn finding ->
        ContentItem.code(Codes.finding(), finding, relationship_type: "CONTAINS")
      end)

    children =
      []
      |> add_code_child(rhythm_code, opts[:rhythm])
      |> add_code_child(conduction_code, opts[:conduction])
      |> add_code_child(morphology_code, opts[:morphology])
      |> add_code_child(ischemia_code, opts[:ischemia])
      |> add_items(additional)
      |> add_text_child(Codes.comment(), opts[:description])

    [
      ContentItem.container(Codes.findings(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3719: ECG Summary ------------------------------------------------

  @doc """
  Builds TID 3719 ECG Summary content items.

  ## Options

    * `:impression` -- summary impression text
    * `:comparison` -- comparison with prior ECG (TEXT)
    * `:severity` -- overall severity Code
    * `:recommendation` -- recommendation text

  """
  @spec ecg_summary(keyword()) :: [ContentItem.t()]
  def ecg_summary(opts \\ []) do
    children =
      []
      |> add_text_child(Codes.impression(), opts[:impression])
      |> add_text_child(Codes.comment(), opts[:comparison])
      |> add_code_child(Codes.finding(), opts[:severity])
      |> add_text_child(Codes.recommendation(), opts[:recommendation])

    [
      ContentItem.container(Codes.summary(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- Private helpers -------------------------------------------------------

  defp add_items(items, []), do: items
  defp add_items(items, more), do: items ++ more

  defp source_items(nil), do: []
  defp source_items(opts), do: measurement_source(opts)

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
