defmodule Dicom.SR.SubTemplates.CardiovascularAnalysisTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.CardiovascularAnalysis
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

  # -- TID 3905 Calcium Scoring --

  describe "TID 3905 calcium_scoring/1" do
    test "builds container with all three scores" do
      item =
        CardiovascularAnalysis.calcium_scoring(
          agatston: 120,
          volume: 95.5,
          mass: 22.3
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113691"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "112227" in codes
      assert "112228" in codes
      assert "112229" in codes
    end

    test "builds container with Agatston score only" do
      item =
        CardiovascularAnalysis.calcium_scoring(agatston: 0)
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      codes = children_codes(item)
      assert "112227" in codes
      refute "112228" in codes
      refute "112229" in codes
    end

    test "Agatston score uses correct units" do
      item =
        CardiovascularAnalysis.calcium_scoring(agatston: 400)
        |> render()

      agatston_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "112227"))

      [measured] = agatston_item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "1"
    end

    test "volume score uses cubic millimeter units" do
      item =
        CardiovascularAnalysis.calcium_scoring(volume: 80.0)
        |> render()

      volume_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "112228"))

      [measured] = volume_item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "mm3"
    end

    test "mass score uses milligram units" do
      item =
        CardiovascularAnalysis.calcium_scoring(mass: 15.0)
        |> render()

      mass_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "112229"))

      [measured] = mass_item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "mg"
    end

    test "builds empty container when no scores given" do
      item = CardiovascularAnalysis.calcium_scoring([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113691"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- TID 3902 Vascular Analysis --

  describe "TID 3902 vascular_analysis/1" do
    test "builds container with vessel analyses" do
      vessel =
        CardiovascularAnalysis.vessel_analysis(
          segment: Code.new("41801008", "SCT", "Coronary artery")
        )

      item =
        CardiovascularAnalysis.vascular_analysis(vessels: [vessel])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113692"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "125007" in codes
    end

    test "builds container with multiple vessels" do
      vessels =
        Enum.map(
          [
            Code.new("41801008", "SCT", "Coronary artery"),
            Code.new("76862006", "SCT", "Left anterior descending")
          ],
          fn seg -> CardiovascularAnalysis.vessel_analysis(segment: seg) end
        )

      item =
        CardiovascularAnalysis.vascular_analysis(vessels: vessels)
        |> render()

      children = item[Tag.content_sequence()].value
      assert length(children) == 2
    end

    test "raises when vessels is missing" do
      assert_raise KeyError, fn ->
        CardiovascularAnalysis.vascular_analysis([])
      end
    end
  end

  describe "vessel_analysis/1" do
    test "builds measurement group with segment" do
      item =
        CardiovascularAnalysis.vessel_analysis(
          segment: Code.new("41801008", "SCT", "Coronary artery")
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "125007"

      codes = children_codes(item)
      assert "363704007" in codes
    end

    test "includes stenosis severity" do
      item =
        CardiovascularAnalysis.vessel_analysis(
          segment: Code.new("41801008", "SCT", "Coronary artery"),
          stenosis: Code.new("24484000", "SCT", "Severe")
        )
        |> render()

      codes = children_codes(item)
      assert "363704007" in codes
      assert "246112005" in codes
    end

    test "includes plaque type" do
      item =
        CardiovascularAnalysis.vessel_analysis(
          segment: Code.new("41801008", "SCT", "Coronary artery"),
          plaque_type: Code.new("122213", "DCM", "Calcified")
        )
        |> render()

      codes = children_codes(item)
      assert "363704007" in codes
      assert "112176" in codes
    end

    test "includes measurements" do
      diameter = Measurement.new(Codes.minimum_lumen_diameter(), 1.5, Codes.mm())

      item =
        CardiovascularAnalysis.vessel_analysis(
          segment: Code.new("41801008", "SCT", "Coronary artery"),
          measurements: [diameter]
        )
        |> render()

      codes = children_codes(item)
      assert "363704007" in codes
      assert "122208" in codes
    end

    test "includes all optional fields" do
      diameter = Measurement.new(Codes.minimum_lumen_diameter(), 1.2, Codes.mm())

      item =
        CardiovascularAnalysis.vessel_analysis(
          segment: Code.new("76862006", "SCT", "Left anterior descending"),
          stenosis: Code.new("24484000", "SCT", "Severe"),
          plaque_type: Code.new("122213", "DCM", "Calcified"),
          measurements: [diameter]
        )
        |> render()

      codes = children_codes(item)
      assert "363704007" in codes
      assert "246112005" in codes
      assert "112176" in codes
      assert "122208" in codes
    end

    test "raises when segment is missing" do
      assert_raise KeyError, fn ->
        CardiovascularAnalysis.vessel_analysis(stenosis: Code.new("24484000", "SCT", "Severe"))
      end
    end
  end

  # -- TID 3920 Ventricular Analysis --

  describe "TID 3920 ventricular_analysis/1" do
    test "builds container with all measurements" do
      item =
        CardiovascularAnalysis.ventricular_analysis(
          ejection_fraction: 62,
          edv: 120,
          esv: 45,
          stroke_volume: 75,
          myocardial_mass: 130
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113693"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "10230-1" in codes
      assert "10231-9" in codes
      assert "10232-7" in codes
      assert "90096-0" in codes
      assert "10236-8" in codes
    end

    test "builds container with EF only" do
      item =
        CardiovascularAnalysis.ventricular_analysis(ejection_fraction: 55)
        |> render()

      codes = children_codes(item)
      assert "10230-1" in codes
      refute "10231-9" in codes
      refute "10232-7" in codes
    end

    test "ejection fraction uses percent units" do
      item =
        CardiovascularAnalysis.ventricular_analysis(ejection_fraction: 55)
        |> render()

      ef_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "10230-1"))

      [measured] = ef_item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "%"
    end

    test "volumes use milliliter units" do
      item =
        CardiovascularAnalysis.ventricular_analysis(edv: 140, esv: 55)
        |> render()

      edv_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "10231-9"))

      [measured] = edv_item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "mL"
    end

    test "myocardial mass uses gram units" do
      item =
        CardiovascularAnalysis.ventricular_analysis(myocardial_mass: 150)
        |> render()

      mass_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "10236-8"))

      [measured] = mass_item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "g"
    end

    test "builds empty container when no options" do
      item = CardiovascularAnalysis.ventricular_analysis([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113693"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- TID 3926 Perfusion Analysis --

  describe "TID 3926 perfusion_analysis/1" do
    test "builds container with text findings" do
      item =
        CardiovascularAnalysis.perfusion_analysis(
          findings: ["Reversible perfusion defect in LAD territory"]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113694"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "121071" in codes

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      assert finding_item[Tag.text_value()].value ==
               "Reversible perfusion defect in LAD territory"
    end

    test "builds container with code findings" do
      item =
        CardiovascularAnalysis.perfusion_analysis(
          findings: [Code.new("373930000", "SCT", "Normal perfusion")]
        )
        |> render()

      codes = children_codes(item)
      assert "121071" in codes

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      assert code_value(finding_item, Tag.concept_code_sequence()) == "373930000"
    end

    test "builds container with multiple findings" do
      item =
        CardiovascularAnalysis.perfusion_analysis(
          findings: [
            "Fixed defect in inferior wall",
            Code.new("373930000", "SCT", "Normal perfusion"),
            "No reversible ischemia"
          ]
        )
        |> render()

      children = item[Tag.content_sequence()].value
      assert length(children) == 3
    end

    test "builds empty container when no findings" do
      item = CardiovascularAnalysis.perfusion_analysis([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113694"
      refute Map.has_key?(item, Tag.content_sequence())
    end

    test "builds empty container with explicit empty findings" do
      item = CardiovascularAnalysis.perfusion_analysis(findings: []) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end
end
