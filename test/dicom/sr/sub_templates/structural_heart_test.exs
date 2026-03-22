defmodule Dicom.SR.SubTemplates.StructuralHeartTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.StructuralHeart
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

  describe "TID 5321 annular_measurement_section/1" do
    test "builds container with annular measurements" do
      m1 = Measurement.new(Code.new("122350", "DCM", "Annulus Diameter"), 23.5, Codes.mm())
      m2 = Measurement.new(Code.new("122351", "DCM", "Annulus Area"), 4.3, Codes.sq_mm())

      item =
        StructuralHeart.annular_measurement_section(measurements: [m1, m2])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "125321"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "122350" in codes
      assert "122351" in codes
    end

    test "raises when measurements missing" do
      assert_raise KeyError, fn ->
        StructuralHeart.annular_measurement_section([])
      end
    end
  end

  describe "TID 5322 device_measurement_section/1" do
    test "builds container with device measurements" do
      m1 = Measurement.new(Code.new("122352", "DCM", "Device Size"), 26, Codes.mm())

      item =
        StructuralHeart.device_measurement_section(measurements: [m1])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "125322"

      codes = children_codes(item)
      assert "122352" in codes
    end

    test "raises when measurements missing" do
      assert_raise KeyError, fn ->
        StructuralHeart.device_measurement_section([])
      end
    end
  end

  describe "TID 5323 procedure_modifier/1" do
    test "builds code item for TAVR procedure" do
      procedure = Code.new("439980006", "SCT", "Transcatheter aortic valve replacement")

      item = StructuralHeart.procedure_modifier(procedure) |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121058"
      assert code_value(item, Tag.concept_code_sequence()) == "439980006"
      assert item[Tag.relationship_type()].value == "HAS CONCEPT MOD"
    end
  end

  describe "TID 5324 findings/1" do
    test "builds text findings" do
      items =
        StructuralHeart.findings(["Mild paravalvular leak", "No migration"])

      assert length(items) == 2
      rendered = Enum.map(items, &render/1)
      assert Enum.all?(rendered, &(&1[Tag.value_type()].value == "TEXT"))

      codes =
        Enum.map(rendered, &code_value(&1, Tag.concept_name_code_sequence()))

      assert Enum.all?(codes, &(&1 == "121071"))
    end

    test "builds code findings" do
      items =
        StructuralHeart.findings([Code.new("95436008", "SCT", "Paravalvular leak")])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
      assert code_value(rendered, Tag.concept_code_sequence()) == "95436008"
    end

    test "returns empty list for empty input" do
      assert StructuralHeart.findings([]) == []
    end
  end

  describe "TID 5325 impressions/1" do
    test "builds text impressions" do
      items = StructuralHeart.impressions(["Successful TAVR deployment"])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "TEXT"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "121073"
      assert rendered[Tag.text_value()].value == "Successful TAVR deployment"
    end

    test "builds code impressions" do
      items =
        StructuralHeart.impressions([Code.new("373930000", "SCT", "Normal")])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "121073"
    end

    test "returns empty list for empty input" do
      assert StructuralHeart.impressions([]) == []
    end
  end
end
