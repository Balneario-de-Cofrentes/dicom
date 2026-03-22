defmodule Dicom.SR.SubTemplates.StressTestingTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.StressTesting
  alias Dicom.Tag

  defp code_value(item, sequence_tag) do
    [code_item] = item[sequence_tag].value
    code_item[Tag.code_value()].value
  end

  defp render(content_item), do: ContentItem.to_item(content_item)

  defp children_codes(rendered) do
    rendered[Tag.content_sequence()].value
    |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
  end

  describe "TID 3301 procedure_description/1" do
    test "builds container with protocol and stress mode" do
      item =
        StressTesting.procedure_description(
          protocol: Code.new("BRUCE", "99LOCAL", "Bruce Protocol"),
          stress_mode: Codes.exercise_stress_test()
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121065"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "122142" in codes
      assert "122143" in codes
    end

    test "includes optional text description" do
      item =
        StressTesting.procedure_description(
          protocol: Code.new("BRUCE", "99LOCAL", "Bruce Protocol"),
          stress_mode: Codes.exercise_stress_test(),
          description: "Standard Bruce treadmill protocol"
        )
        |> render()

      codes = children_codes(item)
      assert "121065" in codes

      text_item =
        item[Tag.content_sequence()].value
        |> Enum.find(fn child ->
          code_value(child, Tag.concept_name_code_sequence()) == "121065"
        end)

      assert text_item[Tag.text_value()].value == "Standard Bruce treadmill protocol"
    end

    test "raises when required protocol is missing" do
      assert_raise KeyError, fn ->
        StressTesting.procedure_description(stress_mode: Codes.exercise_stress_test())
      end
    end
  end

  describe "TID 3303 phase_data/1" do
    test "builds container with phase identification" do
      item =
        StressTesting.phase_data(phase: Codes.peak_phase())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "125007"

      codes = children_codes(item)
      assert "122149" in codes
    end

    test "includes measurements and findings" do
      measurement =
        Measurement.new(
          Codes.peak_heart_rate(),
          150,
          Codes.beats_per_minute()
        )

      item =
        StressTesting.phase_data(
          phase: Codes.peak_phase(),
          measurements: [measurement],
          findings: ["Mild ST depression"]
        )
        |> render()

      codes = children_codes(item)
      assert "122149" in codes
      assert "8867-4" in codes
      assert "121071" in codes
    end

    test "raises when phase is missing" do
      assert_raise KeyError, fn ->
        StressTesting.phase_data(measurements: [])
      end
    end
  end

  describe "TID 3304 measurement_group/1" do
    test "converts measurements to content items" do
      m1 =
        Measurement.new(
          Codes.peak_heart_rate(),
          120,
          Codes.beats_per_minute()
        )

      m2 =
        Measurement.new(
          Codes.systolic_blood_pressure(),
          160,
          Codes.mmhg()
        )

      items = StressTesting.measurement_group([m1, m2])

      assert length(items) == 2
      rendered = Enum.map(items, &render/1)
      assert Enum.all?(rendered, &(&1[Tag.value_type()].value == "NUM"))
    end

    test "returns empty list for empty input" do
      assert StressTesting.measurement_group([]) == []
    end
  end

  describe "TID 3307 perfusion_finding/1" do
    test "builds container with perfusion findings" do
      item =
        StressTesting.perfusion_finding(
          findings: ["Reversible perfusion defect in LAD territory"]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122165"

      codes = children_codes(item)
      assert "122165" in codes
    end

    test "includes phase when provided" do
      item =
        StressTesting.perfusion_finding(
          phase: Codes.peak_phase(),
          findings: [Code.new("129181", "DCM", "Reversible defect")]
        )
        |> render()

      codes = children_codes(item)
      assert "122149" in codes
      assert "122165" in codes
    end
  end

  describe "TID 3309 stress_echo/1" do
    test "builds container with phase and wall motion findings" do
      item =
        StressTesting.stress_echo(
          phase: Codes.peak_phase(),
          wall_motion_findings: ["Apical hypokinesis"]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122301"

      codes = children_codes(item)
      assert "122149" in codes
      assert "F-32040" in codes
    end

    test "includes measurements" do
      measurement =
        Measurement.new(
          Codes.lvef(),
          55,
          Codes.percent()
        )

      item =
        StressTesting.stress_echo(
          phase: Codes.rest_phase(),
          measurements: [measurement]
        )
        |> render()

      codes = children_codes(item)
      assert "122149" in codes
      assert "10230-1" in codes
    end
  end

  describe "TID 3311 test_summary/1" do
    test "returns positive test result" do
      item = StressTesting.test_summary(Codes.positive_stress_test()) |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122155"
      assert code_value(item, Tag.concept_code_sequence()) == "122156"
    end

    test "returns negative test result" do
      item = StressTesting.test_summary(Codes.negative_stress_test()) |> render()
      assert code_value(item, Tag.concept_code_sequence()) == "122157"
    end

    test "returns equivocal test result" do
      item = StressTesting.test_summary(Codes.equivocal_stress_test()) |> render()
      assert code_value(item, Tag.concept_code_sequence()) == "122160"
    end
  end

  describe "TID 3312 physiological_summary/1" do
    test "builds container with measurements" do
      hr = Measurement.new(Codes.resting_heart_rate(), 72, Codes.beats_per_minute())
      sbp = Measurement.new(Codes.systolic_blood_pressure(), 130, Codes.mmhg())

      item =
        StressTesting.physiological_summary(measurements: [hr, sbp])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122162"

      codes = children_codes(item)
      assert "122148" in codes
      assert "8480-6" in codes
    end

    test "includes optional findings" do
      hr = Measurement.new(Codes.resting_heart_rate(), 72, Codes.beats_per_minute())

      item =
        StressTesting.physiological_summary(
          measurements: [hr],
          findings: ["Normal blood pressure response"]
        )
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
    end
  end

  describe "TID 3313 ecg_summary/1" do
    test "builds container with ST findings" do
      item =
        StressTesting.ecg_summary(st_findings: ["1mm ST depression in leads II, III, aVF"])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122164"

      codes = children_codes(item)
      assert "122153" in codes
    end

    test "includes general ECG findings" do
      item =
        StressTesting.ecg_summary(
          st_findings: [Code.new("164931005", "SCT", "ST depression")],
          findings: ["No significant arrhythmias"]
        )
        |> render()

      codes = children_codes(item)
      assert "122153" in codes
      assert "121071" in codes
    end

    test "builds empty container when no findings" do
      item = StressTesting.ecg_summary([]) |> render()
      assert item[Tag.value_type()].value == "CONTAINER"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  describe "TID 3317 imaging_summary/1" do
    test "builds container with imaging findings" do
      item =
        StressTesting.imaging_summary(
          findings: ["No new wall motion abnormalities at peak stress"]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122163"

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "supports code-based findings" do
      item =
        StressTesting.imaging_summary(findings: [Code.new("373930000", "SCT", "Normal")])
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
    end
  end

  describe "TID 3318 comparison_to_prior/1" do
    test "builds text content item" do
      item =
        StressTesting.comparison_to_prior("Compared with prior study from 2025-01-15")
        |> render()

      assert item[Tag.value_type()].value == "TEXT"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122161"
      assert item[Tag.text_value()].value == "Compared with prior study from 2025-01-15"
    end
  end

  describe "TID 3320 conclusions_and_recommendations/1" do
    test "returns conclusion and recommendation items" do
      items =
        StressTesting.conclusions_and_recommendations(
          conclusions: ["Exercise-induced ischemia"],
          recommendations: ["Recommend coronary angiography"]
        )

      assert length(items) == 2

      rendered = Enum.map(items, &render/1)
      codes = Enum.map(rendered, &code_value(&1, Tag.concept_name_code_sequence()))
      assert "121073" in codes
      assert "121075" in codes
    end

    test "supports code-based conclusions and recommendations" do
      items =
        StressTesting.conclusions_and_recommendations(
          conclusions: [Code.new("17621005", "SCT", "Normal")],
          recommendations: [Code.new("710830005", "SCT", "Clinical follow-up")]
        )

      assert length(items) == 2
      rendered = Enum.map(items, &render/1)
      assert Enum.all?(rendered, &(&1[Tag.value_type()].value == "CODE"))
    end

    test "returns empty list when no conclusions or recommendations" do
      assert StressTesting.conclusions_and_recommendations([]) == []
    end
  end
end
