defmodule Dicom.SR.SubTemplates.MeasurementPropertiesTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.MeasurementProperties

  @mm Code.new("mm", "UCUM", "millimeter")
  @cm3 Code.new("cm3", "UCUM", "cubic centimeter")
  @days Code.new("d", "UCUM", "day")
  @no_units Code.new("1", "UCUM", "no units")
  @diameter Code.new("410668003", "SCT", "Length")
  @volume Code.new("118565006", "SCT", "Volume")
  @liver Code.new("10200004", "SCT", "Liver")
  @mean Code.new("373098007", "SCT", "Mean")
  @baseline Code.new("255399007", "SCT", "Baseline")

  # -- TID 300 Measurement ---------------------------------------------------

  describe "measurement/1" do
    test "builds basic measurement" do
      [item] =
        MeasurementProperties.measurement(
          concept: @diameter,
          value: 25,
          units: @mm
        )

      assert item.value_type == :num
      assert item.concept_name == @diameter
      assert item.value.units == @mm
      assert item.relationship_type == "CONTAINS"
      assert item.children == []
    end

    test "includes measurement properties as children" do
      [item] =
        MeasurementProperties.measurement(
          concept: @diameter,
          value: 25,
          units: @mm,
          properties: [
            statistical: [description: @mean, value_for_n: 10],
            authority: "RECIST 1.1"
          ]
        )

      assert length(item.children) > 0
      concepts = Enum.map(item.children, & &1.concept_name)
      assert Codes.statistical_description() in concepts
      assert Codes.measurement_authority() in concepts
    end

    test "custom relationship type" do
      [item] =
        MeasurementProperties.measurement(
          concept: @diameter,
          value: 10,
          units: @mm,
          relationship_type: "INFERRED FROM"
        )

      assert item.relationship_type == "INFERRED FROM"
    end
  end

  # -- TID 301 Measurement Content -------------------------------------------

  describe "measurement_content/1" do
    test "builds container with child measurements" do
      section = Code.new("125007", "DCM", "Measurement Group")

      [container] =
        MeasurementProperties.measurement_content(
          concept: section,
          measurements: [
            [concept: @diameter, value: 10, units: @mm],
            [concept: @volume, value: 50, units: @cm3]
          ]
        )

      assert container.value_type == :container
      assert container.concept_name == section
      assert length(container.children) == 2
      assert Enum.all?(container.children, &(&1.value_type == :num))
    end

    test "empty measurements" do
      section = Code.new("125007", "DCM", "Measurement Group")

      [container] =
        MeasurementProperties.measurement_content(
          concept: section,
          measurements: []
        )

      assert container.children == []
    end
  end

  # -- TID 310 Measurement Properties ----------------------------------------

  describe "measurement_properties/1" do
    test "empty options returns empty list" do
      assert MeasurementProperties.measurement_properties([]) == []
    end

    test "includes selection status" do
      selected = Code.new("121410", "DCM", "Selected")

      items =
        MeasurementProperties.measurement_properties(selection_status: selected)

      assert length(items) == 1
      [item] = items
      assert item.value_type == :code
      assert item.concept_name == Codes.selection_status()
    end

    test "includes population description and authority" do
      items =
        MeasurementProperties.measurement_properties(
          population_description: "Adult males 18-65",
          authority: "WHO"
        )

      assert length(items) == 2
      assert Enum.all?(items, &(&1.value_type == :text))
    end

    test "combines statistical and normal range" do
      items =
        MeasurementProperties.measurement_properties(
          statistical: [description: @mean],
          normal_range: [upper: 100, upper_units: @mm, lower: 10, lower_units: @mm]
        )

      assert length(items) == 3
    end
  end

  # -- TID 311 Statistical Properties ----------------------------------------

  describe "statistical_properties/1" do
    test "builds statistical description" do
      items =
        MeasurementProperties.statistical_properties(description: @mean)

      assert length(items) == 1
      [item] = items
      assert item.value_type == :code
      assert item.concept_name == Codes.statistical_description()
      assert item.value == @mean
    end

    test "includes value for N" do
      items =
        MeasurementProperties.statistical_properties(
          description: @mean,
          value_for_n: 42,
          units_for_n: @no_units
        )

      assert length(items) == 2
      n_item = Enum.find(items, &(&1.concept_name == Codes.value_for_n()))
      assert n_item.value_type == :num
    end

    test "value for N without explicit units uses no-units" do
      items =
        MeasurementProperties.statistical_properties(value_for_n: 5)

      [item] = items
      assert item.value_type == :num
    end

    test "empty options returns empty" do
      assert MeasurementProperties.statistical_properties([]) == []
    end
  end

  # -- TID 312 Normal Range Properties ---------------------------------------

  describe "normal_range_properties/1" do
    test "builds upper and lower bounds" do
      items =
        MeasurementProperties.normal_range_properties(
          upper: 120,
          upper_units: @mm,
          lower: 10,
          lower_units: @mm
        )

      assert length(items) == 2
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.normal_range_upper() in concepts
      assert Codes.normal_range_lower() in concepts
    end

    test "includes description" do
      items =
        MeasurementProperties.normal_range_properties(description: "Based on Smith et al. 2020")

      [item] = items
      assert item.value_type == :text
      assert item.concept_name == Codes.normal_range_description()
    end

    test "empty returns empty" do
      assert MeasurementProperties.normal_range_properties([]) == []
    end
  end

  # -- TID 314 Ratio --------------------------------------------------------

  describe "ratio/1" do
    test "builds ratio container with numerator and denominator" do
      ratio_concept = Code.new("126401", "DCM", "SUVbw")

      [container] =
        MeasurementProperties.ratio(
          concept: ratio_concept,
          numerator: 5.2,
          numerator_units: Code.new("Bq/mL", "UCUM", "Bq/mL"),
          denominator: 75.0,
          denominator_units: Code.new("kg", "UCUM", "kilogram")
        )

      assert container.value_type == :container
      assert container.concept_name == ratio_concept
      assert length(container.children) == 2

      [num_item, den_item] = container.children
      assert num_item.concept_name == Codes.numerator()
      assert num_item.value_type == :num
      assert num_item.relationship_type == "HAS PROPERTIES"

      assert den_item.concept_name == Codes.denominator()
      assert den_item.value_type == :num
    end
  end

  # -- TID 315 Equation or Table ---------------------------------------------

  describe "equation_or_table/1" do
    test "builds equation text" do
      items =
        MeasurementProperties.equation_or_table(equation: "V = 4/3 * pi * r^3")

      [item] = items
      assert item.value_type == :text
      assert item.concept_name == Codes.equation_or_table()
      assert item.value == "V = 4/3 * pi * r^3"
    end

    test "builds table reference" do
      items = MeasurementProperties.equation_or_table(table: "Table A.1")

      [item] = items
      assert item.value_type == :text
      assert item.concept_name == Codes.table()
    end

    test "includes algorithm name and version" do
      items =
        MeasurementProperties.equation_or_table(
          equation: "linear regression",
          algorithm_name: "LesionTracker",
          algorithm_version: "2.1.0"
        )

      assert length(items) == 3
    end

    test "empty returns empty" do
      assert MeasurementProperties.equation_or_table([]) == []
    end
  end

  # -- TID 1501 Measurement and Qualitative Evaluation Group ----------------

  describe "measurement_group/1" do
    test "builds group container with tracking" do
      [container] =
        MeasurementProperties.measurement_group(
          tracking_identifier: "Lesion 1",
          tracking_uid: "1.2.3.4.5.6.7",
          finding: @liver,
          finding_site: @liver
        )

      assert container.value_type == :container
      assert container.concept_name == Codes.measurement_group()
      assert container.relationship_type == "CONTAINS"
      assert length(container.children) == 4
    end

    test "includes measurements and evaluations" do
      assessment = Code.new("112034", "DCM", "Assessment")
      stable = Code.new("58158008", "SCT", "Stable")

      [container] =
        MeasurementProperties.measurement_group(
          tracking_identifier: "Lesion 1",
          tracking_uid: "1.2.3.4.5",
          measurements: [
            [concept: @diameter, value: 25, units: @mm],
            [concept: @volume, value: 8.2, units: @cm3]
          ],
          evaluations: [{assessment, stable}]
        )

      num_items = Enum.filter(container.children, &(&1.value_type == :num))
      code_items = Enum.filter(container.children, &(&1.value_type == :code))

      assert length(num_items) == 2
      assert length(code_items) == 1
    end

    test "includes time point context" do
      [container] =
        MeasurementProperties.measurement_group(
          tracking_identifier: "Lesion 1",
          tracking_uid: "1.2.3.4",
          time_point: [
            time_point: "Baseline",
            time_point_type: @baseline
          ]
        )

      text_children = Enum.filter(container.children, &(&1.value_type == :text))
      # tracking_identifier + time_point = 2 text items
      assert length(text_children) == 2
    end

    test "empty group" do
      [container] = MeasurementProperties.measurement_group([])
      assert container.value_type == :container
      assert container.children == []
    end
  end

  # -- TID 1502 Time Point Context ------------------------------------------

  describe "time_point_context/1" do
    test "builds basic time point" do
      items =
        MeasurementProperties.time_point_context(
          time_point: "Visit 1",
          time_point_type: @baseline
        )

      assert length(items) == 2

      text_item = Enum.find(items, &(&1.value_type == :text))
      assert text_item.concept_name == Codes.time_point()
      assert text_item.value == "Visit 1"

      code_item = Enum.find(items, &(&1.value_type == :code))
      assert code_item.concept_name == Codes.time_point_type()
    end

    test "includes order and identifiers" do
      items =
        MeasurementProperties.time_point_context(
          time_point: "Follow-up 3",
          time_point_order: 3,
          order_units: @no_units,
          subject_time_point_identifier: "TP-003",
          protocol_time_point_identifier: "WEEK-12"
        )

      assert length(items) == 4
    end

    test "includes temporal offset and event" do
      event = Code.new("276326001", "SCT", "Onset of symptoms")

      items =
        MeasurementProperties.time_point_context(
          temporal_offset_from_event: 90,
          offset_units: @days,
          event: event
        )

      assert length(items) == 2
      num_item = Enum.find(items, &(&1.value_type == :num))
      assert num_item != nil
    end

    test "empty returns empty" do
      assert MeasurementProperties.time_point_context([]) == []
    end
  end
end
