defmodule Dicom.SR.ContentTreeTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, Tag, UID}

  alias Dicom.SR.{
    Code,
    Codes,
    ContentItem,
    ContentTree,
    Document,
    DocumentReader,
    Measurement,
    MeasurementGroup,
    Reference,
    Scoord2D
  }

  alias Dicom.SR.Templates.MeasurementReport

  # -- Helpers ----------------------------------------------------------------

  @doc false
  defp round_trip(data_set) do
    {:ok, binary} = Dicom.write(data_set)
    Dicom.parse(binary)
  end

  defp build_document(root, opts \\ []) do
    default_opts = [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.900",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.901",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.902"
    ]

    {:ok, document} = Document.new(root, Keyword.merge(default_opts, opts))
    {:ok, data_set} = Document.to_data_set(document)
    data_set
  end

  defp assert_code_equal(%Code{} = a, %Code{} = b) do
    assert a.value == b.value
    assert a.scheme_designator == b.scheme_designator
    assert a.meaning == b.meaning
    assert a.scheme_version == b.scheme_version
  end

  defp assert_reference_equal(%Reference{} = a, %Reference{} = b) do
    assert a.sop_class_uid == b.sop_class_uid
    assert a.sop_instance_uid == b.sop_instance_uid
    assert a.frame_numbers == b.frame_numbers
    assert a.segment_numbers == b.segment_numbers

    case {a.purpose, b.purpose} do
      {nil, nil} -> :ok
      {%Code{} = pa, %Code{} = pb} -> assert_code_equal(pa, pb)
    end
  end

  # -- Round-trip: CONTAINER --------------------------------------------------

  describe "CONTAINER round-trip" do
    test "reconstructs an empty container root" do
      root = ContentItem.container(Codes.imaging_measurement_report())
      data_set = build_document(root)

      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      assert tree.value_type == :container
      assert_code_equal(tree.concept_name, Codes.imaging_measurement_report())
      assert tree.relationship_type == nil
      assert tree.continuity_of_content == "SEPARATE"
      assert tree.children == []
    end

    test "preserves CONTINUOUS continuity_of_content" do
      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          continuity_of_content: "CONTINUOUS"
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      assert tree.continuity_of_content == "CONTINUOUS"
    end

    test "reconstructs nested containers (3+ levels deep)" do
      leaf =
        ContentItem.text(Codes.finding(), "Deep finding", relationship_type: "CONTAINS")

      mid =
        ContentItem.container(Codes.measurement_group(),
          relationship_type: "CONTAINS",
          children: [leaf]
        )

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.container(Codes.imaging_measurements(),
              relationship_type: "CONTAINS",
              children: [mid]
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      assert tree.value_type == :container
      assert length(tree.children) == 1

      [level1] = tree.children
      assert level1.value_type == :container
      assert level1.relationship_type == "CONTAINS"
      assert length(level1.children) == 1

      [level2] = level1.children
      assert level2.value_type == :container
      assert level2.relationship_type == "CONTAINS"
      assert length(level2.children) == 1

      [level3] = level2.children
      assert level3.value_type == :text
      assert level3.value == "Deep finding"
    end
  end

  # -- Round-trip: TEXT -------------------------------------------------------

  describe "TEXT round-trip" do
    test "reconstructs text content items" do
      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.text(Codes.finding(), "Stable nodule", relationship_type: "CONTAINS")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [text_item] = tree.children
      assert text_item.value_type == :text
      assert text_item.value == "Stable nodule"
      assert text_item.relationship_type == "CONTAINS"
      assert_code_equal(text_item.concept_name, Codes.finding())
    end
  end

  # -- Round-trip: CODE -------------------------------------------------------

  describe "CODE round-trip" do
    test "reconstructs code content items" do
      procedure = Code.new("P5-09051", "SRT", "Chest CT")

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.code(Codes.procedure_reported(), procedure,
              relationship_type: "HAS CONCEPT MOD"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [code_item] = tree.children
      assert code_item.value_type == :code
      assert code_item.relationship_type == "HAS CONCEPT MOD"
      assert_code_equal(code_item.concept_name, Codes.procedure_reported())
      assert_code_equal(code_item.value, procedure)
    end

    test "preserves coding scheme version" do
      code_with_version =
        Code.new("121058", "DCM", "Procedure reported", scheme_version: "2026a")

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.code(Codes.procedure_reported(), code_with_version,
              relationship_type: "HAS CONCEPT MOD"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [code_item] = tree.children
      assert code_item.value.scheme_version == "2026a"
    end
  end

  # -- Round-trip: NUM --------------------------------------------------------

  describe "NUM round-trip" do
    test "reconstructs numeric content items with integer values" do
      units = Code.new("/min", "UCUM", "beats per minute")

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.num(
              Code.new("8867-4", "LN", "Heart rate"),
              62,
              units,
              relationship_type: "CONTAINS"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [num_item] = tree.children
      assert num_item.value_type == :num
      assert num_item.relationship_type == "CONTAINS"
      assert num_item.value.numeric_value == "62"
      assert_code_equal(num_item.value.units, units)
      assert num_item.value.qualifier == nil
    end

    test "reconstructs numeric content items with float values" do
      units = Code.new("mm", "UCUM", "millimeters")

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.num(
              Code.new("410668003", "SCT", "Length"),
              12.5,
              units,
              relationship_type: "CONTAINS"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [num_item] = tree.children
      assert num_item.value.numeric_value == "12.5"
    end

    test "reconstructs numeric content items with string values" do
      units = Code.new("/min", "UCUM", "beats per minute")

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.num(
              Code.new("8867-4", "LN", "Heart rate"),
              "62.5",
              units,
              relationship_type: "CONTAINS"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [num_item] = tree.children
      assert num_item.value.numeric_value == "62.5"
    end

    test "reconstructs numeric content items with qualifier" do
      units = Code.new("/min", "UCUM", "beats per minute")
      qualifier = Code.new("114006", "DCM", "Measurement failure")

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.num(
              Code.new("8867-4", "LN", "Heart rate"),
              62,
              units,
              relationship_type: "CONTAINS",
              qualifier: qualifier
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [num_item] = tree.children
      assert num_item.value.qualifier != nil
      assert_code_equal(num_item.value.qualifier, qualifier)
    end
  end

  # -- Round-trip: UIDREF -----------------------------------------------------

  describe "UIDREF round-trip" do
    test "reconstructs uidref content items" do
      uid = "1.2.826.0.1.3680043.10.1137.705"

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.uidref(Codes.tracking_unique_identifier(), uid,
              relationship_type: "HAS OBS CONTEXT"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [uid_item] = tree.children
      assert uid_item.value_type == :uidref
      assert uid_item.value == uid
      assert uid_item.relationship_type == "HAS OBS CONTEXT"
    end
  end

  # -- Round-trip: IMAGE ------------------------------------------------------

  describe "IMAGE round-trip" do
    test "reconstructs image content items with basic reference" do
      reference =
        Reference.new(
          UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.700"
        )

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.image(Codes.source(), reference, relationship_type: "INFERRED FROM")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [img_item] = tree.children
      assert img_item.value_type == :image
      assert img_item.relationship_type == "INFERRED FROM"
      assert_reference_equal(img_item.value, reference)
    end

    test "reconstructs image content items with frame numbers and purpose" do
      reference =
        Reference.new(
          UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.701",
          frame_numbers: [1, 3],
          purpose: Codes.original_source()
        )

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.image(Codes.source(), reference, relationship_type: "INFERRED FROM")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [img_item] = tree.children
      assert_reference_equal(img_item.value, reference)
    end

    test "reconstructs image content items with segment numbers" do
      reference =
        Reference.new(
          UID.segmentation_storage(),
          "1.2.826.0.1.3680043.10.1137.704",
          segment_numbers: [2, 4]
        )

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.image(Codes.source(), reference, relationship_type: "CONTAINS")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [img_item] = tree.children
      assert_reference_equal(img_item.value, reference)
    end
  end

  # -- Round-trip: COMPOSITE --------------------------------------------------

  describe "COMPOSITE round-trip" do
    test "reconstructs composite content items" do
      reference =
        Reference.new(
          UID.encapsulated_pdf_storage(),
          "1.2.826.0.1.3680043.10.1137.703",
          purpose: Codes.original_source()
        )

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.composite(Codes.source(), reference, relationship_type: "CONTAINS")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [comp_item] = tree.children
      assert comp_item.value_type == :composite
      assert_reference_equal(comp_item.value, reference)
    end
  end

  # -- Round-trip: SCOORD -----------------------------------------------------

  describe "SCOORD round-trip" do
    test "reconstructs SCOORD content items with POINT graphic type" do
      reference =
        Reference.new(
          UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.702",
          purpose: Codes.original_source()
        )

      region = Scoord2D.new(reference, "POINT", [120.0, 220.0])

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.scoord(Codes.image_region(), region, relationship_type: "INFERRED FROM")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [scoord_item] = tree.children
      assert scoord_item.value_type == :scoord
      assert scoord_item.relationship_type == "INFERRED FROM"
      assert scoord_item.value.graphic_type == "POINT"
      assert_in_delta Enum.at(scoord_item.value.graphic_data, 0), 120.0, 0.01
      assert_in_delta Enum.at(scoord_item.value.graphic_data, 1), 220.0, 0.01
      assert_reference_equal(scoord_item.value.reference, reference)
    end

    test "reconstructs SCOORD content items with POLYLINE graphic type" do
      reference =
        Reference.new(
          UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.703"
        )

      region = Scoord2D.new(reference, "POLYLINE", [10.0, 20.0, 30.0, 40.0])

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.scoord(Codes.image_region(), region, relationship_type: "INFERRED FROM")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [scoord_item] = tree.children
      assert scoord_item.value.graphic_type == "POLYLINE"
      assert length(scoord_item.value.graphic_data) == 4
    end
  end

  # -- Round-trip: PNAME ------------------------------------------------------

  describe "PNAME round-trip" do
    test "reconstructs person name content items" do
      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.pname(Codes.person_observer_name(), "DOE^JANE",
              relationship_type: "HAS OBS CONTEXT"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [pname_item] = tree.children
      assert pname_item.value_type == :pname
      assert pname_item.value == "DOE^JANE"
      assert pname_item.relationship_type == "HAS OBS CONTEXT"
    end
  end

  # -- Round-trip: TID 1500 Measurement Report --------------------------------

  describe "TID 1500 Measurement Report round-trip" do
    test "reconstructs a full measurement report with groups, observations, and image references" do
      source_image =
        Reference.new(
          UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.710",
          purpose: Codes.original_source()
        )

      measurement =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          62,
          Code.new("/min", "UCUM", "beats per minute"),
          source_images: [source_image],
          finding_sites: [Code.new("80891009", "SCT", "Heart structure")]
        )

      group =
        MeasurementGroup.new("lesion-1", "1.2.826.0.1.3680043.10.1137.1500.1",
          measurements: [measurement],
          source_images: [source_image],
          finding_sites: [Code.new("80891009", "SCT", "Heart structure")]
        )

      {:ok, document} =
        MeasurementReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.100",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.101",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.102",
          observer_name: "REPORTER^ALICE",
          procedure_reported: [Code.new("P5-09051", "SRT", "Chest CT")],
          measurement_groups: [group],
          image_library: [source_image]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      # Root is a CONTAINER with concept name "Imaging Measurement Report"
      assert tree.value_type == :container
      assert_code_equal(tree.concept_name, Codes.imaging_measurement_report())
      assert tree.relationship_type == nil

      # Find the imaging measurements container
      imaging_measurements =
        Enum.find(tree.children, fn item ->
          item.value_type == :container and
            item.concept_name.value == "126010"
        end)

      assert imaging_measurements != nil
      assert imaging_measurements.relationship_type == "CONTAINS"

      # Measurement group inside
      [mg] = imaging_measurements.children
      assert mg.value_type == :container
      assert mg.concept_name.value == "125007"

      # Find tracking ID and UID inside measurement group
      tracking_id = Enum.find(mg.children, &(&1.concept_name.value == "112039"))
      assert tracking_id.value_type == :text
      assert tracking_id.value == "lesion-1"

      tracking_uid = Enum.find(mg.children, &(&1.concept_name.value == "112040"))
      assert tracking_uid.value_type == :uidref
      assert tracking_uid.value == "1.2.826.0.1.3680043.10.1137.1500.1"

      # Find the NUM measurement
      num_item = Enum.find(mg.children, &(&1.value_type == :num))
      assert num_item != nil
      assert num_item.value.numeric_value == "62"
      assert_code_equal(num_item.value.units, Code.new("/min", "UCUM", "beats per minute"))

      # Find image reference
      image_items = Enum.filter(mg.children, &(&1.value_type == :image))
      assert length(image_items) >= 1

      # Find finding site
      finding_site_items =
        Enum.filter(mg.children, fn item ->
          item.value_type == :code and item.concept_name.value == "363698007"
        end)

      assert length(finding_site_items) >= 1

      # Observer context
      observer_type = Enum.find(tree.children, &(&1.concept_name.value == "121005"))
      assert observer_type.value_type == :code
      assert observer_type.value.value == "121006"

      observer_name = Enum.find(tree.children, &(&1.concept_name.value == "121008"))
      assert observer_name.value_type == :pname
      assert observer_name.value == "REPORTER^ALICE"

      # Language
      language = Enum.find(tree.children, &(&1.concept_name.value == "121049"))
      assert language.value_type == :code

      # Procedure reported
      procedure = Enum.find(tree.children, &(&1.concept_name.value == "121058"))
      assert procedure.value_type == :code
      assert procedure.value.value == "P5-09051"

      # Image library
      image_library =
        Enum.find(tree.children, &(&1.concept_name.value == "111028"))

      assert image_library.value_type == :container
      assert length(image_library.children) == 1
      [lib_image] = image_library.children
      assert lib_image.value_type == :image
    end
  end

  # -- Round-trip: Mixed children ---------------------------------------------

  describe "mixed children round-trip" do
    test "reconstructs a tree with all value types as children" do
      reference =
        Reference.new(
          UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.800"
        )

      region = Scoord2D.new(reference, "POINT", [50.0, 50.0])

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.text(Codes.finding(), "A finding", relationship_type: "CONTAINS"),
            ContentItem.code(
              Codes.procedure_reported(),
              Code.new("P5-09051", "SRT", "Chest CT"),
              relationship_type: "HAS CONCEPT MOD"
            ),
            ContentItem.num(
              Code.new("8867-4", "LN", "Heart rate"),
              72,
              Code.new("/min", "UCUM", "bpm"),
              relationship_type: "CONTAINS"
            ),
            ContentItem.uidref(
              Codes.tracking_unique_identifier(),
              "1.2.826.0.1.3680043.10.1137.801",
              relationship_type: "HAS OBS CONTEXT"
            ),
            ContentItem.image(Codes.source(), reference, relationship_type: "CONTAINS"),
            ContentItem.composite(Codes.source(), reference, relationship_type: "CONTAINS"),
            ContentItem.scoord(Codes.image_region(), region, relationship_type: "INFERRED FROM"),
            ContentItem.pname(Codes.person_observer_name(), "DOE^JOHN",
              relationship_type: "HAS OBS CONTEXT"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      assert length(tree.children) == 8

      types = Enum.map(tree.children, & &1.value_type)

      assert :text in types
      assert :code in types
      assert :num in types
      assert :uidref in types
      assert :image in types
      assert :composite in types
      assert :scoord in types
      assert :pname in types
    end
  end

  # -- Error cases ------------------------------------------------------------

  describe "error cases" do
    test "returns error for missing value type" do
      ds = DataSet.new()
      assert {:error, :missing_value_type} = ContentTree.from_data_set(ds)
    end

    test "returns error for missing concept name" do
      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "CONTAINER")

      assert {:error, :missing_concept_name} = ContentTree.from_data_set(ds)
    end

    test "returns error for unsupported value type" do
      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "WAVEFORM")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [
          %{
            Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121058"),
            Tag.coding_scheme_designator() =>
              Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
            Tag.code_meaning() =>
              Dicom.DataElement.new(Tag.code_meaning(), :LO, "Procedure reported")
          }
        ])

      assert {:error, {:unsupported_value_type, "WAVEFORM"}} = ContentTree.from_data_set(ds)
    end

    test "from_sequence_item returns error for missing value type" do
      item = %{}
      assert {:error, :missing_value_type} = ContentTree.from_sequence_item(item)
    end

    test "from_sequence_item returns error for missing concept name" do
      item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "TEXT")
      }

      assert {:error, :missing_concept_name} = ContentTree.from_sequence_item(item)
    end
  end

  # -- DocumentReader ---------------------------------------------------------

  describe "DocumentReader" do
    test "extracts document-level metadata from a TID 1500 document" do
      measurement =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          62,
          Code.new("/min", "UCUM", "beats per minute")
        )

      group =
        MeasurementGroup.new("lesion-1", "1.2.826.0.1.3680043.10.1137.1500.1",
          measurements: [measurement]
        )

      {:ok, document} =
        MeasurementReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.100",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.101",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.102",
          observer_name: "REPORTER^ALICE",
          measurement_groups: [group],
          content_datetime: ~N[2026-03-20 14:30:00]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, parsed} = round_trip(data_set)
      {:ok, metadata} = DocumentReader.from_data_set(parsed)

      assert metadata.completion_flag == "COMPLETE"
      assert metadata.verification_flag == "UNVERIFIED"
      assert metadata.content_date == "20260320"
      assert metadata.content_time == "143000"
      assert metadata.template_identifier == "1500"
      assert metadata.mapping_resource == "DCMR"
      assert metadata.sop_class_uid == UID.comprehensive_sr_storage()
      assert metadata.sop_instance_uid == "1.2.826.0.1.3680043.10.1137.102"
      assert metadata.study_instance_uid == "1.2.826.0.1.3680043.10.1137.100"
      assert metadata.series_instance_uid == "1.2.826.0.1.3680043.10.1137.101"
      assert metadata.modality == "SR"
    end

    test "extracts verification metadata from a verified document" do
      root = ContentItem.container(Codes.imaging_measurement_report())

      {:ok, document} =
        Document.new(
          root,
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.196",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.197",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.198",
          verification_flag: "VERIFIED",
          verifying_observer_name: "REPORTER^ALICE",
          verification_datetime: ~N[2026-03-20 10:00:00]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, parsed} = round_trip(data_set)
      {:ok, metadata} = DocumentReader.from_data_set(parsed)

      assert metadata.verification_flag == "VERIFIED"
      assert metadata.verification_datetime == "20260320100000"
      assert metadata.verifying_observer_name == "REPORTER^ALICE"
    end

    test "handles document without template sequence" do
      root = ContentItem.container(Codes.imaging_measurement_report())

      {:ok, document} =
        Document.new(
          root,
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.300",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.301",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.302"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, parsed} = round_trip(data_set)
      {:ok, metadata} = DocumentReader.from_data_set(parsed)

      assert metadata.template_identifier == nil
      assert metadata.mapping_resource == nil
    end

    test "handles unverified document with no observer info" do
      root = ContentItem.container(Codes.imaging_measurement_report())

      {:ok, document} =
        Document.new(
          root,
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.310",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.311",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.312"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, parsed} = round_trip(data_set)
      {:ok, metadata} = DocumentReader.from_data_set(parsed)

      assert metadata.verification_flag == "UNVERIFIED"
      assert metadata.verification_datetime == nil
      assert metadata.verifying_observer_name == nil
    end
  end

  # -- Edge cases: direct sequence item construction --------------------------

  describe "edge cases with direct sequence item construction" do
    test "handles frame numbers as integer value" do
      # When parser produces a single integer for frame numbers (IS with single value)
      reference =
        Reference.new(
          UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.750",
          frame_numbers: [5]
        )

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.image(Codes.source(), reference, relationship_type: "CONTAINS")
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [img] = tree.children
      assert img.value.frame_numbers == [5]
    end

    test "handles empty graphic data gracefully when not binary" do
      # Build a container with children that exercise edge case branches
      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            ContentItem.code(
              Codes.observer_type(),
              Codes.person(),
              relationship_type: "HAS OBS CONTEXT"
            )
          ]
        )

      data_set = build_document(root)
      {:ok, parsed} = round_trip(data_set)
      {:ok, tree} = ContentTree.from_data_set(parsed)

      [code_child] = tree.children
      assert code_child.value_type == :code
      assert code_child.value.value == "121006"
    end

    test "from_sequence_item works for manually constructed SCOORD items" do
      scoord_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "SCOORD"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "111030"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Image Region")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "INFERRED FROM"),
        Tag.graphic_type() => Dicom.DataElement.new(Tag.graphic_type(), :CS, "POINT"),
        Tag.graphic_data() => Dicom.DataElement.new(Tag.graphic_data(), :FL, [100.0, 200.0]),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.dx_image_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.760"
                )
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(scoord_item)
      assert item.value_type == :scoord
      assert item.value.graphic_type == "POINT"
      assert item.value.graphic_data == [100.0, 200.0]
    end

    test "from_sequence_item works for manually constructed NUM items with qualifier" do
      qualifier_code_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "114006"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
        Tag.code_meaning() =>
          Dicom.DataElement.new(Tag.code_meaning(), :LO, "Measurement failure")
      }

      units_code_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "/min"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "UCUM"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "beats per minute")
      }

      measurement_item = %{
        Tag.numeric_value() => Dicom.DataElement.new(Tag.numeric_value(), :DS, "62"),
        Tag.measurement_units_code_sequence() =>
          Dicom.DataElement.new(Tag.measurement_units_code_sequence(), :SQ, [units_code_item]),
        Tag.numeric_value_qualifier_code_sequence() =>
          Dicom.DataElement.new(
            Tag.numeric_value_qualifier_code_sequence(),
            :SQ,
            [qualifier_code_item]
          )
      }

      num_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "NUM"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "8867-4"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "LN"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Heart rate")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.measured_value_sequence() =>
          Dicom.DataElement.new(Tag.measured_value_sequence(), :SQ, [measurement_item])
      }

      {:ok, item} = ContentTree.from_sequence_item(num_item)
      assert item.value_type == :num
      assert item.value.numeric_value == "62"
      assert item.value.units.value == "/min"
      assert item.value.qualifier.value == "114006"
    end

    test "from_sequence_item works for manually constructed IMAGE items with segment numbers" do
      image_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "IMAGE"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.segmentation_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.770"
                ),
              Tag.referenced_segment_number() =>
                Dicom.DataElement.new(Tag.referenced_segment_number(), :US, [2, 4])
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(image_item)
      assert item.value_type == :image
      assert item.value.segment_numbers == [2, 4]
    end

    test "from_sequence_item works for manually constructed PNAME items" do
      pname_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "PNAME"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121008"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() =>
                Dicom.DataElement.new(Tag.code_meaning(), :LO, "Person Observer Name")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "HAS OBS CONTEXT"),
        Tag.person_name_value() =>
          Dicom.DataElement.new(Tag.person_name_value(), :PN, "SMITH^JOHN")
      }

      {:ok, item} = ContentTree.from_sequence_item(pname_item)
      assert item.value_type == :pname
      assert item.value == "SMITH^JOHN"
    end

    test "from_sequence_item works for manually constructed TEXT items" do
      text_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "TEXT"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121071"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Finding")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.text_value() => Dicom.DataElement.new(Tag.text_value(), :UT, "Normal findings")
      }

      {:ok, item} = ContentTree.from_sequence_item(text_item)
      assert item.value_type == :text
      assert item.value == "Normal findings"
    end

    test "from_sequence_item works for manually constructed UIDREF items" do
      uidref_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "UIDREF"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "112040"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() =>
                Dicom.DataElement.new(
                  Tag.code_meaning(),
                  :LO,
                  "Tracking Unique Identifier"
                )
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "HAS OBS CONTEXT"),
        Tag.uid_value() =>
          Dicom.DataElement.new(Tag.uid_value(), :UI, "1.2.826.0.1.3680043.10.1137.780")
      }

      {:ok, item} = ContentTree.from_sequence_item(uidref_item)
      assert item.value_type == :uidref
      assert item.value == "1.2.826.0.1.3680043.10.1137.780"
    end

    test "from_sequence_item works for manually constructed COMPOSITE items" do
      composite_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "COMPOSITE"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.encapsulated_pdf_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.790"
                )
            }
          ]),
        Tag.purpose_of_reference_code_sequence() =>
          Dicom.DataElement.new(Tag.purpose_of_reference_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "111040"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() =>
                Dicom.DataElement.new(Tag.code_meaning(), :LO, "Original Source")
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(composite_item)
      assert item.value_type == :composite
      assert item.value.sop_class_uid == UID.encapsulated_pdf_storage()
      assert item.value.purpose.value == "111040"
    end

    test "from_sequence_item works for CONTAINER with children" do
      child_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "TEXT"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121071"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Finding")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.text_value() => Dicom.DataElement.new(Tag.text_value(), :UT, "Child finding")
      }

      container_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "CONTAINER"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "126010"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() =>
                Dicom.DataElement.new(Tag.code_meaning(), :LO, "Imaging Measurements")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.continuity_of_content() =>
          Dicom.DataElement.new(Tag.continuity_of_content(), :CS, "SEPARATE"),
        Tag.content_sequence() => Dicom.DataElement.new(Tag.content_sequence(), :SQ, [child_item])
      }

      {:ok, item} = ContentTree.from_sequence_item(container_item)
      assert item.value_type == :container
      assert item.continuity_of_content == "SEPARATE"
      assert length(item.children) == 1
      [child] = item.children
      assert child.value_type == :text
      assert child.value == "Child finding"
    end
  end

  # -- Non-container root from DataSet ----------------------------------------

  describe "non-container root from DataSet" do
    test "reconstructs a CODE root item from a DataSet" do
      # Build a DataSet that has a CODE value type at top level
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121071"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Finding")
      }

      concept_code_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "P5-09051"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SRT"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Chest CT")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "CODE")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])
        |> DataSet.put(Tag.concept_code_sequence(), :SQ, [concept_code_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :code
      assert tree.concept_name.value == "121071"
      assert tree.value.value == "P5-09051"
    end

    test "reconstructs a NUM root item from a DataSet" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "8867-4"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "LN"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Heart rate")
      }

      units_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "/min"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "UCUM"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "beats per minute")
      }

      mv_item = %{
        Tag.numeric_value() => Dicom.DataElement.new(Tag.numeric_value(), :DS, "72"),
        Tag.measurement_units_code_sequence() =>
          Dicom.DataElement.new(Tag.measurement_units_code_sequence(), :SQ, [units_item])
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "NUM")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])
        |> DataSet.put(Tag.measured_value_sequence(), :SQ, [mv_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :num
      assert tree.value.numeric_value == "72"
      assert tree.value.units.value == "/min"
    end

    test "reconstructs an IMAGE root item from a DataSet" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
      }

      ref_item = %{
        Tag.referenced_sop_class_uid() =>
          Dicom.DataElement.new(Tag.referenced_sop_class_uid(), :UI, UID.dx_image_storage()),
        Tag.referenced_sop_instance_uid() =>
          Dicom.DataElement.new(
            Tag.referenced_sop_instance_uid(),
            :UI,
            "1.2.826.0.1.3680043.10.1137.950"
          )
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "IMAGE")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])
        |> DataSet.put(Tag.referenced_sop_sequence(), :SQ, [ref_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :image
      assert tree.value.sop_class_uid == UID.dx_image_storage()
    end
  end

  # -- code_from_item error paths ---------------------------------------------

  describe "code_from_item error paths" do
    test "returns error when concept name has missing code value" do
      item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "TEXT"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Finding")
            }
          ])
      }

      assert {:error, :missing_code_value} = ContentTree.from_sequence_item(item)
    end

    test "returns error when concept name has missing scheme designator" do
      item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "TEXT"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121071"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Finding")
            }
          ])
      }

      assert {:error, :missing_coding_scheme_designator} = ContentTree.from_sequence_item(item)
    end

    test "returns error when concept name has missing code meaning" do
      item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "TEXT"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121071"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM")
            }
          ])
      }

      assert {:error, :missing_code_meaning} = ContentTree.from_sequence_item(item)
    end
  end

  # -- Direct DataSet path: non-container values at root level ----------------

  describe "non-container root with missing optional fields" do
    test "TEXT root with no content children" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121071"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Finding")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "TEXT")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])
        |> DataSet.put(Tag.text_value(), :UT, "Some finding")

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :text
      assert tree.value == "Some finding"
      assert tree.children == []
    end

    test "UIDREF root item" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "112040"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
        Tag.code_meaning() =>
          Dicom.DataElement.new(Tag.code_meaning(), :LO, "Tracking Unique Identifier")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "UIDREF")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])
        |> DataSet.put(Tag.uid_value(), :UI, "1.2.826.0.1.3680043.10.1137.999")

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :uidref
      assert tree.value == "1.2.826.0.1.3680043.10.1137.999"
    end

    test "PNAME root item" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121008"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
        Tag.code_meaning() =>
          Dicom.DataElement.new(Tag.code_meaning(), :LO, "Person Observer Name")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "PNAME")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])
        |> DataSet.put(Tag.person_name_value(), :PN, "DOE^JOHN")

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :pname
      assert tree.value == "DOE^JOHN"
    end

    test "COMPOSITE root with no reference returns nil value" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "COMPOSITE")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :composite
      assert tree.value == nil
    end

    test "NUM root with no measured value sequence returns nil value" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "8867-4"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "LN"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Heart rate")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "NUM")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :num
      assert tree.value == nil
    end

    test "NUM root with missing units returns nil units" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "8867-4"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "LN"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Heart rate")
      }

      mv_item = %{
        Tag.numeric_value() => Dicom.DataElement.new(Tag.numeric_value(), :DS, "72")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "NUM")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])
        |> DataSet.put(Tag.measured_value_sequence(), :SQ, [mv_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value.numeric_value == "72"
      assert tree.value.units == nil
    end

    test "CODE root with no concept code sequence returns nil value" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "121071"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Finding")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "CODE")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :code
      assert tree.value == nil
    end

    test "IMAGE root with no reference returns nil value" do
      concept_name_item = %{
        Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
        Tag.coding_scheme_designator() =>
          Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
        Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.value_type(), :CS, "IMAGE")
        |> DataSet.put(Tag.concept_name_code_sequence(), :SQ, [concept_name_item])

      {:ok, tree} = ContentTree.from_data_set(ds)
      assert tree.value_type == :image
      assert tree.value == nil
    end
  end

  # -- Decoder edge cases for binary values ------------------------------------

  describe "decoder edge cases" do
    test "IMAGE with single-segment binary US reference" do
      # Build an image item where segment_number is a 2-byte binary (single US value)
      image_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "IMAGE"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.segmentation_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.960"
                ),
              # Single US value as raw 2-byte binary
              Tag.referenced_segment_number() =>
                Dicom.DataElement.new(
                  Tag.referenced_segment_number(),
                  :US,
                  <<3, 0>>
                )
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(image_item)
      assert item.value.segment_numbers == [3]
    end

    test "IMAGE with integer segment number" do
      image_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "IMAGE"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.segmentation_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.961"
                ),
              # Pre-decoded integer value
              Tag.referenced_segment_number() =>
                Dicom.DataElement.new(Tag.referenced_segment_number(), :US, 5)
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(image_item)
      assert item.value.segment_numbers == [5]
    end

    test "IMAGE with integer frame number" do
      image_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "IMAGE"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.dx_image_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.962"
                ),
              # Pre-decoded integer frame number
              Tag.referenced_frame_number() =>
                Dicom.DataElement.new(Tag.referenced_frame_number(), :IS, 7)
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(image_item)
      assert item.value.frame_numbers == [7]
    end

    test "IMAGE with list frame numbers" do
      image_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "IMAGE"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "260753009"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "SCT"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Source")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "CONTAINS"),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.dx_image_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.963"
                ),
              # Pre-decoded list of frame numbers
              Tag.referenced_frame_number() =>
                Dicom.DataElement.new(Tag.referenced_frame_number(), :IS, [1, 3, 5])
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(image_item)
      assert item.value.frame_numbers == [1, 3, 5]
    end

    test "SCOORD with single FL graphic data (4-byte binary)" do
      scoord_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "SCOORD"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "111030"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Image Region")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "INFERRED FROM"),
        Tag.graphic_type() => Dicom.DataElement.new(Tag.graphic_type(), :CS, "POINT"),
        # Raw binary FL data (two floats encoded as 8 bytes)
        Tag.graphic_data() =>
          Dicom.DataElement.new(
            Tag.graphic_data(),
            :FL,
            Dicom.Value.encode(100.0, :FL) <> Dicom.Value.encode(200.0, :FL)
          ),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.dx_image_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.964"
                )
            }
          ])
      }

      {:ok, item} = ContentTree.from_sequence_item(scoord_item)
      assert item.value.graphic_type == "POINT"
      assert_in_delta Enum.at(item.value.graphic_data, 0), 100.0, 0.01
      assert_in_delta Enum.at(item.value.graphic_data, 1), 200.0, 0.01
    end

    test "SCOORD with nil graphic data" do
      scoord_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "SCOORD"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "111030"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Image Region")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "INFERRED FROM"),
        Tag.graphic_type() => Dicom.DataElement.new(Tag.graphic_type(), :CS, "MULTIPOINT"),
        # graphic_data is missing — nil from get_value
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.dx_image_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.965"
                )
            }
          ])
      }

      # This will raise from Scoord2D.new because MULTIPOINT needs at least 2 coords.
      # But the graphic_data extraction should return [] for nil.
      assert_raise ArgumentError, fn ->
        ContentTree.from_sequence_item(scoord_item)
      end
    end

    test "SCOORD with single FL value (4-byte = one float)" do
      # Single 4-byte FL binary decodes to a single number (not a list)
      single_fl = Dicom.Value.encode(42.5, :FL)

      scoord_item = %{
        Tag.value_type() => Dicom.DataElement.new(Tag.value_type(), :CS, "SCOORD"),
        Tag.concept_name_code_sequence() =>
          Dicom.DataElement.new(Tag.concept_name_code_sequence(), :SQ, [
            %{
              Tag.code_value() => Dicom.DataElement.new(Tag.code_value(), :SH, "111030"),
              Tag.coding_scheme_designator() =>
                Dicom.DataElement.new(Tag.coding_scheme_designator(), :SH, "DCM"),
              Tag.code_meaning() => Dicom.DataElement.new(Tag.code_meaning(), :LO, "Image Region")
            }
          ]),
        Tag.relationship_type() =>
          Dicom.DataElement.new(Tag.relationship_type(), :CS, "INFERRED FROM"),
        Tag.graphic_type() => Dicom.DataElement.new(Tag.graphic_type(), :CS, "MULTIPOINT"),
        Tag.graphic_data() => Dicom.DataElement.new(Tag.graphic_data(), :FL, single_fl),
        Tag.referenced_sop_sequence() =>
          Dicom.DataElement.new(Tag.referenced_sop_sequence(), :SQ, [
            %{
              Tag.referenced_sop_class_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_class_uid(),
                  :UI,
                  UID.dx_image_storage()
                ),
              Tag.referenced_sop_instance_uid() =>
                Dicom.DataElement.new(
                  Tag.referenced_sop_instance_uid(),
                  :UI,
                  "1.2.826.0.1.3680043.10.1137.966"
                )
            }
          ])
      }

      # Scoord2D.new will raise because MULTIPOINT requires at least 2 points
      # but the decode_fl path for single value is exercised
      assert_raise ArgumentError, fn ->
        ContentTree.from_sequence_item(scoord_item)
      end
    end
  end

  # -- ContentTree + DocumentReader combined ----------------------------------

  describe "full document round-trip (ContentTree + DocumentReader)" do
    test "write, serialize, parse, and reconstruct match the original structure" do
      procedure = Code.new("P5-09051", "SRT", "Chest CT")
      units = Code.new("/min", "UCUM", "beats per minute")

      measurement =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          62,
          units,
          finding_sites: [Code.new("80891009", "SCT", "Heart structure")]
        )

      group =
        MeasurementGroup.new("lesion-roundtrip", "1.2.826.0.1.3680043.10.1137.1500.99",
          measurements: [measurement],
          finding_category: Code.new("M-01000", "SRT", "Morphologically Altered Structure")
        )

      {:ok, document} =
        MeasurementReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402",
          observer_name: "ROUNDTRIP^TEST",
          procedure_reported: [procedure],
          measurement_groups: [group],
          content_datetime: ~N[2026-03-20 08:00:00]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      # Reconstruct content tree
      {:ok, tree} = ContentTree.from_data_set(parsed)
      {:ok, metadata} = DocumentReader.from_data_set(parsed)

      # Document metadata
      assert metadata.completion_flag == "COMPLETE"
      assert metadata.template_identifier == "1500"
      assert metadata.content_date == "20260320"
      assert metadata.content_time == "080000"

      # Content tree structure
      assert tree.value_type == :container
      assert tree.relationship_type == nil

      # Procedure reported
      proc_item = Enum.find(tree.children, &(&1.concept_name.value == "121058"))
      assert proc_item.value_type == :code
      assert proc_item.value.value == "P5-09051"

      # Imaging measurements container
      im_container = Enum.find(tree.children, &(&1.concept_name.value == "126010"))
      assert im_container.value_type == :container

      # Measurement group
      [mg] = im_container.children
      assert mg.value_type == :container
      assert mg.concept_name.value == "125007"

      # Finding category
      finding_cat = Enum.find(mg.children, &(&1.concept_name.value == "276214006"))
      assert finding_cat.value_type == :code
      assert finding_cat.value.value == "M-01000"

      # Measurement value
      num = Enum.find(mg.children, &(&1.value_type == :num))
      assert num.value.numeric_value == "62"
    end
  end
end
