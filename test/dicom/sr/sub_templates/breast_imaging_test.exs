defmodule Dicom.SR.SubTemplates.BreastImagingTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Codes, ContentItem}
  alias Dicom.SR.SubTemplates.BreastImaging
  alias Dicom.Tag

  defp code_value(item, sequence_tag) do
    [code_item] = item[sequence_tag].value
    code_item[Tag.code_value()].value
  end

  defp render(content_item), do: ContentItem.to_item(content_item)

  describe "TID 4205 breast_composition/1" do
    test "almost entirely fat" do
      item =
        BreastImaging.breast_composition(Codes.almost_entirely_fat())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111031"
      assert code_value(item, Tag.concept_code_sequence()) == "111044"
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end

    test "scattered fibroglandular" do
      item =
        BreastImaging.breast_composition(Codes.scattered_fibroglandular())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "111031"
      assert code_value(item, Tag.concept_code_sequence()) == "111045"
    end

    test "heterogeneously dense" do
      item =
        BreastImaging.breast_composition(Codes.heterogeneously_dense())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "111031"
      assert code_value(item, Tag.concept_code_sequence()) == "111046"
    end

    test "extremely dense" do
      item =
        BreastImaging.breast_composition(Codes.extremely_dense())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "111031"
      assert code_value(item, Tag.concept_code_sequence()) == "111047"
    end
  end

  describe "TID 4202 report_narrative/1" do
    test "builds TEXT item with narrative summary" do
      item =
        BreastImaging.report_narrative("No suspicious findings identified.")
        |> render()

      assert item[Tag.value_type()].value == "TEXT"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111043"
      assert item[Tag.text_value()].value == "No suspicious findings identified."
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end

    test "preserves multiline narrative text" do
      text = "Right breast: No abnormality detected.\nLeft breast: Benign calcifications."

      item =
        BreastImaging.report_narrative(text)
        |> render()

      assert item[Tag.text_value()].value == text
    end
  end

  describe "TID 4203 birads_assessment/1" do
    test "category 0 -- incomplete" do
      item =
        BreastImaging.birads_assessment(Codes.birads_category_0())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111037"
      assert code_value(item, Tag.concept_code_sequence()) == "111170"
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end

    test "category 1 -- negative" do
      item =
        BreastImaging.birads_assessment(Codes.birads_category_1())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111171"
    end

    test "category 2 -- benign" do
      item =
        BreastImaging.birads_assessment(Codes.birads_category_2())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111172"
    end

    test "category 3 -- probably benign" do
      item =
        BreastImaging.birads_assessment(Codes.birads_category_3())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111173"
    end

    test "category 4 -- suspicious" do
      item =
        BreastImaging.birads_assessment(Codes.birads_category_4())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111174"
    end

    test "category 5 -- highly suggestive of malignancy" do
      item =
        BreastImaging.birads_assessment(Codes.birads_category_5())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111175"
    end

    test "category 6 -- known biopsy proven malignancy" do
      item =
        BreastImaging.birads_assessment(Codes.birads_category_6())
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "111176"
    end
  end

  describe "TID 4206 finding_item/1" do
    test "coded finding -- mass" do
      item =
        BreastImaging.finding_item(Codes.mass())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121071"
      assert code_value(item, Tag.concept_code_sequence()) == "4147007"
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end

    test "coded finding -- calcification" do
      item =
        BreastImaging.finding_item(Codes.calcification())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "121071"
      assert code_value(item, Tag.concept_code_sequence()) == "129748003"
    end

    test "coded finding -- architectural distortion" do
      item =
        BreastImaging.finding_item(Codes.architectural_distortion())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "121071"
      assert code_value(item, Tag.concept_code_sequence()) == "129770000"
    end

    test "coded finding -- asymmetry" do
      item =
        BreastImaging.finding_item(Codes.asymmetry())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "121071"
      assert code_value(item, Tag.concept_code_sequence()) == "129769005"
    end

    test "text finding" do
      item =
        BreastImaging.finding_item("Focal asymmetry in upper outer quadrant")
        |> render()

      assert item[Tag.value_type()].value == "TEXT"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121071"
      assert item[Tag.text_value()].value == "Focal asymmetry in upper outer quadrant"
    end
  end
end
