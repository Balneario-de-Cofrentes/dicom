defmodule Dicom.SR.SubTemplates.OBGYNTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.OBGYN

  @cm Code.new("cm", "UCUM", "centimeter")
  @cm_s Code.new("cm/s", "UCUM", "centimeters per second")
  @g Code.new("g", "UCUM", "gram")
  @weeks Code.new("wk", "UCUM", "week")
  @ml Code.new("mL", "UCUM", "milliliter")
  @cephalic Code.new("70028003", "SCT", "Cephalic presentation")
  @active Code.new("11948-7", "LN", "Fetal heart activity present")
  @anterior Code.new("261183002", "SCT", "Anterior")
  @left Code.new("7771000", "SCT", "Left")
  @right Code.new("24028007", "SCT", "Right")
  @present Code.new("52101004", "SCT", "Present")
  @normal Code.new("17621005", "SCT", "Normal")
  @umbilical_artery Code.new("243938005", "SCT", "Umbilical artery")
  @uterine_artery Code.new("15825003", "SCT", "Uterine artery")
  @hadlock Code.new("122150", "DCM", "Hadlock formula")
  @head Code.new("302548004", "SCT", "Fetal head")
  @spine Code.new("421060004", "SCT", "Fetal spine")

  # -- TID 5001 Patient Characteristics (OB-GYN) ----------------------------

  describe "patient_characteristics/1" do
    test "builds patient characteristics container" do
      [item] =
        OBGYN.patient_characteristics(
          gravidity: 3,
          parity: 2,
          lmp: "20240101",
          edd: "20241008",
          gestational_age: 20,
          ga_units: @weeks,
          clinical_info: "Routine anatomy scan"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.patient_characteristics()
      assert length(item.children) == 6
    end

    test "builds minimal patient characteristics" do
      [item] = OBGYN.patient_characteristics()
      assert item.children == []
    end

    test "partial characteristics" do
      [item] =
        OBGYN.patient_characteristics(
          gravidity: 1,
          lmp: "20240301"
        )

      assert length(item.children) == 2
    end
  end

  # -- TID 5002 Procedure Summary -------------------------------------------

  describe "procedure_summary/1" do
    test "builds procedure summary container" do
      [item] =
        OBGYN.procedure_summary(
          fetal_number: 1,
          fetal_presentation: @cephalic,
          fetal_heart_activity: @active,
          placenta_location: @anterior,
          description: "Second trimester anatomy scan"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.procedure_summary()
      assert length(item.children) == 5
    end

    test "builds minimal procedure summary" do
      [item] = OBGYN.procedure_summary()
      assert item.children == []
    end
  end

  # -- TID 5003 Fetus Summary ------------------------------------------------

  describe "fetus_summary/1" do
    test "builds fetus summary container" do
      [item] =
        OBGYN.fetus_summary(
          fetus_id: "A",
          fetal_presentation: @cephalic,
          fetal_heart_activity: @active,
          biometry: [
            head: [bpd: 50, hc: 180],
            abdomen: [ac: 160],
            limb: [fl: 35]
          ]
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.fetus_summary()
      # 3 text/code items + 1 biometry container
      assert length(item.children) == 4
    end

    test "includes estimated weight" do
      [item] =
        OBGYN.fetus_summary(estimated_weight: [weight: 350, units: @g])

      assert length(item.children) == 1
    end

    test "builds minimal fetus summary" do
      [item] = OBGYN.fetus_summary()
      assert item.children == []
    end
  end

  # -- TID 5004 Fetal Biometry -----------------------------------------------

  describe "fetal_biometry/1" do
    test "builds fetal biometry container" do
      [item] =
        OBGYN.fetal_biometry(
          head: [bpd: 50, hc: 180],
          abdomen: [ac: 160],
          limb: [fl: 35]
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.fetal_biometry()
      # 2 head + 1 abdomen + 1 limb = 4
      assert length(item.children) == 4
    end

    test "builds minimal fetal biometry" do
      [item] = OBGYN.fetal_biometry()
      assert item.children == []
    end
  end

  # -- TID 5005 Head Biometry -----------------------------------------------

  describe "head_biometry/1" do
    test "builds head biometry measurements" do
      items = OBGYN.head_biometry(bpd: 50, hc: 180)
      assert length(items) == 2

      [bpd, hc] = items
      assert bpd.concept_name == Codes.biparietal_diameter()
      assert hc.concept_name == Codes.head_circumference()
    end

    test "defaults to mm units" do
      [item] = OBGYN.head_biometry(bpd: 48)
      assert item.value.units == Codes.millimeter()
    end

    test "empty returns empty list" do
      assert OBGYN.head_biometry() == []
    end
  end

  # -- TID 5006 Abdominal Biometry ------------------------------------------

  describe "abdominal_biometry/1" do
    test "builds abdominal biometry" do
      [item] = OBGYN.abdominal_biometry(ac: 160)
      assert item.concept_name == Codes.abdominal_circumference()
      assert item.value.units == Codes.millimeter()
    end

    test "empty returns empty list" do
      assert OBGYN.abdominal_biometry() == []
    end
  end

  # -- TID 5007 Limb Biometry -----------------------------------------------

  describe "limb_biometry/1" do
    test "builds limb biometry" do
      [item] = OBGYN.limb_biometry(fl: 35)
      assert item.concept_name == Codes.femur_length()
      assert item.value.units == Codes.millimeter()
    end

    test "empty returns empty list" do
      assert OBGYN.limb_biometry() == []
    end
  end

  # -- TID 5008 Estimated Fetal Weight ---------------------------------------

  describe "estimated_fetal_weight/1" do
    test "builds estimated fetal weight" do
      [item] =
        OBGYN.estimated_fetal_weight(
          weight: 350,
          units: @g,
          method: @hadlock,
          percentile: 50
        )

      assert item.value_type == :num
      assert item.concept_name == Codes.estimated_fetal_weight()
      assert item.value.units == @g
      # method + percentile children
      assert length(item.children) == 2
    end

    test "weight-only" do
      [item] = OBGYN.estimated_fetal_weight(weight: 500, units: @g)
      assert item.value_type == :num
    end

    test "empty returns empty list" do
      assert OBGYN.estimated_fetal_weight() == []
    end
  end

  # -- TID 5009 Biophysical Profile ------------------------------------------

  describe "biophysical_profile/1" do
    test "builds complete biophysical profile" do
      items =
        OBGYN.biophysical_profile(
          fetal_breathing: 2,
          fetal_movement: 2,
          fetal_tone: 2,
          amniotic_fluid: 2,
          nst: 2,
          total_score: 10
        )

      assert length(items) == 6
    end

    test "partial profile" do
      items = OBGYN.biophysical_profile(total_score: 8)
      assert length(items) == 1
    end

    test "empty returns empty list" do
      assert OBGYN.biophysical_profile() == []
    end
  end

  # -- TID 5010 Amniotic Sac ------------------------------------------------

  describe "amniotic_sac/1" do
    test "builds amniotic sac container" do
      [item] =
        OBGYN.amniotic_sac(
          afi: 12.5,
          sdp: 4.2
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.amniotic_sac()
      assert length(item.children) == 2
    end

    test "defaults to cm units" do
      [item] = OBGYN.amniotic_sac(afi: 15.0)
      [afi_child] = item.children
      assert afi_child.value.units == @cm
    end

    test "builds minimal amniotic sac" do
      [item] = OBGYN.amniotic_sac()
      assert item.children == []
    end
  end

  # -- TID 5011 Early Gestation ---------------------------------------------

  describe "early_gestation/1" do
    test "builds early gestation items" do
      items =
        OBGYN.early_gestation(
          gestational_age: 8,
          ga_units: @weeks,
          crown_rump_length: 16.5,
          yolk_sac_diameter: 4.0,
          fetal_heart_activity: @active
        )

      assert length(items) == 4
    end

    test "CRL defaults to mm" do
      [_ga, crl] =
        OBGYN.early_gestation(
          gestational_age: 7,
          ga_units: @weeks,
          crown_rump_length: 10.0
        )

      assert crl.value.units == Codes.millimeter()
    end

    test "empty returns empty list" do
      assert OBGYN.early_gestation() == []
    end
  end

  # -- TID 5012 Ovaries ------------------------------------------------------

  describe "ovaries/1" do
    test "builds ovary container" do
      [item] =
        OBGYN.ovaries(
          laterality: @left,
          length: 30,
          width: 20,
          volume: 8.5,
          volume_units: @ml,
          findings: "Normal ovary"
        )

      assert item.value_type == :container
      assert length(item.children) == 5
    end

    test "builds minimal ovary" do
      [item] = OBGYN.ovaries()
      assert item.children == []
    end
  end

  # -- TID 5013 Pelvis -------------------------------------------------------

  describe "pelvis/1" do
    test "builds pelvis container" do
      [item] = OBGYN.pelvis(findings: "No free fluid")
      assert item.value_type == :container
      assert item.concept_name == Codes.pelvis_and_uterus()
      assert length(item.children) == 1
    end

    test "builds minimal pelvis" do
      [item] = OBGYN.pelvis()
      assert item.children == []
    end
  end

  # -- TID 5014 Uterus -------------------------------------------------------

  describe "uterus/1" do
    test "builds uterus container" do
      [item] =
        OBGYN.uterus(
          length: 80,
          width: 50,
          findings: "Anteverted uterus, no fibroids"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.pelvis_and_uterus()
      assert length(item.children) == 3
    end

    test "builds minimal uterus" do
      [item] = OBGYN.uterus()
      assert item.children == []
    end
  end

  # -- TID 5015 Cervix -------------------------------------------------------

  describe "cervix/1" do
    test "builds cervix measurements" do
      items =
        OBGYN.cervix(
          cervical_length: 35,
          findings: "Closed, normal length"
        )

      assert length(items) == 2
    end

    test "empty returns empty list" do
      assert OBGYN.cervix() == []
    end
  end

  # -- TID 5016 Adnexa -------------------------------------------------------

  describe "adnexa/1" do
    test "builds adnexa container" do
      [item] =
        OBGYN.adnexa(
          laterality: @right,
          findings: "No adnexal mass"
        )

      assert item.value_type == :container
      assert length(item.children) == 2
    end

    test "builds minimal adnexa" do
      [item] = OBGYN.adnexa()
      assert item.children == []
    end
  end

  # -- TID 5017 Cul-de-Sac ---------------------------------------------------

  describe "cul_de_sac/1" do
    test "builds cul-de-sac items" do
      items =
        OBGYN.cul_de_sac(
          fluid: @present,
          findings: "Small amount of free fluid"
        )

      assert length(items) == 2
    end

    test "empty returns empty list" do
      assert OBGYN.cul_de_sac() == []
    end
  end

  # -- TID 5025 Fetal Vascular -----------------------------------------------

  describe "fetal_vascular/1" do
    test "builds fetal vascular measurement group" do
      [item] =
        OBGYN.fetal_vascular(
          vessel: @umbilical_artery,
          peak_systolic_velocity: 45.0,
          end_diastolic_velocity: 15.0,
          velocity_units: @cm_s,
          pulsatility_index: 1.2,
          resistive_index: 0.67
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.vascular_section()
      # vessel + PSV + EDV + PI + RI = 5
      assert length(item.children) == 5
    end

    test "partial vascular measurements" do
      [item] =
        OBGYN.fetal_vascular(
          vessel: @umbilical_artery,
          pulsatility_index: 1.1
        )

      # vessel + PI = 2
      assert length(item.children) == 2
    end

    test "builds minimal fetal vascular" do
      [item] = OBGYN.fetal_vascular([])
      assert item.children == []
    end
  end

  # -- TID 5026 Maternal Vascular -------------------------------------------

  describe "maternal_vascular/1" do
    test "delegates to fetal_vascular" do
      [item] =
        OBGYN.maternal_vascular(
          vessel: @uterine_artery,
          pulsatility_index: 0.8
        )

      assert item.value_type == :container
      assert length(item.children) == 2
    end
  end

  # -- TID 5030 Fetal Anatomy Survey ----------------------------------------

  describe "fetal_anatomy_survey/1" do
    test "builds fetal anatomy survey container" do
      [item] =
        OBGYN.fetal_anatomy_survey(
          evaluations: [
            {@head, @normal},
            {@spine, @normal}
          ],
          description: "Complete anatomy survey"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.findings()
      # 2 evaluations + 1 description = 3
      assert length(item.children) == 3
    end

    test "builds minimal anatomy survey" do
      [item] = OBGYN.fetal_anatomy_survey()
      assert item.children == []
    end
  end
end
