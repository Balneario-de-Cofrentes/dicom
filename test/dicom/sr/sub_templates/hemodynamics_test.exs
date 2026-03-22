defmodule Dicom.SR.SubTemplates.HemodynamicsTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.Hemodynamics

  @mmhg Code.new("mm[Hg]", "UCUM", "mmHg")
  @bpm Code.new("/min", "UCUM", "beats per minute")
  @kg Code.new("kg", "UCUM", "kilogram")
  @cm Code.new("cm", "UCUM", "centimeter")
  @m2 Code.new("m2", "UCUM", "square meter")
  @l_min Code.new("L/min", "UCUM", "liters per minute")
  @ml Code.new("mL", "UCUM", "milliliter")
  @cm_s Code.new("cm/s", "UCUM", "centimeters per second")
  @lv Code.new("87878005", "SCT", "Left ventricle structure")
  @aorta Code.new("15825003", "SCT", "Aortic structure")
  @resting Code.new("128972", "DCM", "Resting state")
  @thermodilution Code.new("122130", "DCM", "Thermodilution")
  @mean Code.new("373098007", "SCT", "Mean")

  # -- TID 3501 Hemodynamic Measurement Group --------------------------------

  describe "hemodynamic_measurement_group/1" do
    test "builds hemodynamic measurement group container" do
      measurement =
        Dicom.SR.ContentItem.num(
          Codes.systolic_blood_pressure(),
          120,
          @mmhg,
          relationship_type: "CONTAINS"
        )

      [item] =
        Hemodynamics.hemodynamic_measurement_group(
          clinical_context: [patient_state: @resting],
          measurements: [measurement]
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.hemodynamic_measurements()
      assert item.relationship_type == "CONTAINS"
      # 1 clinical context item + 1 measurement
      assert length(item.children) == 2
    end

    test "builds with custom concept" do
      custom = Code.new("122103", "DCM", "Custom Measurements")

      [item] = Hemodynamics.hemodynamic_measurement_group(concept: custom)
      assert item.concept_name == custom
    end

    test "builds minimal group" do
      [item] = Hemodynamics.hemodynamic_measurement_group()
      assert item.value_type == :container
      assert item.children == []
    end

    test "includes acquisition context" do
      [item] =
        Hemodynamics.hemodynamic_measurement_group(
          acquisition_context: [
            datetime: "20240101120000",
            description: "Baseline acquisition"
          ]
        )

      assert length(item.children) == 2
    end
  end

  # -- TID 3504 Arterial Pressure -------------------------------------------

  describe "arterial_pressure/1" do
    test "builds arterial pressure measurements" do
      items =
        Hemodynamics.arterial_pressure(
          systolic: 120,
          diastolic: 80,
          mean: 93,
          finding_site: @aorta
        )

      assert length(items) == 3
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.systolic_blood_pressure() in concepts
      assert Codes.diastolic_blood_pressure() in concepts
      assert Codes.mean_blood_pressure() in concepts

      # Each measurement should have finding site child
      Enum.each(items, fn item ->
        site = Enum.find(item.children, &(&1.concept_name == Codes.finding_site()))
        assert site != nil
        assert site.value == @aorta
      end)
    end

    test "partial pressure measurements" do
      items = Hemodynamics.arterial_pressure(systolic: 130)
      assert length(items) == 1
    end

    test "defaults to mmHg units" do
      [item] = Hemodynamics.arterial_pressure(systolic: 120)
      assert item.value.units == @mmhg
    end

    test "empty returns empty list" do
      assert Hemodynamics.arterial_pressure() == []
    end
  end

  # -- TID 3505 Atrial Pressure ---------------------------------------------

  describe "atrial_pressure/1" do
    test "builds atrial pressure measurements" do
      items =
        Hemodynamics.atrial_pressure(
          mean: 12,
          a_wave: 15,
          v_wave: 18,
          finding_site: @lv
        )

      assert length(items) == 3
    end

    test "mean-only atrial pressure" do
      items = Hemodynamics.atrial_pressure(mean: 10)
      assert length(items) == 1
    end

    test "empty returns empty list" do
      assert Hemodynamics.atrial_pressure() == []
    end
  end

  # -- TID 3506 Venous Pressure ---------------------------------------------

  describe "venous_pressure/1" do
    test "builds venous pressure measurement" do
      items = Hemodynamics.venous_pressure(mean: 8, finding_site: @aorta)
      assert length(items) == 1
      [item] = items
      assert item.value_type == :num
      assert item.concept_name == Codes.mean_blood_pressure()
    end

    test "empty returns empty list" do
      assert Hemodynamics.venous_pressure() == []
    end
  end

  # -- TID 3507 Ventricular Pressure ----------------------------------------

  describe "ventricular_pressure/1" do
    test "builds ventricular pressure measurements" do
      items =
        Hemodynamics.ventricular_pressure(
          systolic: 130,
          end_diastolic: 18,
          finding_site: @lv
        )

      assert length(items) == 2
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.systolic_blood_pressure() in concepts
      assert Codes.lv_end_diastolic_pressure() in concepts
    end

    test "empty returns empty list" do
      assert Hemodynamics.ventricular_pressure() == []
    end
  end

  # -- TID 3508 Pressure Gradient -------------------------------------------

  describe "pressure_gradient/1" do
    test "builds pressure gradient measurements" do
      items =
        Hemodynamics.pressure_gradient(
          peak: 50,
          mean: 25,
          finding_site: @aorta
        )

      assert length(items) == 2
    end

    test "peak-only gradient" do
      items = Hemodynamics.pressure_gradient(peak: 40)
      assert length(items) == 1
    end

    test "empty returns empty list" do
      assert Hemodynamics.pressure_gradient() == []
    end
  end

  # -- TID 3509 Blood Velocity ----------------------------------------------

  describe "blood_velocity/1" do
    test "builds blood velocity measurements" do
      items =
        Hemodynamics.blood_velocity(
          peak_systolic: 120,
          end_diastolic: 40,
          units: @cm_s,
          finding_site: @aorta
        )

      assert length(items) == 2
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.peak_systolic_velocity() in concepts
      assert Codes.end_diastolic_velocity() in concepts
    end

    test "empty returns empty list" do
      assert Hemodynamics.blood_velocity() == []
    end
  end

  # -- TID 3510 Vital Signs ------------------------------------------------

  describe "vital_signs/1" do
    test "builds complete vital signs" do
      items =
        Hemodynamics.vital_signs(
          heart_rate: 72,
          heart_rate_units: @bpm,
          systolic_bp: 120,
          diastolic_bp: 80,
          mean_bp: 93,
          body_weight: 75,
          weight_units: @kg,
          body_height: 175,
          height_units: @cm,
          body_surface_area: 1.85,
          bsa_units: @m2
        )

      assert length(items) == 7
    end

    test "partial vital signs" do
      items =
        Hemodynamics.vital_signs(
          heart_rate: 80,
          heart_rate_units: @bpm,
          systolic_bp: 130
        )

      assert length(items) == 2
    end

    test "empty returns empty list" do
      assert Hemodynamics.vital_signs() == []
    end
  end

  # -- TID 3515 Cardiac Output ----------------------------------------------

  describe "cardiac_output/1" do
    test "builds cardiac output measurements" do
      items =
        Hemodynamics.cardiac_output(
          cardiac_output: 5.2,
          cardiac_output_units: @l_min,
          stroke_volume: 72,
          stroke_volume_units: @ml,
          ejection_fraction: 60,
          method: @thermodilution
        )

      assert length(items) == 3
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.cardiac_output() in concepts
      assert Codes.stroke_volume() in concepts
      assert Codes.ejection_fraction() in concepts

      # Cardiac output should have method child
      co_item = Enum.find(items, &(&1.concept_name == Codes.cardiac_output()))
      method_child = Enum.find(co_item.children, &(&1.concept_name == Codes.measurement_method()))
      assert method_child != nil
      assert method_child.value == @thermodilution
    end

    test "ejection-fraction-only cardiac output" do
      items = Hemodynamics.cardiac_output(ejection_fraction: 55)
      assert length(items) == 1
      [item] = items
      assert item.concept_name == Codes.ejection_fraction()
      assert item.value.units == Codes.percent()
    end

    test "empty returns empty list" do
      assert Hemodynamics.cardiac_output() == []
    end
  end

  # -- TID 3520 Clinical Context ---------------------------------------------

  describe "clinical_context/1" do
    test "builds clinical context items" do
      items =
        Hemodynamics.clinical_context(
          patient_state: @resting,
          clinical_info: "Known coronary artery disease",
          history: "Prior MI 2020"
        )

      assert length(items) == 3
    end

    test "partial clinical context" do
      items = Hemodynamics.clinical_context(patient_state: @resting)
      assert length(items) == 1
      [item] = items
      assert item.value_type == :code
      assert item.value == @resting
    end

    test "empty returns empty list" do
      assert Hemodynamics.clinical_context() == []
    end
  end

  # -- TID 3530 Acquisition Context ------------------------------------------

  describe "acquisition_context/1" do
    test "builds acquisition context items" do
      items =
        Hemodynamics.acquisition_context(
          datetime: "20240101120000",
          description: "Baseline hemodynamic measurement"
        )

      assert length(items) == 2
    end

    test "empty returns empty list" do
      assert Hemodynamics.acquisition_context() == []
    end
  end

  # -- TID 3550 Pressure Waveform -------------------------------------------

  describe "pressure_waveform/1" do
    test "builds pressure waveform container" do
      waveform_type = Code.new("122170", "DCM", "Pressure Waveform")

      [item] =
        Hemodynamics.pressure_waveform(
          waveform_type: waveform_type,
          finding_site: @lv,
          description: "LV pressure trace"
        )

      assert item.value_type == :container
      assert item.concept_name == waveform_type
      assert length(item.children) == 2
    end

    test "defaults to pressure gradient concept" do
      [item] = Hemodynamics.pressure_waveform()
      assert item.concept_name == Codes.pressure_gradient()
    end
  end

  # -- TID 3560 Derived Hemodynamic Measurements ----------------------------

  describe "derived_hemodynamic_measurements/1" do
    test "builds derived measurements container" do
      [item] =
        Hemodynamics.derived_hemodynamic_measurements(
          measurements: [
            [concept: Codes.cardiac_output(), value: 5.2, units: @l_min, derivation: @mean],
            [concept: Codes.ejection_fraction(), value: 60, units: Codes.percent()]
          ]
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.derived_hemodynamic_measurements()
      assert length(item.children) == 2

      # First child should have derivation modifier
      [co, _ef] = item.children
      deriv = Enum.find(co.children, &(&1.concept_name == Codes.derivation()))
      assert deriv != nil
      assert deriv.value == @mean
    end

    test "empty measurements returns empty list" do
      assert Hemodynamics.derived_hemodynamic_measurements() == []
    end

    test "single measurement" do
      [item] =
        Hemodynamics.derived_hemodynamic_measurements(
          measurements: [
            [concept: Codes.stroke_volume(), value: 72, units: @ml]
          ]
        )

      assert length(item.children) == 1
    end
  end
end
