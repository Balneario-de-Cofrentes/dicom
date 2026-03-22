defmodule Dicom.SR.SubTemplates.SpectaclePrescriptionTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.ContentItem
  alias Dicom.SR.SubTemplates.SpectaclePrescription
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

  describe "TID 2021 eye_prescription/1" do
    test "builds right eye prescription with full parameters" do
      item =
        SpectaclePrescription.eye_prescription(
          eye: :right,
          sphere: -2.50,
          cylinder: -0.75,
          axis: 180,
          add_power: 2.00,
          prism_power: 1.5,
          prism_base: "Base Out",
          interpupillary_distance: 32.0
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "70947-5"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)

      # laterality
      assert "272741003" in codes
      # sphere
      assert "251795007" in codes
      # cylinder
      assert "251797004" in codes
      # axis
      assert "251799001" in codes
      # add power
      assert "251718005" in codes
      # prism power
      assert "246223004" in codes
      # prism base
      assert "246224005" in codes
      # interpupillary distance
      assert "251762001" in codes
    end

    test "builds left eye prescription with minimal parameters" do
      item =
        SpectaclePrescription.eye_prescription(eye: :left, sphere: -1.00)
        |> render()

      codes = children_codes(item)

      # laterality with left eye code
      laterality_child =
        item[Tag.content_sequence()].value
        |> Enum.find(fn child ->
          code_value(child, Tag.concept_name_code_sequence()) == "272741003"
        end)

      assert code_value(laterality_child, Tag.concept_code_sequence()) == "8966001"

      # sphere present
      assert "251795007" in codes
      # no cylinder, axis, etc.
      assert length(codes) == 2
    end

    test "right eye has correct laterality code" do
      item =
        SpectaclePrescription.eye_prescription(eye: :right, sphere: -1.00)
        |> render()

      laterality_child =
        item[Tag.content_sequence()].value
        |> Enum.find(fn child ->
          code_value(child, Tag.concept_name_code_sequence()) == "272741003"
        end)

      assert code_value(laterality_child, Tag.concept_code_sequence()) == "81745001"
    end

    test "raises when eye is missing" do
      assert_raise KeyError, fn ->
        SpectaclePrescription.eye_prescription(sphere: -1.00)
      end
    end
  end

  describe "TID 2022 lens_parameters/1" do
    test "builds sphere, cylinder, and axis items" do
      items =
        SpectaclePrescription.lens_parameters(
          sphere: -3.00,
          cylinder: -1.25,
          axis: 90
        )

      assert length(items) == 3
      rendered = Enum.map(items, &render/1)
      assert Enum.all?(rendered, &(&1[Tag.value_type()].value == "NUM"))

      codes =
        Enum.map(rendered, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "251795007" in codes
      assert "251797004" in codes
      assert "251799001" in codes
    end

    test "builds only sphere when cylinder and axis absent" do
      items = SpectaclePrescription.lens_parameters(sphere: -2.00)

      assert length(items) == 1
      [rendered] = Enum.map(items, &render/1)
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "251795007"
    end

    test "returns empty list when no parameters" do
      assert SpectaclePrescription.lens_parameters([]) == []
    end
  end

  describe "TID 2023 prism_parameters/1" do
    test "builds prism power and base items" do
      items =
        SpectaclePrescription.prism_parameters(
          power: 2.0,
          base: "Base In"
        )

      assert length(items) == 2
      rendered = Enum.map(items, &render/1)

      codes =
        Enum.map(rendered, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "246223004" in codes
      assert "246224005" in codes
    end

    test "builds only base when power absent" do
      items = SpectaclePrescription.prism_parameters(base: "Base Up")

      assert length(items) == 1
      [rendered] = Enum.map(items, &render/1)
      assert code_value(rendered, Tag.concept_name_code_sequence()) == "246224005"
      assert rendered[Tag.text_value()].value == "Base Up"
    end

    test "returns empty list when no parameters" do
      assert SpectaclePrescription.prism_parameters([]) == []
    end
  end
end
