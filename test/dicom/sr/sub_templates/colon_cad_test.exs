defmodule Dicom.SR.SubTemplates.ColonCADTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Codes, ContentItem}
  alias Dicom.SR.SubTemplates.ColonCAD
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

  describe "TID 4121 findings_summary/1" do
    test "builds container with text findings" do
      item =
        ColonCAD.findings_summary(findings: ["3 polyp candidates detected"])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # cad_processing_and_findings_summary = "111017"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111017"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      # finding = "121071"
      assert "121071" in codes
    end

    test "builds container with code findings" do
      item =
        ColonCAD.findings_summary(findings: [Codes.polyp_candidate()])
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "supports mixed text and code findings" do
      item =
        ColonCAD.findings_summary(findings: [Codes.polyp_candidate(), "CAD processing complete"])
        |> render()

      children = item[Tag.content_sequence()].value
      assert length(children) == 2
    end

    test "raises when findings is missing" do
      assert_raise KeyError, fn ->
        ColonCAD.findings_summary([])
      end
    end
  end

  describe "TID 4122 polyp_finding/1" do
    test "builds container with default finding type (polyp candidate)" do
      item =
        ColonCAD.polyp_finding([])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # single_image_finding = "111059"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111059"

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      # polyp_candidate = "112172"
      assert code_value(finding_item, Tag.concept_code_sequence()) == "112172"
    end

    test "builds container with custom finding type" do
      item =
        ColonCAD.polyp_finding(finding_type: Codes.mass())
        |> render()

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      # mass = "4147007"
      assert code_value(finding_item, Tag.concept_code_sequence()) == "4147007"
    end

    test "includes polyp size" do
      item =
        ColonCAD.polyp_finding(size_mm: 8.5)
        |> render()

      codes = children_codes(item)
      # polyp_size = "246120007"
      assert "246120007" in codes

      size_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "246120007"))

      [measurement] = size_item[Tag.measured_value_sequence()].value
      assert measurement[Tag.numeric_value()].value == "8.5"
    end

    test "includes colonic segment (cecum)" do
      item =
        ColonCAD.polyp_finding(segment: Codes.cecum())
        |> render()

      codes = children_codes(item)
      # colonic_segment = "T-59300"
      assert "T-59300" in codes

      segment_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "T-59300"))

      # cecum SCT code = "32713005"
      assert code_value(segment_item, Tag.concept_code_sequence()) == "32713005"
    end

    test "includes colonic segment (ascending colon)" do
      item =
        ColonCAD.polyp_finding(segment: Codes.ascending_colon())
        |> render()

      segment_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "T-59300"))

      # ascending_colon SCT code = "9040008"
      assert code_value(segment_item, Tag.concept_code_sequence()) == "9040008"
    end

    test "includes colonic segment (sigmoid colon)" do
      item =
        ColonCAD.polyp_finding(segment: Codes.sigmoid_colon())
        |> render()

      segment_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "T-59300"))

      # sigmoid_colon SCT code = "60184004"
      assert code_value(segment_item, Tag.concept_code_sequence()) == "60184004"
    end

    test "includes detection confidence" do
      item =
        ColonCAD.polyp_finding(confidence: 87.5)
        |> render()

      codes = children_codes(item)
      # detection_confidence = "111057"
      assert "111057" in codes

      confidence_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "111057"))

      [measurement] = confidence_item[Tag.measured_value_sequence()].value
      assert measurement[Tag.numeric_value()].value == "87.5"
    end

    test "includes all optional fields at once" do
      item =
        ColonCAD.polyp_finding(
          size_mm: 12.0,
          segment: Codes.transverse_colon(),
          confidence: 95.0
        )
        |> render()

      codes = children_codes(item)
      # finding, polyp_size, colonic_segment, detection_confidence
      assert "121071" in codes
      assert "246120007" in codes
      assert "T-59300" in codes
      assert "111057" in codes
      assert length(codes) == 4
    end

    test "colonic segment values cover all segments" do
      segments = [
        {Codes.cecum(), "32713005"},
        {Codes.ascending_colon(), "9040008"},
        {Codes.transverse_colon(), "485005"},
        {Codes.descending_colon(), "32622004"},
        {Codes.sigmoid_colon(), "60184004"},
        {Codes.rectum(), "34402009"}
      ]

      for {segment_code, expected_value} <- segments do
        item =
          ColonCAD.polyp_finding(segment: segment_code)
          |> render()

        segment_item =
          item[Tag.content_sequence()].value
          |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "T-59300"))

        assert code_value(segment_item, Tag.concept_code_sequence()) == expected_value,
               "Expected segment code #{expected_value} for #{segment_code.meaning}"
      end
    end
  end
end
