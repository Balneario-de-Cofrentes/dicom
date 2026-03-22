defmodule Dicom.SR.SubTemplates.PediatricCardiacUSTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.PediatricCardiacUS
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

  describe "TID 5221 patient_characteristics/1" do
    test "builds container with text characteristics" do
      item =
        PediatricCardiacUS.patient_characteristics(
          characteristics: ["Weight: 3.5 kg", "Gestational age: 38 weeks"]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121070"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert length(codes) == 2
      assert Enum.all?(codes, &(&1 == "121071"))
    end

    test "builds container with code characteristics" do
      item =
        PediatricCardiacUS.patient_characteristics(
          characteristics: [Code.new("414025005", "SCT", "Disorder of heart")]
        )
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "raises when characteristics missing" do
      assert_raise KeyError, fn ->
        PediatricCardiacUS.patient_characteristics([])
      end
    end
  end

  describe "TID 5222 cardiac_measurement_sections/1" do
    test "builds measurement group items" do
      m = Measurement.new(Codes.lvef(), 65, Codes.percent())

      items =
        PediatricCardiacUS.cardiac_measurement_sections([
          %{
            name: "Left Ventricle",
            tracking_uid: "1.2.3.4.5",
            measurements: [m],
            findings: ["Normal systolic function"]
          }
        ])

      assert length(items) == 1
      rendered = hd(items) |> render()
      assert rendered[Tag.value_type()].value == "CONTAINER"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "125007"
    end

    test "handles sections without findings" do
      items =
        PediatricCardiacUS.cardiac_measurement_sections([
          %{name: "Right Ventricle", tracking_uid: "1.2.3.4.6"}
        ])

      assert length(items) == 1
    end

    test "returns empty list for empty sections" do
      assert PediatricCardiacUS.cardiac_measurement_sections([]) == []
    end
  end

  describe "TID 5223 summary/1" do
    test "builds container with text values" do
      item =
        PediatricCardiacUS.summary(values: ["No significant structural abnormalities"])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121077"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "builds container with code values" do
      item =
        PediatricCardiacUS.summary(values: [Code.new("17621005", "SCT", "Normal")])
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "raises when values missing" do
      assert_raise KeyError, fn ->
        PediatricCardiacUS.summary([])
      end
    end
  end

  describe "TID 5224 findings/1" do
    test "builds text findings" do
      items = PediatricCardiacUS.findings(["Small VSD noted"])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "TEXT"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "121071"
    end

    test "builds code findings" do
      items =
        PediatricCardiacUS.findings([Code.new("30288003", "SCT", "Ventricular septal defect")])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
      assert code_value(rendered, Tag.concept_code_sequence()) == "30288003"
    end

    test "returns empty list for empty input" do
      assert PediatricCardiacUS.findings([]) == []
    end
  end

  describe "TID 5225 impressions/1" do
    test "builds text impressions" do
      items = PediatricCardiacUS.impressions(["Normal biventricular function"])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "TEXT"
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "121073"
    end

    test "builds code impressions" do
      items = PediatricCardiacUS.impressions([Code.new("373930000", "SCT", "Normal")])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
    end

    test "returns empty list for empty input" do
      assert PediatricCardiacUS.impressions([]) == []
    end
  end
end
