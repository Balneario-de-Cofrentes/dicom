defmodule Dicom.SR.SubTemplates.OBGYN do
  @moduledoc """
  TID 5001-5030 OB-GYN Sub-Templates.

  Implements the OB-GYN ultrasound sub-template hierarchy:

  - TID 5001 -- Patient Characteristics (OB-GYN)
  - TID 5002 -- Procedure Summary
  - TID 5003 -- Fetus Summary
  - TID 5004 -- Fetal Biometry (Group)
  - TID 5005 -- Head and Skull Biometry
  - TID 5006 -- Abdominal Biometry
  - TID 5007 -- Limb Biometry
  - TID 5008 -- Estimated Fetal Weight
  - TID 5009 -- Biophysical Profile
  - TID 5010 -- Amniotic Sac
  - TID 5011 -- Early Gestation
  - TID 5012 -- Ovaries
  - TID 5013 -- Pelvis
  - TID 5014 -- Uterus
  - TID 5015 -- Cervix
  - TID 5016 -- Adnexa
  - TID 5017 -- Cul-de-Sac
  - TID 5025 -- Fetal Vascular Measurement Group
  - TID 5026 -- Maternal Vascular Measurement Group
  - TID 5030 -- Fetal Anatomy Survey

  These sub-templates are referenced by TID 5000 OB-GYN Ultrasound
  Procedure Report for structured reporting of obstetric and
  gynecologic ultrasound findings.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 5001: Patient Characteristics (OB-GYN) ----------------------------

  @doc """
  Builds TID 5001 Patient Characteristics content items for OB-GYN.

  ## Options

    * `:gravidity` -- gravidity (number)
    * `:parity` -- parity (number)
    * `:lmp` -- last menstrual period date (string)
    * `:edd` -- estimated date of delivery (string)
    * `:gestational_age` -- gestational age (number, with `:ga_units`)
    * `:ga_units` -- units for gestational age
    * `:clinical_info` -- clinical information text

  """
  @spec patient_characteristics(keyword()) :: [ContentItem.t()]
  def patient_characteristics(opts \\ []) do
    children =
      []
      |> add_num_child(Codes.gravidity(), opts[:gravidity], nil)
      |> add_num_child(Codes.parity(), opts[:parity], nil)
      |> add_date_child(Codes.last_menstrual_period(), opts[:lmp])
      |> add_date_child(Codes.estimated_date_of_delivery(), opts[:edd])
      |> add_num_child(Codes.gestational_age(), opts[:gestational_age], opts[:ga_units])
      |> add_text_child(Codes.clinical_information(), opts[:clinical_info])

    [
      ContentItem.container(Codes.patient_characteristics(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 5002: Procedure Summary -------------------------------------------

  @doc """
  Builds TID 5002 Procedure Summary content items.

  ## Options

    * `:fetal_number` -- number of fetuses (number)
    * `:fetal_presentation` -- fetal presentation Code
    * `:fetal_heart_activity` -- fetal heart activity Code
    * `:placenta_location` -- placenta location Code
    * `:description` -- procedure summary description (TEXT)

  """
  @spec procedure_summary(keyword()) :: [ContentItem.t()]
  def procedure_summary(opts \\ []) do
    children =
      []
      |> add_num_child(Codes.fetal_number(), opts[:fetal_number], nil)
      |> add_code_child(Codes.fetal_presentation(), opts[:fetal_presentation])
      |> add_code_child(Codes.fetal_heart_activity(), opts[:fetal_heart_activity])
      |> add_code_child(Codes.placenta_location(), opts[:placenta_location])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.procedure_summary(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 5003: Fetus Summary -----------------------------------------------

  @doc """
  Builds TID 5003 Fetus Summary content items.

  ## Options

    * `:fetus_id` -- fetus identifier (TEXT)
    * `:fetal_presentation` -- fetal presentation Code
    * `:fetal_heart_activity` -- fetal heart activity Code
    * `:biometry` -- fetal biometry options (keyword, see `fetal_biometry/1`)
    * `:estimated_weight` -- estimated weight options (keyword, see `estimated_fetal_weight/1`)

  """
  @spec fetus_summary(keyword()) :: [ContentItem.t()]
  def fetus_summary(opts \\ []) do
    children =
      []
      |> add_text_child(Codes.fetus_id(), opts[:fetus_id])
      |> add_code_child(Codes.fetal_presentation(), opts[:fetal_presentation])
      |> add_code_child(Codes.fetal_heart_activity(), opts[:fetal_heart_activity])
      |> add_items(biometry_items(opts[:biometry]))
      |> add_items(weight_items(opts[:estimated_weight]))

    [
      ContentItem.container(Codes.fetus_summary(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 5004: Fetal Biometry (Group) --------------------------------------

  @doc """
  Builds TID 5004 Fetal Biometry group content items.

  ## Options

    * `:head` -- head biometry options (keyword, see `head_biometry/1`)
    * `:abdomen` -- abdominal biometry options (keyword, see `abdominal_biometry/1`)
    * `:limb` -- limb biometry options (keyword, see `limb_biometry/1`)

  """
  @spec fetal_biometry(keyword()) :: [ContentItem.t()]
  def fetal_biometry(opts \\ []) do
    children =
      []
      |> add_items(head_items(opts[:head]))
      |> add_items(abdomen_items(opts[:abdomen]))
      |> add_items(limb_items(opts[:limb]))

    [
      ContentItem.container(Codes.fetal_biometry(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 5005: Head and Skull Biometry -------------------------------------

  @doc """
  Builds TID 5005 Head and Skull Biometry content items.

  ## Options

    * `:bpd` -- biparietal diameter (number, with `:units`)
    * `:hc` -- head circumference (number, with `:units`)
    * `:units` -- measurement units Code (default: mm)

  """
  @spec head_biometry(keyword()) :: [ContentItem.t()]
  def head_biometry(opts \\ []) do
    units = opts[:units] || Codes.millimeter()

    []
    |> add_num_child(Codes.biparietal_diameter(), opts[:bpd], units)
    |> add_num_child(Codes.head_circumference(), opts[:hc], units)
  end

  # -- TID 5006: Abdominal Biometry ------------------------------------------

  @doc """
  Builds TID 5006 Abdominal Biometry content items.

  ## Options

    * `:ac` -- abdominal circumference (number, with `:units`)
    * `:units` -- measurement units Code (default: mm)

  """
  @spec abdominal_biometry(keyword()) :: [ContentItem.t()]
  def abdominal_biometry(opts \\ []) do
    units = opts[:units] || Codes.millimeter()

    []
    |> add_num_child(Codes.abdominal_circumference(), opts[:ac], units)
  end

  # -- TID 5007: Limb Biometry -----------------------------------------------

  @doc """
  Builds TID 5007 Limb Biometry content items.

  ## Options

    * `:fl` -- femur length (number, with `:units`)
    * `:units` -- measurement units Code (default: mm)

  """
  @spec limb_biometry(keyword()) :: [ContentItem.t()]
  def limb_biometry(opts \\ []) do
    units = opts[:units] || Codes.millimeter()

    []
    |> add_num_child(Codes.femur_length(), opts[:fl], units)
  end

  # -- TID 5008: Estimated Fetal Weight --------------------------------------

  @doc """
  Builds TID 5008 Estimated Fetal Weight content items.

  ## Options

    * `:weight` -- estimated weight (number, with `:units`)
    * `:units` -- weight units Code
    * `:method` -- estimation method Code
    * `:percentile` -- weight percentile (number)

  """
  @spec estimated_fetal_weight(keyword()) :: [ContentItem.t()]
  def estimated_fetal_weight(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.measurement_method(), opts[:method])
      |> add_num_child(Codes.finding(), opts[:percentile], Codes.percent())

    []
    |> add_num_item_with_children(
      Codes.estimated_fetal_weight(),
      opts[:weight],
      opts[:units],
      children
    )
  end

  # -- TID 5009: Biophysical Profile ------------------------------------------

  @doc """
  Builds TID 5009 Biophysical Profile content items.

  ## Options

    * `:fetal_breathing` -- fetal breathing score (number)
    * `:fetal_movement` -- fetal movement score (number)
    * `:fetal_tone` -- fetal tone score (number)
    * `:amniotic_fluid` -- amniotic fluid score (number)
    * `:nst` -- non-stress test score (number)
    * `:total_score` -- total biophysical profile score (number)

  """
  @spec biophysical_profile(keyword()) :: [ContentItem.t()]
  def biophysical_profile(opts \\ []) do
    breathing_code = Code.new("122157", "DCM", "Fetal Breathing Score")
    movement_code = Code.new("122158", "DCM", "Fetal Movement Score")
    tone_code = Code.new("122159", "DCM", "Fetal Tone Score")
    fluid_code = Code.new("122160", "DCM", "Amniotic Fluid Score")
    nst_code = Code.new("122161", "DCM", "Non-Stress Test Score")
    total_code = Code.new("122156", "DCM", "Biophysical Profile Total Score")

    []
    |> add_num_child(breathing_code, opts[:fetal_breathing], nil)
    |> add_num_child(movement_code, opts[:fetal_movement], nil)
    |> add_num_child(tone_code, opts[:fetal_tone], nil)
    |> add_num_child(fluid_code, opts[:amniotic_fluid], nil)
    |> add_num_child(nst_code, opts[:nst], nil)
    |> add_num_child(total_code, opts[:total_score], nil)
  end

  # -- TID 5010: Amniotic Sac ------------------------------------------------

  @doc """
  Builds TID 5010 Amniotic Sac content items.

  ## Options

    * `:afi` -- amniotic fluid index (number, with `:afi_units`)
    * `:afi_units` -- units for AFI (default: cm)
    * `:sdp` -- single deepest pocket (number, with `:sdp_units`)
    * `:sdp_units` -- units for SDP (default: cm)

  """
  @spec amniotic_sac(keyword()) :: [ContentItem.t()]
  def amniotic_sac(opts \\ []) do
    cm = Code.new("cm", "UCUM", "centimeter")
    afi_units = opts[:afi_units] || cm
    sdp_units = opts[:sdp_units] || cm

    children =
      []
      |> add_num_child(Codes.amniotic_fluid_index(), opts[:afi], afi_units)
      |> add_num_child(Codes.single_deepest_pocket(), opts[:sdp], sdp_units)

    [
      ContentItem.container(Codes.amniotic_sac(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 5011: Early Gestation ---------------------------------------------

  @doc """
  Builds TID 5011 Early Gestation content items.

  ## Options

    * `:gestational_age` -- gestational age (number, with `:ga_units`)
    * `:ga_units` -- units for gestational age
    * `:crown_rump_length` -- CRL (number, with `:crl_units`)
    * `:crl_units` -- units for CRL (default: mm)
    * `:yolk_sac_diameter` -- yolk sac diameter (number, with `:ysd_units`)
    * `:ysd_units` -- units for YSD (default: mm)
    * `:fetal_heart_activity` -- fetal heart activity Code

  """
  @spec early_gestation(keyword()) :: [ContentItem.t()]
  def early_gestation(opts \\ []) do
    mm = Codes.millimeter()
    crl_code = Code.new("11957-8", "LN", "Crown rump length")
    ysd_code = Code.new("11818-2", "LN", "Yolk sac diameter")

    []
    |> add_num_child(Codes.gestational_age(), opts[:gestational_age], opts[:ga_units])
    |> add_num_child(crl_code, opts[:crown_rump_length], opts[:crl_units] || mm)
    |> add_num_child(ysd_code, opts[:yolk_sac_diameter], opts[:ysd_units] || mm)
    |> add_code_child(Codes.fetal_heart_activity(), opts[:fetal_heart_activity])
  end

  # -- TID 5012-5017: Gynecologic structures ---------------------------------

  @doc """
  Builds TID 5012 Ovaries content items.

  ## Options

    * `:laterality` -- laterality Code (left/right)
    * `:length` -- ovary length (number, with `:units`)
    * `:width` -- ovary width (number, with `:units`)
    * `:volume` -- ovary volume (number, with `:volume_units`)
    * `:volume_units` -- units for volume
    * `:units` -- length/width units Code (default: mm)
    * `:findings` -- findings description (TEXT)

  """
  @spec ovaries(keyword()) :: [ContentItem.t()]
  def ovaries(opts \\ []) do
    units = opts[:units] || Codes.millimeter()

    children =
      []
      |> add_code_child(Codes.laterality(), opts[:laterality])
      |> add_num_child(Codes.organ_length(), opts[:length], units)
      |> add_num_child(Codes.organ_width(), opts[:width], units)
      |> add_num_child(Codes.organ_volume(), opts[:volume], opts[:volume_units])
      |> add_text_child(Codes.finding(), opts[:findings])

    [
      ContentItem.container(Codes.finding_site(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  @doc """
  Builds TID 5013 Pelvis content items.

  ## Options

    * `:findings` -- pelvis findings description (TEXT)

  """
  @spec pelvis(keyword()) :: [ContentItem.t()]
  def pelvis(opts \\ []) do
    children =
      []
      |> add_text_child(Codes.finding(), opts[:findings])

    [
      ContentItem.container(Codes.pelvis_and_uterus(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  @doc """
  Builds TID 5014 Uterus content items.

  ## Options

    * `:length` -- uterus length (number, with `:units`)
    * `:width` -- uterus width (number, with `:units`)
    * `:units` -- measurement units Code (default: mm)
    * `:findings` -- uterus findings description (TEXT)

  """
  @spec uterus(keyword()) :: [ContentItem.t()]
  def uterus(opts \\ []) do
    units = opts[:units] || Codes.millimeter()

    children =
      []
      |> add_num_child(Codes.organ_length(), opts[:length], units)
      |> add_num_child(Codes.organ_width(), opts[:width], units)
      |> add_text_child(Codes.finding(), opts[:findings])

    [
      ContentItem.container(Codes.pelvis_and_uterus(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  @doc """
  Builds TID 5015 Cervix content items.

  ## Options

    * `:cervical_length` -- cervical length (number, with `:units`)
    * `:units` -- measurement units Code (default: mm)
    * `:findings` -- cervix findings (TEXT)

  """
  @spec cervix(keyword()) :: [ContentItem.t()]
  def cervix(opts \\ []) do
    units = opts[:units] || Codes.millimeter()

    []
    |> add_num_child(Codes.cervical_length(), opts[:cervical_length], units)
    |> add_text_child(Codes.finding(), opts[:findings])
  end

  @doc """
  Builds TID 5016 Adnexa content items.

  ## Options

    * `:laterality` -- laterality Code
    * `:findings` -- adnexa findings (TEXT)

  """
  @spec adnexa(keyword()) :: [ContentItem.t()]
  def adnexa(opts \\ []) do
    children =
      []
      |> add_code_child(Codes.laterality(), opts[:laterality])
      |> add_text_child(Codes.finding(), opts[:findings])

    [
      ContentItem.container(Codes.finding_site(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  @doc """
  Builds TID 5017 Cul-de-Sac content items.

  ## Options

    * `:fluid` -- presence of fluid Code
    * `:findings` -- cul-de-sac findings (TEXT)

  """
  @spec cul_de_sac(keyword()) :: [ContentItem.t()]
  def cul_de_sac(opts \\ []) do
    fluid_code = Code.new("122161", "DCM", "Fluid in Cul-de-Sac")

    []
    |> add_code_child(fluid_code, opts[:fluid])
    |> add_text_child(Codes.finding(), opts[:findings])
  end

  # -- TID 5025: Fetal Vascular Measurement Group ----------------------------

  @doc """
  Builds TID 5025 Fetal Vascular Measurement Group content items.

  ## Options

    * `:vessel` -- vessel Code
    * `:peak_systolic_velocity` -- PSV (number, with `:velocity_units`)
    * `:end_diastolic_velocity` -- EDV (number, with `:velocity_units`)
    * `:velocity_units` -- units for velocity
    * `:pulsatility_index` -- PI (number)
    * `:resistive_index` -- RI (number)

  """
  @spec fetal_vascular(keyword()) :: [ContentItem.t()]
  def fetal_vascular(opts \\ []) do
    vel_units = opts[:velocity_units] || Code.new("cm/s", "UCUM", "centimeters per second")

    children =
      []
      |> add_code_child(Codes.finding_site(), opts[:vessel])
      |> add_num_child(Codes.peak_systolic_velocity(), opts[:peak_systolic_velocity], vel_units)
      |> add_num_child(Codes.end_diastolic_velocity(), opts[:end_diastolic_velocity], vel_units)
      |> add_num_child(Codes.pulsatility_index(), opts[:pulsatility_index], nil)
      |> add_num_child(Codes.resistive_index(), opts[:resistive_index], nil)

    [
      ContentItem.container(Codes.vascular_section(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 5026: Maternal Vascular Measurement Group -------------------------

  @doc """
  Builds TID 5026 Maternal Vascular Measurement Group content items.

  Same structure as fetal vascular but for maternal vessels.

  ## Options

  Same as `fetal_vascular/1`.

  """
  @spec maternal_vascular(keyword()) :: [ContentItem.t()]
  def maternal_vascular(opts), do: fetal_vascular(opts)

  # -- TID 5030: Fetal Anatomy Survey ----------------------------------------

  @doc """
  Builds TID 5030 Fetal Anatomy Survey content items.

  ## Options

    * `:evaluations` -- list of `{anatomy_code, finding_code}` tuples
    * `:description` -- survey description (TEXT)

  """
  @spec fetal_anatomy_survey(keyword()) :: [ContentItem.t()]
  def fetal_anatomy_survey(opts \\ []) do
    evaluations = Keyword.get(opts, :evaluations, [])

    eval_items =
      Enum.map(evaluations, fn {anatomy, finding} ->
        ContentItem.code(anatomy, finding, relationship_type: "CONTAINS")
      end)

    children =
      eval_items
      |> add_text_child(Codes.procedure_description(), opts[:description])

    [
      ContentItem.container(Codes.findings(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- Private helpers -------------------------------------------------------

  defp add_items(items, []), do: items
  defp add_items(items, more), do: items ++ more

  defp biometry_items(nil), do: []
  defp biometry_items(opts), do: fetal_biometry(opts)

  defp weight_items(nil), do: []
  defp weight_items(opts), do: estimated_fetal_weight(opts)

  defp head_items(nil), do: []
  defp head_items(opts), do: head_biometry(opts)

  defp abdomen_items(nil), do: []
  defp abdomen_items(opts), do: abdominal_biometry(opts)

  defp limb_items(nil), do: []
  defp limb_items(opts), do: limb_biometry(opts)

  defp add_code_child(children, _concept, nil), do: children

  defp add_code_child(children, concept, %Code{} = code) do
    children ++ [ContentItem.code(concept, code, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_text_child(children, _concept, nil), do: children

  defp add_text_child(children, concept, text) when is_binary(text) do
    children ++ [ContentItem.text(concept, text, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, _concept, nil, _units), do: children

  defp add_num_child(children, concept, value, nil) when is_number(value) do
    no_units = Code.new("1", "UCUM", "no units")
    children ++ [ContentItem.num(concept, value, no_units, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, concept, value, %Code{} = units) when is_number(value) do
    children ++ [ContentItem.num(concept, value, units, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_date_child(children, _concept, nil), do: children

  defp add_date_child(children, concept, date) when is_binary(date) do
    children ++ [ContentItem.date(concept, date, relationship_type: "HAS CONCEPT MOD")]
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
end
