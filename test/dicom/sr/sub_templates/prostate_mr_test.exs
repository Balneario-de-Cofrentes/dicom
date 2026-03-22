defmodule Dicom.SR.SubTemplates.ProstateMRTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.ProstateMR
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

  # -- TID 4301 Patient History --

  describe "TID 4301 patient_history/1" do
    test "builds container with PSA, prior biopsies, and family history" do
      psa = Measurement.new(Codes.psa_level(), 6.5, Codes.ng_per_ml())

      item =
        ProstateMR.patient_history(
          psa: psa,
          prior_biopsies: "Two prior negative biopsies",
          family_history: "Father diagnosed at age 65"
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # patient_history concept = "121060"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121060"
      assert item[Tag.relationship_type()].value == "HAS OBS CONTEXT"

      codes = children_codes(item)
      # PSA level = "2857-1"
      assert "2857-1" in codes
      # Prior biopsy = "65854-2"
      assert "65854-2" in codes
      # Family history = "10157-6"
      assert "10157-6" in codes
    end

    test "builds container with PSA only" do
      psa = Measurement.new(Codes.psa_level(), 4.0, Codes.ng_per_ml())

      item =
        ProstateMR.patient_history(psa: psa)
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      codes = children_codes(item)
      assert "2857-1" in codes
      assert length(codes) == 1
    end

    test "builds container with text items only" do
      item =
        ProstateMR.patient_history(
          prior_biopsies: "Negative",
          family_history: "No family history"
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      codes = children_codes(item)
      assert "65854-2" in codes
      assert "10157-6" in codes
    end

    test "returns nil when all options are absent" do
      assert ProstateMR.patient_history([]) == nil
    end
  end

  # -- TID 4302 Prostate Imaging Findings --

  describe "TID 4302 imaging_findings/1" do
    test "builds container with volume, PSA density, and assessment" do
      volume = Measurement.new(Codes.prostate_volume(), 45.0, Codes.milliliter())
      density = Measurement.new(Codes.psa_density(), 0.15, Codes.ng_per_ml_per_ml())

      item =
        ProstateMR.imaging_findings(
          prostate_volume: volume,
          psa_density: density,
          overall_assessment: Codes.pirads_category_3()
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # prostate_imaging_findings = "126200"
      assert code_value(item, Tag.concept_name_code_sequence()) == "126200"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      # prostate_volume = "118565006"
      assert "118565006" in codes
      # psa_density = "126401"
      assert "126401" in codes
      # overall_assessment = "111037"
      assert "111037" in codes
    end

    test "includes localized and extraprostatic findings" do
      item =
        ProstateMR.imaging_findings(
          localized_findings: [
            [location: Code.new("T-D0066", "SRT", "Peripheral zone"), t2w_score: 4]
          ],
          extraprostatic_findings: ["Seminal vesicle asymmetry"]
        )
        |> render()

      codes = children_codes(item)
      # localized_finding = "126403"
      assert "126403" in codes
      # extraprostatic_finding = "126404"
      assert "126404" in codes
    end

    test "returns nil when all options are absent" do
      assert ProstateMR.imaging_findings([]) == nil
    end
  end

  # -- TID 4303 Overall PI-RADS Assessment --

  describe "TID 4303 overall_assessment/1" do
    test "builds container with PI-RADS code" do
      item =
        ProstateMR.overall_assessment(Codes.pirads_category_4())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # overall_assessment = "111037"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111037"

      codes = children_codes(item)
      # pirads_assessment = "126400"
      assert "126400" in codes
    end

    test "accepts integer PI-RADS category 1" do
      item = ProstateMR.overall_assessment(1) |> render()
      [child] = item[Tag.content_sequence()].value
      # pirads_category_1 = "126410"
      assert code_value(child, Tag.concept_code_sequence()) == "126410"
    end

    test "accepts integer PI-RADS category 5" do
      item = ProstateMR.overall_assessment(5) |> render()
      [child] = item[Tag.content_sequence()].value
      # pirads_category_5 = "126414"
      assert code_value(child, Tag.concept_code_sequence()) == "126414"
    end

    test "all PI-RADS categories map to correct codes" do
      expected = %{
        1 => "126410",
        2 => "126411",
        3 => "126412",
        4 => "126413",
        5 => "126414"
      }

      for {n, expected_code} <- expected do
        item = ProstateMR.overall_assessment(n) |> render()
        [child] = item[Tag.content_sequence()].value
        assert code_value(child, Tag.concept_code_sequence()) == expected_code
      end
    end
  end

  # -- TID 4304 Localized Finding --

  describe "TID 4304 localized_finding/1" do
    test "builds container with all fields" do
      item =
        ProstateMR.localized_finding(
          location: Code.new("T-D0066", "SRT", "Peripheral zone"),
          size: 15,
          t2w_score: 4,
          dwi_score: 4,
          dce_score: 1,
          pirads_category: 4,
          likert_score: 4
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # localized_finding = "126403"
      assert code_value(item, Tag.concept_name_code_sequence()) == "126403"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      # finding_site = "363698007"
      assert "363698007" in codes
      # lesion_size = "246120007"
      assert "246120007" in codes
      # t2w_signal_score = "126420"
      assert "126420" in codes
      # dwi_signal_score = "126421"
      assert "126421" in codes
      # dce_curve_type = "126422"
      assert "126422" in codes
      # pirads_assessment = "126400"
      assert "126400" in codes
      # likert_score = "126423"
      assert "126423" in codes
    end

    test "builds container with location only" do
      item =
        ProstateMR.localized_finding(location: Code.new("T-D0067", "SRT", "Transition zone"))
        |> render()

      codes = children_codes(item)
      assert "363698007" in codes
      assert length(codes) == 1
    end

    test "accepts Measurement for size" do
      size_measurement = Measurement.new(Codes.lesion_size(), 12, Codes.mm())

      item =
        ProstateMR.localized_finding(size: size_measurement)
        |> render()

      codes = children_codes(item)
      # lesion_size = "246120007"
      assert "246120007" in codes
    end

    test "accepts numeric size in mm" do
      item = ProstateMR.localized_finding(size: 10) |> render()

      codes = children_codes(item)
      assert "246120007" in codes
    end

    test "accepts Code for PI-RADS category" do
      item =
        ProstateMR.localized_finding(pirads_category: Codes.pirads_category_5())
        |> render()

      codes = children_codes(item)
      assert "126400" in codes

      children = item[Tag.content_sequence()].value

      pirads_child =
        Enum.find(children, fn c ->
          code_value(c, Tag.concept_name_code_sequence()) == "126400"
        end)

      # pirads_category_5 = "126414"
      assert code_value(pirads_child, Tag.concept_code_sequence()) == "126414"
    end

    test "accepts integer PI-RADS category" do
      item = ProstateMR.localized_finding(pirads_category: 3) |> render()

      children = item[Tag.content_sequence()].value

      pirads_child =
        Enum.find(children, fn c ->
          code_value(c, Tag.concept_name_code_sequence()) == "126400"
        end)

      # pirads_category_3 = "126412"
      assert code_value(pirads_child, Tag.concept_code_sequence()) == "126412"
    end

    test "builds empty container when no options" do
      item = ProstateMR.localized_finding([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "126403"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- TID 4305 Extra-prostatic Finding --

  describe "TID 4305 extraprostatic_finding/1" do
    test "builds CODE item for coded finding" do
      item =
        ProstateMR.extraprostatic_finding(Codes.seminal_vesicle_invasion())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      # extraprostatic_finding = "126404"
      assert code_value(item, Tag.concept_name_code_sequence()) == "126404"
      # seminal_vesicle_invasion = "126430"
      assert code_value(item, Tag.concept_code_sequence()) == "126430"
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end

    test "builds CODE item for extraprostatic extension" do
      item =
        ProstateMR.extraprostatic_finding(Codes.extraprostatic_extension())
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      # extraprostatic_extension = "126431"
      assert code_value(item, Tag.concept_code_sequence()) == "126431"
    end

    test "builds TEXT item for free-text finding" do
      item =
        ProstateMR.extraprostatic_finding("Suspicious pelvic lymph node")
        |> render()

      assert item[Tag.value_type()].value == "TEXT"
      assert code_value(item, Tag.concept_name_code_sequence()) == "126404"
      assert item[Tag.relationship_type()].value == "CONTAINS"
      assert item[Tag.text_value()].value == "Suspicious pelvic lymph node"
    end
  end
end
