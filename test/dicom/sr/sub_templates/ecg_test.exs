defmodule Dicom.SR.SubTemplates.ECGTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.ECG

  @ms Code.new("ms", "UCUM", "millisecond")
  @deg Code.new("deg", "UCUM", "degree")
  @bpm Code.new("/min", "UCUM", "beats per minute")
  @kg Code.new("kg", "UCUM", "kilogram")
  @cm Code.new("cm", "UCUM", "centimeter")
  @years Code.new("a", "UCUM", "year")
  @male Code.new("M", "DCM", "Male")
  @lead_i Code.new("2:1", "MDC", "Lead I")
  @lead_ii Code.new("2:2", "MDC", "Lead II")
  @good_quality Code.new("251602002", "SCT", "Good signal quality")
  @algorithm Code.new("122160", "DCM", "Algorithm")
  @sinus_rhythm Code.new("426783006", "SCT", "Sinus rhythm")
  @normal_conduction Code.new("164925009", "SCT", "Normal conduction")
  @normal_morphology Code.new("17621005", "SCT", "Normal")
  @no_ischemia Code.new("17621005", "SCT", "Normal")
  @lvh Code.new("55827005", "SCT", "Left ventricular hypertrophy")
  @normal Code.new("17621005", "SCT", "Normal")

  # -- TID 3702 Prior ECG Study -----------------------------------------------

  describe "prior_ecg_study/1" do
    test "builds prior ECG study container" do
      [item] =
        ECG.prior_ecg_study(
          study_uid: "1.2.840.10008.1.1",
          study_date: "20230601",
          description: "Prior 12-lead ECG",
          findings: "Normal sinus rhythm"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.history()
      assert length(item.children) == 4
    end

    test "builds minimal prior ECG study" do
      [item] = ECG.prior_ecg_study()
      assert item.children == []
    end
  end

  # -- TID 3704 Patient Characteristics (ECG) --------------------------------

  describe "patient_characteristics/1" do
    test "builds patient characteristics container" do
      [item] =
        ECG.patient_characteristics(
          age: 65,
          age_units: @years,
          sex: @male,
          heart_rate: 72,
          heart_rate_units: @bpm,
          body_weight: 80,
          weight_units: @kg,
          body_height: 180,
          height_units: @cm,
          clinical_info: "Chest pain on exertion"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.patient_characteristics()
      assert length(item.children) == 6
    end

    test "builds minimal patient characteristics" do
      [item] = ECG.patient_characteristics()
      assert item.children == []
    end

    test "partial characteristics" do
      [item] =
        ECG.patient_characteristics(
          heart_rate: 80,
          heart_rate_units: @bpm,
          sex: @male
        )

      assert length(item.children) == 2
    end

    test "age with nil units uses no-units fallback" do
      [item] = ECG.patient_characteristics(age: 65)
      assert length(item.children) == 1
      [age_child] = item.children
      assert age_child.value.units == Code.new("1", "UCUM", "no units")
    end
  end

  # -- TID 3708 Waveform Information -----------------------------------------

  describe "waveform_information/1" do
    test "builds waveform information container" do
      ecg_type = Code.new("122172", "DCM", "12-Lead ECG")

      [item] =
        ECG.waveform_information(
          waveform_type: ecg_type,
          signal_quality: @good_quality,
          description: "12-lead standard ECG",
          filter_description: "0.05-150Hz bandpass"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.waveform_reference()
      assert length(item.children) == 4
    end

    test "builds minimal waveform information" do
      [item] = ECG.waveform_information()
      assert item.children == []
    end
  end

  # -- TID 3713 ECG Global Measurements -------------------------------------

  describe "global_measurements/1" do
    test "builds ECG global measurements container" do
      [item] =
        ECG.global_measurements(
          heart_rate: 72,
          heart_rate_units: @bpm,
          pr_interval: 160,
          qrs_duration: 100,
          qt_interval: 380,
          qtc_interval: 420,
          qrs_axis: 45
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.ecg_global_measurements()
      assert length(item.children) == 6
    end

    test "defaults to millisecond for intervals" do
      [item] =
        ECG.global_measurements(pr_interval: 160)

      [pr_item] = item.children
      assert pr_item.value.units == @ms
    end

    test "defaults to degrees for axis" do
      [item] =
        ECG.global_measurements(qrs_axis: 60)

      [axis_item] = item.children
      assert axis_item.value.units == @deg
    end

    test "includes additional measurements" do
      extra =
        Dicom.SR.ContentItem.num(
          Code.new("122172", "DCM", "RR Interval"),
          830,
          @ms,
          relationship_type: "CONTAINS"
        )

      [item] =
        ECG.global_measurements(
          heart_rate: 72,
          heart_rate_units: @bpm,
          measurements: [extra]
        )

      assert length(item.children) == 2
    end

    test "builds minimal global measurements" do
      [item] = ECG.global_measurements()
      assert item.children == []
    end
  end

  # -- TID 3714 ECG Lead Measurements ----------------------------------------

  describe "lead_measurements/1" do
    test "builds ECG lead measurements container" do
      p_amp = Code.new("122174", "DCM", "P-wave Amplitude")
      r_amp = Code.new("122176", "DCM", "R-wave Amplitude")
      mv = Code.new("mV", "UCUM", "millivolt")

      [item] =
        ECG.lead_measurements(
          lead: @lead_i,
          measurements: [
            [concept: p_amp, value: 0.15, units: mv],
            [concept: r_amp, value: 1.2, units: mv]
          ]
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.ecg_lead_measurements()
      # 1 lead code + 2 measurements
      assert length(item.children) == 3
    end

    test "includes measurement source" do
      [item] =
        ECG.lead_measurements(
          lead: @lead_ii,
          source: [source_type: @algorithm, description: "GE algorithm v5"]
        )

      assert item.value_type == :container
      # 1 lead + 2 source items
      assert length(item.children) == 3
    end

    test "builds minimal lead measurements" do
      [item] = ECG.lead_measurements()
      assert item.children == []
    end
  end

  # -- TID 3715 Measurement Source -------------------------------------------

  describe "measurement_source/1" do
    test "builds measurement source items" do
      items =
        ECG.measurement_source(
          source_type: @algorithm,
          description: "Automated algorithm"
        )

      assert length(items) == 2
    end

    test "empty returns empty list" do
      assert ECG.measurement_source() == []
    end
  end

  # -- TID 3717 Qualitative ECG Analysis ------------------------------------

  describe "qualitative_analysis/1" do
    test "builds qualitative analysis container" do
      [item] =
        ECG.qualitative_analysis(
          rhythm: @sinus_rhythm,
          conduction: @normal_conduction,
          morphology: @normal_morphology,
          ischemia: @no_ischemia,
          description: "Normal ECG"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.findings()
      assert length(item.children) == 5
    end

    test "includes additional findings" do
      [item] =
        ECG.qualitative_analysis(
          rhythm: @sinus_rhythm,
          findings: [@lvh]
        )

      assert length(item.children) == 2

      additional = Enum.find(item.children, &(&1.concept_name == Codes.finding()))
      assert additional != nil
      assert additional.value == @lvh
    end

    test "builds minimal qualitative analysis" do
      [item] = ECG.qualitative_analysis()
      assert item.children == []
    end
  end

  # -- TID 3719 ECG Summary -------------------------------------------------

  describe "ecg_summary/1" do
    test "builds ECG summary container" do
      [item] =
        ECG.ecg_summary(
          impression: "Normal sinus rhythm, no acute changes",
          comparison: "Compared to prior ECG 2023-06-01",
          severity: @normal,
          recommendation: "No further cardiac workup needed"
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.summary()
      assert length(item.children) == 4
    end

    test "impression-only summary" do
      [item] =
        ECG.ecg_summary(impression: "Normal ECG")

      assert length(item.children) == 1
    end

    test "builds minimal ECG summary" do
      [item] = ECG.ecg_summary()
      assert item.children == []
    end
  end
end
