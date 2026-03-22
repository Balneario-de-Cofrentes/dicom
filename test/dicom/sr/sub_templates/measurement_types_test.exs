defmodule Dicom.SR.SubTemplates.MeasurementTypesTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.MeasurementTypes

  @mm Code.new("mm", "UCUM", "millimeter")
  @cm2 Code.new("cm2", "UCUM", "square centimeter")
  @cm3 Code.new("cm3", "UCUM", "cubic centimeter")
  @ml Code.new("mL", "UCUM", "milliliter")
  @hu Code.new("[hnsf'U]", "UCUM", "Hounsfield unit")
  @diameter Code.new("410668003", "SCT", "Length")
  @area Code.new("42798000", "SCT", "Area")
  @volume Code.new("118565006", "SCT", "Volume")
  @mean Code.new("373098007", "SCT", "Mean")
  @liver Code.new("10200004", "SCT", "Liver")
  @ruler Code.new("128864", "DCM", "Ruler")
  @density Code.new("112031", "DCM", "Attenuation Coefficient")

  # -- TID 1404 Numeric Measurement ------------------------------------------

  describe "numeric_measurement/1" do
    test "builds basic numeric measurement" do
      [item] =
        MeasurementTypes.numeric_measurement(
          concept: @diameter,
          value: 25.4,
          units: @mm
        )

      assert item.value_type == :num
      assert item.concept_name == @diameter
      assert item.value.units == @mm
      assert item.relationship_type == "CONTAINS"
    end

    test "includes derivation modifier" do
      [item] =
        MeasurementTypes.numeric_measurement(
          concept: @diameter,
          value: 12.0,
          units: @mm,
          derivation: @mean
        )

      derivation_child =
        Enum.find(item.children, fn c ->
          c.concept_name == Codes.derivation()
        end)

      assert derivation_child != nil
      assert derivation_child.value == @mean
      assert derivation_child.relationship_type == "HAS CONCEPT MOD"
    end

    test "includes method and finding site" do
      [item] =
        MeasurementTypes.numeric_measurement(
          concept: @diameter,
          value: 50,
          units: @mm,
          method: @ruler,
          finding_site: @liver
        )

      concepts = Enum.map(item.children, & &1.concept_name)
      assert Codes.measurement_method() in concepts
      assert Codes.finding_site() in concepts
    end

    test "includes equation text" do
      [item] =
        MeasurementTypes.numeric_measurement(
          concept: @volume,
          value: 123.4,
          units: @cm3,
          equation: "4/3 * pi * r^3"
        )

      eq_child =
        Enum.find(item.children, fn c ->
          c.concept_name == Codes.equation_or_table()
        end)

      assert eq_child != nil
      assert eq_child.value_type == :text
      assert eq_child.value == "4/3 * pi * r^3"
    end

    test "supports qualifier" do
      [item] =
        MeasurementTypes.numeric_measurement(
          concept: @diameter,
          value: 0,
          units: @mm,
          qualifier: Code.new("114000", "DCM", "Not a number")
        )

      assert item.value.qualifier != nil
    end

    test "custom relationship type" do
      [item] =
        MeasurementTypes.numeric_measurement(
          concept: @diameter,
          value: 10,
          units: @mm,
          relationship_type: "INFERRED FROM"
        )

      assert item.relationship_type == "INFERRED FROM"
    end
  end

  # -- TID 1400 Linear Measurement ------------------------------------------

  describe "linear_measurement/1" do
    test "delegates to numeric_measurement" do
      [item] =
        MeasurementTypes.linear_measurement(
          concept: @diameter,
          value: 30,
          units: @mm
        )

      assert item.value_type == :num
      assert item.concept_name == @diameter
    end
  end

  # -- TID 1401 Area Measurement --------------------------------------------

  describe "area_measurement/1" do
    test "builds area measurement" do
      [item] =
        MeasurementTypes.area_measurement(
          concept: @area,
          value: 15.2,
          units: @cm2
        )

      assert item.value_type == :num
      assert item.value.units == @cm2
    end
  end

  # -- TID 1402 Volume Measurement ------------------------------------------

  describe "volume_measurement/1" do
    test "builds volume measurement" do
      [item] =
        MeasurementTypes.volume_measurement(
          concept: @volume,
          value: 250.0,
          units: @ml
        )

      assert item.value_type == :num
      assert item.value.units == @ml
    end
  end

  # -- TID 1406 Three Dimensional Linear Measurement ------------------------

  describe "three_dimensional_linear_measurement/1" do
    test "builds 3D linear measurement" do
      [item] =
        MeasurementTypes.three_dimensional_linear_measurement(
          concept: @diameter,
          value: 42.5,
          units: @mm,
          finding_site: @liver
        )

      assert item.value_type == :num
      assert length(item.children) == 1
    end
  end

  # -- TID 1410 Planar ROI Measurements ------------------------------------

  describe "planar_roi_measurements/1" do
    test "builds multiple measurements with shared finding site" do
      items =
        MeasurementTypes.planar_roi_measurements(
          finding_site: @liver,
          measurements: [
            [concept: @diameter, value: 25, units: @mm],
            [concept: @area, value: 4.8, units: @cm2]
          ]
        )

      assert length(items) == 2

      Enum.each(items, fn item ->
        assert item.value_type == :num
        site_child = Enum.find(item.children, &(&1.concept_name == Codes.finding_site()))
        assert site_child != nil
        assert site_child.value == @liver
      end)
    end

    test "includes qualitative evaluations" do
      assessment = Code.new("112034", "DCM", "Assessment")
      benign = Code.new("111172", "DCM", "Benign")

      items =
        MeasurementTypes.planar_roi_measurements(
          measurements: [
            [concept: @diameter, value: 5, units: @mm]
          ],
          evaluations: [{assessment, benign}]
        )

      assert length(items) == 2
      eval_item = Enum.find(items, &(&1.value_type == :code))
      assert eval_item != nil
      assert eval_item.concept_name == assessment
      assert eval_item.value == benign
    end

    test "empty measurements and evaluations" do
      assert MeasurementTypes.planar_roi_measurements([]) == []
    end

    test "measurement options are not overridden by shared finding_site" do
      custom_site = Code.new("56459004", "SCT", "Foot")

      items =
        MeasurementTypes.planar_roi_measurements(
          finding_site: @liver,
          measurements: [
            [concept: @diameter, value: 10, units: @mm, finding_site: custom_site]
          ]
        )

      [item] = items
      site_child = Enum.find(item.children, &(&1.concept_name == Codes.finding_site()))
      assert site_child.value == custom_site
    end
  end

  # -- TID 1411 Volumetric ROI Measurements ---------------------------------

  describe "volumetric_roi_measurements/1" do
    test "delegates to planar_roi_measurements" do
      items =
        MeasurementTypes.volumetric_roi_measurements(
          measurements: [
            [concept: @volume, value: 100, units: @cm3]
          ]
        )

      assert length(items) == 1
      [item] = items
      assert item.value_type == :num
    end
  end

  # -- TID 1419 ROI Measurements --------------------------------------------

  describe "roi_measurements/1" do
    test "builds collection of measurements" do
      items =
        MeasurementTypes.roi_measurements(
          measurements: [
            [concept: @diameter, value: 10, units: @mm],
            [concept: @area, value: 3.14, units: @cm2],
            [concept: @density, value: 45, units: @hu]
          ]
        )

      assert length(items) == 3
      assert Enum.all?(items, &(&1.value_type == :num))
    end

    test "custom relationship type propagates" do
      items =
        MeasurementTypes.roi_measurements(
          relationship_type: "INFERRED FROM",
          measurements: [
            [concept: @diameter, value: 10, units: @mm]
          ]
        )

      [item] = items
      assert item.relationship_type == "INFERRED FROM"
    end
  end

  # -- TID 1420 Derived Measurements ----------------------------------------

  describe "derived_measurements/1" do
    test "builds derived measurement with derivation" do
      items =
        MeasurementTypes.derived_measurements(
          measurements: [
            [concept: @diameter, value: 18.5, units: @mm, derivation: @mean]
          ]
        )

      [item] = items
      assert item.value_type == :num

      derivation_child =
        Enum.find(item.children, &(&1.concept_name == Codes.derivation()))

      assert derivation_child.value == @mean
    end

    test "multiple derived measurements" do
      std_dev = Code.new("386136009", "SCT", "Standard Deviation")

      items =
        MeasurementTypes.derived_measurements(
          measurements: [
            [concept: @diameter, value: 18.5, units: @mm, derivation: @mean],
            [concept: @diameter, value: 3.2, units: @mm, derivation: std_dev]
          ]
        )

      assert length(items) == 2
    end
  end
end
