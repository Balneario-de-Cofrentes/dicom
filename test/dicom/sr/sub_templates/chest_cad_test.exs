defmodule Dicom.SR.SubTemplates.ChestCADTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Codes, ContentItem, Reference, Scoord2D}
  alias Dicom.SR.SubTemplates.ChestCAD
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

  describe "TID 4101 findings_summary/1" do
    test "builds container with text findings" do
      item =
        ChestCAD.findings_summary(findings: ["No significant abnormality detected"])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # findings_summary concept name code = "111035"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111035"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      # finding concept name code = "121071"
      assert "121071" in codes
    end

    test "builds container with code findings" do
      item =
        ChestCAD.findings_summary(findings: [Codes.nodule(), Codes.mass()])
        |> render()

      codes = children_codes(item)
      assert length(codes) == 2
      assert Enum.all?(codes, &(&1 == "121071"))
    end

    test "supports mixed text and code findings" do
      item =
        ChestCAD.findings_summary(findings: [Codes.nodule(), "Possible consolidation"])
        |> render()

      children = item[Tag.content_sequence()].value
      assert length(children) == 2
    end

    test "raises when findings is missing" do
      assert_raise KeyError, fn ->
        ChestCAD.findings_summary([])
      end
    end
  end

  describe "TID 4102 composite_finding/1" do
    test "builds container with tracking and single findings" do
      sf1 = ChestCAD.single_finding(finding_type: Codes.nodule())
      sf2 = ChestCAD.single_finding(finding_type: Codes.nodule())

      item =
        ChestCAD.composite_finding(
          tracking_id: "nodule-cluster-1",
          single_findings: [sf1, sf2]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # composite_feature concept name code = "111058"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111058"

      codes = children_codes(item)
      # tracking_identifier = "112039"
      assert "112039" in codes

      single_finding_count =
        item[Tag.content_sequence()].value
        |> Enum.count(&(code_value(&1, Tag.concept_name_code_sequence()) == "111059"))

      assert single_finding_count == 2
    end

    test "raises when tracking_id is missing" do
      assert_raise KeyError, fn ->
        ChestCAD.composite_finding(single_findings: [])
      end
    end

    test "raises when single_findings is missing" do
      assert_raise KeyError, fn ->
        ChestCAD.composite_finding(tracking_id: "cluster-1")
      end
    end
  end

  describe "TID 4104 single_finding/1" do
    test "builds container with nodule finding type" do
      item =
        ChestCAD.single_finding(finding_type: Codes.nodule())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # single_image_finding concept name code = "111059"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111059"

      codes = children_codes(item)
      # finding = "121071"
      assert "121071" in codes

      # verify the finding value is nodule SCT code "27925004"
      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      assert code_value(finding_item, Tag.concept_code_sequence()) == "27925004"
    end

    test "builds container with mass finding type" do
      item =
        ChestCAD.single_finding(finding_type: Codes.mass())
        |> render()

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      # mass SCT code = "4147007"
      assert code_value(finding_item, Tag.concept_code_sequence()) == "4147007"
    end

    test "builds container with lung opacity finding type" do
      item =
        ChestCAD.single_finding(finding_type: Codes.lung_opacity())
        |> render()

      finding_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121071"))

      # lung_opacity SCT code = "128477000"
      assert code_value(finding_item, Tag.concept_code_sequence()) == "128477000"
    end

    test "includes spatial coordinates" do
      ref = make_reference(4101)
      scoord = Scoord2D.new(ref, "POINT", [150.0, 220.0])

      item =
        ChestCAD.single_finding(
          finding_type: Codes.nodule(),
          scoord: scoord
        )
        |> render()

      codes = children_codes(item)
      # image_region = "111030"
      assert "111030" in codes
    end

    test "includes probability of malignancy" do
      item =
        ChestCAD.single_finding(
          finding_type: Codes.nodule(),
          probability: 85.5
        )
        |> render()

      codes = children_codes(item)
      # probability_of_malignancy = "111047"
      assert "111047" in codes
    end

    test "includes rendering intent (required)" do
      item =
        ChestCAD.single_finding(
          finding_type: Codes.nodule(),
          rendering_intent: :required
        )
        |> render()

      codes = children_codes(item)
      # rendering_intent concept name = "111056"
      assert "111056" in codes

      rendering_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "111056"))

      # presentation_required = "111150"
      assert code_value(rendering_item, Tag.concept_code_sequence()) == "111150"
    end

    test "includes rendering intent (not for presentation)" do
      item =
        ChestCAD.single_finding(
          finding_type: Codes.nodule(),
          rendering_intent: :not_for_presentation
        )
        |> render()

      rendering_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "111056"))

      # not_for_presentation = "111151"
      assert code_value(rendering_item, Tag.concept_code_sequence()) == "111151"
    end

    test "includes all optional fields at once" do
      ref = make_reference(4102)
      scoord = Scoord2D.new(ref, "CIRCLE", [200.0, 300.0, 215.0, 300.0])

      item =
        ChestCAD.single_finding(
          finding_type: Codes.nodule(),
          scoord: scoord,
          probability: 92.0,
          rendering_intent: :required
        )
        |> render()

      codes = children_codes(item)
      # finding, scoord, probability, rendering intent
      assert "121071" in codes
      assert "111030" in codes
      assert "111047" in codes
      assert "111056" in codes
      assert length(codes) == 4
    end

    test "raises when finding_type is missing" do
      assert_raise KeyError, fn ->
        ChestCAD.single_finding([])
      end
    end
  end
end
