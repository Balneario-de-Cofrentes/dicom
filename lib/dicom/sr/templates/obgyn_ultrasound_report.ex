defmodule Dicom.SR.Templates.OBGYNUltrasoundReport do
  @moduledoc """
  Builder for a practical TID 5000 OB-GYN Ultrasound Procedure Report document.

  The current builder covers the root title, language, observer context,
  procedure reported, patient characteristics (LMP, EDD, gravidity, parity),
  fetus summaries with biometry measurements, amniotic fluid assessment,
  pelvis and uterus measurements, placenta location, and clinical narrative
  sections (findings, impressions, recommendations).

  Structure:

      CONTAINER: OB-GYN Ultrasound Procedure Report (root)
        +-- HAS CONCEPT MOD: Language
        +-- HAS OBS CONTEXT: Observer (person and/or device)
        +-- HAS CONCEPT MOD: Procedure Reported (optional)
        +-- HAS OBS CONTEXT: Patient Characteristics (optional)
        |     +-- DATE: Last Menstrual Period
        |     +-- DATE: Estimated Date of Delivery
        |     +-- NUM: Gravidity
        |     +-- NUM: Parity
        +-- CONTAINS: Fetus Summary (repeating per fetus)
        |     +-- NUM: Fetal Number
        |     +-- CODE: Fetal Presentation
        |     +-- CODE: Fetal Heart Activity
        |     +-- CONTAINS: Fetal Biometry
        |     |     +-- NUM: BPD, HC, AC, FL
        |     +-- NUM: Estimated Fetal Weight
        |     +-- NUM: Gestational Age
        +-- CONTAINS: Amniotic Sac (optional)
        |     +-- NUM: Amniotic Fluid Index
        |     +-- NUM: Single Deepest Pocket
        +-- CONTAINS: Pelvis and Uterus (optional)
        |     +-- NUM: Cervical Length
        +-- CODE: Placenta Location (optional)
        +-- CONTAINS: Finding (0-n)
        +-- CONTAINS: Impression (0-n)
        +-- CONTAINS: Recommendation (0-n)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  import Dicom.SR.Templates.Helpers

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
      |> add_optional(
        optional_patient_characteristics(Keyword.get(opts, :patient_characteristics))
      )
      |> add_optional(fetus_items(Keyword.get(opts, :fetuses, [])))
      |> add_optional(optional_amniotic_fluid(Keyword.get(opts, :amniotic_fluid)))
      |> add_optional(optional_pelvis_uterus(Keyword.get(opts, :pelvis_uterus)))
      |> add_optional(optional_placenta(Keyword.get(opts, :placenta)))
      |> add_optional(map_items(Keyword.get(opts, :findings, []), &Codes.finding/0))
      |> add_optional(map_items(Keyword.get(opts, :impressions, []), &Codes.impression/0))
      |> add_optional(map_items(Keyword.get(opts, :recommendations, []), &Codes.recommendation/0))

    root =
      ContentItem.container(Codes.obgyn_ultrasound_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "5000",
        series_description:
          Keyword.get(opts, :series_description, "OB-GYN Ultrasound Procedure Report")
      )
    )
  end

  # -- Procedure Reported --

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  # -- Patient Characteristics (TID 5001) --

  defp optional_patient_characteristics(nil), do: nil

  defp optional_patient_characteristics(chars) when is_map(chars) do
    children =
      []
      |> add_optional(optional_date_item(Codes.last_menstrual_period(), chars[:lmp]))
      |> add_optional(optional_date_item(Codes.estimated_date_of_delivery(), chars[:edd]))
      |> add_optional(optional_num_item(Codes.gravidity(), chars[:gravidity], unitless_code()))
      |> add_optional(optional_num_item(Codes.parity(), chars[:parity], unitless_code()))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.patient_characteristics(),
        relationship_type: "HAS OBS CONTEXT",
        children: children
      )
    end
  end

  # -- Fetus Summary (TID 5003, repeating) --

  defp fetus_items(fetuses) do
    Enum.map(fetuses, &fetus_summary_item/1)
  end

  defp fetus_summary_item(fetus) when is_map(fetus) do
    children =
      []
      |> add_optional(optional_num_item(Codes.fetal_number(), fetus[:number], unitless_code()))
      |> add_optional(optional_code_item(Codes.fetal_presentation(), fetus[:presentation]))
      |> add_optional(optional_code_item(Codes.fetal_heart_activity(), fetus[:heart_activity]))
      |> add_optional(optional_biometry(fetus[:biometry]))
      |> add_optional(
        optional_num_item(
          Codes.estimated_fetal_weight(),
          fetus[:estimated_weight],
          weight_unit(fetus[:weight_unit])
        )
      )
      |> add_optional(
        optional_num_item(
          Codes.gestational_age(),
          fetus[:gestational_age],
          days_code()
        )
      )

    ContentItem.container(Codes.fetus_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Fetal Biometry (TID 5005) --

  defp optional_biometry(nil), do: nil

  defp optional_biometry(biometry) when is_map(biometry) do
    mm = mm_code()

    children =
      []
      |> add_optional(optional_num_item(Codes.biparietal_diameter(), biometry[:bpd], mm))
      |> add_optional(optional_num_item(Codes.head_circumference(), biometry[:hc], mm))
      |> add_optional(optional_num_item(Codes.abdominal_circumference(), biometry[:ac], mm))
      |> add_optional(optional_num_item(Codes.femur_length(), biometry[:fl], mm))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.fetal_biometry(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  # -- Amniotic Fluid (TID 5010) --

  defp optional_amniotic_fluid(nil), do: nil

  defp optional_amniotic_fluid(fluid) when is_map(fluid) do
    cm = cm_code()

    children =
      []
      |> add_optional(optional_num_item(Codes.amniotic_fluid_index(), fluid[:afi], cm))
      |> add_optional(optional_num_item(Codes.single_deepest_pocket(), fluid[:sdp], cm))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.amniotic_sac(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  # -- Pelvis and Uterus (TID 5015) --

  defp optional_pelvis_uterus(nil), do: nil

  defp optional_pelvis_uterus(pelvis) when is_map(pelvis) do
    children =
      []
      |> add_optional(
        optional_num_item(Codes.cervical_length(), pelvis[:cervical_length], mm_code())
      )

    if children == [] do
      nil
    else
      ContentItem.container(Codes.pelvis_and_uterus(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  # -- Placenta --

  defp optional_placenta(nil), do: nil

  defp optional_placenta(placenta) when is_map(placenta) do
    case placenta[:location] do
      nil ->
        nil

      %Code{} = location_code ->
        ContentItem.code(Codes.placenta_location(), location_code, relationship_type: "CONTAINS")
    end
  end

  # -- Clinical narrative items (findings, impressions, recommendations) --

  defp map_items(values, concept_fn) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(concept_fn.(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(concept_fn.(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- Content item helpers --

  defp optional_date_item(_concept, nil), do: nil

  defp optional_date_item(concept, value) do
    ContentItem.date(concept, value, relationship_type: "CONTAINS")
  end

  defp optional_num_item(_concept, nil, _units), do: nil

  defp optional_num_item(concept, value, units) do
    ContentItem.num(concept, value, units, relationship_type: "CONTAINS")
  end

  defp optional_code_item(_concept, nil), do: nil

  defp optional_code_item(concept, %Code{} = value) do
    ContentItem.code(concept, value, relationship_type: "CONTAINS")
  end

  # -- UCUM unit codes --

  defp mm_code, do: Code.new("mm", "UCUM", "millimeters")
  defp cm_code, do: Code.new("cm", "UCUM", "centimeters")
  defp days_code, do: Code.new("d", "UCUM", "days")
  defp unitless_code, do: Code.new("1", "UCUM", "no units")

  defp weight_unit(nil), do: Code.new("g", "UCUM", "grams")
  defp weight_unit(:g), do: Code.new("g", "UCUM", "grams")
  defp weight_unit(:kg), do: Code.new("kg", "UCUM", "kilograms")
end
