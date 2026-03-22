defmodule Dicom.SR.SubTemplates.EchocardiographyTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}
  alias Dicom.SR.SubTemplates.Echocardiography
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

  describe "TID 5201 patient_characteristics/1" do
    test "builds container with body measurements" do
      bsa = Measurement.new(Codes.body_surface_area(), 1.85, Codes.m_sq())
      weight = Measurement.new(Codes.body_weight(), 80, Codes.kg())
      height = Measurement.new(Codes.body_height(), 175, Codes.cm())

      item =
        Echocardiography.patient_characteristics(measurements: [bsa, weight, height])
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121070"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "301898006" in codes
      assert "27113001" in codes
      assert "50373000" in codes
    end

    test "raises when measurements missing" do
      assert_raise KeyError, fn ->
        Echocardiography.patient_characteristics([])
      end
    end
  end

  describe "TID 5202 echo_section/1" do
    test "builds section for left ventricle with measurements" do
      lvef_measurement =
        Echocardiography.echo_measurement(Measurement.new(Codes.lvef(), 60, Codes.percent()))

      lvidd_measurement =
        Echocardiography.echo_measurement(
          Measurement.new(Codes.lv_end_diastolic_dimension(), 4.8, Codes.cm())
        )

      item =
        Echocardiography.echo_section(
          structure: Codes.left_ventricle(),
          measurements: [lvef_measurement, lvidd_measurement]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122301"

      codes = children_codes(item)
      assert "363698007" in codes
      assert "10230-1" in codes
      assert "29468-6" in codes
    end

    test "builds section with findings" do
      item =
        Echocardiography.echo_section(
          structure: Codes.mitral_valve(),
          findings: ["Mild mitral regurgitation"]
        )
        |> render()

      codes = children_codes(item)
      assert "363698007" in codes
      assert "121071" in codes
    end

    test "builds section with code-based findings" do
      item =
        Echocardiography.echo_section(
          structure: Codes.aortic_valve(),
          findings: [Code.new("48724000", "SCT", "Mitral valve stenosis")]
        )
        |> render()

      codes = children_codes(item)
      assert "121071" in codes
    end

    test "raises when structure is missing" do
      assert_raise KeyError, fn ->
        Echocardiography.echo_section(measurements: [])
      end
    end
  end

  describe "TID 5203 echo_measurement/1" do
    test "converts measurement to content item" do
      item =
        Echocardiography.echo_measurement(Measurement.new(Codes.lvef(), 55, Codes.percent()))
        |> render()

      assert item[Tag.value_type()].value == "NUM"
      assert code_value(item, Tag.concept_name_code_sequence()) == "10230-1"
    end

    test "preserves units" do
      item =
        Echocardiography.echo_measurement(Measurement.new(Codes.lv_mass(), 150, Codes.grams()))
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "10231-9"
      [measured] = item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "g"
    end
  end

  describe "TID 5204 wall_motion_analysis/1" do
    test "builds container with scores and regional assessments" do
      wms = Measurement.new(Codes.wall_motion_score(), 16, Code.new("1", "UCUM", "score"))
      wmsi = Measurement.new(Codes.wall_motion_score_index(), 1.0, Code.new("1", "UCUM", "index"))

      apical_assessment =
        Echocardiography.regional_wall_motion(
          Code.new("71252005", "SCT", "Apical segment"),
          Codes.normal_wall_motion()
        )

      item =
        Echocardiography.wall_motion_analysis(
          wall_motion_score: wms,
          wall_motion_score_index: wmsi,
          regional_assessments: [apical_assessment]
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122307"

      codes = children_codes(item)
      assert "122307" in codes
      assert "125209" in codes
      assert "F-32040" in codes
    end

    test "builds container with scores only" do
      wms = Measurement.new(Codes.wall_motion_score(), 16, Code.new("1", "UCUM", "score"))

      item =
        Echocardiography.wall_motion_analysis(wall_motion_score: wms)
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      codes = children_codes(item)
      assert "122307" in codes
    end

    test "builds empty container when no options" do
      item = Echocardiography.wall_motion_analysis([]) |> render()
      assert item[Tag.value_type()].value == "CONTAINER"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  describe "regional_wall_motion/2" do
    test "builds normal wall motion for segment" do
      item =
        Echocardiography.regional_wall_motion(
          Code.new("71252005", "SCT", "Apical segment"),
          Codes.normal_wall_motion()
        )
        |> render()

      assert item[Tag.value_type()].value == "CODE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "F-32040"
      assert code_value(item, Tag.concept_code_sequence()) == "122309"

      [child] = item[Tag.content_sequence()].value
      assert code_value(child, Tag.concept_name_code_sequence()) == "363698007"
    end

    test "builds hypokinesis assessment" do
      item =
        Echocardiography.regional_wall_motion(
          Code.new("71252005", "SCT", "Apical segment"),
          Codes.hypokinesis()
        )
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "122310"
    end

    test "builds akinesis assessment" do
      item =
        Echocardiography.regional_wall_motion(
          Code.new("71252005", "SCT", "Apical segment"),
          Codes.akinesis()
        )
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "122311"
    end

    test "builds dyskinesis assessment" do
      item =
        Echocardiography.regional_wall_motion(
          Code.new("71252005", "SCT", "Apical segment"),
          Codes.dyskinesis()
        )
        |> render()

      assert code_value(item, Tag.concept_code_sequence()) == "122312"
    end
  end

  describe "TID 5240 myocardial_strain_analysis/1" do
    test "builds container with global strain" do
      gls = Measurement.new(Codes.global_longitudinal_strain(), -20.5, Codes.percent())

      item =
        Echocardiography.myocardial_strain_analysis(global_strain: gls)
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122313"

      codes = children_codes(item)
      assert "122313" in codes
    end

    test "includes regional strain measurements" do
      gls = Measurement.new(Codes.global_longitudinal_strain(), -19.0, Codes.percent())

      regional =
        Measurement.new(
          Code.new("122314", "DCM", "Apical Longitudinal Strain"),
          -22.0,
          Codes.percent()
        )

      item =
        Echocardiography.myocardial_strain_analysis(
          global_strain: gls,
          regional_strains: [regional]
        )
        |> render()

      codes = children_codes(item)
      assert "122313" in codes
      assert "122314" in codes
    end

    test "raises when global_strain is missing" do
      assert_raise KeyError, fn ->
        Echocardiography.myocardial_strain_analysis(regional_strains: [])
      end
    end
  end
end
