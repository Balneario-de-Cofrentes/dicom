defmodule Dicom.SR.ContentConstraintTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.{Code, Codes, ContentConstraint, ContentItem, Document, Reference}
  alias Dicom.SR.Constraints.{KeyObjectSelection, MeasurementReport}

  # -- Helpers ----------------------------------------------------------------

  defp code(value, scheme, meaning), do: Code.new(value, scheme, meaning)

  defp uid(suffix), do: "1.2.826.0.1.3680043.10.1137.#{suffix}"

  defp reference(class_suffix \\ "1", instance_suffix \\ "2") do
    Reference.new(uid(class_suffix), uid(instance_suffix))
  end

  defp default_doc_opts do
    [
      study_instance_uid: uid("900"),
      series_instance_uid: uid("901"),
      sop_instance_uid: uid("902")
    ]
  end

  # -- validate/2: single item checks ----------------------------------------

  describe "validate/2 value type check" do
    test "passes when value type matches" do
      item = ContentItem.text(Codes.finding(), "Normal", relationship_type: "CONTAINS")

      constraint = %ContentConstraint{
        concept_name: Codes.finding(),
        value_type: :text,
        relationship_type: "CONTAINS"
      }

      assert :ok = ContentConstraint.validate(item, constraint)
    end

    test "fails when value type mismatches" do
      item = ContentItem.text(Codes.finding(), "Normal", relationship_type: "CONTAINS")

      constraint = %ContentConstraint{
        concept_name: Codes.finding(),
        value_type: :num,
        relationship_type: "CONTAINS"
      }

      assert {:error, violations} = ContentConstraint.validate(item, constraint)
      assert [{:wrong_value_type, opts}] = violations
      assert opts[:expected] == :num
      assert opts[:got] == :text
      assert is_list(opts[:path])
    end
  end

  describe "validate/2 relationship type check" do
    test "passes when relationship type matches" do
      item =
        ContentItem.code(Codes.observer_type(), Codes.person(),
          relationship_type: "HAS OBS CONTEXT"
        )

      constraint = %ContentConstraint{
        concept_name: Codes.observer_type(),
        value_type: :code,
        relationship_type: "HAS OBS CONTEXT"
      }

      assert :ok = ContentConstraint.validate(item, constraint)
    end

    test "fails when relationship type mismatches" do
      item =
        ContentItem.code(Codes.observer_type(), Codes.person(),
          relationship_type: "HAS OBS CONTEXT"
        )

      constraint = %ContentConstraint{
        concept_name: Codes.observer_type(),
        value_type: :code,
        relationship_type: "CONTAINS"
      }

      assert {:error, violations} = ContentConstraint.validate(item, constraint)
      assert [{:wrong_relationship_type, opts}] = violations
      assert opts[:expected] == "CONTAINS"
      assert opts[:got] == "HAS OBS CONTEXT"
    end
  end

  describe "validate/2 nil constraint fields skip checks" do
    test "nil value_type skips value type check" do
      item = ContentItem.text(Codes.finding(), "Normal", relationship_type: "CONTAINS")

      constraint = %ContentConstraint{
        concept_name: Codes.finding(),
        value_type: nil,
        relationship_type: "CONTAINS"
      }

      assert :ok = ContentConstraint.validate(item, constraint)
    end

    test "nil relationship_type skips relationship check" do
      item = ContentItem.text(Codes.finding(), "Normal", relationship_type: "CONTAINS")

      constraint = %ContentConstraint{
        concept_name: Codes.finding(),
        value_type: :text,
        relationship_type: nil
      }

      assert :ok = ContentConstraint.validate(item, constraint)
    end
  end

  # -- validate_tree/2: cardinality -------------------------------------------

  describe "validate_tree/2 missing mandatory" do
    test "fails when mandatory item is absent" do
      children = []

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one
        }
      ]

      assert {:error, violations} = ContentConstraint.validate_tree(children, constraints)
      assert [{:missing_mandatory, "Finding", _path}] = violations
    end

    test "passes with mandatory item present" do
      children = [
        ContentItem.text(Codes.finding(), "Normal", relationship_type: "CONTAINS")
      ]

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one
        }
      ]

      assert :ok = ContentConstraint.validate_tree(children, constraints)
    end
  end

  describe "validate_tree/2 optional items" do
    test "passes when optional item is absent" do
      children = []

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :optional,
          vm: :zero_or_one
        }
      ]

      assert :ok = ContentConstraint.validate_tree(children, constraints)
    end
  end

  describe "validate_tree/2 VM :zero_or_more" do
    test "allows multiple items" do
      children = [
        ContentItem.text(Codes.finding(), "Finding A", relationship_type: "CONTAINS"),
        ContentItem.text(Codes.finding(), "Finding B", relationship_type: "CONTAINS"),
        ContentItem.text(Codes.finding(), "Finding C", relationship_type: "CONTAINS")
      ]

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :optional,
          vm: :zero_or_more
        }
      ]

      assert :ok = ContentConstraint.validate_tree(children, constraints)
    end

    test "allows zero items" do
      children = []

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :optional,
          vm: :zero_or_more
        }
      ]

      assert :ok = ContentConstraint.validate_tree(children, constraints)
    end
  end

  describe "validate_tree/2 VM :one exceeds" do
    test "fails when more than one item for VM :one" do
      children = [
        ContentItem.text(Codes.finding(), "Finding A", relationship_type: "CONTAINS"),
        ContentItem.text(Codes.finding(), "Finding B", relationship_type: "CONTAINS")
      ]

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one
        }
      ]

      assert {:error, violations} = ContentConstraint.validate_tree(children, constraints)
      assert Enum.any?(violations, fn {type, _} -> type == :vm_exceeded end)
    end
  end

  describe "validate_tree/2 VM :zero_or_one exceeds" do
    test "fails when more than one item for VM :zero_or_one" do
      children = [
        ContentItem.text(Codes.finding(), "Finding A", relationship_type: "CONTAINS"),
        ContentItem.text(Codes.finding(), "Finding B", relationship_type: "CONTAINS")
      ]

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :optional,
          vm: :zero_or_one
        }
      ]

      assert {:error, violations} = ContentConstraint.validate_tree(children, constraints)
      assert [{:vm_exceeded, opts}] = violations
      assert opts[:max] == :zero_or_one
      assert opts[:count] == 2
    end
  end

  # -- Nested container validation --------------------------------------------

  describe "validate_tree/2 nested containers" do
    test "validates children of nested containers" do
      inner_child = ContentItem.text(Codes.finding(), "OK", relationship_type: "CONTAINS")

      container =
        ContentItem.container(Codes.imaging_measurements(),
          relationship_type: "CONTAINS",
          children: [inner_child]
        )

      constraints = [
        %ContentConstraint{
          concept_name: Codes.imaging_measurements(),
          value_type: :container,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one,
          children: [
            %ContentConstraint{
              concept_name: Codes.finding(),
              value_type: :text,
              relationship_type: "CONTAINS",
              requirement: :mandatory,
              vm: :one
            }
          ]
        }
      ]

      assert :ok = ContentConstraint.validate_tree([container], constraints)
    end

    test "reports violations in nested containers with path" do
      # Container present but missing required child
      container =
        ContentItem.container(Codes.imaging_measurements(),
          relationship_type: "CONTAINS",
          children: []
        )

      constraints = [
        %ContentConstraint{
          concept_name: Codes.imaging_measurements(),
          value_type: :container,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one,
          children: [
            %ContentConstraint{
              concept_name: Codes.finding(),
              value_type: :text,
              relationship_type: "CONTAINS",
              requirement: :mandatory,
              vm: :one
            }
          ]
        }
      ]

      assert {:error, violations} = ContentConstraint.validate_tree([container], constraints)
      assert [{:missing_mandatory, "Finding", path}] = violations
      assert path == ["Imaging Measurements"]
    end
  end

  # -- CID membership check --------------------------------------------------

  describe "validate/2 CID membership" do
    test "passes when code is in CID" do
      # CID 244 = Laterality
      laterality_code = code("24028007", "SCT", "Right")

      item =
        ContentItem.code(Codes.finding_site(), laterality_code,
          relationship_type: "HAS CONCEPT MOD"
        )

      constraint = %ContentConstraint{
        concept_name: Codes.finding_site(),
        value_type: :code,
        relationship_type: "HAS CONCEPT MOD",
        cid: 244
      }

      assert :ok = ContentConstraint.validate(item, constraint)
    end

    test "warns when code not in non-extensible CID" do
      bogus_code = code("BOGUS999", "FAKE", "Bogus Code")

      item =
        ContentItem.code(Codes.finding_site(), bogus_code, relationship_type: "HAS CONCEPT MOD")

      # Use CID 244 (Laterality) which is known to be non-extensible
      constraint = %ContentConstraint{
        concept_name: Codes.finding_site(),
        value_type: :code,
        relationship_type: "HAS CONCEPT MOD",
        cid: 244
      }

      result = ContentConstraint.validate(item, constraint)

      case Dicom.SR.ContextGroup.validate(bogus_code, 244) do
        {:error, :not_in_cid} ->
          assert {:error, violations} = result
          assert Enum.any?(violations, fn {type, _} -> type == :cid_warning end)

        {:error, :unknown_cid} ->
          # CID not in registry -- no warning produced
          assert :ok = result

        _ ->
          :ok
      end
    end

    test "skips CID check when cid is nil" do
      item =
        ContentItem.code(Codes.finding_site(), code("BOGUS", "FAKE", "Bogus"),
          relationship_type: "HAS CONCEPT MOD"
        )

      constraint = %ContentConstraint{
        concept_name: Codes.finding_site(),
        value_type: :code,
        relationship_type: "HAS CONCEPT MOD",
        cid: nil
      }

      assert :ok = ContentConstraint.validate(item, constraint)
    end

    test "skips CID check for non-code items" do
      item = ContentItem.text(Codes.finding(), "Normal", relationship_type: "CONTAINS")

      constraint = %ContentConstraint{
        concept_name: Codes.finding(),
        value_type: :text,
        relationship_type: "CONTAINS",
        cid: 244
      }

      assert :ok = ContentConstraint.validate(item, constraint)
    end
  end

  # -- Path reporting ---------------------------------------------------------

  describe "path reporting in violations" do
    test "path includes concept name meaning" do
      item = ContentItem.text(Codes.finding(), "Normal", relationship_type: "CONTAINS")

      constraint = %ContentConstraint{
        concept_name: Codes.finding(),
        value_type: :num,
        relationship_type: "CONTAINS"
      }

      assert {:error, [{:wrong_value_type, opts}]} = ContentConstraint.validate(item, constraint)
      assert opts[:path] == ["Finding"]
    end

    test "nested path includes parent concept name" do
      inner = ContentItem.text(Codes.finding(), "OK", relationship_type: "CONTAINS")

      container =
        ContentItem.container(Codes.imaging_measurements(),
          relationship_type: "CONTAINS",
          children: [inner]
        )

      constraints = [
        %ContentConstraint{
          concept_name: Codes.imaging_measurements(),
          value_type: :container,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one,
          children: [
            %ContentConstraint{
              concept_name: Codes.finding(),
              value_type: :num,
              relationship_type: "CONTAINS",
              requirement: :mandatory,
              vm: :one
            }
          ]
        }
      ]

      assert {:error, violations} = ContentConstraint.validate_tree([container], constraints)

      assert Enum.any?(violations, fn
               {:wrong_value_type, opts} ->
                 opts[:path] == ["Imaging Measurements", "Finding"]

               _ ->
                 false
             end)
    end
  end

  # -- Built-in constraint definitions ----------------------------------------

  describe "MeasurementReport constraints" do
    test "returns a non-empty list of constraints" do
      constraints = MeasurementReport.constraints()
      assert is_list(constraints)
      assert length(constraints) > 0
      assert Enum.all?(constraints, &match?(%ContentConstraint{}, &1))
    end

    test "root_concept returns imaging measurement report code" do
      root = MeasurementReport.root_concept()
      assert root.value == "126000"
      assert root.scheme_designator == "DCM"
    end
  end

  describe "KeyObjectSelection constraints" do
    test "returns a non-empty list of constraints" do
      constraints = KeyObjectSelection.constraints()
      assert is_list(constraints)
      assert length(constraints) > 0
      assert Enum.all?(constraints, &match?(%ContentConstraint{}, &1))
    end

    test "root_concept returns key object selection code" do
      root = KeyObjectSelection.root_concept()
      assert root.value == "113000"
      assert root.scheme_designator == "DCM"
    end
  end

  # -- Document.new/2 validate: true integration ------------------------------

  describe "Document.new with validate: true" do
    test "valid KOS document passes validation" do
      ref = reference()

      root_children = [
        ContentItem.code(Codes.observer_type(), Codes.person(),
          relationship_type: "HAS OBS CONTEXT"
        ),
        ContentItem.pname(Codes.person_observer_name(), "Dr. Test",
          relationship_type: "HAS OBS CONTEXT"
        ),
        ContentItem.image(Codes.source(), ref, relationship_type: "CONTAINS")
      ]

      root = ContentItem.container(Codes.key_object_selection(), children: root_children)

      opts =
        default_doc_opts() ++
          [
            template_identifier: "2000",
            sop_class_uid: Dicom.UID.key_object_selection_document_storage(),
            validate: true
          ]

      assert {:ok, %Document{}} = Document.new(root, opts)
    end

    test "KOS document missing mandatory image fails validation" do
      root_children = [
        ContentItem.code(Codes.observer_type(), Codes.person(),
          relationship_type: "HAS OBS CONTEXT"
        ),
        ContentItem.pname(Codes.person_observer_name(), "Dr. Test",
          relationship_type: "HAS OBS CONTEXT"
        )
        # Missing IMAGE reference -- mandatory per TID 2010
      ]

      root = ContentItem.container(Codes.key_object_selection(), children: root_children)

      opts =
        default_doc_opts() ++
          [
            template_identifier: "2000",
            sop_class_uid: Dicom.UID.key_object_selection_document_storage(),
            validate: true
          ]

      assert {:error, violations} = Document.new(root, opts)
      assert is_list(violations)
      assert Enum.any?(violations, fn {type, _, _} -> type == :missing_mandatory end)
    end

    test "validate: false (default) skips validation" do
      # Intentionally malformed tree -- no observer, no images
      root = ContentItem.container(Codes.key_object_selection(), children: [])

      opts =
        default_doc_opts() ++
          [
            template_identifier: "2000",
            sop_class_uid: Dicom.UID.key_object_selection_document_storage()
          ]

      assert {:ok, %Document{}} = Document.new(root, opts)
    end

    test "unknown template identifier skips validation" do
      root = ContentItem.container(Codes.key_object_selection(), children: [])

      opts =
        default_doc_opts() ++
          [
            template_identifier: "9999",
            validate: true
          ]

      assert {:ok, %Document{}} = Document.new(root, opts)
    end

    test "valid measurement report passes validation" do
      procedure = code("77343006", "SCT", "Angiography")

      root_children = [
        ContentItem.code(Codes.observer_type(), Codes.person(),
          relationship_type: "HAS OBS CONTEXT"
        ),
        ContentItem.pname(Codes.person_observer_name(), "Dr. Smith",
          relationship_type: "HAS OBS CONTEXT"
        ),
        ContentItem.code(Codes.procedure_reported(), procedure,
          relationship_type: "HAS CONCEPT MOD"
        ),
        ContentItem.container(Codes.imaging_measurements(),
          relationship_type: "CONTAINS",
          children: []
        )
      ]

      root = ContentItem.container(Codes.imaging_measurement_report(), children: root_children)

      opts =
        default_doc_opts() ++
          [
            template_identifier: "1500",
            validate: true
          ]

      assert {:ok, %Document{}} = Document.new(root, opts)
    end

    test "measurement report missing procedure_reported fails" do
      root_children = [
        ContentItem.code(Codes.observer_type(), Codes.person(),
          relationship_type: "HAS OBS CONTEXT"
        ),
        ContentItem.pname(Codes.person_observer_name(), "Dr. Smith",
          relationship_type: "HAS OBS CONTEXT"
        ),
        # Missing procedure_reported
        ContentItem.container(Codes.imaging_measurements(),
          relationship_type: "CONTAINS",
          children: []
        )
      ]

      root = ContentItem.container(Codes.imaging_measurement_report(), children: root_children)

      opts =
        default_doc_opts() ++
          [
            template_identifier: "1500",
            validate: true
          ]

      assert {:error, violations} = Document.new(root, opts)

      assert Enum.any?(violations, fn {type, meaning, _} ->
               type == :missing_mandatory and meaning == "Procedure reported"
             end)
    end
  end

  # -- Multiple violations in one pass ---------------------------------------

  describe "multiple violations" do
    test "collects all violations from tree" do
      # Wrong value type on first child + missing mandatory second child
      bad_child = ContentItem.text(Codes.finding(), "text", relationship_type: "CONTAINS")

      constraints = [
        %ContentConstraint{
          concept_name: Codes.finding(),
          value_type: :num,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one
        },
        %ContentConstraint{
          concept_name: Codes.impression(),
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one
        }
      ]

      assert {:error, violations} = ContentConstraint.validate_tree([bad_child], constraints)
      types = Enum.map(violations, &elem(&1, 0))
      assert :wrong_value_type in types
      assert :missing_mandatory in types
    end
  end

  # -- Matching by value type when concept_name is nil ------------------------

  describe "concept_name nil matching" do
    test "matches by value_type when concept_name is nil" do
      children = [
        ContentItem.text(code("X", "TEST", "Custom"), "val", relationship_type: "CONTAINS")
      ]

      constraints = [
        %ContentConstraint{
          concept_name: nil,
          value_type: :text,
          relationship_type: "CONTAINS",
          requirement: :mandatory,
          vm: :one_or_more
        }
      ]

      assert :ok = ContentConstraint.validate_tree(children, constraints)
    end
  end
end
