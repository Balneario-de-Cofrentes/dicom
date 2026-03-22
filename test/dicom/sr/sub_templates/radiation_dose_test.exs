defmodule Dicom.SR.SubTemplates.RadiationDoseTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Codes, ContentItem}
  alias Dicom.SR.SubTemplates.RadiationDose
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

  # -- TID 10012: CT Accumulated Dose Data ------------------------------------

  describe "TID 10012 ct_accumulated_dose/1" do
    test "builds container with total DLP" do
      item =
        RadiationDose.ct_accumulated_dose(total_dlp: 850.0)
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # ct_accumulated_dose_data code: 113811
      assert code_value(item, Tag.concept_name_code_sequence()) == "113811"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      # ct_dose_length_product_total code: 113813
      assert "113813" in codes
    end

    test "builds empty container when no measurements given" do
      item = RadiationDose.ct_accumulated_dose([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113811"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- TID 10013: CT Irradiation Event Data -----------------------------------

  describe "TID 10013 ct_irradiation_event/1" do
    test "builds container with all CT event fields" do
      item =
        RadiationDose.ct_irradiation_event(
          irradiation_event_uid: "1.2.3.4.5",
          ct_acquisition_type: Codes.helical_acquisition(),
          ctdi_vol: 15.2,
          dlp: 350.0,
          scanning_length: 400.0,
          mean_ctdi_vol: 14.8,
          phantom_type: Codes.body_phantom()
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # ct_irradiation_event_data code: 113819
      assert code_value(item, Tag.concept_name_code_sequence()) == "113819"

      codes = children_codes(item)
      # irradiation_event_uid: 113769
      assert "113769" in codes
      # ct_acquisition_type: 113820
      assert "113820" in codes
      # ctdi_vol: 113830
      assert "113830" in codes
      # dlp: 113838
      assert "113838" in codes
      # scanning_length: 113825
      assert "113825" in codes
      # phantom_type: 113835
      assert "113835" in codes
    end

    test "builds container with partial CT event fields" do
      item =
        RadiationDose.ct_irradiation_event(
          ctdi_vol: 12.0,
          dlp: 280.0
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"

      codes = children_codes(item)
      assert "113830" in codes
      assert "113838" in codes
      assert length(codes) == 2
    end

    test "builds empty container when no options given" do
      item = RadiationDose.ct_irradiation_event([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113819"
      refute Map.has_key?(item, Tag.content_sequence())
    end

    test "includes head phantom type" do
      item =
        RadiationDose.ct_irradiation_event(phantom_type: Codes.head_phantom())
        |> render()

      children = item[Tag.content_sequence()].value
      phantom_child = List.first(children)
      # phantom_type concept: 113835
      assert code_value(phantom_child, Tag.concept_name_code_sequence()) == "113835"
      # head_phantom value: 113690
      assert code_value(phantom_child, Tag.concept_code_sequence()) == "113690"
    end
  end

  # -- TID 10002: Accumulated X-Ray Dose Data ---------------------------------

  describe "TID 10002 xray_accumulated_dose/1" do
    test "builds container with all X-ray accumulated fields" do
      item =
        RadiationDose.xray_accumulated_dose(
          total_dap: 25.3,
          fluoro_dap: 18.7,
          acquisition_dap: 6.6,
          total_fluoro_time: 120.0,
          total_number_of_radiographic_frames: 45
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # accumulated_xray_dose code: 113702
      assert code_value(item, Tag.concept_name_code_sequence()) == "113702"

      codes = children_codes(item)
      # dose_area_product: 113725
      assert "113725" in codes
      # fluoro_dose_area_product: 113726
      assert "113726" in codes
      # acquisition_dose_area_product: 113727
      assert "113727" in codes
      # total_fluoro_time: 113730
      assert "113730" in codes
      # total_number_of_radiographic_frames: 113731
      assert "113731" in codes
    end

    test "builds container with partial fields" do
      item =
        RadiationDose.xray_accumulated_dose(total_dap: 10.0, total_fluoro_time: 60.0)
        |> render()

      codes = children_codes(item)
      assert "113725" in codes
      assert "113730" in codes
      assert length(codes) == 2
    end

    test "builds empty container when no measurements given" do
      item = RadiationDose.xray_accumulated_dose([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113702"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- TID 10003: Irradiation Event X-Ray Data --------------------------------

  describe "TID 10003 xray_irradiation_event/1" do
    test "builds container with all X-ray event fields" do
      item =
        RadiationDose.xray_irradiation_event(
          irradiation_event_uid: "1.2.3.4.99",
          datetime_started: "20240115120000",
          dose_rp: 125.0,
          dap: 3.5,
          kvp: 80.0,
          tube_current: 250.0,
          exposure_time: 0.5
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # irradiation_event_xray_data code: 113706
      assert code_value(item, Tag.concept_name_code_sequence()) == "113706"

      codes = children_codes(item)
      # irradiation_event_uid: 113769
      assert "113769" in codes
      # datetime_started: 113809
      assert "113809" in codes
      # dose_rp: 113738
      assert "113738" in codes
      # dose_area_product: 113725
      assert "113725" in codes
      # kvp: 113733
      assert "113733" in codes
      # tube_current: 113734
      assert "113734" in codes
      # exposure_time: 113735
      assert "113735" in codes
    end

    test "builds container with partial X-ray event fields" do
      item =
        RadiationDose.xray_irradiation_event(
          dose_rp: 80.0,
          kvp: 75.0
        )
        |> render()

      codes = children_codes(item)
      assert "113738" in codes
      assert "113733" in codes
      assert length(codes) == 2
    end

    test "builds empty container when no options given" do
      item = RadiationDose.xray_irradiation_event([]) |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113706"
      refute Map.has_key?(item, Tag.content_sequence())
    end

    test "includes datetime as DATETIME value type" do
      item =
        RadiationDose.xray_irradiation_event(datetime_started: "20240115120000")
        |> render()

      [child] = item[Tag.content_sequence()].value
      assert child[Tag.value_type()].value == "DATETIME"
      assert code_value(child, Tag.concept_name_code_sequence()) == "113809"
    end
  end

  # -- Shared Builders --------------------------------------------------------

  describe "irradiation_event_uid/1" do
    test "builds UIDREF content item" do
      uid = "1.2.840.10008.5.1.4.1.1.88.67.1"

      item = RadiationDose.irradiation_event_uid(uid) |> render()

      assert item[Tag.value_type()].value == "UIDREF"
      # irradiation_event_uid code: 113769
      assert code_value(item, Tag.concept_name_code_sequence()) == "113769"
      assert item[Tag.uid_value()].value == uid
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end
  end

  describe "dose_measurement/3" do
    test "builds NUM content item with concept and units" do
      item =
        RadiationDose.dose_measurement(Codes.ctdi_vol(), 15.2, Codes.mgy())
        |> render()

      assert item[Tag.value_type()].value == "NUM"
      # ctdi_vol code: 113830
      assert code_value(item, Tag.concept_name_code_sequence()) == "113830"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      [measured] = item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "mGy"
    end

    test "builds NUM for dose area product in Gy.m2" do
      item =
        RadiationDose.dose_measurement(Codes.dose_area_product(), 3.5, Codes.gy_cm2())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "113725"

      [measured] = item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "Gy.m2"
    end

    test "builds NUM for DLP in mGy.cm" do
      item =
        RadiationDose.dose_measurement(Codes.dlp(), 500.0, Codes.mgy_cm())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "113838"

      [measured] = item[Tag.measured_value_sequence()].value
      [unit_item] = measured[Tag.measurement_units_code_sequence()].value
      assert unit_item[Tag.code_value()].value == "mGy.cm"
    end

    test "accepts integer values" do
      item =
        RadiationDose.dose_measurement(
          Codes.total_number_of_radiographic_frames(),
          45,
          Codes.pulses()
        )
        |> render()

      assert item[Tag.value_type()].value == "NUM"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113731"
    end
  end
end
