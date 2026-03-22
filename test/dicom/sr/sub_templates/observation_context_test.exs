defmodule Dicom.SR.SubTemplates.ObservationContextTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.SubTemplates.ObservationContext

  # -- TID 1001 Observation Context ----------------------------------------

  describe "observation_context/1" do
    test "returns empty list with no options" do
      assert ObservationContext.observation_context() == []
    end

    test "builds full context with observer, procedure, and subject" do
      items =
        ObservationContext.observation_context(
          observer: [name: "SMITH^JOHN"],
          procedure: [accession_number: "ACC001"],
          subject: [class: :patient, patient: [name: "DOE^JANE"]]
        )

      assert length(items) > 0
      types = Enum.map(items, & &1.value_type)
      assert :code in types
      assert :pname in types
      assert :text in types
    end
  end

  # -- TID 1002 Observer Context -------------------------------------------

  describe "observer_context/1 person" do
    test "basic person observer" do
      items = ObservationContext.observer_context(name: "SMITH^JOHN")
      assert length(items) == 2

      [type_item, name_item] = items
      assert type_item.value_type == :code
      assert name_item.value_type == :pname
    end

    test "person with extended attributes" do
      items =
        ObservationContext.observer_context(
          name: "SMITH^JOHN",
          login_name: "jsmith",
          organization: "General Hospital",
          role_in_organization: Code.new("121024", "DCM", "Radiologist"),
          role_in_procedure: Code.new("121025", "DCM", "Reporting"),
          identifier_within_role: "RAD-42"
        )

      assert length(items) == 6
      value_types = Enum.map(items, & &1.value_type)
      # observer_type + role_in_org + role_in_procedure = 3 codes
      assert Enum.count(value_types, &(&1 == :code)) == 3
      # login_name + organization = 2 texts
      assert Enum.count(value_types, &(&1 == :text)) == 2
      assert Enum.count(value_types, &(&1 == :pname)) == 1
    end

    test "person with role and identifier nesting" do
      items =
        ObservationContext.observer_context(
          name: "DOC^ALICE",
          role_in_procedure: Code.new("121025", "DCM", "Performing"),
          identifier_within_role: "PERF-001"
        )

      role_item = Enum.find(items, &match?(%{value_type: :code, children: [_ | _]}, &1))
      assert role_item != nil
      [child] = role_item.children
      assert child.value_type == :text
      assert child.relationship_type == "HAS CONCEPT MOD"
    end
  end

  describe "observer_context/1 device" do
    test "basic device observer" do
      items = ObservationContext.observer_context(uid: "1.2.3.4.5")
      assert length(items) >= 2

      type_item = List.first(items)
      assert type_item.value_type == :code
    end

    test "device with extended attributes" do
      items =
        ObservationContext.observer_context(
          uid: "1.2.3.4.5",
          name: "Scanner-1",
          manufacturer: "MedCo",
          model_name: "CT-Pro",
          serial_number: "SN123",
          physical_location: "Room 3B",
          role_in_procedure: Code.new("113859", "DCM", "Acquiring"),
          station_ae_title: "CT_SCANNER_1",
          manufacturer_class_uid: "1.2.3.99"
        )

      assert length(items) >= 6
      value_types = Enum.map(items, & &1.value_type)
      assert :uidref in value_types
      assert :text in value_types
      assert :code in value_types
    end
  end

  describe "observer_context/1 fallback" do
    test "returns empty list when neither :name nor :uid is provided" do
      assert ObservationContext.observer_context(some_other_key: "value") == []
    end
  end

  describe "observer_context/1 role without identifier" do
    test "person with role_in_procedure but no identifier_within_role" do
      items =
        ObservationContext.observer_context(
          name: "DOC^BOB",
          role_in_procedure: Code.new("121025", "DCM", "Performing")
        )

      role_item = Enum.find(items, &match?(%{value_type: :code, children: _}, &1))

      assert role_item != nil
      # role_children(nil) returns [], so the role item should have no children
      matching =
        Enum.find(items, fn item ->
          item.value_type == :code and item.children == []
        end)

      assert matching != nil
    end
  end

  # -- TID 1005 Procedure Study Context ------------------------------------

  describe "procedure_context/1" do
    test "empty options returns empty list" do
      assert ObservationContext.procedure_context([]) == []
    end

    test "with accession number" do
      items = ObservationContext.procedure_context(accession_number: "ACC-2026-001")
      assert length(items) == 1
      [item] = items
      assert item.value_type == :text
      assert item.relationship_type == "HAS OBS CONTEXT"
    end

    test "with accession number and issuer" do
      items =
        ObservationContext.procedure_context(
          accession_number: "ACC-001",
          accession_issuer: "GENERAL-HOSPITAL"
        )

      assert length(items) == 1
      [item] = items
      assert item.value_type == :text
      assert length(item.children) == 1
      [issuer] = item.children
      assert issuer.value_type == :text
      assert issuer.relationship_type == "HAS CONCEPT MOD"
    end

    test "with study UIDs and procedure code" do
      items =
        ObservationContext.procedure_context(
          study_instance_uid: "1.2.3.4",
          procedure_code: Code.new("P5-09051", "SRT", "Chest CT")
        )

      assert length(items) == 2
      types = Enum.map(items, & &1.value_type)
      assert :uidref in types
      assert :code in types
    end
  end

  # -- TID 1006 Subject Context --------------------------------------------

  describe "subject_context/1" do
    test "empty options returns empty list" do
      assert ObservationContext.subject_context([]) == []
    end

    test "patient subject with class atom" do
      items =
        ObservationContext.subject_context(
          class: :patient,
          patient: [name: "DOE^JOHN", sex: Code.new("M", "DCM", "Male")]
        )

      assert length(items) >= 2
      class_item = List.first(items)
      assert class_item.value_type == :code
    end

    test "fetus subject" do
      items =
        ObservationContext.subject_context(
          class: :fetus,
          fetus: [fetus_id: "Fetus A", mother_name: "DOE^JANE"]
        )

      assert length(items) >= 2
    end

    test "specimen subject" do
      items =
        ObservationContext.subject_context(
          class: :specimen,
          specimen: [
            identifier: "SPEC-001",
            type: Code.new("119376003", "SCT", "Tissue specimen")
          ]
        )

      assert length(items) >= 2
    end
  end

  # -- TID 1007 Patient Context --------------------------------------------

  describe "patient_context/1" do
    test "full patient context" do
      items =
        ObservationContext.patient_context(
          name: "DOE^JOHN",
          id: "PAT-001",
          birth_date: ~D[1990-05-15],
          sex: Code.new("M", "DCM", "Male"),
          age: 35,
          age_units: Code.new("a", "UCUM", "years")
        )

      # name(pname) + id(text) + birth_date(date) + sex(code) + age(num) = 5
      assert length(items) == 5
      types = Enum.map(items, & &1.value_type)
      assert :pname in types
      assert :text in types
      assert :date in types
      assert :code in types
      assert :num in types
    end

    test "patient context without name (add_pname nil branch)" do
      items =
        ObservationContext.patient_context(
          id: "PAT-002",
          sex: Code.new("F", "DCM", "Female")
        )

      assert length(items) == 2
      refute Enum.any?(items, &(&1.value_type == :pname))
    end

    test "patient context with string birth_date" do
      items =
        ObservationContext.patient_context(
          name: "DOE^JANE",
          birth_date: "19900515"
        )

      assert length(items) == 2
      date_item = Enum.find(items, &(&1.value_type == :date))
      assert date_item != nil
    end
  end

  # -- TID 1008 Fetus Context ----------------------------------------------

  describe "fetus_context/1" do
    test "full fetus context" do
      items =
        ObservationContext.fetus_context(
          mother_name: "DOE^JANE",
          fetus_id: "A",
          number_by_us: 2
        )

      assert length(items) == 3
    end
  end

  # -- TID 1009 Specimen Context -------------------------------------------

  describe "specimen_context/1" do
    test "full specimen context" do
      items =
        ObservationContext.specimen_context(
          uid: "1.2.3.4.5",
          identifier: "SPEC-001",
          issuer: "Lab Corp",
          type: Code.new("119376003", "SCT", "Tissue specimen"),
          container_id: "CONT-A"
        )

      assert length(items) == 5
    end

    test "specimen with nested patient context" do
      items =
        ObservationContext.specimen_context(
          identifier: "SPEC-001",
          patient: [name: "DOE^JOHN"]
        )

      assert length(items) >= 2
      pname = Enum.find(items, &(&1.value_type == :pname))
      assert pname != nil
    end
  end
end
