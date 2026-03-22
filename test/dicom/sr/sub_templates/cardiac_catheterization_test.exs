defmodule Dicom.SR.SubTemplates.CardiacCatheterizationTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem}
  alias Dicom.SR.SubTemplates.CardiacCatheterization
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

  # -- procedure_section/1 ----------------------------------------------------

  describe "procedure_section/1" do
    test "builds container with current procedure descriptions concept" do
      item =
        CardiacCatheterization.procedure_section()
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # Codes.current_procedure_descriptions() => "121064"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121064"
      assert item[Tag.relationship_type()].value == "CONTAINS"
    end

    test "includes access site as code" do
      item =
        CardiacCatheterization.procedure_section(access_site: Codes.femoral_artery())
        |> render()

      codes = children_codes(item)
      # Codes.access_site() => "111027"
      assert "111027" in codes
    end

    test "includes access site as text" do
      item =
        CardiacCatheterization.procedure_section(access_site: "Right radial artery")
        |> render()

      [child] = item[Tag.content_sequence()].value
      assert code_value(child, Tag.concept_name_code_sequence()) == "111027"
      assert child[Tag.value_type()].value == "TEXT"
    end

    test "includes catheters" do
      item =
        CardiacCatheterization.procedure_section(catheters: ["JL4", "JR4"])
        |> render()

      codes = children_codes(item)
      # Codes.catheter_type() => "111026"
      assert Enum.count(codes, &(&1 == "111026")) == 2
    end

    test "includes PCI sub-container" do
      item =
        CardiacCatheterization.procedure_section(pci: [stent_placed: "Drug-eluting stent"])
        |> render()

      codes = children_codes(item)
      # Codes.pci_procedure() => "122152"
      assert "122152" in codes
    end

    test "builds full procedure section" do
      item =
        CardiacCatheterization.procedure_section(
          access_site: Codes.femoral_artery(),
          catheters: ["JL4"],
          pci: [
            stent_placed: "DES",
            vessel: Codes.left_anterior_descending_artery()
          ]
        )
        |> render()

      codes = children_codes(item)
      assert "111027" in codes
      assert "111026" in codes
      assert "122152" in codes
    end

    test "empty options yields empty container" do
      item =
        CardiacCatheterization.procedure_section()
        |> render()

      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- pci_procedure/1 --------------------------------------------------------

  describe "pci_procedure/1" do
    test "builds PCI container" do
      item =
        CardiacCatheterization.pci_procedure()
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # Codes.pci_procedure() => "122152"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122152"
    end

    test "includes stent as code" do
      stent_code = Code.new("122154", "DCM", "Drug-eluting stent")

      item =
        CardiacCatheterization.pci_procedure(stent_placed: stent_code)
        |> render()

      codes = children_codes(item)
      # Codes.stent_placed() => "122154"
      assert "122154" in codes
    end

    test "includes stent as text" do
      item =
        CardiacCatheterization.pci_procedure(stent_placed: "Bare metal stent")
        |> render()

      [child] = item[Tag.content_sequence()].value
      assert code_value(child, Tag.concept_name_code_sequence()) == "122154"
      assert child[Tag.value_type()].value == "TEXT"
    end

    test "includes vessel as concept modifier" do
      item =
        CardiacCatheterization.pci_procedure(vessel: Codes.left_anterior_descending_artery())
        |> render()

      [child] = item[Tag.content_sequence()].value
      # Codes.finding_site() => "363698007"
      assert code_value(child, Tag.concept_name_code_sequence()) == "363698007"
      assert child[Tag.relationship_type()].value == "HAS CONCEPT MOD"
    end

    test "empty PCI yields empty container" do
      item =
        CardiacCatheterization.pci_procedure()
        |> render()

      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- lv_findings/1 ----------------------------------------------------------

  describe "lv_findings/1" do
    test "builds LV findings container" do
      item =
        CardiacCatheterization.lv_findings()
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # Codes.lv_findings() => "122157"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122157"
    end

    test "includes ejection fraction" do
      item =
        CardiacCatheterization.lv_findings(ef: 55)
        |> render()

      codes = children_codes(item)
      # Codes.lv_ejection_fraction() => "10230-1"
      assert "10230-1" in codes
    end

    test "includes LVEDP" do
      item =
        CardiacCatheterization.lv_findings(lvedp: 12)
        |> render()

      codes = children_codes(item)
      # Codes.lv_end_diastolic_pressure() => "8440-2"
      assert "8440-2" in codes
    end

    test "includes wall motion as code" do
      wm_code = Code.new("F-32040", "SRT", "Wall motion abnormality")

      item =
        CardiacCatheterization.lv_findings(wall_motion: wm_code)
        |> render()

      codes = children_codes(item)
      # Codes.wall_motion_abnormality() => "F-32040"
      assert "F-32040" in codes
    end

    test "includes wall motion as text" do
      item =
        CardiacCatheterization.lv_findings(wall_motion: "Apical hypokinesis")
        |> render()

      [child] = item[Tag.content_sequence()].value
      assert code_value(child, Tag.concept_name_code_sequence()) == "F-32040"
      assert child[Tag.value_type()].value == "TEXT"
    end

    test "builds full LV findings" do
      item =
        CardiacCatheterization.lv_findings(
          ef: 60,
          lvedp: 15,
          wall_motion: "Normal"
        )
        |> render()

      codes = children_codes(item)
      assert "10230-1" in codes
      assert "8440-2" in codes
      assert "F-32040" in codes
    end

    test "empty options yields empty container" do
      item =
        CardiacCatheterization.lv_findings()
        |> render()

      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- coronary_findings/1 ----------------------------------------------------

  describe "coronary_findings/1" do
    test "builds coronary findings container" do
      item =
        CardiacCatheterization.coronary_findings()
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # Codes.coronary_findings() => "122153"
      assert code_value(item, Tag.concept_name_code_sequence()) == "122153"
    end

    test "includes vessel findings" do
      item =
        CardiacCatheterization.coronary_findings(
          vessels: [
            [vessel: Codes.left_anterior_descending_artery(), stenosis: 70],
            [vessel: Codes.right_coronary_artery(), stenosis: 50]
          ]
        )
        |> render()

      codes = children_codes(item)
      # Codes.left_anterior_descending_artery() => "53655008"
      assert "53655008" in codes
      # Codes.right_coronary_artery() => "12800006"
      assert "12800006" in codes
    end

    test "empty vessels yields empty container" do
      item =
        CardiacCatheterization.coronary_findings()
        |> render()

      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- vessel_finding/1 -------------------------------------------------------

  describe "vessel_finding/1" do
    test "builds vessel container using vessel code as concept" do
      item =
        CardiacCatheterization.vessel_finding(vessel: Codes.left_main_coronary_artery())
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      # Codes.left_main_coronary_artery() => "6685003"
      assert code_value(item, Tag.concept_name_code_sequence()) == "6685003"
    end

    test "includes stenosis measurement" do
      item =
        CardiacCatheterization.vessel_finding(
          vessel: Codes.left_anterior_descending_artery(),
          stenosis: 80
        )
        |> render()

      codes = children_codes(item)
      # Codes.coronary_stenosis() => "36228007"
      assert "36228007" in codes
    end

    test "includes TIMI flow as text" do
      item =
        CardiacCatheterization.vessel_finding(
          vessel: Codes.right_coronary_artery(),
          timi_flow: "TIMI 3"
        )
        |> render()

      [child] = item[Tag.content_sequence()].value
      # Codes.timi_flow_grade() => "122155"
      assert code_value(child, Tag.concept_name_code_sequence()) == "122155"
      assert child[Tag.value_type()].value == "TEXT"
    end

    test "includes TIMI flow as code" do
      timi_code = Code.new("122155", "DCM", "TIMI 3")

      item =
        CardiacCatheterization.vessel_finding(
          vessel: Codes.left_circumflex_artery(),
          timi_flow: timi_code
        )
        |> render()

      codes = children_codes(item)
      assert "122155" in codes
    end

    test "builds full vessel finding with stenosis and TIMI flow" do
      item =
        CardiacCatheterization.vessel_finding(
          vessel: Codes.left_anterior_descending_artery(),
          stenosis: 90,
          timi_flow: "TIMI 2"
        )
        |> render()

      codes = children_codes(item)
      assert "36228007" in codes
      assert "122155" in codes
    end

    test "raises when vessel is missing" do
      assert_raise KeyError, fn ->
        CardiacCatheterization.vessel_finding(stenosis: 50)
      end
    end

    test "empty options yields vessel-only container" do
      item =
        CardiacCatheterization.vessel_finding(vessel: Codes.right_coronary_artery())
        |> render()

      assert code_value(item, Tag.concept_name_code_sequence()) == "12800006"
      refute Map.has_key?(item, Tag.content_sequence())
    end
  end

  # -- adverse_outcomes/1 -----------------------------------------------------

  describe "adverse_outcomes/1" do
    test "returns empty list when no outcomes" do
      assert CardiacCatheterization.adverse_outcomes() == []
    end

    test "wraps code outcomes as finding items" do
      complication = Code.new("439127006", "SCT", "Thrombosis")

      [item] =
        CardiacCatheterization.adverse_outcomes(outcomes: [complication])
        |> Enum.map(&render/1)

      # Codes.finding() => "121071"
      assert code_value(item, Tag.concept_name_code_sequence()) == "121071"
      assert item[Tag.value_type()].value == "CODE"
    end

    test "wraps text outcomes as finding items" do
      [item] =
        CardiacCatheterization.adverse_outcomes(outcomes: ["Minor hematoma at access site"])
        |> Enum.map(&render/1)

      assert code_value(item, Tag.concept_name_code_sequence()) == "121071"
      assert item[Tag.value_type()].value == "TEXT"
    end

    test "handles mixed code and text outcomes" do
      complication = Code.new("439127006", "SCT", "Thrombosis")

      items =
        CardiacCatheterization.adverse_outcomes(outcomes: [complication, "Contrast reaction"])

      assert length(items) == 2
    end
  end
end
