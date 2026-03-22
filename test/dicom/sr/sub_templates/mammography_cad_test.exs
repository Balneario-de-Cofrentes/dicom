defmodule Dicom.SR.SubTemplates.MammographyCADTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Codes, ContentItem, Measurement, Reference}
  alias Dicom.SR.SubTemplates.MammographyCAD
  alias Dicom.{Tag, UID}

  defp code_value(item, sequence_tag) do
    [code_item] = item[sequence_tag].value
    code_item[Tag.code_value()].value
  end

  defp render(content_item), do: ContentItem.to_item(content_item)

  defp children_codes(rendered) do
    rendered[Tag.content_sequence()].value
    |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
  end

  defp make_reference(suffix) do
    Reference.new(
      UID.dx_image_storage(),
      "1.2.826.0.1.3680043.10.1137.#{suffix}"
    )
  end

  describe "TID 4001 overall_assessment/1" do
    test "builds container with laterality and text assessment" do
      item =
        MammographyCAD.overall_assessment(
          laterality: Codes.right_breast(),
          assessment: "No significant findings"
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111037"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "363698007" in codes
      assert "111037" in codes
    end

    test "supports code-based assessment" do
      item =
        MammographyCAD.overall_assessment(
          laterality: Codes.left_breast(),
          assessment: Codes.negative_stress_test()
        )
        |> render()

      codes = children_codes(item)
      assert "363698007" in codes
      assert "111037" in codes
    end

    test "includes individual impressions" do
      impression =
        MammographyCAD.individual_impression(finding_type: Codes.calcification())

      item =
        MammographyCAD.overall_assessment(
          laterality: Codes.right_breast(),
          assessment: "Calcification cluster detected",
          individual_impressions: [impression]
        )
        |> render()

      codes = children_codes(item)
      assert "111038" in codes
    end

    test "raises when laterality is missing" do
      assert_raise KeyError, fn ->
        MammographyCAD.overall_assessment(assessment: "No findings")
      end
    end

    test "raises when assessment is missing" do
      assert_raise KeyError, fn ->
        MammographyCAD.overall_assessment(laterality: Codes.right_breast())
      end
    end
  end

  describe "TID 4003 individual_impression/1" do
    test "builds container with finding type" do
      item =
        MammographyCAD.individual_impression(finding_type: Codes.mass())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111038"

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "includes probability and source image" do
      probability =
        Measurement.new(Codes.probability_of_cancer(), 0.75, Codes.percent())

      ref = make_reference(5001)

      item =
        MammographyCAD.individual_impression(
          finding_type: Codes.calcification(),
          probability: probability,
          source_image: ref
        )
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
      assert "111056" in codes
      assert "260753009" in codes
    end

    test "includes sub-findings" do
      sub_finding =
        MammographyCAD.single_finding(finding_type: Codes.calcification())

      item =
        MammographyCAD.individual_impression(
          finding_type: Codes.calcification(),
          findings: [sub_finding]
        )
        |> render()

      codes = children_codes(item)
      assert "111059" in codes
    end
  end

  describe "TID 4004 composite_finding/1" do
    test "builds container with tracking and single findings" do
      sf1 = MammographyCAD.single_finding(finding_type: Codes.calcification())
      sf2 = MammographyCAD.single_finding(finding_type: Codes.calcification())

      item =
        MammographyCAD.composite_finding(
          tracking_id: "cluster-1",
          single_findings: [sf1, sf2]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111058"

      codes = children_codes(item)
      assert "112039" in codes

      single_finding_count =
        item[Tag.content_sequence()].value
        |> Enum.count(&(code_value(&1, Tag.concept_name_code_sequence()) == "111059"))

      assert single_finding_count == 2
    end

    test "raises when tracking_id is missing" do
      assert_raise KeyError, fn ->
        MammographyCAD.composite_finding(single_findings: [])
      end
    end

    test "raises when single_findings is missing" do
      assert_raise KeyError, fn ->
        MammographyCAD.composite_finding(tracking_id: "cluster-1")
      end
    end
  end

  describe "TID 4005-4006 single_finding/1" do
    test "builds container with finding type" do
      item =
        MammographyCAD.single_finding(finding_type: Codes.mass())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111059"

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "includes source image and measurements" do
      ref = make_reference(5010)

      size =
        Measurement.new(
          Codes.maximum_lumen_diameter(),
          15.0,
          Codes.mm()
        )

      item =
        MammographyCAD.single_finding(
          finding_type: Codes.mass(),
          source_image: ref,
          measurements: [size]
        )
        |> render()

      codes = children_codes(item)
      assert "260753009" in codes
      assert "122209" in codes
    end

    test "supports architectural distortion finding" do
      item =
        MammographyCAD.single_finding(finding_type: Codes.architectural_distortion())
        |> render()

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      assert code_value(finding_item, Tag.concept_code_sequence()) == "129770000"
    end

    test "supports asymmetry finding" do
      item =
        MammographyCAD.single_finding(finding_type: Codes.asymmetry())
        |> render()

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      assert code_value(finding_item, Tag.concept_code_sequence()) == "129769005"
    end
  end

  describe "TID 4007 breast_composition/1" do
    test "almost entirely fat" do
      item =
        MammographyCAD.breast_composition(Codes.almost_entirely_fat())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111031"
      assert code_value(item, Tag.concept_code_sequence()) == "111044"
    end

    test "scattered fibroglandular" do
      item =
        MammographyCAD.breast_composition(Codes.scattered_fibroglandular())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111045"
    end

    test "heterogeneously dense" do
      item =
        MammographyCAD.breast_composition(Codes.heterogeneously_dense())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111046"
    end

    test "extremely dense" do
      item =
        MammographyCAD.breast_composition(Codes.extremely_dense())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111047"
    end
  end

  describe "TID 4014 algorithm/1" do
    test "builds container with name and version" do
      item =
        MammographyCAD.algorithm(
          name: "BreastCAD Pro",
          version: "3.2.1"
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111001"

      codes = children_codes(item)
      assert "111001" in codes
      assert "111003" in codes
    end

    test "includes optional parameters" do
      item =
        MammographyCAD.algorithm(
          name: "BreastCAD Pro",
          version: "3.2.1",
          parameters: "sensitivity=high, threshold=0.5"
        )
        |> render()

      codes = children_codes(item)
      assert "111002" in codes

      param_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "111002"))

      assert param_item[Tag.text_value()].value == "sensitivity=high, threshold=0.5"
    end

    test "raises when name is missing" do
      assert_raise KeyError, fn ->
        MammographyCAD.algorithm(version: "1.0")
      end
    end

    test "raises when version is missing" do
      assert_raise KeyError, fn ->
        MammographyCAD.algorithm(name: "BreastCAD")
      end
    end
  end

  describe "TID 4019 operating_point/1" do
    test "builds container with performance metrics" do
      sensitivity =
        Measurement.new(Codes.detection_sensitivity(), 92.5, Codes.percent())

      specificity =
        Measurement.new(Codes.detection_specificity(), 85.0, Codes.percent())

      fpr =
        Measurement.new(Codes.false_positive_rate(), 1.2, Codes.percent())

      item =
        MammographyCAD.operating_point(
          sensitivity: sensitivity,
          specificity: specificity,
          false_positive_rate: fpr
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111055"

      codes = children_codes(item)
      assert "111048" in codes
      assert "111049" in codes
      assert "111050" in codes
    end

    test "builds container with partial metrics" do
      sensitivity =
        Measurement.new(Codes.detection_sensitivity(), 90.0, Codes.percent())

      item =
        MammographyCAD.operating_point(sensitivity: sensitivity)
        |> render()

      codes = children_codes(item)
      assert "111048" in codes
      assert length(codes) == 1
    end

    test "builds empty container when no metrics" do
      item = MammographyCAD.operating_point([]) |> render()
      assert item[Tag.value_type()].value == "CONTAINER"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  describe "TID 4023 image_quality/1" do
    test "adequate quality" do
      item =
        MammographyCAD.image_quality(Codes.adequate_quality())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111051"
      assert code_value(item, Tag.concept_code_sequence()) == "111052"
    end

    test "inadequate quality" do
      item =
        MammographyCAD.image_quality(Codes.inadequate_quality())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111053"
    end
  end
end
