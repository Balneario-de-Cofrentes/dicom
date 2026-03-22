defmodule Dicom.SR.SubTemplates.VascularUltrasoundTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.VascularUltrasound
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

  describe "TID 5101 patient_characteristics/1" do
    test "builds container with body measurements" do
      weight = Measurement.new(Codes.body_weight(), 85, Codes.kg())
      height = Measurement.new(Codes.body_height(), 178, Codes.cm())

      item =
        VascularUltrasound.patient_characteristics(measurements: [weight, height])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122401"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "27113001" in codes
      assert "50373000" in codes
    end

    test "raises when measurements is missing" do
      assert_raise KeyError, fn ->
        VascularUltrasound.patient_characteristics([])
      end
    end
  end

  describe "TID 5102 procedure_summary/1" do
    test "builds container with description" do
      item =
        VascularUltrasound.procedure_summary(description: "Bilateral carotid duplex ultrasound")
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122402"

      codes = children_codes(item)
      assert "121065" in codes

      desc_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "121065"))

      assert desc_item[Tag.text_value()].value == "Bilateral carotid duplex ultrasound"
    end

    test "includes findings and impressions" do
      item =
        VascularUltrasound.procedure_summary(
          description: "Carotid duplex",
          findings: ["Moderate ICA stenosis on the right"],
          impressions: ["Recommend follow-up in 6 months"]
        )
        |> render()

      codes = children_codes(item)
      assert "121065" in codes
      assert "121071" in codes
      assert "121073" in codes
    end

    test "supports code-based findings and impressions" do
      item =
        VascularUltrasound.procedure_summary(
          description: "Lower extremity arterial",
          findings: [Code.new("64572001", "SCT", "Atherosclerosis")],
          impressions: [Code.new("373930000", "SCT", "Normal")]
        )
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
      assert "121073" in codes
    end

    test "raises when description is missing" do
      assert_raise KeyError, fn ->
        VascularUltrasound.procedure_summary(findings: [])
      end
    end
  end

  describe "TID 5103 vascular_section/1" do
    test "builds section for a vessel with finding site" do
      item =
        VascularUltrasound.vascular_section(vessel: Codes.common_carotid_artery())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121196"

      codes = children_codes(item)
      assert "363698007" in codes
    end

    test "includes laterality modifier" do
      item =
        VascularUltrasound.vascular_section(
          vessel: Codes.internal_carotid_artery(),
          laterality: Codes.right_breast()
        )
        |> render()

      finding_site_count =
        item[Tag.content_sequence()].value
        |> Enum.count(&(code_value(&1, Tag.concept_name_code_sequence()) == "363698007"))

      assert finding_site_count == 2
    end

    test "includes measurement groups and findings" do
      mg =
        VascularUltrasound.measurement_group(
          tracking_id: "proximal-ICA",
          measurements: [
            Measurement.new(Codes.peak_systolic_velocity(), 125, Codes.cm_per_s())
          ]
        )

      item =
        VascularUltrasound.vascular_section(
          vessel: Codes.internal_carotid_artery(),
          measurement_groups: [mg],
          findings: ["50-69% stenosis by velocity criteria"]
        )
        |> render()

      codes = children_codes(item)
      assert "363698007" in codes
      assert "122404" in codes
      assert "121071" in codes
    end

    test "raises when vessel is missing" do
      assert_raise KeyError, fn ->
        VascularUltrasound.vascular_section(measurement_groups: [])
      end
    end
  end

  describe "TID 5104 measurement_group/1" do
    test "builds container with tracking and measurements" do
      psv = Measurement.new(Codes.peak_systolic_velocity(), 120, Codes.cm_per_s())
      edv = Measurement.new(Codes.end_diastolic_velocity(), 40, Codes.cm_per_s())
      ri = Measurement.new(Codes.resistive_index(), 0.67, Code.new("1", "UCUM", "ratio"))
      pi = Measurement.new(Codes.pulsatility_index(), 1.2, Code.new("1", "UCUM", "ratio"))

      item =
        VascularUltrasound.measurement_group(
          tracking_id: "mid-CCA",
          measurements: [psv, edv, ri, pi]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122404"

      codes = children_codes(item)
      assert "112039" in codes
      assert "11726-7" in codes
      assert "11653-3" in codes
      assert "20354-7" in codes
      assert "20355-4" in codes
    end

    test "includes IMT and stenosis measurements" do
      imt = Measurement.new(Codes.intima_media_thickness(), 0.8, Codes.mm())
      diameter_st = Measurement.new(Codes.diameter_stenosis(), 55, Codes.percent())
      area_st = Measurement.new(Codes.area_stenosis(), 70, Codes.percent())

      item =
        VascularUltrasound.measurement_group(
          tracking_id: "bulb",
          measurements: [imt, diameter_st, area_st]
        )
        |> render()

      codes = children_codes(item)
      assert "122408" in codes
      assert "122409" in codes
      assert "122410" in codes
    end

    test "raises when tracking_id is missing" do
      assert_raise KeyError, fn ->
        VascularUltrasound.measurement_group(
          measurements: [Measurement.new(Codes.peak_systolic_velocity(), 100, Codes.cm_per_s())]
        )
      end
    end

    test "raises when measurements is missing" do
      assert_raise KeyError, fn ->
        VascularUltrasound.measurement_group(tracking_id: "site-1")
      end
    end
  end

  describe "TID 5105 graft_section/1" do
    test "builds graft container with all required fields" do
      item =
        VascularUltrasound.graft_section(
          graft_type: Codes.synthetic_graft(),
          origin: "Common femoral artery",
          destination: "Above-knee popliteal artery",
          patency: Codes.patent()
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "12101003"

      codes = children_codes(item)
      assert "122411" in codes
      assert "122414" in codes
      assert "122415" in codes
      assert "122416" in codes

      type_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "122411"))

      assert code_value(type_item, Tag.concept_code_sequence()) == "122412"

      patency_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "122416"))

      assert code_value(patency_item, Tag.concept_code_sequence()) == "122417"
    end

    test "supports vein graft with occluded patency" do
      item =
        VascularUltrasound.graft_section(
          graft_type: Codes.vein_graft(),
          origin: "Greater saphenous vein",
          destination: "Posterior tibial artery",
          patency: Codes.occluded()
        )
        |> render()

      type_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "122411"))

      assert code_value(type_item, Tag.concept_code_sequence()) == "122413"

      patency_item =
        item[Tag.content_sequence()].value
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "122416"))

      assert code_value(patency_item, Tag.concept_code_sequence()) == "122418"
    end

    test "includes measurements and findings" do
      psv = Measurement.new(Codes.peak_systolic_velocity(), 200, Codes.cm_per_s())

      item =
        VascularUltrasound.graft_section(
          graft_type: Codes.synthetic_graft(),
          origin: "Aorta",
          destination: "Femoral bifurcation",
          patency: Codes.patent(),
          measurements: [psv],
          findings: ["Elevated velocity at proximal anastomosis"]
        )
        |> render()

      codes = children_codes(item)
      assert "11726-7" in codes
      assert "121071" in codes
    end

    test "raises when required fields are missing" do
      assert_raise KeyError, fn ->
        VascularUltrasound.graft_section(
          origin: "CFA",
          destination: "AK Pop",
          patency: Codes.patent()
        )
      end

      assert_raise KeyError, fn ->
        VascularUltrasound.graft_section(
          graft_type: Codes.synthetic_graft(),
          destination: "AK Pop",
          patency: Codes.patent()
        )
      end

      assert_raise KeyError, fn ->
        VascularUltrasound.graft_section(
          graft_type: Codes.synthetic_graft(),
          origin: "CFA",
          patency: Codes.patent()
        )
      end

      assert_raise KeyError, fn ->
        VascularUltrasound.graft_section(
          graft_type: Codes.synthetic_graft(),
          origin: "CFA",
          destination: "AK Pop"
        )
      end
    end
  end
end
