defmodule Dicom.SR.SubTemplates.ImplantationPlanTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Reference}
  alias Dicom.SR.SubTemplates.ImplantationPlan
  alias Dicom.Tag

  defp code_value(item, sequence_tag) do
    [code_item] = item[sequence_tag].value
    code_item[Tag.code_value()].value
  end

  defp render(content_item), do: ContentItem.to_item(content_item)

  describe "TID 7001 implant_template/1" do
    test "builds text implant template" do
      item = ImplantationPlan.implant_template("Hip prosthesis size L") |> render()

      assert item[Tag.value_type()].value == "TEXT"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122349"
      assert item[Tag.relationship_type()].value == "CONTAINS"
      assert item[Tag.text_value()].value == "Hip prosthesis size L"
    end

    test "builds composite implant template" do
      ref = Reference.new("1.2.840.10008.5.1.4.1.1.66", "1.2.3.4.5.6.7")

      item = ImplantationPlan.implant_template(ref) |> render()

      assert item[Tag.value_type()].value == "COMPOSITE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122349"
    end
  end

  describe "TID 7002 planning_measurement/1" do
    test "builds num content item for measurement" do
      item =
        ImplantationPlan.planning_measurement(
          concept: Code.new("122346", "DCM", "Stem length"),
          value: 150,
          units: Codes.mm()
        )
        |> render()

      assert item[Tag.value_type()].value == "NUM"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122346"
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end

    test "raises when concept missing" do
      assert_raise KeyError, fn ->
        ImplantationPlan.planning_measurement(value: 10, units: Codes.mm())
      end
    end

    test "raises when value missing" do
      assert_raise KeyError, fn ->
        ImplantationPlan.planning_measurement(
          concept: Code.new("122346", "DCM", "Test"),
          units: Codes.mm()
        )
      end
    end
  end

  describe "TID 7003 implantation_site/1" do
    test "builds code item for site" do
      site = Code.new("29836001", "SCT", "Hip region structure")

      item = ImplantationPlan.implantation_site(site) |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111176"
      assert code_value(item, Tag.concept_code_sequence()) == "29836001"
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end
  end

  describe "TID 7004 findings/1" do
    test "builds text findings" do
      items = ImplantationPlan.findings(["Moderate osteoarthritis"])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "TEXT"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "121071"
    end

    test "builds code findings" do
      items =
        ImplantationPlan.findings([Code.new("396275006", "SCT", "Osteoarthritis")])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
      assert code_value(rendered, Tag.concept_code_sequence()) == "396275006"
    end

    test "returns empty list for empty input" do
      assert ImplantationPlan.findings([]) == []
    end
  end

  describe "TID 7004 impressions/1" do
    test "builds text impressions" do
      items = ImplantationPlan.impressions(["Suitable for total hip replacement"])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "TEXT"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "121073"
    end

    test "builds code impressions" do
      items =
        ImplantationPlan.impressions([Code.new("373930000", "SCT", "Normal")])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
    end

    test "returns empty list for empty input" do
      assert ImplantationPlan.impressions([]) == []
    end
  end

  describe "TID 7004 recommendations/1" do
    test "builds text recommendations" do
      items =
        ImplantationPlan.recommendations(["Proceed with planned arthroplasty"])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "TEXT"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "121075"
    end

    test "builds code recommendations" do
      items =
        ImplantationPlan.recommendations([
          Code.new("710830005", "SCT", "Clinical follow-up")
        ])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
      assert code_value(rendered, Tag.concept_code_sequence()) == "710830005"
    end

    test "returns empty list for empty input" do
      assert ImplantationPlan.recommendations([]) == []
    end
  end
end
