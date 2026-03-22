defmodule Dicom.SR.SubTemplates.ProcedureActionsTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.ProcedureActions

  @mmhg Code.new("mm[Hg]", "UCUM", "mmHg")
  @bpm Code.new("/min", "UCUM", "beats per minute")
  @ml Code.new("mL", "UCUM", "milliliter")
  @mg Code.new("mg", "UCUM", "milligram")
  @mv Code.new("mV", "UCUM", "millivolt")
  @femoral Code.new("7657000", "SCT", "Femoral artery")
  @lad Code.new("53655008", "SCT", "Left anterior descending coronary artery")
  @xray Code.new("CR", "DCM", "Computed Radiography")
  @iv_route Code.new("47625008", "SCT", "Intravenous route")
  @heparin Code.new("372877000", "SCT", "Heparin")
  @balloon Code.new("122346", "DCM", "Balloon catheter")
  @pigtail Code.new("111026", "DCM", "Pigtail catheter")
  @blood Code.new("119297000", "SCT", "Blood specimen")
  @severe Code.new("24484000", "SCT", "Severe")
  @stenosis_type Code.new("36228007", "SCT", "Coronary artery stenosis")
  @resting_state Code.new("128972", "DCM", "Resting state")
  @ecg_lead Code.new("I", "SCPECG", "Lead I")
  @diameter Code.new("410668003", "SCT", "Length")
  @mm Code.new("mm", "UCUM", "millimeter")
  @action_type Code.new("121148", "DCM", "Procedure Action")

  # -- TID 3100 Procedure Action ---------------------------------------------

  describe "procedure_action/1" do
    test "builds a procedure action container" do
      [item] =
        ProcedureActions.procedure_action(
          action_type: @action_type,
          datetime: "20240101120000",
          description: "Catheter insertion"
        )

      assert item.value_type == :container
      assert item.concept_name == @action_type
      assert item.relationship_type == "CONTAINS"
      assert length(item.children) == 2
    end

    test "builds minimal procedure action" do
      [item] =
        ProcedureActions.procedure_action(action_type: @action_type)

      assert item.value_type == :container
      assert item.children == []
    end

    test "includes additional children" do
      extra =
        Dicom.SR.ContentItem.text(Codes.comment(), "test note", relationship_type: "CONTAINS")

      [item] =
        ProcedureActions.procedure_action(
          action_type: @action_type,
          children: [extra]
        )

      assert length(item.children) == 1
    end
  end

  # -- TID 3101 Image Acquisition -------------------------------------------

  describe "image_acquisition/1" do
    test "builds image acquisition container" do
      [item] =
        ProcedureActions.image_acquisition(
          datetime: "20240101120000",
          description: "Coronary angiogram",
          modality: @xray,
          target: @lad
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.image_acquisition()
      assert length(item.children) == 4
    end

    test "builds minimal image acquisition" do
      [item] = ProcedureActions.image_acquisition()
      assert item.value_type == :container
      assert item.children == []
    end
  end

  # -- TID 3102 Waveform Acquisition ----------------------------------------

  describe "waveform_acquisition/1" do
    test "builds waveform acquisition container" do
      waveform_type = Code.new("122172", "DCM", "ECG Waveform")

      [item] =
        ProcedureActions.waveform_acquisition(
          datetime: "20240101120100",
          description: "12-lead ECG",
          waveform_type: waveform_type
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.waveform_reference()
      assert length(item.children) == 3
    end

    test "builds minimal waveform acquisition" do
      [item] = ProcedureActions.waveform_acquisition()
      assert item.children == []
    end
  end

  # -- TID 3103 Referenced Object -------------------------------------------

  describe "referenced_object/1" do
    test "builds referenced object container" do
      [item] =
        ProcedureActions.referenced_object(
          uid: "1.2.840.10008.1.1",
          description: "Prior study reference"
        )

      assert item.value_type == :container
      assert length(item.children) == 2
    end

    test "builds minimal referenced object" do
      [item] = ProcedureActions.referenced_object()
      assert item.children == []
    end
  end

  # -- TID 3104 Consumables ------------------------------------------------

  describe "consumables/1" do
    test "builds consumables container" do
      contrast = Code.new("385420005", "SCT", "Contrast media")

      [item] =
        ProcedureActions.consumables(
          consumable: contrast,
          quantity: 100,
          quantity_units: @ml,
          description: "Iodinated contrast agent"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.consumable_used()
      assert length(item.children) == 3
    end

    test "builds minimal consumables" do
      [item] = ProcedureActions.consumables()
      assert item.children == []
    end
  end

  # -- TID 3105 Lesion Properties -------------------------------------------

  describe "lesion_properties/1" do
    test "builds lesion properties container" do
      [item] =
        ProcedureActions.lesion_properties(
          lesion_type: @stenosis_type,
          severity: @severe,
          finding_site: @lad,
          description: "95% stenosis in proximal LAD"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.lesion()
      assert length(item.children) == 4
    end

    test "builds minimal lesion properties" do
      [item] = ProcedureActions.lesion_properties()
      assert item.children == []
    end
  end

  # -- TID 3106 Drugs/Contrast Agent Administration -------------------------

  describe "drugs_contrast/1" do
    test "builds drug administration container" do
      [item] =
        ProcedureActions.drugs_contrast(
          drug: @heparin,
          dose: 5000,
          dose_units: @mg,
          route: @iv_route,
          datetime: "20240101120000"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.drug_administered()
      assert length(item.children) == 4
    end

    test "builds minimal drug administration" do
      [item] = ProcedureActions.drugs_contrast()
      assert item.children == []
    end
  end

  # -- TID 3107 Device Used ------------------------------------------------

  describe "device_used/1" do
    test "builds device used container" do
      [item] =
        ProcedureActions.device_used(
          device_type: @balloon,
          device_name: "TREK 2.5x15mm",
          description: "Balloon dilation catheter"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.device()
      assert length(item.children) == 3
    end

    test "builds minimal device used" do
      [item] = ProcedureActions.device_used()
      assert item.children == []
    end
  end

  # -- TID 3108 Intervention ------------------------------------------------

  describe "intervention/1" do
    test "builds intervention container" do
      pci = Code.new("122152", "DCM", "PCI Procedure")

      [item] =
        ProcedureActions.intervention(
          intervention_type: pci,
          finding_site: @lad,
          description: "PTCA with stent placement",
          datetime: "20240101130000"
        )

      assert item.value_type == :container
      assert item.concept_name == pci
      assert length(item.children) == 3
    end

    test "defaults to procedure action concept" do
      [item] = ProcedureActions.intervention()
      assert item.concept_name == Codes.procedure_action()
    end
  end

  # -- TID 3109 Measurements -----------------------------------------------

  describe "measurements/1" do
    test "builds multiple measurements with shared site" do
      items =
        ProcedureActions.measurements(
          finding_site: @lad,
          measurements: [
            [concept: @diameter, value: 3.5, units: @mm],
            [concept: Codes.lesion_size(), value: 15.0, units: @mm]
          ]
        )

      assert length(items) == 2

      Enum.each(items, fn item ->
        assert item.value_type == :num
        site_child = Enum.find(item.children, &(&1.concept_name == Codes.finding_site()))
        assert site_child != nil
      end)
    end

    test "per-measurement site overrides shared site" do
      items =
        ProcedureActions.measurements(
          finding_site: @lad,
          measurements: [
            [concept: @diameter, value: 3.5, units: @mm, finding_site: @femoral]
          ]
        )

      [item] = items
      site_child = Enum.find(item.children, &(&1.concept_name == Codes.finding_site()))
      assert site_child.value == @femoral
    end

    test "empty measurements returns empty list" do
      assert ProcedureActions.measurements() == []
    end
  end

  # -- TID 3110 Impressions ------------------------------------------------

  describe "impressions/1" do
    test "builds impression text items" do
      items =
        ProcedureActions.impressions(
          impressions: ["Normal coronary arteries", "No significant stenosis"]
        )

      assert length(items) == 2

      Enum.each(items, fn item ->
        assert item.value_type == :text
        assert item.concept_name == Codes.impression()
      end)
    end

    test "empty impressions returns empty list" do
      assert ProcedureActions.impressions() == []
    end
  end

  # -- TID 3111 Percutaneous Entry ------------------------------------------

  describe "percutaneous_entry/1" do
    test "builds percutaneous entry container" do
      [item] =
        ProcedureActions.percutaneous_entry(
          access_site: @femoral,
          catheter_type: @pigtail,
          description: "Right femoral artery access"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.access_site()
      assert length(item.children) == 3
    end

    test "builds minimal percutaneous entry" do
      [item] = ProcedureActions.percutaneous_entry()
      assert item.children == []
    end
  end

  # -- TID 3112 Specimen Obtained -------------------------------------------

  describe "specimen_obtained/1" do
    test "builds specimen obtained container" do
      [item] =
        ProcedureActions.specimen_obtained(
          specimen_type: @blood,
          finding_site: @femoral,
          description: "Blood sample from femoral artery"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.specimen_type()
      assert length(item.children) == 3
    end

    test "builds minimal specimen obtained" do
      [item] = ProcedureActions.specimen_obtained()
      assert item.children == []
    end
  end

  # -- TID 3113 Patient Support ---------------------------------------------

  describe "patient_support/1" do
    test "builds patient support container" do
      [item] =
        ProcedureActions.patient_support(
          patient_state: @resting_state,
          description: "Patient supine on table"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.patient_state()
      assert length(item.children) == 2
    end

    test "builds minimal patient support" do
      [item] = ProcedureActions.patient_support()
      assert item.children == []
    end
  end

  # -- TID 3114 Patient Assessment ------------------------------------------

  describe "patient_assessment/1" do
    test "builds patient assessment with vitals" do
      items =
        ProcedureActions.patient_assessment(
          heart_rate: 72,
          heart_rate_units: @bpm,
          systolic_bp: 120,
          diastolic_bp: 80,
          bp_units: @mmhg
        )

      assert length(items) == 3
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.heart_rate() in concepts
      assert Codes.systolic_blood_pressure() in concepts
      assert Codes.diastolic_blood_pressure() in concepts
    end

    test "partial assessment only includes provided values" do
      items =
        ProcedureActions.patient_assessment(
          heart_rate: 80,
          heart_rate_units: @bpm
        )

      assert length(items) == 1
    end

    test "empty assessment returns empty list" do
      assert ProcedureActions.patient_assessment() == []
    end
  end

  # -- TID 3115 ECG ST Assessment -------------------------------------------

  describe "ecg_st_assessment/1" do
    test "builds ECG ST assessment container" do
      [item] =
        ProcedureActions.ecg_st_assessment(
          lead: @ecg_lead,
          st_segment: 0.2,
          st_units: @mv,
          description: "ST elevation in Lead I"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.ecg_global_measurements()
      assert length(item.children) == 3
    end

    test "builds minimal ECG ST assessment" do
      [item] = ProcedureActions.ecg_st_assessment()
      assert item.children == []
    end
  end
end
