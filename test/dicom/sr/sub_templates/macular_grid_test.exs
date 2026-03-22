defmodule Dicom.SR.SubTemplates.MacularGridTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.ContentItem
  alias Dicom.SR.SubTemplates.MacularGrid
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

  describe "grid_sector/1" do
    test "builds container with finding site for center sector" do
      item = MacularGrid.grid_sector(sector: :center) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111700"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "363698007" in codes

      site_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "363698007"))

      assert code_value(site_item, Tag.concept_code_sequence()) == "110860"
    end

    test "includes thickness and volume measurements" do
      item =
        MacularGrid.grid_sector(sector: :inner_superior, thickness: 310, volume: 0.25)
        |> render()

      codes = children_codes(item)
      assert "363698007" in codes
      assert "410668003" in codes
      assert "121216" in codes
    end

    test "omits thickness and volume when not provided" do
      item = MacularGrid.grid_sector(sector: :outer_nasal) |> render()

      codes = children_codes(item)
      assert codes == ["363698007"]
    end

    test "maps all 9 ETDRS sectors to correct codes" do
      expected = %{
        center: "110860",
        inner_superior: "110861",
        inner_nasal: "110862",
        inner_inferior: "110863",
        inner_temporal: "110864",
        outer_superior: "110865",
        outer_nasal: "110866",
        outer_inferior: "110867",
        outer_temporal: "110868"
      }

      for {sector, expected_code} <- expected do
        item = MacularGrid.grid_sector(sector: sector) |> render()

        site_item =
          item[Tag.content_sequence()].value
          |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "363698007"))

        assert code_value(site_item, Tag.concept_code_sequence()) == expected_code,
               "sector #{sector} expected code #{expected_code}"
      end
    end

    test "raises on unknown sector" do
      assert_raise ArgumentError, ~r/unknown grid sector/, fn ->
        MacularGrid.grid_sector(sector: :fovea)
      end
    end

    test "raises when sector is missing" do
      assert_raise KeyError, fn ->
        MacularGrid.grid_sector(thickness: 300)
      end
    end
  end

  describe "quality_assessment/1" do
    test "builds NUM item with quality concept and signal quality units" do
      item = MacularGrid.quality_assessment(rating: 8) |> render()

      assert item[Tag.value_type()].value == "NUM"
      assert code_value(item, Tag.concept_name_code_sequence()) == "363679005"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      [measured_value] = item[Tag.measured_value_sequence()].value
      assert measured_value[Tag.numeric_value()].value == "8"

      [units_item] = measured_value[Tag.measurement_units_code_sequence()].value
      assert units_item[Tag.code_value()].value == "251602002"
    end

    test "raises when rating is missing" do
      assert_raise KeyError, fn ->
        MacularGrid.quality_assessment([])
      end
    end
  end

  describe "central_subfield_thickness/1" do
    test "builds NUM item with CST concept and micrometer units" do
      item = MacularGrid.central_subfield_thickness(value: 275) |> render()

      assert item[Tag.value_type()].value == "NUM"
      assert code_value(item, Tag.concept_name_code_sequence()) == "410669006"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      [measured_value] = item[Tag.measured_value_sequence()].value
      assert measured_value[Tag.numeric_value()].value == "275"

      [units_item] = measured_value[Tag.measurement_units_code_sequence()].value
      assert units_item[Tag.code_value()].value == "um"
    end

    test "raises when value is missing" do
      assert_raise KeyError, fn ->
        MacularGrid.central_subfield_thickness([])
      end
    end
  end

  describe "total_volume/1" do
    test "builds NUM item with total volume concept and cubic millimeter units" do
      item = MacularGrid.total_volume(value: 8.2) |> render()

      assert item[Tag.value_type()].value == "NUM"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121217"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      [measured_value] = item[Tag.measured_value_sequence()].value
      assert measured_value[Tag.numeric_value()].value == "8.2"

      [units_item] = measured_value[Tag.measurement_units_code_sequence()].value
      assert units_item[Tag.code_value()].value == "mm3"
    end

    test "raises when value is missing" do
      assert_raise KeyError, fn ->
        MacularGrid.total_volume([])
      end
    end
  end
end
