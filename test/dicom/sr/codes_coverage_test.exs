defmodule Dicom.SR.CodesTest do
  @moduledoc """
  Coverage tests for Codes functions not exercised by sub-template or template tests.
  Each function is a simple Code.t() getter — we verify it returns a valid Code struct.
  """
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes}

  defp assert_code(%Code{value: v, scheme_designator: s, meaning: m}) do
    assert is_binary(v) and v != ""
    assert is_binary(s) and s != ""
    assert is_binary(m) and m != ""
  end

  describe "echo/cardiac measurement codes" do
    test "a_wave_velocity" do
      assert_code(Codes.a_wave_velocity())
      assert Codes.a_wave_velocity().value == "122304"
    end

    test "e_wave_velocity" do
      assert_code(Codes.e_wave_velocity())
      assert Codes.e_wave_velocity().value == "122303"
    end

    test "e_a_ratio" do
      assert_code(Codes.e_a_ratio())
      assert Codes.e_a_ratio().value == "122305"
    end

    test "echo_measurement" do
      assert_code(Codes.echo_measurement())
      assert Codes.echo_measurement().value == "122302"
    end

    test "deceleration_time" do
      assert_code(Codes.deceleration_time())
      assert Codes.deceleration_time().value == "122306"
    end

    test "lv_end_systolic_dimension" do
      assert_code(Codes.lv_end_systolic_dimension())
      assert Codes.lv_end_systolic_dimension().value == "29469-4"
    end

    test "left_atrium" do
      assert_code(Codes.left_atrium())
      assert Codes.left_atrium().value == "82471001"
    end

    test "cardiac_measurements" do
      assert_code(Codes.cardiac_measurements())
      assert Codes.cardiac_measurements().value == "125201"
    end
  end

  describe "stress testing codes" do
    test "exercise_duration" do
      assert_code(Codes.exercise_duration())
      assert Codes.exercise_duration().value == "122144"
    end

    test "exercise_mets" do
      assert_code(Codes.exercise_mets())
      assert Codes.exercise_mets().value == "122146"
    end

    test "percent_max_predicted_hr" do
      assert_code(Codes.percent_max_predicted_hr())
      assert Codes.percent_max_predicted_hr().value == "122147"
    end

    test "pharmacological_stress_test" do
      assert_code(Codes.pharmacological_stress_test())
      assert Codes.pharmacological_stress_test().value == "76746007"
    end

    test "target_heart_rate" do
      assert_code(Codes.target_heart_rate())
      assert Codes.target_heart_rate().value == "122145"
    end

    test "recovery_phase" do
      assert_code(Codes.recovery_phase())
      assert Codes.recovery_phase().value == "122152"
    end
  end

  describe "vascular/anatomical codes" do
    test "external_carotid_artery" do
      assert_code(Codes.external_carotid_artery())
      assert Codes.external_carotid_artery().value == "22286001"
    end

    test "vertebral_artery" do
      assert_code(Codes.vertebral_artery())
      assert Codes.vertebral_artery().value == "85234005"
    end

    test "vessel_diameter" do
      assert_code(Codes.vessel_diameter())
    end

    test "vessel_patency" do
      assert_code(Codes.vessel_patency())
    end

    test "blood_velocity" do
      assert_code(Codes.blood_velocity())
      assert Codes.blood_velocity().value == "110852"
    end

    test "flow_direction" do
      assert_code(Codes.flow_direction())
    end

    test "plaque_eccentricity_index" do
      assert_code(Codes.plaque_eccentricity_index())
      assert Codes.plaque_eccentricity_index().value == "122211"
    end
  end

  describe "breast/CAD codes" do
    test "breast_density" do
      assert_code(Codes.breast_density())
      assert Codes.breast_density().value == "111043"
    end

    test "cad_processing_unsuccessful" do
      assert_code(Codes.cad_processing_unsuccessful())
    end
  end

  describe "unit codes" do
    test "minutes" do
      assert_code(Codes.minutes())
      assert Codes.minutes().value == "min"
    end

    test "ms" do
      assert_code(Codes.ms())
      assert Codes.ms().value == "ms"
    end
  end

  describe "miscellaneous domain codes" do
    test "individual_impression_recommendation" do
      assert_code(Codes.individual_impression_recommendation())
    end

    test "planning_measurement" do
      assert_code(Codes.planning_measurement())
      assert Codes.planning_measurement().value == "122346"
    end

    test "stationary_acquisition" do
      assert_code(Codes.stationary_acquisition())
      assert Codes.stationary_acquisition().value == "113806"
    end

    test "successful_analyses_performed" do
      assert_code(Codes.successful_analyses_performed())
    end
  end
end
