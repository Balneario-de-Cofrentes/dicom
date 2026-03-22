defmodule Dicom.SR.SubTemplates.IVUSTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.IVUS
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

  describe "TID 3251 vessel/1" do
    test "builds vessel container with finding site" do
      item =
        IVUS.vessel(vessel: Codes.common_carotid_artery())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122201"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "363698007" in codes
    end

    test "includes lesion and measurement children" do
      lesion =
        IVUS.lesion(
          tracking_id: "lesion-1",
          measurements: [
            Measurement.new(Codes.vessel_lumen_area(), 4.5, Codes.sq_mm())
          ]
        )

      measurement_items =
        IVUS.measurements([
          Measurement.new(Codes.vessel_area(), 12.0, Codes.sq_mm())
        ])

      item =
        IVUS.vessel(
          vessel: Codes.internal_carotid_artery(),
          lesions: [lesion],
          measurements: measurement_items
        )
        |> render()

      codes = children_codes(item)
      # Finding site + lesion container + measurement
      assert "363698007" in codes
      assert "122202" in codes
      assert "122153" in codes
    end

    test "raises when vessel is missing" do
      assert_raise KeyError, fn ->
        IVUS.vessel(lesions: [])
      end
    end
  end

  describe "TID 3252 lesion/1" do
    test "builds lesion container with tracking identifier" do
      item =
        IVUS.lesion(tracking_id: "proximal-LAD-lesion")
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122202"

      codes = children_codes(item)
      assert "112039" in codes

      tracking_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "112039"))

      assert tracking_item[Tag.text_value()].value == "proximal-LAD-lesion"
    end

    test "includes measurements and qualitative assessments" do
      plaque_assessment =
        IVUS.qualitative_assessment(Codes.plaque_morphology(), Codes.calcified_plaque())

      item =
        IVUS.lesion(
          tracking_id: "mid-LAD-lesion",
          measurements: [
            Measurement.new(Codes.plaque_burden(), 65, Codes.percent()),
            Measurement.new(Codes.stenosis_severity(), 50, Codes.percent())
          ],
          qualitative_assessments: [plaque_assessment]
        )
        |> render()

      codes = children_codes(item)
      assert "112039" in codes
      assert "122155" in codes
      assert "246112005" in codes
      assert "122212" in codes
    end

    test "raises when tracking_id is missing" do
      assert_raise KeyError, fn ->
        IVUS.lesion(measurements: [])
      end
    end
  end

  describe "TID 3253 measurements/1" do
    test "converts standard IVUS measurements to content items" do
      lumen = Measurement.new(Codes.vessel_lumen_area(), 5.2, Codes.sq_mm())
      vessel = Measurement.new(Codes.vessel_area(), 14.0, Codes.sq_mm())
      plaque = Measurement.new(Codes.plaque_area(), 8.8, Codes.sq_mm())
      min_dia = Measurement.new(Codes.minimum_lumen_diameter(), 2.1, Codes.mm())
      max_dia = Measurement.new(Codes.maximum_lumen_diameter(), 3.0, Codes.mm())

      items = IVUS.measurements([lumen, vessel, plaque, min_dia, max_dia])

      assert length(items) == 5
      rendered = Enum.map(items, &render/1)
      assert Enum.all?(rendered, &(&1[Tag.value_type()].value == "NUM"))

      measurement_codes = Enum.map(rendered, &code_value(&1, Tag.concept_name_code_sequence()))
      assert "122203" in measurement_codes
      assert "122153" in measurement_codes
      assert "122205" in measurement_codes
      assert "122208" in measurement_codes
      assert "122209" in measurement_codes
    end

    test "returns empty list for empty input" do
      assert IVUS.measurements([]) == []
    end
  end

  describe "TID 3254 qualitative_assessment/2" do
    test "builds plaque morphology assessment" do
      item =
        IVUS.qualitative_assessment(Codes.plaque_morphology(), Codes.calcified_plaque())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122212"
      assert code_value(item, Tag.concept_code_sequence()) == "122213"
    end

    test "supports fibrous plaque" do
      item =
        IVUS.qualitative_assessment(Codes.plaque_morphology(), Codes.fibrous_plaque())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "122214"
    end

    test "supports lipid rich plaque" do
      item =
        IVUS.qualitative_assessment(Codes.plaque_morphology(), Codes.lipid_rich_plaque())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "122215"
    end

    test "supports mixed plaque" do
      item =
        IVUS.qualitative_assessment(Codes.plaque_morphology(), Codes.mixed_plaque())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "122216"
    end

    test "supports remodeling index assessment" do
      item =
        IVUS.qualitative_assessment(
          Codes.remodeling_index(),
          Code.new("122230", "DCM", "Positive remodeling")
        )
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "122210"
    end
  end

  describe "TID 3255 volume_measurement/1" do
    test "builds volume container with tracking and measurements" do
      lumen_vol = Measurement.new(Codes.lumen_volume(), 450.0, Codes.cubic_mm())
      vessel_vol = Measurement.new(Codes.vessel_volume(), 900.0, Codes.cubic_mm())
      plaque_vol = Measurement.new(Codes.plaque_volume(), 450.0, Codes.cubic_mm())

      item =
        IVUS.volume_measurement(
          tracking_id: "LAD-segment-1",
          measurements: [lumen_vol, vessel_vol, plaque_vol]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122217"

      codes = children_codes(item)
      assert "112039" in codes
      assert "122218" in codes
      assert "122219" in codes
      assert "122220" in codes
    end

    test "raises when tracking_id is missing" do
      assert_raise KeyError, fn ->
        IVUS.volume_measurement(
          measurements: [Measurement.new(Codes.lumen_volume(), 100.0, Codes.cubic_mm())]
        )
      end
    end

    test "raises when measurements is missing" do
      assert_raise KeyError, fn ->
        IVUS.volume_measurement(tracking_id: "segment-1")
      end
    end
  end
end
