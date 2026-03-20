defmodule Dicom.SRTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, Tag}

  alias Dicom.SR.{
    Code,
    Codes,
    ContentItem,
    Document,
    Measurement,
    MeasurementGroup,
    Observer,
    Reference,
    Scoord2D,
    Scoord3D
  }

  alias Dicom.SR.Templates.{ECGReport, MeasurementReport, StressTestingReport}

  describe "Code" do
    test "encodes a coded entry as a code sequence item" do
      code = Code.new("121058", "DCM", "Procedure reported", scheme_version: "2026a")
      item = Code.to_item(code)

      assert item[Tag.code_value()].value == "121058"
      assert item[Tag.coding_scheme_designator()].value == "DCM"
      assert item[Tag.code_meaning()].value == "Procedure reported"
      assert item[Tag.coding_scheme_version()].value == "2026a"
    end

    test "rejects blank coded entry fields" do
      assert_raise ArgumentError, ~r/value/, fn ->
        Code.new("   ", "DCM", "Procedure reported")
      end

      assert_raise ArgumentError, ~r/scheme_designator/, fn ->
        Code.new("121058", "   ", "Procedure reported")
      end

      assert_raise ArgumentError, ~r/meaning/, fn ->
        Code.new("121058", "DCM", "   ")
      end
    end
  end

  describe "Reference" do
    test "validates UID inputs and numeric lists" do
      assert_raise ArgumentError, ~r/valid UID/, fn ->
        Reference.new("not-a-uid", "1.2.826.0.1.3680043.10.1137.800")
      end

      assert_raise ArgumentError, ~r/frame_numbers/, fn ->
        Reference.new(
          Dicom.UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.801",
          frame_numbers: [0]
        )
      end
    end

    test "accepts segment numbers and rejects non-list inputs" do
      reference =
        Reference.new(
          Dicom.UID.segmentation_storage(),
          "1.2.826.0.1.3680043.10.1137.805",
          segment_numbers: [1, 2]
        )

      assert reference.segment_numbers == [1, 2]

      assert_raise ArgumentError, ~r/segment_numbers to be a list/, fn ->
        Reference.new(
          Dicom.UID.segmentation_storage(),
          "1.2.826.0.1.3680043.10.1137.806",
          segment_numbers: 1
        )
      end
    end
  end

  describe "Scoord2D" do
    test "validates supported graphic types and point counts" do
      reference =
        Reference.new(Dicom.UID.dx_image_storage(), "1.2.826.0.1.3680043.10.1137.802")

      assert_raise ArgumentError, ~r/unsupported SCOORD graphic_type/, fn ->
        Scoord2D.new(reference, "RECTANGLE", [1.0, 2.0, 3.0, 4.0])
      end

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord2D.new(reference, "POINT", [1.0, 2.0, 3.0])
      end
    end

    test "normalizes case and supports remaining graphic types" do
      reference =
        Reference.new(Dicom.UID.dx_image_storage(), "1.2.826.0.1.3680043.10.1137.803")

      assert %Scoord2D{graphic_type: "MULTIPOINT"} =
               Scoord2D.new(reference, "multipoint", [1.0, 2.0, 3.0, 4.0])

      assert %Scoord2D{graphic_type: "CIRCLE"} =
               Scoord2D.new(reference, "circle", [1.0, 2.0, 3.0, 4.0])

      assert %Scoord2D{graphic_type: "ELLIPSE"} =
               Scoord2D.new(reference, "ellipse", [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])

      assert_raise ArgumentError, ~r/contain only numbers/, fn ->
        Scoord2D.new(reference, "POINT", [1.0, "bad"])
      end
    end
  end

  describe "Scoord3D" do
    @frame_of_ref_uid "1.2.826.0.1.3680043.10.1137.900"

    test "validates supported graphic types and coordinate counts" do
      assert_raise ArgumentError, ~r/unsupported SCOORD3D graphic_type/, fn ->
        Scoord3D.new("RECTANGLE", [1.0, 2.0, 3.0], @frame_of_ref_uid)
      end

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord3D.new("POINT", [1.0, 2.0], @frame_of_ref_uid)
      end

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord3D.new("POINT", [1.0, 2.0, 3.0, 4.0], @frame_of_ref_uid)
      end
    end

    test "creates POINT with exactly 3 values" do
      scoord = Scoord3D.new("POINT", [1.0, 2.0, 3.0], @frame_of_ref_uid)
      assert scoord.graphic_type == "POINT"
      assert scoord.graphic_data == [1.0, 2.0, 3.0]
      assert scoord.frame_of_reference_uid == @frame_of_ref_uid
    end

    test "creates MULTIPOINT with divisible-by-3, minimum 3 values" do
      scoord = Scoord3D.new("MULTIPOINT", [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], @frame_of_ref_uid)
      assert scoord.graphic_type == "MULTIPOINT"
      assert length(scoord.graphic_data) == 6

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord3D.new("MULTIPOINT", [1.0, 2.0], @frame_of_ref_uid)
      end
    end

    test "creates POLYLINE with divisible-by-3, minimum 6 values" do
      scoord = Scoord3D.new("POLYLINE", [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], @frame_of_ref_uid)
      assert scoord.graphic_type == "POLYLINE"

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord3D.new("POLYLINE", [1.0, 2.0, 3.0], @frame_of_ref_uid)
      end
    end

    test "creates POLYGON with divisible-by-3, minimum 9 values" do
      data = Enum.map(1..9, &(&1 * 1.0))
      scoord = Scoord3D.new("POLYGON", data, @frame_of_ref_uid)
      assert scoord.graphic_type == "POLYGON"

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord3D.new("POLYGON", Enum.map(1..6, &(&1 * 1.0)), @frame_of_ref_uid)
      end
    end

    test "creates ELLIPSE with exactly 12 values" do
      data = Enum.map(1..12, &(&1 * 1.0))
      scoord = Scoord3D.new("ELLIPSE", data, @frame_of_ref_uid)
      assert scoord.graphic_type == "ELLIPSE"

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord3D.new("ELLIPSE", Enum.map(1..9, &(&1 * 1.0)), @frame_of_ref_uid)
      end
    end

    test "creates ELLIPSOID with exactly 18 values" do
      data = Enum.map(1..18, &(&1 * 1.0))
      scoord = Scoord3D.new("ELLIPSOID", data, @frame_of_ref_uid)
      assert scoord.graphic_type == "ELLIPSOID"

      assert_raise ArgumentError, ~r/invalid graphic_data/, fn ->
        Scoord3D.new("ELLIPSOID", Enum.map(1..12, &(&1 * 1.0)), @frame_of_ref_uid)
      end
    end

    test "normalizes case" do
      scoord = Scoord3D.new("point", [1.0, 2.0, 3.0], @frame_of_ref_uid)
      assert scoord.graphic_type == "POINT"
    end

    test "rejects non-numeric graphic_data" do
      assert_raise ArgumentError, ~r/contain only numbers/, fn ->
        Scoord3D.new("POINT", [1.0, "bad", 3.0], @frame_of_ref_uid)
      end
    end
  end

  describe "ContentItem" do
    test "default wrappers require relationship_type and preserve binary numeric values" do
      code = Code.new("121058", "DCM", "Procedure reported")
      reference = Reference.new(Dicom.UID.dx_image_storage(), "1.2.826.0.1.3680043.10.1137.707")
      region = Scoord2D.new(reference, "POINT", [1.0, 2.0])

      assert_raise KeyError, fn -> ContentItem.code(Codes.finding(), code) end
      assert_raise KeyError, fn -> ContentItem.text(Codes.finding(), "missing relationship") end

      assert_raise KeyError, fn ->
        ContentItem.num(Codes.finding(), 1, Code.new("1", "UCUM", "one"))
      end

      assert_raise KeyError, fn ->
        ContentItem.uidref(Codes.tracking_unique_identifier(), "1.2.826.0.1.3680043.10.1137.708")
      end

      assert_raise KeyError, fn -> ContentItem.image(Codes.source(), reference) end
      assert_raise KeyError, fn -> ContentItem.composite(Codes.source(), reference) end
      assert_raise KeyError, fn -> ContentItem.scoord(Codes.image_region(), region) end
      assert_raise KeyError, fn -> ContentItem.pname(Codes.person_observer_name(), "DOE^JOHN") end

      numeric_item =
        ContentItem.num(
          Code.new("8867-4", "LN", "Heart rate"),
          "62.5",
          Code.new("/min", "UCUM", "beats per minute"),
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      [measured_value] = numeric_item[Tag.measured_value_sequence()].value
      assert measured_value[Tag.numeric_value()].value == "62.5"
    end

    test "renders a rooted container with nested children" do
      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          children: [
            Observer.language(Code.new("en-US", "RFC5646", "English (United States)")),
            ContentItem.code(Codes.procedure_reported(), Code.new("P5-09051", "SRT", "Chest CT"),
              relationship_type: "HAS CONCEPT MOD"
            ),
            ContentItem.text(Codes.finding(), "Stable nodule", relationship_type: "CONTAINS")
          ]
        )

      item = ContentItem.to_root_elements(root)
      [language, procedure, finding] = item[Tag.content_sequence()].value

      assert item[Tag.value_type()].value == "CONTAINER"
      assert item[Tag.continuity_of_content()].value == "SEPARATE"
      assert code_value(item, Tag.concept_name_code_sequence()) == "126000"

      assert language[Tag.relationship_type()].value == "HAS CONCEPT MOD"
      assert procedure[Tag.relationship_type()].value == "HAS CONCEPT MOD"
      assert finding[Tag.relationship_type()].value == "CONTAINS"
      assert finding[Tag.text_value()].value == "Stable nodule"
    end

    test "renders image references with referenced SOP information and purpose" do
      reference =
        Reference.new(
          Dicom.UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.700",
          frame_numbers: [1, 3],
          purpose: Codes.original_source()
        )

      item =
        ContentItem.image(Codes.source(), reference, relationship_type: "INFERRED FROM")
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "IMAGE"
      assert item[Tag.relationship_type()].value == "INFERRED FROM"
      assert code_value(item, Tag.concept_name_code_sequence()) == "260753009"
      assert code_value(item, Tag.purpose_of_reference_code_sequence()) == "111040"

      [sop_ref] = item[Tag.referenced_sop_sequence()].value
      assert sop_ref[Tag.referenced_sop_class_uid()].value == Dicom.UID.dx_image_storage()
      assert sop_ref[Tag.referenced_sop_instance_uid()].value == "1.2.826.0.1.3680043.10.1137.700"
      assert sop_ref[Tag.referenced_frame_number()].value == "1\\3"
    end

    test "renders SCOORD references with graphic data and referenced SOP information" do
      reference =
        Reference.new(
          Dicom.UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.701",
          purpose: Codes.original_source()
        )

      region =
        Scoord2D.new(reference, "POLYLINE", [10.0, 20.0, 30.0, 40.0])

      item =
        ContentItem.scoord(Codes.image_region(), region, relationship_type: "INFERRED FROM")
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "SCOORD"
      assert item[Tag.graphic_type()].value == "POLYLINE"
      assert item[Tag.graphic_data()].value == [10.0, 20.0, 30.0, 40.0]
      assert code_value(item, Tag.purpose_of_reference_code_sequence()) == "111040"

      [sop_ref] = item[Tag.referenced_sop_sequence()].value
      assert sop_ref[Tag.referenced_sop_instance_uid()].value == "1.2.826.0.1.3680043.10.1137.701"
    end

    test "renders SCOORD3D references with graphic data and frame of reference UID" do
      frame_of_ref_uid = "1.2.826.0.1.3680043.10.1137.850"

      region =
        Scoord3D.new("POINT", [10.0, 20.0, 30.0], frame_of_ref_uid)

      item =
        ContentItem.scoord3d(
          Code.new("111030", "DCM", "Image Region"),
          region,
          relationship_type: "INFERRED FROM"
        )
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "SCOORD3D"
      assert item[Tag.graphic_type()].value == "POINT"
      assert item[Tag.graphic_data()].value == [10.0, 20.0, 30.0]
      assert item[Tag.graphic_data()].vr == :FD
      assert item[Tag.referenced_frame_of_reference_uid()].value == frame_of_ref_uid
      refute Map.has_key?(item, Tag.referenced_sop_sequence())
    end

    test "renders DATE content items" do
      item =
        ContentItem.date(
          Code.new("82688-0", "LN", "Date of measurement"),
          ~D[2026-03-20],
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "DATE"
      assert item[Tag.sr_date()].value == "20260320"
      assert item[Tag.sr_date()].vr == :DA
    end

    test "renders DATE content items from string" do
      item =
        ContentItem.date(
          Code.new("82688-0", "LN", "Date of measurement"),
          "20260320",
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      assert item[Tag.sr_date()].value == "20260320"
    end

    test "renders TIME content items" do
      item =
        ContentItem.time(
          Code.new("82689-8", "LN", "Time of measurement"),
          ~T[14:30:22],
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "TIME"
      assert item[Tag.sr_time()].value == "143022"
      assert item[Tag.sr_time()].vr == :TM
    end

    test "renders TIME content items from string" do
      item =
        ContentItem.time(
          Code.new("82689-8", "LN", "Time of measurement"),
          "143022.500",
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      assert item[Tag.sr_time()].value == "143022.500"
    end

    test "renders DATETIME content items from NaiveDateTime" do
      item =
        ContentItem.datetime(
          Code.new("82690-6", "LN", "DateTime of measurement"),
          ~N[2026-03-20 14:30:22],
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "DATETIME"
      assert item[Tag.sr_datetime()].value == "20260320143022"
      assert item[Tag.sr_datetime()].vr == :DT
    end

    test "renders DATETIME content items from DateTime with timezone" do
      dt = DateTime.from_naive!(~N[2026-03-20 14:30:22], "Etc/UTC")

      item =
        ContentItem.datetime(
          Code.new("82690-6", "LN", "DateTime of measurement"),
          dt,
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      assert item[Tag.sr_datetime()].value == "20260320143022+0000"
    end

    test "renders DATETIME content items from string" do
      item =
        ContentItem.datetime(
          Code.new("82690-6", "LN", "DateTime of measurement"),
          "20260320143022",
          relationship_type: "CONTAINS"
        )
        |> ContentItem.to_item()

      assert item[Tag.sr_datetime()].value == "20260320143022"
    end

    test "scoord3d, date, time, and datetime require relationship_type" do
      scoord3d = Scoord3D.new("POINT", [1.0, 2.0, 3.0], "1.2.826.0.1.3680043.10.1137.851")
      concept = Code.new("111030", "DCM", "Image Region")
      date_concept = Code.new("82688-0", "LN", "Date")

      assert_raise KeyError, fn -> ContentItem.scoord3d(concept, scoord3d) end
      assert_raise KeyError, fn -> ContentItem.date(date_concept, ~D[2026-03-20]) end
      assert_raise KeyError, fn -> ContentItem.time(date_concept, ~T[14:30:00]) end

      assert_raise KeyError, fn ->
        ContentItem.datetime(date_concept, ~N[2026-03-20 14:30:00])
      end
    end

    test "renders composite references" do
      reference =
        Reference.new(
          Dicom.UID.encapsulated_pdf_storage(),
          "1.2.826.0.1.3680043.10.1137.703",
          purpose: Codes.original_source()
        )

      item =
        ContentItem.composite(Codes.source(), reference, relationship_type: "CONTAINS")
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "COMPOSITE"
      assert code_value(item, Tag.purpose_of_reference_code_sequence()) == "111040"
    end

    test "renders uidref, pname, numeric qualifiers, segment references, and root continuity overrides" do
      segment_reference =
        Reference.new(
          Dicom.UID.segmentation_storage(),
          "1.2.826.0.1.3680043.10.1137.704",
          segment_numbers: [2, 4]
        )

      uid_item =
        ContentItem.uidref(Codes.tracking_unique_identifier(), "1.2.826.0.1.3680043.10.1137.705",
          relationship_type: "HAS OBS CONTEXT"
        )
        |> ContentItem.to_item()

      pname_item =
        ContentItem.pname(Codes.person_observer_name(), "DOE^JANE",
          relationship_type: "HAS OBS CONTEXT"
        )
        |> ContentItem.to_item()

      numeric_item =
        ContentItem.num(
          Code.new("8867-4", "LN", "Heart rate"),
          62.5,
          Code.new("/min", "UCUM", "beats per minute"),
          relationship_type: "CONTAINS",
          qualifier: Code.new("114006", "DCM", "Measurement failure")
        )
        |> ContentItem.to_item()

      segment_item =
        ContentItem.image(Codes.source(), segment_reference, relationship_type: "CONTAINS")
        |> ContentItem.to_item()

      root =
        ContentItem.container(Codes.imaging_measurement_report(),
          continuity_of_content: "CONTINUOUS"
        )
        |> ContentItem.to_root_elements()

      assert uid_item[Tag.uid_value()].value == "1.2.826.0.1.3680043.10.1137.705"
      assert pname_item[Tag.person_name_value()].value == "DOE^JANE"

      assert numeric_item[Tag.measured_value_sequence()].value
             |> hd()
             |> Map.has_key?(Tag.numeric_value_qualifier_code_sequence())

      [segment_ref] = segment_item[Tag.referenced_sop_sequence()].value
      assert segment_ref[Tag.referenced_segment_number()].value == [2, 4]
      assert root[Tag.continuity_of_content()].value == "CONTINUOUS"
    end

    test "requires relationship types for non-root items" do
      assert_raise ArgumentError, ~r/require a relationship_type/, fn ->
        %ContentItem{
          value_type: :text,
          concept_name: Codes.finding(),
          value: "orphaned item"
        }
        |> ContentItem.to_item()
      end
    end
  end

  describe "MeasurementReport" do
    test "builds measurement groups with default opts and optional finding category" do
      group =
        MeasurementGroup.new("lesion-plain", "1.2.826.0.1.3680043.10.1137.1500.9")

      plain_item = MeasurementGroup.to_content_item(group) |> ContentItem.to_item()

      assert plain_item[Tag.relationship_type()].value == "CONTAINS"

      plain_codes =
        plain_item[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "276214006" in plain_codes

      categorized_group =
        MeasurementGroup.new("lesion-cat", "1.2.826.0.1.3680043.10.1137.1500.10",
          finding_category: Code.new("M-01000", "SRT", "Morphologically Altered Structure")
        )

      categorized_item =
        MeasurementGroup.to_content_item(categorized_group) |> ContentItem.to_item()

      assert Enum.any?(categorized_item[Tag.content_sequence()].value, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "276214006"
             end)
    end

    test "builds a TID 1500 document with measurement groups and serializes to P10" do
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
          procedure_reported: [Code.new("P5-09051", "SRT", "Chest CT")],
          measurement_groups: [group]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.get(parsed, Tag.completion_flag()) == "COMPLETE"
      assert DataSet.get(parsed, Tag.verification_flag()) == "UNVERIFIED"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "126000"
      assert template_identifier(parsed) == "1500"

      [language, observer_type, observer_name, procedure_reported, imaging_measurements] =
        DataSet.get(parsed, Tag.content_sequence())

      assert code_value(language, Tag.concept_name_code_sequence()) == "121049"
      assert code_value(observer_type, Tag.concept_name_code_sequence()) == "121005"
      assert code_value(observer_type, Tag.concept_code_sequence()) == "121006"
      assert observer_name[Tag.person_name_value()].value == "REPORTER^ALICE"
      assert code_value(procedure_reported, Tag.concept_name_code_sequence()) == "121058"
      assert code_value(imaging_measurements, Tag.concept_name_code_sequence()) == "126010"

      [measurement_group] = imaging_measurements[Tag.content_sequence()].value
      assert code_value(measurement_group, Tag.concept_name_code_sequence()) == "125007"

      [tracking_id, tracking_uid, measurement_item] =
        measurement_group[Tag.content_sequence()].value

      assert tracking_id[Tag.text_value()].value == "lesion-1"
      assert tracking_uid[Tag.uid_value()].value == "1.2.826.0.1.3680043.10.1137.1500.1"
      assert String.trim(measurement_item[Tag.value_type()].value) == "NUM"
    end

    test "requires verification metadata when building a verified document" do
      root = ContentItem.container(Codes.imaging_measurement_report())

      assert {:error, {:missing_required_field, :verifying_observer_name}} =
               Document.new(
                 root,
                 study_instance_uid: "1.2.826.0.1.3680043.10.1137.190",
                 series_instance_uid: "1.2.826.0.1.3680043.10.1137.191",
                 sop_instance_uid: "1.2.826.0.1.3680043.10.1137.192",
                 verification_flag: "VERIFIED",
                 verification_datetime: ~N[2026-03-20 10:00:00]
               )

      assert {:error, {:missing_required_field, :verification_datetime}} =
               Document.new(
                 root,
                 study_instance_uid: "1.2.826.0.1.3680043.10.1137.193",
                 series_instance_uid: "1.2.826.0.1.3680043.10.1137.194",
                 sop_instance_uid: "1.2.826.0.1.3680043.10.1137.195",
                 verification_flag: "VERIFIED",
                 verifying_observer_name: "REPORTER^ALICE"
               )
    end

    test "serializes verification metadata for a verified document" do
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

      assert DataSet.get(data_set, Tag.verification_flag()) == "VERIFIED"
      assert DataSet.get(data_set, Tag.verification_date_time()) == "20260320100000"
      [observer] = DataSet.get(data_set, Tag.verifying_observer_sequence())
      assert observer[Tag.verifying_observer_name()].value == "REPORTER^ALICE"
    end

    test "rejects invalid roots and missing or malformed UIDs" do
      orphan =
        ContentItem.text(Codes.finding(), "invalid root", relationship_type: "CONTAINS")

      assert {:error, :invalid_root_content} =
               Document.new(
                 orphan,
                 study_instance_uid: "1.2.826.0.1.3680043.10.1137.199",
                 series_instance_uid: "1.2.826.0.1.3680043.10.1137.200",
                 sop_instance_uid: "1.2.826.0.1.3680043.10.1137.201"
               )

      root = ContentItem.container(Codes.imaging_measurement_report())

      assert {:error, {:missing_uid, :study_instance_uid}} =
               Document.new(
                 root,
                 series_instance_uid: "1.2.826.0.1.3680043.10.1137.202",
                 sop_instance_uid: "1.2.826.0.1.3680043.10.1137.203"
               )

      assert {:error, {:invalid_uid, :study_instance_uid}} =
               Document.new(
                 root,
                 study_instance_uid: "not-a-uid",
                 series_instance_uid: "1.2.826.0.1.3680043.10.1137.204",
                 sop_instance_uid: "1.2.826.0.1.3680043.10.1137.205"
               )
    end

    test "supports DateTime content and verification timestamps" do
      root = ContentItem.container(Codes.imaging_measurement_report())
      datetime = DateTime.from_naive!(~N[2026-03-20 12:34:56], "Etc/UTC")

      {:ok, document} =
        Document.new(
          root,
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.206",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.207",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.208",
          content_datetime: datetime,
          verification_flag: "VERIFIED",
          verifying_observer_name: "REPORTER^ALICE",
          verification_datetime: datetime
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.content_date()) == "20260320"
      assert DataSet.get(data_set, Tag.content_time()) == "123456"
      assert DataSet.get(data_set, Tag.verification_date_time()) == "20260320123456+0000"
    end

    test "supports device observer context and image-backed measurement evidence" do
      source_image =
        Reference.new(
          Dicom.UID.dx_image_storage(),
          "1.2.826.0.1.3680043.10.1137.710",
          purpose: Codes.original_source()
        )

      measurement =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          62,
          Code.new("/min", "UCUM", "beats per minute"),
          source_regions: [
            Scoord2D.new(source_image, "POINT", [120.0, 220.0])
          ],
          source_images: [source_image],
          finding_sites: [Code.new("80891009", "SCT", "Heart structure")]
        )

      group =
        MeasurementGroup.new("lesion-2", "1.2.826.0.1.3680043.10.1137.1500.2",
          measurements: [measurement],
          source_images: [source_image],
          finding_sites: [Code.new("80891009", "SCT", "Heart structure")]
        )

      {:ok, document} =
        MeasurementReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.711",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.712",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.713",
          observer_name: "REPORTER^ALICE",
          observer_device: [
            uid: "1.2.826.0.1.3680043.10.1137.714",
            name: "CALIPER-01",
            manufacturer: "Balneario Devices",
            model_name: "Annotator Pro",
            serial_number: "SN-1500"
          ],
          procedure_reported: [Code.new("P5-09051", "SRT", "Chest CT")],
          image_library: [source_image],
          measurement_groups: [group]
        )

      {:ok, data_set} = Document.to_data_set(document)

      content_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in content_codes
      assert "121013" in content_codes

      imaging_measurements =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126010"
        end)

      assert Enum.any?(DataSet.get(data_set, Tag.content_sequence()), fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "111028"
             end)

      [measurement_group] = imaging_measurements[Tag.content_sequence()].value
      group_children = measurement_group[Tag.content_sequence()].value

      assert Enum.any?(group_children, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "363698007"
             end)

      assert Enum.any?(group_children, fn item ->
               item[Tag.value_type()].value == "IMAGE" and
                 code_value(item, Tag.purpose_of_reference_code_sequence()) == "111040"
             end)

      assert Enum.any?(group_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 Enum.any?(item[Tag.content_sequence()].value, fn child ->
                   child[Tag.value_type()].value == "SCOORD" and
                     child[Tag.graphic_type()].value == "POINT"
                 end)
             end)
    end
  end

  describe "Observer" do
    test "builds device observation context items" do
      items =
        Observer.device(
          uid: "1.2.826.0.1.3680043.10.1137.820",
          name: "ECG-CART-01",
          manufacturer: "Balneario Devices",
          model_name: "Stress 5000",
          serial_number: "ECG-001"
        )

      codes =
        items
        |> Enum.map(&ContentItem.to_item/1)
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121005" in codes
      assert "121012" in codes
      assert "121013" in codes
      assert "121014" in codes
      assert "121015" in codes
      assert "121016" in codes
    end

    test "omits optional device text fields when they are not provided" do
      items = Observer.device(uid: "1.2.826.0.1.3680043.10.1137.821")
      assert length(items) == 2
    end
  end

  describe "ECGReport" do
    test "omits device observer context when observer_device is nil" do
      {:ok, document} =
        ECGReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.213",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.214",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.215",
          observer_name: "CARDIOLOGIST^BOB",
          observer_device: nil
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end

    test "builds a TID 3700 document with global and lead measurement sections" do
      global_measurement =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          58,
          Code.new("/min", "UCUM", "beats per minute")
        )

      lead_measurement =
        Measurement.new(
          Code.new("2:16016", "MDC", "QRS duration"),
          92,
          Code.new("ms", "UCUM", "milliseconds")
        )

      {:ok, document} =
        ECGReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.200",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.201",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.202",
          observer_name: "CARDIOLOGIST^BOB",
          procedure_reported: Code.new("11524-6", "LN", "EKG study"),
          global_measurements: [global_measurement],
          lead_measurements: [%{lead: "I", measurements: [lead_measurement]}],
          findings: [
            Code.new("164873001", "SCT", "Sinus rhythm")
          ],
          summary: ["Borderline prolonged QRS duration."]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "28010-7"
      assert template_identifier(data_set) == "3700"

      section_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "122158" in section_codes
      assert "122159" in section_codes
      assert "121071" in section_codes
      assert "121073" in section_codes
    end

    test "supports code and text mixtures without optional procedure or device sections" do
      {:ok, document} =
        ECGReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.210",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.211",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.212",
          observer_name: "CARDIOLOGIST^BOB",
          reasons: [Code.new("12345", "99B", "Palpitations"), "Dyspnea"],
          findings: ["Sinus tachycardia"],
          summary: [Code.new("373930000", "SCT", "Normal ECG")]
        )

      {:ok, data_set} = Document.to_data_set(document)

      section_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in section_codes
      assert "121073" in section_codes
      refute "121058" in section_codes
      refute "122158" in section_codes
      refute "122159" in section_codes
    end
  end

  describe "StressTestingReport" do
    test "omits device observer context when observer_device is nil" do
      {:ok, document} =
        StressTestingReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.313",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.314",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.315",
          observer_name: "STRESS^CAROL",
          observer_device: nil
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end

    test "builds a TID 3300 document with procedure, phases, conclusions, and recommendations" do
      phase_measurement =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          121,
          Code.new("/min", "UCUM", "beats per minute")
        )

      {:ok, document} =
        StressTestingReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.300",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.301",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.302",
          observer_name: "STRESS^CAROL",
          procedure_reported: Code.new("34789-4", "LN", "Cardiac stress test"),
          indications: ["Exertional chest discomfort"],
          procedure_description: "Bruce treadmill protocol",
          phase_data: [
            %{
              name: "Peak exercise",
              measurements: [phase_measurement],
              findings: ["Mild ST depression"]
            }
          ],
          conclusions: ["Exercise-induced ischemic changes are present."],
          recommendations: ["Recommend cardiology review."]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "18752-6"
      assert template_identifier(data_set) == "3300"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121065" in concept_codes
      assert "121071" in concept_codes
      assert "121073" in concept_codes
      assert "121075" in concept_codes
    end

    test "supports code-based indications, impressions, and recommendations without optional procedure text" do
      {:ok, document} =
        StressTestingReport.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.310",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.311",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.312",
          observer_name: "STRESS^CAROL",
          indications: [Code.new("233604007", "SCT", "Chest pain")],
          summary: [Code.new("373930000", "SCT", "Normal ECG")],
          conclusions: [Code.new("17621005", "SCT", "Exercise tolerance test normal")],
          recommendations: [Code.new("710830005", "SCT", "Clinical follow-up")]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
      assert "121073" in concept_codes
      assert "121075" in concept_codes
      refute "121065" in concept_codes
      refute "121058" in concept_codes
    end
  end

  defp code_value(item, sequence_tag) do
    [code_item] = sequence_value(item, sequence_tag)
    code_item[Tag.code_value()].value
  end

  defp template_identifier(data_set) do
    [template_item] = DataSet.get(data_set, Tag.content_template_sequence())
    template_item[Tag.template_identifier()].value
  end

  defp sequence_value(%DataSet{} = data_set, tag) do
    DataSet.get(data_set, tag)
  end

  defp sequence_value(item, tag) when is_map(item) do
    item[tag].value
  end
end
