defmodule Dicom.SR.SubTemplates.ImagingAgentTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentItem}
  alias Dicom.SR.SubTemplates.ImagingAgent
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

  describe "TID 11002 agent_information/1" do
    test "builds container with agent name" do
      item =
        ImagingAgent.agent_information(agent_name: "Iohexol 350")
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113500"
      assert item[Tag.relationship_type()].value == "CONTAINS"

      codes = children_codes(item)
      assert "113500" in codes
    end

    test "includes concentration and route" do
      item =
        ImagingAgent.agent_information(
          agent_name: "Iohexol 350",
          concentration: {350, Code.new("mg/mL", "UCUM", "mg/mL")},
          route: Codes.intravenous_route()
        )
        |> render()

      codes = children_codes(item)
      assert "113500" in codes
      assert "118555000" in codes
      assert "410675002" in codes
    end

    test "raises when agent_name missing" do
      assert_raise KeyError, fn ->
        ImagingAgent.agent_information([])
      end
    end
  end

  describe "performed_activity/1" do
    test "builds container with dose and volume" do
      item =
        ImagingAgent.performed_activity(
          dose: {100, Codes.milliliter()},
          volume: {120, Codes.milliliter()}
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113521"

      codes = children_codes(item)
      assert "113521" in codes
      assert "113522" in codes
    end

    test "includes timing and injection site" do
      item =
        ImagingAgent.performed_activity(
          dose: {100, Codes.milliliter()},
          start_time: "20260322100000",
          end_time: "20260322100500",
          injection_site: "Left antecubital fossa"
        )
        |> render()

      codes = children_codes(item)
      assert "113521" in codes
      assert "113509" in codes
      assert "113510" in codes
      assert "246513007" in codes
    end

    test "supports code-based injection site" do
      site = Code.new("368209003", "SCT", "Right antecubital fossa")

      item =
        ImagingAgent.performed_activity(
          dose: {50, Codes.milliliter()},
          injection_site: site
        )
        |> render()

      codes = children_codes(item)
      assert "246513007" in codes
    end

    test "returns nil when no options provided" do
      assert ImagingAgent.performed_activity([]) == nil
    end
  end

  describe "planned_activity/1" do
    test "builds container with planned dose and volume" do
      item =
        ImagingAgent.planned_activity(
          dose: {100, Codes.milliliter()},
          volume: {120, Codes.milliliter()}
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "113502"

      codes = children_codes(item)
      assert "113502" in codes
      assert "113503" in codes
    end

    test "includes flow rate" do
      item =
        ImagingAgent.planned_activity(
          dose: {100, Codes.milliliter()},
          flow_rate: {4.0, Code.new("mL/s", "UCUM", "mL/s")}
        )
        |> render()

      codes = children_codes(item)
      assert "424254007" in codes
    end

    test "returns nil when no options provided" do
      assert ImagingAgent.planned_activity([]) == nil
    end
  end

  describe "patient_characteristics/1" do
    test "builds container with weight and kidney function" do
      item =
        ImagingAgent.patient_characteristics(
          patient_weight: {80, Codes.kg()},
          kidney_function: {90, Code.new("mL/min", "UCUM", "mL/min")}
        )
        |> render()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert code_value(item, Tag.concept_name_code_sequence()) == "27113001"
      assert item[Tag.relationship_type()].value == "HAS OBS CONTEXT"

      codes = children_codes(item)
      assert "27113001" in codes
      assert "80274001" in codes
    end

    test "returns nil when no characteristics provided" do
      assert ImagingAgent.patient_characteristics([]) == nil
    end
  end

  describe "TID 11021 adverse_events/1" do
    test "builds text adverse events" do
      items = ImagingAgent.adverse_events(["Mild nausea", "Transient flushing"])

      assert length(items) == 2
      rendered = Enum.map(items, &render/1)
      assert Enum.all?(rendered, &(&1[Tag.value_type()].value == "TEXT"))

      codes =
        Enum.map(rendered, &code_value(&1, Tag.concept_name_code_sequence()))

      assert Enum.all?(codes, &(&1 == "121071"))
    end

    test "builds code adverse events" do
      items =
        ImagingAgent.adverse_events([Code.new("422587007", "SCT", "Nausea")])

      [rendered] = Enum.map(items, &render/1)
      assert rendered[Tag.value_type()].value == "CODE"
    end

    test "returns empty list for empty input" do
      assert ImagingAgent.adverse_events([]) == []
    end
  end

  describe "TID 11005 consumables/1" do
    test "builds text consumable items" do
      items = ImagingAgent.consumables(["Syringe 60mL", "Extension tubing"])

      assert length(items) == 2
      rendered = Enum.map(items, &render/1)
      assert Enum.all?(rendered, &(&1[Tag.value_type()].value == "TEXT"))

      codes =
        Enum.map(rendered, &code_value(&1, Tag.concept_name_code_sequence()))

      assert Enum.all?(codes, &(&1 == "113541"))
    end

    test "returns empty list for empty input" do
      assert ImagingAgent.consumables([]) == []
    end
  end
end
