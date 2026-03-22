defmodule Dicom.SRTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, Tag}

  alias Dicom.SR.{
    Code,
    Codes,
    ContentItem,
    Document,
    LogEntry,
    Measurement,
    MeasurementGroup,
    Observer,
    Reference,
    Scoord2D,
    Scoord3D,
    Tcoord
  }

  alias Dicom.SR.Templates.{
    BreastImagingReport,
    CTRadiationDose,
    CardiacCatheterizationReport,
    CardiovascularAnalysisReport,
    ColonCAD,
    ECGReport,
    EchocardiographyReport,
    EnhancedXrayRadiationDose,
    GeneralUltrasoundReport,
    HemodynamicsReport,
    IVUSReport,
    ImagingReport,
    ImplantationPlan,
    MacularGridReport,
    MeasurementReport,
    OBGYNUltrasoundReport,
    PatientRadiationDose,
    PediatricCardiacUSReport,
    PerformedImagingAgentAdministration,
    PlannedImagingAgentAdministration,
    PreclinicalAcquisitionContext,
    ProcedureLog,
    ProjectionXRayRadiationDose,
    ProstateMRReport,
    RadiopharmaceuticalRadiationDose,
    SimplifiedEchoReport,
    SpectaclePrescriptionReport,
    StressTestingReport,
    StructuralHeartReport,
    TranscribedDiagnosticImagingReport,
    VascularUltrasoundReport,
    WaveformAnnotation
  }

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

  describe "Tcoord" do
    test "creates POINT with sample positions" do
      tcoord = Tcoord.new("POINT", sample_positions: [100])
      assert tcoord.temporal_range_type == "POINT"
      assert tcoord.sample_positions == [100]
    end

    test "creates SEGMENT with time offsets" do
      tcoord = Tcoord.new("SEGMENT", time_offsets: [0.5, 1.5])
      assert tcoord.temporal_range_type == "SEGMENT"
      assert tcoord.time_offsets == [0.5, 1.5]
    end

    test "creates BEGIN with datetime values" do
      tcoord = Tcoord.new("BEGIN", datetime_values: ["20260320143022"])
      assert tcoord.temporal_range_type == "BEGIN"
      assert tcoord.datetime_values == ["20260320143022"]
    end

    test "normalizes case" do
      tcoord = Tcoord.new("point", sample_positions: [42])
      assert tcoord.temporal_range_type == "POINT"
    end

    test "rejects unsupported temporal range types" do
      assert_raise ArgumentError, ~r/unsupported temporal_range_type/, fn ->
        Tcoord.new("INVALID", sample_positions: [1])
      end
    end

    test "rejects when no reference is provided" do
      assert_raise ArgumentError, ~r/exactly one/, fn ->
        Tcoord.new("POINT")
      end
    end

    test "rejects when multiple references are provided" do
      assert_raise ArgumentError, ~r/exactly one/, fn ->
        Tcoord.new("POINT", sample_positions: [1], time_offsets: [0.5])
      end
    end

    test "supports all temporal range types" do
      for type <- ~w(POINT MULTIPOINT SEGMENT MULTISEGMENT BEGIN END) do
        tcoord = Tcoord.new(type, sample_positions: [1])
        assert tcoord.temporal_range_type == type
      end
    end
  end

  describe "ContentItem TCOORD" do
    test "renders TCOORD with sample positions" do
      tcoord = Tcoord.new("POINT", sample_positions: [100, 200])

      item =
        ContentItem.tcoord(
          Codes.finding(),
          tcoord,
          relationship_type: "INFERRED FROM"
        )
        |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "TCOORD"
      assert item[Tag.relationship_type()].value == "INFERRED FROM"
      assert item[Tag.temporal_range_type()].value == "POINT"
      assert item[Tag.referenced_sample_positions()].value == [100, 200]
      assert item[Tag.referenced_sample_positions()].vr == :UL
    end

    test "renders TCOORD with time offsets" do
      tcoord = Tcoord.new("SEGMENT", time_offsets: [0.5, 1.5])

      item =
        ContentItem.tcoord(
          Codes.finding(),
          tcoord,
          relationship_type: "INFERRED FROM"
        )
        |> ContentItem.to_item()

      assert item[Tag.temporal_range_type()].value == "SEGMENT"
      assert item[Tag.referenced_time_offsets()].value == "0.5\\1.5"
      assert item[Tag.referenced_time_offsets()].vr == :DS
    end

    test "renders TCOORD with datetime values" do
      tcoord = Tcoord.new("BEGIN", datetime_values: ["20260320143022"])

      item =
        ContentItem.tcoord(
          Codes.finding(),
          tcoord,
          relationship_type: "INFERRED FROM"
        )
        |> ContentItem.to_item()

      assert item[Tag.temporal_range_type()].value == "BEGIN"
      assert item[Tag.referenced_datetime()].value == "20260320143022"
      assert item[Tag.referenced_datetime()].vr == :DT
    end

    test "requires relationship_type" do
      tcoord = Tcoord.new("POINT", sample_positions: [1])

      assert_raise KeyError, fn ->
        ContentItem.tcoord(Codes.finding(), tcoord)
      end
    end
  end

  describe "WaveformAnnotation" do
    @waveform_sop_class "1.2.840.10008.5.1.4.1.1.9.1.1"

    defp waveform_base_opts do
      [
        study_instance_uid: "1.2.826.0.1.3680043.10.1137.3750.1",
        series_instance_uid: "1.2.826.0.1.3680043.10.1137.3750.2",
        sop_instance_uid: "1.2.826.0.1.3680043.10.1137.3750.3",
        observer_name: "ANNOTATOR^ALICE",
        waveform_reference:
          Reference.new(@waveform_sop_class, "1.2.826.0.1.3680043.10.1137.3750.100")
      ]
    end

    test "builds a basic TID 3750 document with waveform reference only" do
      {:ok, document} = WaveformAnnotation.new(waveform_base_opts())

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "122172"
      assert template_identifier(data_set) == "3750"

      content = DataSet.get(data_set, Tag.content_sequence())

      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Language + Observer Type + Observer Name + Waveform Reference
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
      assert "122175" in concept_codes

      waveform_item =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122175"
        end)

      assert waveform_item[Tag.value_type()].value == "COMPOSITE"
    end

    test "builds a document with pattern annotations" do
      tcoord = Tcoord.new("POINT", sample_positions: [500])

      opts =
        Keyword.merge(waveform_base_opts(),
          patterns: [
            %{
              code: Code.new("164873001", "SCT", "Sinus rhythm"),
              tcoord: tcoord
            }
          ]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      finding_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121071" and
            item[Tag.value_type()].value == "CODE"
        end)

      assert length(finding_items) == 1
      [finding] = finding_items

      # Check the TCOORD child
      [tcoord_child] = finding[Tag.content_sequence()].value
      assert tcoord_child[Tag.value_type()].value == "TCOORD"
      assert tcoord_child[Tag.temporal_range_type()].value == "POINT"
      assert tcoord_child[Tag.referenced_sample_positions()].value == [500]
    end

    test "builds a document with measurement annotations" do
      tcoord = Tcoord.new("SEGMENT", time_offsets: [0.1, 0.5])

      opts =
        Keyword.merge(waveform_base_opts(),
          measurements: [
            %{
              name: Code.new("8867-4", "LN", "Heart rate"),
              value: 72,
              units: Code.new("/min", "UCUM", "beats per minute"),
              tcoord: tcoord
            }
          ]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      num_items =
        Enum.filter(content, fn item ->
          String.trim(item[Tag.value_type()].value) == "NUM"
        end)

      assert length(num_items) == 1
      [num_item] = num_items

      # Check that measurement has TCOORD child
      children = num_item[Tag.content_sequence()].value

      tcoord_children =
        Enum.filter(children, fn child ->
          child[Tag.value_type()].value == "TCOORD"
        end)

      assert length(tcoord_children) == 1
      [tcoord_child] = tcoord_children
      assert tcoord_child[Tag.temporal_range_type()].value == "SEGMENT"
    end

    test "builds a document with text notes" do
      tcoord = Tcoord.new("BEGIN", datetime_values: ["20260320143022"])

      opts =
        Keyword.merge(waveform_base_opts(),
          notes: [
            %{
              text: "Possible artifact at lead V1",
              tcoord: tcoord
            }
          ]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      comment_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121106"
        end)

      assert length(comment_items) == 1
      [comment] = comment_items
      assert comment[Tag.text_value()].value == "Possible artifact at lead V1"

      # Check that note has TCOORD child
      [tcoord_child] = comment[Tag.content_sequence()].value
      assert tcoord_child[Tag.value_type()].value == "TCOORD"
    end

    test "builds a document with text notes without temporal coordinates" do
      opts =
        Keyword.merge(waveform_base_opts(),
          notes: [
            %{text: "General observation about waveform quality"}
          ]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      comment_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121106"
        end)

      assert length(comment_items) == 1
      [comment] = comment_items
      assert comment[Tag.text_value()].value == "General observation about waveform quality"
      refute Map.has_key?(comment, Tag.content_sequence())
    end

    test "builds a document with mixed annotation types" do
      point_tcoord = Tcoord.new("POINT", sample_positions: [250])
      segment_tcoord = Tcoord.new("SEGMENT", time_offsets: [0.1, 0.5])

      opts =
        Keyword.merge(waveform_base_opts(),
          annotations: [
            %{
              type: :pattern,
              code: Code.new("164873001", "SCT", "Sinus rhythm"),
              tcoord: point_tcoord
            },
            %{
              type: :measurement,
              name: Code.new("8867-4", "LN", "Heart rate"),
              value: 72,
              units: Code.new("/min", "UCUM", "beats per minute"),
              tcoord: segment_tcoord
            },
            %{
              type: :note,
              text: "Artifact detected"
            }
          ]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      # Should have: language + observer_type + observer_name + waveform_ref + 3 annotations
      value_types = Enum.map(content, &String.trim(&1[Tag.value_type()].value))

      assert "CODE" in value_types
      assert "NUM" in value_types
      assert "TEXT" in value_types
      assert "COMPOSITE" in value_types
    end

    test "builds a document with measurements without temporal coordinates" do
      opts =
        Keyword.merge(waveform_base_opts(),
          measurements: [
            %{
              name: Code.new("8867-4", "LN", "Heart rate"),
              value: 60,
              units: Code.new("/min", "UCUM", "beats per minute")
            }
          ]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      num_items =
        Enum.filter(content, fn item ->
          String.trim(item[Tag.value_type()].value) == "NUM"
        end)

      assert length(num_items) == 1
      [num_item] = num_items

      # No TCOORD children expected -- content_sequence absent or has no TCOORD
      case num_item[Tag.content_sequence()] do
        nil -> assert true
        seq -> refute Enum.any?(seq.value, &(&1[Tag.value_type()].value == "TCOORD"))
      end
    end

    test "includes device observer context when provided" do
      opts =
        Keyword.merge(waveform_base_opts(),
          observer_device: [
            uid: "1.2.826.0.1.3680043.10.1137.3750.200",
            name: "ECG-CART-01"
          ]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
      assert "121013" in concept_codes
    end

    test "serializes to valid P10 binary and round-trips" do
      tcoord = Tcoord.new("POINT", sample_positions: [100])

      opts =
        Keyword.merge(waveform_base_opts(),
          patterns: [
            %{
              code: Code.new("164873001", "SCT", "Sinus rhythm"),
              tcoord: tcoord
            }
          ],
          notes: [%{text: "Normal sinus rhythm throughout"}]
        )

      {:ok, document} = WaveformAnnotation.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "122172"
      assert template_identifier(parsed) == "3750"
    end
  end

  defp find_by_concept_code(data_set, code_val) do
    data_set
    |> DataSet.get(Tag.content_sequence())
    |> Enum.find(fn item ->
      code_value(item, Tag.concept_name_code_sequence()) == code_val
    end)
  end

  defp find_child_by_concept_code(parent, code_val) do
    parent[Tag.content_sequence()].value
    |> Enum.find(fn item ->
      code_value(item, Tag.concept_name_code_sequence()) == code_val
    end)
  end

  defp code_value(item, sequence_tag) do
    [code_item] = sequence_value(item, sequence_tag)
    code_item[Tag.code_value()].value
  end

  defp template_identifier(data_set) do
    [template_item] = DataSet.get(data_set, Tag.content_template_sequence())
    template_item[Tag.template_identifier()].value |> String.trim()
  end

  defp sequence_value(%DataSet{} = data_set, tag) do
    DataSet.get(data_set, tag)
  end

  defp sequence_value(item, tag) when is_map(item) do
    item[tag].value
  end

  describe "BreastImagingReport" do
    @base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402",
      observer_name: "BREAST^ALICE"
    ]

    test "builds a minimal report with assessment only" do
      {:ok, document} =
        BreastImagingReport.new(
          @base_opts ++
            [assessment: Codes.birads_category_1()]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "111036"
      assert template_identifier(data_set) == "4200"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Assessment is always present
      assert "111037" in concept_codes
    end

    test "builds a full report with composition, findings, assessment, impressions, and recommendations" do
      {:ok, document} =
        BreastImagingReport.new(
          @base_opts ++
            [
              procedure_reported: Code.new("24623-3", "LN", "Mammography"),
              breast_composition: Code.new("111413", "DCM", "Almost entirely fatty"),
              narrative: "Screening mammography shows no significant findings.",
              findings: [
                Codes.mass(),
                "Focal asymmetry in right upper outer quadrant"
              ],
              assessment: Codes.birads_category_2(),
              impressions: ["No evidence of malignancy"],
              recommendations: [
                Code.new("399013003", "SCT", "Follow-up mammography")
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure reported
      assert "121058" in concept_codes
      # Breast composition
      assert "111031" in concept_codes
      # Narrative summary
      assert "111043" in concept_codes
      # Findings
      assert "121071" in concept_codes
      # Assessment
      assert "111037" in concept_codes
      # Impression
      assert "121073" in concept_codes
      # Recommendation
      assert "121075" in concept_codes
    end

    test "supports all BI-RADS assessment categories 0 through 6" do
      categories = [
        {Codes.birads_category_0(), "111170"},
        {Codes.birads_category_1(), "111171"},
        {Codes.birads_category_2(), "111172"},
        {Codes.birads_category_3(), "111173"},
        {Codes.birads_category_4(), "111174"},
        {Codes.birads_category_5(), "111175"},
        {Codes.birads_category_6(), "111176"}
      ]

      for {category, expected_code} <- categories do
        uid_suffix = expected_code

        {:ok, document} =
          BreastImagingReport.new(
            study_instance_uid: "1.2.826.0.1.3680043.10.1137.4#{uid_suffix}",
            series_instance_uid: "1.2.826.0.1.3680043.10.1137.5#{uid_suffix}",
            sop_instance_uid: "1.2.826.0.1.3680043.10.1137.6#{uid_suffix}",
            observer_name: "BREAST^ALICE",
            assessment: category
          )

        {:ok, data_set} = Document.to_data_set(document)

        # Find the assessment item in the content sequence
        assessment_item =
          data_set
          |> DataSet.get(Tag.content_sequence())
          |> Enum.find(fn item ->
            code_value(item, Tag.concept_name_code_sequence()) == "111037"
          end)

        assert assessment_item, "Assessment item not found for category #{expected_code}"
        assert code_value(assessment_item, Tag.concept_code_sequence()) == expected_code
      end
    end

    test "handles multiple findings of different types" do
      {:ok, document} =
        BreastImagingReport.new(
          @base_opts ++
            [
              assessment: Codes.birads_category_4(),
              findings: [
                Codes.mass(),
                Codes.calcification(),
                Codes.architectural_distortion(),
                Codes.asymmetry(),
                "Skin thickening"
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      finding_items =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121071"
        end)

      assert length(finding_items) == 5
    end

    test "includes impressions and recommendations as text and codes" do
      {:ok, document} =
        BreastImagingReport.new(
          @base_opts ++
            [
              assessment: Codes.birads_category_0(),
              impressions: [
                "Incomplete evaluation",
                Code.new("397138000", "SCT", "Mammographic finding")
              ],
              recommendations: [
                "Additional views recommended",
                Code.new("399013003", "SCT", "Follow-up mammography")
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      impression_count = Enum.count(concept_codes, &(&1 == "121073"))
      recommendation_count = Enum.count(concept_codes, &(&1 == "121075"))

      assert impression_count == 2
      assert recommendation_count == 2
    end

    test "series description defaults to Breast Imaging Report" do
      {:ok, document} =
        BreastImagingReport.new(
          @base_opts ++
            [assessment: Codes.birads_category_1()]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.series_description()) == "Breast Imaging Report"
    end

    test "omits optional sections when not provided" do
      {:ok, document} =
        BreastImagingReport.new(
          @base_opts ++
            [assessment: Codes.birads_category_1()]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure not present
      refute "121058" in concept_codes
      # Breast composition not present
      refute "111031" in concept_codes
      # Narrative not present
      refute "111043" in concept_codes
      # No findings
      refute "121071" in concept_codes
      # No impressions
      refute "121073" in concept_codes
      # No recommendations
      refute "121075" in concept_codes
    end
  end

  describe "CardiacCatheterizationReport" do
    @cath_uid_base "1.2.826.0.1.3680043.10.1137.3800"

    defp cath_opts(extra \\ []) do
      Keyword.merge(
        [
          study_instance_uid: "#{@cath_uid_base}.100",
          series_instance_uid: "#{@cath_uid_base}.101",
          sop_instance_uid: "#{@cath_uid_base}.102",
          observer_name: "CARDIOLOGIST^SMITH"
        ],
        extra
      )
    end

    test "builds a basic report with observer context and template identifier 3800" do
      {:ok, document} = CardiacCatheterizationReport.new(cath_opts())
      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "18745-0"
      assert template_identifier(data_set) == "3800"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Language + observer type + observer name = minimum children
      assert "121049" in concept_codes
      assert "121005" in concept_codes
    end

    test "builds a report with single vessel coronary findings" do
      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            coronary_findings: [
              %{
                vessel: Codes.left_anterior_descending_artery(),
                stenosis: 70,
                timi_flow: "3"
              }
            ]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      findings_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      assert findings_section != nil

      coronary_container =
        findings_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122153"
        end)

      assert coronary_container != nil
      [vessel_item] = coronary_container[Tag.content_sequence()].value
      assert code_value(vessel_item, Tag.concept_name_code_sequence()) == "53655008"

      vessel_children = vessel_item[Tag.content_sequence()].value

      stenosis_item =
        Enum.find(vessel_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "36228007"
        end)

      assert stenosis_item[Tag.value_type()].value == "NUM"

      timi_item =
        Enum.find(vessel_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122155"
        end)

      assert timi_item[Tag.text_value()].value == "3"
    end

    test "builds a report with multiple vessel findings" do
      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            coronary_findings: [
              %{vessel: Codes.left_main_coronary_artery(), stenosis: 30},
              %{vessel: Codes.left_anterior_descending_artery(), stenosis: 90, timi_flow: "2"},
              %{vessel: Codes.right_coronary_artery(), stenosis: 50}
            ]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      findings_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      coronary_container =
        findings_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122153"
        end)

      vessel_items = coronary_container[Tag.content_sequence()].value
      assert length(vessel_items) == 3

      vessel_codes =
        Enum.map(vessel_items, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "6685003" in vessel_codes
      assert "53655008" in vessel_codes
      assert "12800006" in vessel_codes
    end

    test "builds a report with PCI procedure" do
      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            procedure: %{
              access_site: Code.new("7569003", "SCT", "Femoral artery"),
              catheters: ["JL4", "JR4"],
              pci: %{
                vessel: Codes.left_anterior_descending_artery(),
                stent_placed: "DES 3.0x18mm"
              }
            }
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      procedure_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121064"
        end)

      assert procedure_section != nil
      procedure_children = procedure_section[Tag.content_sequence()].value

      # Access site
      access_item =
        Enum.find(procedure_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111027"
        end)

      assert access_item != nil

      # Catheters
      catheter_items =
        Enum.filter(procedure_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111026"
        end)

      assert length(catheter_items) == 2

      # PCI container
      pci_item =
        Enum.find(procedure_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122152"
        end)

      assert pci_item != nil

      pci_children = pci_item[Tag.content_sequence()].value

      stent_item =
        Enum.find(pci_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122154"
        end)

      assert stent_item[Tag.text_value()].value == "DES 3.0x18mm"

      vessel_item =
        Enum.find(pci_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "363698007"
        end)

      assert vessel_item != nil
    end

    test "builds a report with LV findings" do
      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            lv_findings: %{
              ef: 55,
              lvedp: 12,
              wall_motion: "Normal wall motion"
            }
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      findings_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      lv_container =
        findings_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122157"
        end)

      assert lv_container != nil
      lv_children = lv_container[Tag.content_sequence()].value

      ef_item =
        Enum.find(lv_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "10230-1"
        end)

      assert ef_item[Tag.value_type()].value == "NUM"

      edp_item =
        Enum.find(lv_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "8440-2"
        end)

      assert edp_item[Tag.value_type()].value == "NUM"

      wall_motion_item =
        Enum.find(lv_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "F-32040"
        end)

      assert wall_motion_item[Tag.text_value()].value == "Normal wall motion"
    end

    test "builds a report with hemodynamic findings" do
      hemodynamic_measurement =
        Measurement.new(
          Code.new("8480-6", "LN", "Systolic blood pressure"),
          120,
          Codes.mmhg()
        )

      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(hemodynamic_findings: [hemodynamic_measurement])
        )

      {:ok, data_set} = Document.to_data_set(document)

      findings_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      hemodynamic_container =
        findings_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122101"
        end)

      assert hemodynamic_container != nil
      [measurement_item] = hemodynamic_container[Tag.content_sequence()].value
      assert measurement_item[Tag.value_type()].value == "NUM"
    end

    test "builds a full cardiac catheterization report" do
      hemodynamic_measurement =
        Measurement.new(
          Code.new("8480-6", "LN", "Systolic blood pressure"),
          130,
          Codes.mmhg()
        )

      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            procedure_reported: Code.new("34789-4", "LN", "Cardiac catheterization procedure"),
            patient_history: ["Hypertension", "Diabetes mellitus type 2"],
            patient_presentation: ["Chest pain at rest"],
            procedure: %{
              access_site: Code.new("7569003", "SCT", "Femoral artery"),
              catheters: ["JL4"],
              pci: %{
                vessel: Codes.left_anterior_descending_artery(),
                stent_placed: "DES 3.0x18mm"
              }
            },
            hemodynamic_findings: [hemodynamic_measurement],
            lv_findings: %{ef: 45, lvedp: 18},
            coronary_findings: [
              %{vessel: Codes.left_anterior_descending_artery(), stenosis: 95, timi_flow: "1"},
              %{vessel: Codes.right_coronary_artery(), stenosis: 40}
            ],
            adverse_outcomes: ["Minor hematoma at access site"],
            summary: "Severe single-vessel disease with successful PCI to LAD.",
            discharge_summary: "Patient stable for discharge."
          )
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"

      assert code_value(parsed, Tag.concept_name_code_sequence()) |> String.trim() ==
               "18745-0"

      assert template_identifier(parsed) == "3800"

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&(code_value(&1, Tag.concept_name_code_sequence()) |> String.trim()))

      # Language
      assert "121049" in concept_codes
      # Observer type
      assert "121005" in concept_codes
      # Procedure reported
      assert "121058" in concept_codes
      # History sections (patient_history + patient_presentation)
      assert Enum.count(concept_codes, &(&1 == "121060")) == 2
      # Procedure descriptions
      assert "121064" in concept_codes
      # Findings
      assert "121070" in concept_codes
      # Summary (conclusions)
      assert "121076" in concept_codes
      # Discharge summary
      assert "121077" in concept_codes
    end

    test "document metadata uses template_identifier 3800" do
      {:ok, document} = CardiacCatheterizationReport.new(cath_opts())
      assert document.template_identifier == "3800"
      assert document.series_description == "Cardiac Catheterization Report"
    end

    test "supports text recommendations and code impressions" do
      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            impressions: [Code.new("194828000", "SCT", "Angina")],
            recommendations: ["Recommend follow-up angiography"]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121073" in concept_codes
      assert "121075" in concept_codes
    end

    test "supports code-valued catheters and adverse outcomes" do
      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            procedure: %{
              catheters: [Code.new("C-10001", "99LOCAL", "Judkins Left 4")]
            },
            adverse_outcomes: [
              Code.new("95549001", "SCT", "Hematoma"),
              "Minor bleeding at access site"
            ]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      procedure_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121064"
        end)

      catheter_items =
        procedure_section[Tag.content_sequence()].value
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111026"
        end)

      assert length(catheter_items) == 1
      [catheter] = catheter_items
      assert catheter[Tag.value_type()].value == "CODE"

      # Adverse outcomes: both code and text
      adverse_items =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121071"
        end)

      assert length(adverse_items) == 2

      types = Enum.map(adverse_items, fn item -> item[Tag.value_type()].value end)
      assert "CODE" in types
      assert "TEXT" in types
    end

    test "supports code-valued access site, stent, wall motion, TIMI flow, and history items" do
      {:ok, document} =
        CardiacCatheterizationReport.new(
          cath_opts(
            patient_history: [
              {Code.new("38341003", "SCT", "Hypertension"), "Controlled on medication"},
              Code.new("73211009", "SCT", "Diabetes mellitus")
            ],
            procedure: %{
              access_site: "Right radial artery",
              pci: %{
                stent_placed: Code.new("122154-DES", "99LOCAL", "Drug-eluting stent")
              }
            },
            lv_findings: %{
              wall_motion: Code.new("F-32041", "SRT", "Anterior wall hypokinesis")
            },
            coronary_findings: [
              %{
                vessel: Codes.left_circumflex_artery(),
                timi_flow: Code.new("122155-3", "99LOCAL", "TIMI 3")
              }
            ],
            findings: [Code.new("194828000", "SCT", "Angina")],
            impressions: ["Significant coronary artery disease"],
            recommendations: [Code.new("710830005", "SCT", "Clinical follow-up")]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # History present
      assert "121060" in concept_codes
      # Procedure descriptions present
      assert "121064" in concept_codes
      # Findings section present
      assert "121070" in concept_codes
      # Generic finding
      assert "121071" in concept_codes
      # Impression
      assert "121073" in concept_codes
      # Recommendation
      assert "121075" in concept_codes

      # Check text access site
      procedure_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121064"
        end)

      access_item =
        procedure_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111027"
        end)

      assert access_item[Tag.text_value()].value == "Right radial artery"

      # Check code-valued stent
      pci_item =
        procedure_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122152"
        end)

      stent_item =
        pci_item[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122154"
        end)

      assert stent_item[Tag.value_type()].value == "CODE"

      # Check code-valued wall motion
      findings_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      lv_container =
        findings_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122157"
        end)

      wall_motion_item =
        lv_container[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "F-32040"
        end)

      assert wall_motion_item[Tag.value_type()].value == "CODE"

      # Check code-valued TIMI flow
      coronary_container =
        findings_section[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122153"
        end)

      [vessel_item] = coronary_container[Tag.content_sequence()].value

      timi_item =
        vessel_item[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122155"
        end)

      assert timi_item[Tag.value_type()].value == "CODE"
    end

    test "omits findings section when no findings are provided" do
      {:ok, document} = CardiacCatheterizationReport.new(cath_opts())
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121070" in concept_codes
    end

    test "omits device observer context when observer_device is nil" do
      {:ok, document} = CardiacCatheterizationReport.new(cath_opts(observer_device: nil))
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end
  end

  describe "CardiovascularAnalysisReport" do
    @cardio_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402",
      observer_name: "CARDIO^ALICE"
    ]

    test "builds a basic TID 3900 document with observer context" do
      {:ok, document} = CardiovascularAnalysisReport.new(@cardio_base_opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert String.trim(code_value(parsed, Tag.concept_name_code_sequence())) == "18745-0"
      assert template_identifier(parsed) == "3900"

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
        |> Enum.map(&String.trim/1)

      # Language + observer type + observer name
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
    end

    test "includes calcium scoring section with Agatston, volume, and mass scores" do
      opts =
        Keyword.merge(@cardio_base_opts,
          calcium_scoring: %{agatston: 142, volume: 120.5, mass: 28.3}
        )

      {:ok, document} = CardiovascularAnalysisReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      calcium_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113691"
        end)

      assert calcium_section != nil

      scoring_codes =
        calcium_section[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Agatston score (112227), Volume score (112228), Mass score (112229)
      assert "112227" in scoring_codes
      assert "112228" in scoring_codes
      assert "112229" in scoring_codes
    end

    test "includes ventricular analysis with EF, volumes, and mass" do
      opts =
        Keyword.merge(@cardio_base_opts,
          ventricular_analysis: %{
            ejection_fraction: 55.2,
            edv: 120.0,
            esv: 54.0,
            stroke_volume: 66.0,
            myocardial_mass: 130.5
          }
        )

      {:ok, document} = CardiovascularAnalysisReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      ventricular_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113693"
        end)

      assert ventricular_section != nil

      measurement_codes =
        ventricular_section[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # EF (10230-1), EDV (10231-9), ESV (10232-7), SV (90096-0), Mass (10236-8)
      assert "10230-1" in measurement_codes
      assert "10231-9" in measurement_codes
      assert "10232-7" in measurement_codes
      assert "90096-0" in measurement_codes
      assert "10236-8" in measurement_codes
    end

    test "includes vascular analysis with vessel segments and stenosis" do
      opts =
        Keyword.merge(@cardio_base_opts,
          vascular_analyses: [
            %{
              segment: Code.new("91748009", "SCT", "Left anterior descending coronary artery"),
              stenosis: Code.new("255604002", "SCT", "Mild"),
              plaque_type: Code.new("112172", "DCM", "Calcified"),
              measurements: [
                Measurement.new(
                  Code.new("M-02550", "SRT", "Diameter"),
                  3.2,
                  Code.new("mm", "UCUM", "millimeter")
                )
              ]
            }
          ]
        )

      {:ok, document} = CardiovascularAnalysisReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      vascular_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113692"
        end)

      assert vascular_section != nil

      [vessel_group] = vascular_section[Tag.content_sequence()].value

      vessel_codes =
        vessel_group[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Vessel segment (363704007), Stenosis severity (246112005), Plaque type (112176)
      assert "363704007" in vessel_codes
      assert "246112005" in vessel_codes
      assert "112176" in vessel_codes

      # Has a NUM measurement child
      assert Enum.any?(vessel_group[Tag.content_sequence()].value, fn item ->
               String.trim(item[Tag.value_type()].value) == "NUM"
             end)
    end

    test "builds a full report with all sections" do
      opts =
        Keyword.merge(@cardio_base_opts,
          procedure_reported: Code.new("77343006", "SCT", "Computed tomography of heart"),
          procedure_summary: "CT coronary angiography with calcium scoring",
          calcium_scoring: %{agatston: 142, volume: 120.5, mass: 28.3},
          vascular_analyses: [
            %{
              segment: Code.new("91748009", "SCT", "Left anterior descending coronary artery"),
              stenosis: Code.new("255604002", "SCT", "Mild")
            }
          ],
          ventricular_analysis: %{
            ejection_fraction: 55.2,
            edv: 120.0,
            esv: 54.0,
            stroke_volume: 66.0,
            myocardial_mass: 130.5
          },
          perfusion_analysis: %{
            findings: ["No perfusion defect identified"]
          },
          findings: ["Mild stenosis of the LAD"],
          impressions: ["Overall normal cardiac function"],
          recommendations: ["Clinical follow-up in 12 months"],
          summary: "Normal cardiac CT with mild LAD stenosis"
        )

      {:ok, document} = CardiovascularAnalysisReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert String.trim(template_identifier(parsed)) == "3900"

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
        |> Enum.map(&String.trim/1)

      # Procedure reported
      assert "121058" in concept_codes
      # Procedure summary (121060 - History)
      assert "121060" in concept_codes
      # Calcium scoring section
      assert "113691" in concept_codes
      # Vascular analysis section
      assert "113692" in concept_codes
      # Ventricular analysis section
      assert "113693" in concept_codes
      # Perfusion analysis section
      assert "113694" in concept_codes
      # Finding
      assert "121071" in concept_codes
      # Impression
      assert "121073" in concept_codes
      # Recommendation
      assert "121075" in concept_codes
      # Summary/Conclusion
      assert "121077" in concept_codes
    end

    test "supports code-based findings, impressions, and recommendations" do
      opts =
        Keyword.merge(@cardio_base_opts,
          findings: [Code.new("194828000", "SCT", "Coronary artery stenosis")],
          impressions: [Code.new("17621005", "SCT", "Normal")],
          recommendations: [Code.new("710830005", "SCT", "Clinical follow-up")]
        )

      {:ok, document} = CardiovascularAnalysisReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
      assert "121073" in concept_codes
      assert "121075" in concept_codes
    end

    test "handles empty lists for optional sections gracefully" do
      opts =
        Keyword.merge(@cardio_base_opts,
          vascular_analyses: [],
          findings: [],
          impressions: [],
          recommendations: []
        )

      {:ok, document} = CardiovascularAnalysisReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # No vascular section when empty list
      refute "113692" in concept_codes
      # No findings/impressions/recommendations when empty
      refute "121071" in concept_codes
      refute "121073" in concept_codes
      refute "121075" in concept_codes
    end

    test "vascular analysis with vessel having no measurements" do
      opts =
        Keyword.merge(@cardio_base_opts,
          vascular_analyses: [
            %{
              segment: Code.new("91748009", "SCT", "Left anterior descending coronary artery"),
              measurements: []
            }
          ]
        )

      {:ok, document} = CardiovascularAnalysisReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      vascular_section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113692"
        end)

      assert vascular_section != nil

      [vessel_group] = vascular_section[Tag.content_sequence()].value

      vessel_codes =
        vessel_group[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "363704007" in vessel_codes

      # No NUM measurements
      refute Enum.any?(vessel_group[Tag.content_sequence()].value, fn item ->
               String.trim(item[Tag.value_type()].value) == "NUM"
             end)
    end

    test "document metadata contains template_identifier 3900" do
      {:ok, document} = CardiovascularAnalysisReport.new(@cardio_base_opts)
      assert document.template_identifier == "3900"
      assert document.series_description == "CT/MR Cardiovascular Analysis Report"
    end
  end

  describe "EchocardiographyReport" do
    @echo_study_uid "1.2.826.0.1.3680043.10.1137.5200.1"
    @echo_series_uid "1.2.826.0.1.3680043.10.1137.5200.2"
    @echo_sop_uid "1.2.826.0.1.3680043.10.1137.5200.3"

    defp echo_base_opts(overrides \\ []) do
      Keyword.merge(
        [
          study_instance_uid: @echo_study_uid,
          series_instance_uid: @echo_series_uid,
          sop_instance_uid: @echo_sop_uid,
          observer_name: "ECHO^PHYSICIAN"
        ],
        overrides
      )
    end

    test "builds a basic report with observer and template identifier" do
      {:ok, document} = EchocardiographyReport.new(echo_base_opts())
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert String.trim(code_value(parsed, Tag.concept_name_code_sequence())) == "59282-4"
      assert template_identifier(parsed) == "5200"

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
        |> Enum.map(&String.trim/1)

      # Language + observer type + observer name = minimal children
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
    end

    test "includes procedure reported when specified" do
      opts =
        echo_base_opts(procedure_reported: Code.new("40701008", "SCT", "Echocardiography"))

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121058" in concept_codes
    end

    test "builds with patient characteristics" do
      opts =
        echo_base_opts(
          patient_characteristics: %{
            height: 175,
            weight: 80,
            bsa: 1.95,
            bp_systolic: 130,
            bp_diastolic: 85
          }
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      # Find the patient characteristics container (uses "121070" - Findings)
      patient_char =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070" and
            item[Tag.relationship_type()].value == "HAS OBS CONTEXT"
        end)

      assert patient_char != nil

      char_children = patient_char[Tag.content_sequence()].value
      assert length(char_children) == 5

      char_codes =
        Enum.map(char_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # body height, body weight, BSA, systolic BP, diastolic BP
      assert "50373000" in char_codes
      assert "27113001" in char_codes
      assert "301898006" in char_codes
      assert "8480-6" in char_codes
      assert "8462-4" in char_codes
    end

    test "omits patient characteristics when nil or empty" do
      {:ok, document} = EchocardiographyReport.new(echo_base_opts())
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      refute Enum.any?(content_items, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "121070"
             end)

      {:ok, document2} =
        EchocardiographyReport.new(echo_base_opts(patient_characteristics: %{}))

      {:ok, data_set2} = Document.to_data_set(document2)

      refute Enum.any?(DataSet.get(data_set2, Tag.content_sequence()), fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "121070"
             end)
    end

    test "builds with LV measurements via echo section" do
      lv_measurements = [
        Measurement.new(
          Codes.lv_internal_dimension_diastole(),
          48,
          Code.new("mm", "UCUM", "millimeter")
        ),
        Measurement.new(
          Codes.lv_internal_dimension_systole(),
          32,
          Code.new("mm", "UCUM", "millimeter")
        ),
        Measurement.new(Codes.ejection_fraction(), 60, Code.new("%", "UCUM", "percent")),
        Measurement.new(Codes.fractional_shortening(), 33, Code.new("%", "UCUM", "percent"))
      ]

      opts =
        echo_base_opts(
          echo_sections: [
            %{name: Codes.left_ventricle(), measurements: lv_measurements}
          ]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      # Find the measurement group (code 125007)
      group =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      assert group != nil

      group_children = group[Tag.content_sequence()].value

      # Should have: tracking_id, tracking_uid, finding_site (LV), + 4 measurements
      num_items =
        Enum.filter(group_children, fn item ->
          String.trim(item[Tag.value_type()].value) == "NUM"
        end)

      assert length(num_items) == 4

      # Verify finding site is left ventricle
      finding_sites =
        Enum.filter(group_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "363698007"
        end)

      assert length(finding_sites) == 1
      assert code_value(hd(finding_sites), Tag.concept_code_sequence()) == "87878005"
    end

    test "builds with valve measurements" do
      valve_measurements = [
        Measurement.new(Codes.peak_velocity(), 1.5, Code.new("m/s", "UCUM", "meter per second")),
        Measurement.new(
          Codes.mean_gradient(),
          8,
          Code.new("mm[Hg]", "UCUM", "millimeter of mercury")
        ),
        Measurement.new(Codes.valve_area(), 3.2, Code.new("cm2", "UCUM", "square centimeter"))
      ]

      opts =
        echo_base_opts(
          echo_sections: [
            %{name: Codes.aortic_valve(), measurements: valve_measurements}
          ]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      group =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      assert group != nil

      group_children = group[Tag.content_sequence()].value

      num_items =
        Enum.filter(group_children, fn item ->
          String.trim(item[Tag.value_type()].value) == "NUM"
        end)

      assert length(num_items) == 3

      # Finding site should be aortic valve
      finding_site =
        Enum.find(group_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "363698007"
        end)

      assert code_value(finding_site, Tag.concept_code_sequence()) == "34202007"
    end

    test "builds with multiple echo sections" do
      lv_section = %{
        name: Codes.left_ventricle(),
        measurements: [
          Measurement.new(Codes.ejection_fraction(), 55, Code.new("%", "UCUM", "percent"))
        ]
      }

      mv_section = %{
        name: Codes.mitral_valve(),
        measurements: [
          Measurement.new(Codes.peak_velocity(), 1.2, Code.new("m/s", "UCUM", "meter per second"))
        ]
      }

      tv_section = %{
        name: Codes.tricuspid_valve(),
        measurements: [
          Measurement.new(Codes.peak_velocity(), 2.8, Code.new("m/s", "UCUM", "meter per second"))
        ]
      }

      opts =
        echo_base_opts(echo_sections: [lv_section, mv_section, tv_section])

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      groups =
        Enum.filter(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      assert length(groups) == 3

      # Verify each group has a different finding site
      site_codes =
        Enum.map(groups, fn group ->
          group[Tag.content_sequence()].value
          |> Enum.find(fn item ->
            code_value(item, Tag.concept_name_code_sequence()) == "363698007"
          end)
          |> code_value(Tag.concept_code_sequence())
        end)

      assert "87878005" in site_codes
      assert "91134007" in site_codes
      assert "46030003" in site_codes
    end

    test "builds with wall motion analysis" do
      opts =
        echo_base_opts(
          wall_motion: %{
            segments: [
              Code.new("399233001", "SCT", "Normal wall motion"),
              Code.new("399210003", "SCT", "Hypokinetic wall motion")
            ],
            wmsi: 1.25
          }
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      wall_motion =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125205"
        end)

      assert wall_motion != nil

      wm_children = wall_motion[Tag.content_sequence()].value

      # 2 segment items + 1 WMSI measurement
      assert length(wm_children) == 3

      segment_items =
        Enum.filter(wm_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125206"
        end)

      assert length(segment_items) == 2

      wmsi_item =
        Enum.find(wm_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125209"
        end)

      assert String.trim(wmsi_item[Tag.value_type()].value) == "NUM"
    end

    test "builds with summary, findings, impressions, and recommendations" do
      opts =
        echo_base_opts(
          summary: "Normal echocardiographic findings.",
          findings: [
            "Normal LV systolic function",
            Code.new("399233001", "SCT", "Normal wall motion")
          ],
          impressions: ["No significant valvular disease"],
          recommendations: ["Follow-up in 12 months"]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # summary uses Codes.summary() = "121077" (Conclusion)
      assert "121077" in concept_codes
      # findings
      assert "121071" in concept_codes
      # impressions
      assert "121073" in concept_codes
      # recommendations
      assert "121075" in concept_codes
    end

    test "builds with qualitative evaluations in echo sections" do
      opts =
        echo_base_opts(
          echo_sections: [
            %{
              name: Codes.left_ventricle(),
              measurements: [],
              qualitative_evaluations: [
                Code.new("399233001", "SCT", "Normal wall motion"),
                "Mildly dilated left ventricle"
              ]
            }
          ]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      group =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      group_children = group[Tag.content_sequence()].value

      finding_items =
        Enum.filter(group_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121071"
        end)

      # 2 qualitative evaluations (1 code + 1 text) mapped as findings
      assert length(finding_items) == 2
    end

    test "document metadata has template_identifier 5200" do
      {:ok, document} = EchocardiographyReport.new(echo_base_opts())

      assert document.template_identifier == "5200"
      assert document.series_description == "Echocardiography Procedure Report"
    end

    test "full roundtrip with P10 serialization" do
      opts =
        echo_base_opts(
          procedure_reported: Code.new("40701008", "SCT", "Echocardiography"),
          patient_characteristics: %{height: 175, weight: 80, bsa: 1.95},
          echo_sections: [
            %{
              name: Codes.left_ventricle(),
              measurements: [
                Measurement.new(Codes.ejection_fraction(), 58, Code.new("%", "UCUM", "percent"))
              ]
            }
          ],
          wall_motion: %{
            segments: [Code.new("399233001", "SCT", "Normal wall motion")],
            wmsi: 1.0
          },
          summary: "Normal study.",
          findings: ["Normal LV function"],
          impressions: ["No abnormalities detected"],
          recommendations: ["Routine follow-up"]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert String.trim(code_value(parsed, Tag.concept_name_code_sequence())) == "59282-4"
      assert template_identifier(parsed) == "5200"
      assert DataSet.get(parsed, Tag.modality()) == "SR"
    end

    test "omits device observer context when observer_device is nil" do
      {:ok, document} =
        EchocardiographyReport.new(echo_base_opts(observer_device: nil))

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end

    test "includes device observer context when observer_device is provided" do
      {:ok, document} =
        EchocardiographyReport.new(
          echo_base_opts(
            observer_device: [
              uid: "1.2.826.0.1.3680043.10.1137.5200.10",
              name: "ECHO-MACHINE-01"
            ]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
      assert "121013" in concept_codes
    end

    test "supports code-based impressions and recommendations" do
      opts =
        echo_base_opts(
          impressions: [Code.new("373930000", "SCT", "Normal ECG")],
          recommendations: [Code.new("710830005", "SCT", "Clinical follow-up")]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121073" in concept_codes
      assert "121075" in concept_codes
    end

    test "supports wall motion without WMSI" do
      opts =
        echo_base_opts(
          wall_motion: %{
            segments: [Code.new("399233001", "SCT", "Normal wall motion")]
          }
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      wall_motion =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125205"
        end)

      wm_children = wall_motion[Tag.content_sequence()].value
      # 1 segment item, no WMSI
      assert length(wm_children) == 1
    end

    test "supports string section names and ContentItem qualitative evaluations" do
      custom_eval =
        ContentItem.text(Codes.finding(), "Custom evaluation", relationship_type: "CONTAINS")

      opts =
        echo_base_opts(
          echo_sections: [
            %{
              name: Codes.right_ventricle(),
              measurements: [],
              qualitative_evaluations: [custom_eval]
            }
          ]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      group =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      group_children = group[Tag.content_sequence()].value

      # Find the finding site for right ventricle
      finding_site =
        Enum.find(group_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "363698007"
        end)

      assert code_value(finding_site, Tag.concept_code_sequence()) == "53085002"

      # Check that the ContentItem evaluation is present
      text_items =
        Enum.filter(group_children, fn item ->
          String.trim(item[Tag.value_type()].value) == "TEXT" and
            code_value(item, Tag.concept_name_code_sequence()) == "121071"
        end)

      assert length(text_items) == 1
    end

    test "handles partial patient characteristics" do
      opts =
        echo_base_opts(patient_characteristics: %{height: 180})

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      patient_char =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      assert patient_char != nil
      char_children = patient_char[Tag.content_sequence()].value
      assert length(char_children) == 1
    end

    test "omits patient characteristics when all values are nil" do
      opts =
        echo_base_opts(patient_characteristics: %{height: nil, weight: nil})

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      refute Enum.any?(content_items, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "121070"
             end)
    end

    test "builds with IVS and LVPW measurements and pulmonic valve section" do
      lv_section = %{
        name: Codes.left_ventricle(),
        measurements: [
          Measurement.new(
            Codes.interventricular_septum_thickness(),
            10,
            Code.new("mm", "UCUM", "millimeter")
          ),
          Measurement.new(
            Codes.lv_posterior_wall_thickness(),
            11,
            Code.new("mm", "UCUM", "millimeter")
          )
        ]
      }

      pv_section = %{
        name: Codes.pulmonic_valve(),
        measurements: [
          Measurement.new(Codes.peak_velocity(), 0.9, Code.new("m/s", "UCUM", "meter per second"))
        ]
      }

      opts = echo_base_opts(echo_sections: [lv_section, pv_section])

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      groups =
        Enum.filter(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      assert length(groups) == 2

      # Verify pulmonic valve is one of the finding sites
      site_codes =
        Enum.map(groups, fn group ->
          group[Tag.content_sequence()].value
          |> Enum.find(fn item ->
            code_value(item, Tag.concept_name_code_sequence()) == "363698007"
          end)
          |> code_value(Tag.concept_code_sequence())
        end)

      assert "39057004" in site_codes
    end

    test "uses code meaning as tracking identifier for sections" do
      opts =
        echo_base_opts(
          echo_sections: [
            %{
              name: Codes.left_ventricle(),
              measurements: [
                Measurement.new(Codes.ejection_fraction(), 55, Code.new("%", "UCUM", "percent"))
              ]
            }
          ]
        )

      {:ok, document} = EchocardiographyReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      group =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      # The tracking ID should use the Code's meaning
      tracking_id =
        Enum.find(group[Tag.content_sequence()].value, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "112039"
        end)

      assert tracking_id[Tag.text_value()].value == "Left ventricle structure"
    end
  end

  describe "EnhancedXrayRadiationDose" do
    test "builds a minimal TID 10040 document with observer only" do
      {:ok, document} =
        EnhancedXrayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.600",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.601",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.602",
          observer_name: "PHYSICIST^XRAY"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113710"
      assert String.trim(template_identifier(parsed)) == "10040"
    end

    test "builds a TID 10040 document with accumulated dose and irradiation events" do
      dap_measurement =
        Measurement.new(
          Code.new("113838", "DCM", "Dose Area Product Total"),
          2500,
          Code.new("mGy.cm2", "UCUM", "milligray square centimeter")
        )

      event_measurement =
        Measurement.new(
          Code.new("113736", "DCM", "Dose (RP)"),
          12.5,
          Code.new("mGy", "UCUM", "milligray")
        )

      detail_measurement =
        Measurement.new(
          Code.new("113734", "DCM", "KVP"),
          80,
          Code.new("kV", "UCUM", "kilovolt")
        )

      {:ok, document} =
        EnhancedXrayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.610",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.611",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.612",
          observer_name: "PHYSICIST^XRAY",
          procedure_reported: Code.new("77477000", "SCT", "Computed tomography"),
          accumulated_dose: %{measurements: [dap_measurement]},
          irradiation_events: [%{measurements: [event_measurement]}],
          irradiation_details: [%{measurements: [detail_measurement]}]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121058" in concept_codes
      assert "113702" in concept_codes
      assert "113706" in concept_codes
      assert "113724" in concept_codes

      accumulated =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113702"
        end)

      [acc_measurement] = accumulated[Tag.content_sequence()].value
      assert String.trim(acc_measurement[Tag.value_type()].value) == "NUM"
    end

    test "builds a TID 10040 document with multiple irradiation events" do
      events =
        for _i <- 1..3 do
          measurement =
            Measurement.new(
              Code.new("113736", "DCM", "Dose (RP)"),
              10.0,
              Code.new("mGy", "UCUM", "milligray")
            )

          %{measurements: [measurement]}
        end

      {:ok, document} =
        EnhancedXrayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.620",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.621",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.622",
          observer_name: "PHYSICIST^XRAY",
          irradiation_events: events
        )

      {:ok, data_set} = Document.to_data_set(document)

      event_items =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113706"
        end)

      assert length(event_items) == 3
    end

    test "supports device observer context" do
      {:ok, document} =
        EnhancedXrayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.640",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.641",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.642",
          observer_name: "PHYSICIST^XRAY",
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.643"]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
    end

    test "serializes to P10 binary and round-trips" do
      {:ok, document} =
        EnhancedXrayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.630",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.631",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.632",
          observer_name: "PHYSICIST^XRAY",
          procedure_reported: Code.new("77477000", "SCT", "Computed tomography")
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert String.trim(DataSet.get(parsed, Tag.series_description())) ==
               "Enhanced X-Ray Radiation Dose Report"
    end
  end

  describe "GeneralUltrasoundReport" do
    @us_study_uid "1.2.826.0.1.3680043.10.1137.400"
    @us_series_uid "1.2.826.0.1.3680043.10.1137.401"
    @us_sop_uid "1.2.826.0.1.3680043.10.1137.402"

    defp us_base_opts(extra \\ []) do
      Keyword.merge(
        [
          study_instance_uid: @us_study_uid,
          series_instance_uid: @us_series_uid,
          sop_instance_uid: @us_sop_uid,
          observer_name: "SONOGRAPHER^ALICE"
        ],
        extra
      )
    end

    test "builds a basic report with observer and default language" do
      {:ok, document} = GeneralUltrasoundReport.new(us_base_opts())
      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "126060"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
    end

    test "document metadata uses template identifier 12000" do
      {:ok, document} = GeneralUltrasoundReport.new(us_base_opts())
      {:ok, data_set} = Document.to_data_set(document)

      assert template_identifier(data_set) == "12000"
      assert DataSet.get(data_set, Tag.series_description()) == "General Ultrasound Report"
    end

    test "builds a report with a single measurement section (liver)" do
      liver = Code.new("10200004", "SCT", "Liver")
      cm = Code.new("cm", "UCUM", "centimeter")

      length_measurement =
        Measurement.new(Codes.organ_length(), 15.2, cm)

      {:ok, document} =
        GeneralUltrasoundReport.new(
          us_base_opts(
            measurement_sections: [
              %{location: liver, measurements: [length_measurement]}
            ]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "126061" in concept_codes

      section =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(&(code_value(&1, Tag.concept_name_code_sequence()) == "126061"))

      [measurement_group] = section[Tag.content_sequence()].value
      assert code_value(measurement_group, Tag.concept_name_code_sequence()) == "125007"

      group_children = measurement_group[Tag.content_sequence()].value

      assert Enum.any?(group_children, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "363698007"
             end)

      assert Enum.any?(group_children, fn item ->
               String.trim(item[Tag.value_type()].value) == "NUM"
             end)
    end

    test "builds a report with multiple measurement sections (liver, kidney, spleen)" do
      liver = Code.new("10200004", "SCT", "Liver")
      kidney = Code.new("64033007", "SCT", "Kidney")
      spleen = Code.new("78961009", "SCT", "Spleen")
      cm = Code.new("cm", "UCUM", "centimeter")

      {:ok, document} =
        GeneralUltrasoundReport.new(
          us_base_opts(
            measurement_sections: [
              %{
                location: liver,
                measurements: [Measurement.new(Codes.organ_length(), 15.2, cm)]
              },
              %{
                location: kidney,
                measurements: [Measurement.new(Codes.organ_length(), 11.0, cm)]
              },
              %{
                location: spleen,
                measurements: [Measurement.new(Codes.organ_length(), 10.5, cm)]
              }
            ]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      sections =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.filter(&(code_value(&1, Tag.concept_name_code_sequence()) == "126061"))

      assert length(sections) == 3
    end

    test "builds a report with elastography data" do
      m_per_s = Code.new("m/s", "UCUM", "meter per second")
      kpa = Code.new("kPa", "UCUM", "kilopascal")

      velocity = Measurement.new(Codes.shear_wave_velocity(), 1.5, m_per_s)
      elasticity = Measurement.new(Codes.shear_wave_elasticity(), 6.8, kpa)

      {:ok, document} =
        GeneralUltrasoundReport.new(
          us_base_opts(elastography: %{velocity: velocity, elasticity: elasticity})
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "125370" in concept_codes
      assert "125371" in concept_codes
    end

    test "builds a report with attenuation coefficient" do
      db_per_cm_mhz = Code.new("dB/(cm.MHz)", "UCUM", "decibel per centimeter megahertz")

      attenuation = Measurement.new(Codes.attenuation_coefficient(), 0.75, db_per_cm_mhz)

      {:ok, document} =
        GeneralUltrasoundReport.new(us_base_opts(attenuation: attenuation))

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "131190" in concept_codes
    end

    test "builds a full report with all sections" do
      liver = Code.new("10200004", "SCT", "Liver")
      cm = Code.new("cm", "UCUM", "centimeter")
      ml = Code.new("mL", "UCUM", "milliliter")
      m_per_s = Code.new("m/s", "UCUM", "meter per second")
      kpa = Code.new("kPa", "UCUM", "kilopascal")
      db_per_cm_mhz = Code.new("dB/(cm.MHz)", "UCUM", "decibel per centimeter megahertz")

      {:ok, document} =
        GeneralUltrasoundReport.new(
          us_base_opts(
            procedure_reported: Code.new("US-ABD", "99LOCAL", "Abdominal Ultrasound"),
            patient_characteristics: [
              {Code.new("8302-2", "LN", "Body height"), "175 cm"},
              {Code.new("29463-7", "LN", "Body weight"), "80 kg"}
            ],
            measurement_sections: [
              %{
                location: liver,
                measurements: [
                  Measurement.new(Codes.organ_length(), 15.2, cm),
                  Measurement.new(Codes.organ_width(), 12.1, cm),
                  Measurement.new(Codes.organ_depth(), 9.8, cm),
                  Measurement.new(Codes.organ_volume(), 850, ml)
                ],
                assessments: ["Normal echotexture"]
              }
            ],
            elastography: %{
              velocity: Measurement.new(Codes.shear_wave_velocity(), 1.3, m_per_s),
              elasticity: Measurement.new(Codes.shear_wave_elasticity(), 5.1, kpa)
            },
            attenuation: Measurement.new(Codes.attenuation_coefficient(), 0.68, db_per_cm_mhz),
            findings: ["Liver appears normal in size and echogenicity."],
            impressions: ["No significant abnormalities detected."],
            recommendations: ["Follow-up in 12 months."]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "126060"
      assert template_identifier(parsed) == "12000"

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Language
      assert "121049" in concept_codes
      # Observer Type
      assert "121005" in concept_codes
      # Procedure Reported
      assert "121058" in concept_codes
      # Patient Characteristics (Codes.patient_characteristics() = "121070")
      assert "121070" in concept_codes
      # Measurement Section
      assert "126061" in concept_codes
      # Elastography measurements
      assert "125370" in concept_codes
      assert "125371" in concept_codes
      # Attenuation
      assert "131190" in concept_codes
      # Findings
      assert "121071" in concept_codes
      # Impressions
      assert "121073" in concept_codes
      # Recommendations
      assert "121075" in concept_codes
    end

    test "supports device observer context" do
      {:ok, document} =
        GeneralUltrasoundReport.new(
          us_base_opts(
            observer_device: [
              uid: "1.2.826.0.1.3680043.10.1137.450",
              name: "US-SCANNER-01"
            ]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
      assert "121013" in concept_codes
    end

    test "supports code-based findings and impressions" do
      {:ok, document} =
        GeneralUltrasoundReport.new(
          us_base_opts(
            findings: [Code.new("368009", "SCT", "Normal hepatic echogenicity")],
            impressions: [Code.new("17621005", "SCT", "Normal")]
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
      assert "121073" in concept_codes
    end

    test "handles empty elastography map without adding children" do
      {:ok, document} =
        GeneralUltrasoundReport.new(us_base_opts(elastography: %{}))

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "125370" in concept_codes
      refute "125371" in concept_codes
    end

    test "handles empty patient characteristics list" do
      {:ok, document} =
        GeneralUltrasoundReport.new(us_base_opts(patient_characteristics: []))

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121059" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = GeneralUltrasoundReport.new(us_base_opts())
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121058" in concept_codes
      refute "121059" in concept_codes
      refute "126061" in concept_codes
      refute "125370" in concept_codes
      refute "131190" in concept_codes
      refute "121071" in concept_codes
      refute "121073" in concept_codes
      refute "121075" in concept_codes
    end
  end

  describe "HemodynamicsReport" do
    @hemo_uids [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402"
    ]

    test "builds a basic report with observer only" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [observer_name: "HEMODYNAMICS^ALICE"]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "122100"
      assert template_identifier(data_set) == "3500"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Language + observer type + observer name
      assert "121049" in concept_codes
      assert "121005" in concept_codes
    end

    test "builds a report with pressure measurements in a measurement group" do
      systolic =
        Measurement.new(
          Codes.systolic_blood_pressure(),
          120,
          Code.new("mm[Hg]", "UCUM", "mmHg")
        )

      diastolic =
        Measurement.new(
          Codes.diastolic_blood_pressure(),
          80,
          Code.new("mm[Hg]", "UCUM", "mmHg")
        )

      mean =
        Measurement.new(
          Codes.mean_blood_pressure(),
          93,
          Code.new("mm[Hg]", "UCUM", "mmHg")
        )

      group =
        MeasurementGroup.new(
          "Aortic root",
          "1.2.826.0.1.3680043.10.1137.3500.1",
          measurements: [systolic, diastolic, mean]
        )

      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              measurement_groups: [group]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Hemodynamic Measurements container present
      assert "122101" in concept_codes
    end

    test "builds a report with cardiac output measurement" do
      cardiac_output =
        Measurement.new(
          Codes.cardiac_output(),
          5.2,
          Code.new("l/min", "UCUM", "l/min")
        )

      group =
        MeasurementGroup.new(
          "Thermodilution",
          "1.2.826.0.1.3680043.10.1137.3500.2",
          measurements: [cardiac_output]
        )

      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^BOB",
              measurement_groups: [group]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      # Find the hemodynamic measurements container
      measurements_container =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122101"
        end)

      assert measurements_container != nil

      # Should contain the measurement group
      [measurement_group] = measurements_container[Tag.content_sequence()].value
      assert code_value(measurement_group, Tag.concept_name_code_sequence()) == "125007"
    end

    test "supports multiple measurement groups" do
      systolic =
        Measurement.new(
          Codes.systolic_blood_pressure(),
          140,
          Code.new("mm[Hg]", "UCUM", "mmHg")
        )

      heart_rate =
        Measurement.new(
          Codes.heart_rate(),
          72,
          Code.new("/min", "UCUM", "beats per minute")
        )

      group_a =
        MeasurementGroup.new("Left ventricle", "1.2.826.0.1.3680043.10.1137.3500.3",
          measurements: [systolic]
        )

      group_b =
        MeasurementGroup.new("Right atrium", "1.2.826.0.1.3680043.10.1137.3500.4",
          measurements: [heart_rate]
        )

      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^CAROL",
              measurement_groups: [group_a, group_b]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      measurements_container =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122101"
        end)

      groups = measurements_container[Tag.content_sequence()].value
      assert length(groups) == 2
    end

    test "supports map-based measurement groups" do
      systolic =
        Measurement.new(
          Codes.systolic_blood_pressure(),
          130,
          Code.new("mm[Hg]", "UCUM", "mmHg")
        )

      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              measurement_groups: [
                %{name: "Aortic valve", measurements: [systolic]}
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "122101" in concept_codes
    end

    test "includes derived measurements" do
      valve_area =
        Measurement.new(
          Code.new("G-0390", "SRT", "Valve area"),
          1.5,
          Code.new("cm2", "UCUM", "cm2")
        )

      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              derived_measurements: [valve_area]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Derived Hemodynamic Measurements container
      assert "122102" in concept_codes
    end

    test "includes findings and conclusions" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              findings: [
                "Elevated left ventricular end-diastolic pressure",
                Code.new("194727001", "SCT", "Aortic stenosis")
              ],
              conclusions: [
                "Moderate aortic stenosis confirmed",
                Code.new("373572006", "SCT", "Clinical finding absent")
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Finding code
      assert "121071" in concept_codes
      # Conclusion code
      assert "121077" in concept_codes
    end

    test "includes summary text" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              summary: "Normal hemodynamic function."
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Impression (summary) code
      assert "121073" in concept_codes
    end

    test "includes clinical context with patient state and medications" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              clinical_context: [
                patient_state: "Resting, supine position",
                medications: ["Heparin 5000 IU IV", "Nitroglycerin 0.4mg SL"]
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Patient state code (11323-3)
      assert "11323-3" in concept_codes
      # Medication administered code (18610-6)
      assert "18610-6" in concept_codes
    end

    test "includes procedure reported" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              procedure_reported: Code.new("301095005", "SCT", "Cardiac catheterization")
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121058" in concept_codes
    end

    test "serializes to P10 and round-trips" do
      systolic =
        Measurement.new(
          Codes.systolic_blood_pressure(),
          120,
          Code.new("mm[Hg]", "UCUM", "mmHg")
        )

      group =
        MeasurementGroup.new("Aortic root", "1.2.826.0.1.3680043.10.1137.3500.5",
          measurements: [systolic]
        )

      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              procedure_reported: Code.new("301095005", "SCT", "Cardiac catheterization"),
              measurement_groups: [group],
              findings: ["Normal pressures"],
              conclusions: ["No significant gradient"],
              summary: "Hemodynamically stable."
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "122100"
      assert template_identifier(parsed) == "3500"
    end

    test "omits device observer context when observer_device is nil" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              observer_device: nil
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end

    test "supports coded patient state and coded medications in clinical context" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              clinical_context: [
                patient_state: Code.new("128975004", "SCT", "Rest"),
                medications: [Code.new("372709006", "SCT", "Heparin")]
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "11323-3" in concept_codes
      assert "18610-6" in concept_codes
    end

    test "includes device observer when observer_device is provided" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              observer_device: [uid: "1.2.826.0.1.3680043.10.1137.3500.99", name: "CathLab XR"]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
      assert "121013" in concept_codes
    end

    test "omits clinical context when empty keyword list is given" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              clinical_context: []
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "11323-3" in concept_codes
      refute "18610-6" in concept_codes
    end

    test "map-based measurement group includes findings as qualitative evaluations" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [
              observer_name: "HEMODYNAMICS^ALICE",
              measurement_groups: [
                %{name: "Left ventricle", findings: ["Mild dilation"]}
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      measurements_container =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "122101"
        end)

      [group] = measurements_container[Tag.content_sequence()].value

      group_child_codes =
        group[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Finding within the group
      assert "121071" in group_child_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} =
        HemodynamicsReport.new(
          @hemo_uids ++
            [observer_name: "HEMODYNAMICS^ALICE"]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # No measurement groups, derived, findings, conclusions, summary, procedure
      refute "122101" in concept_codes
      refute "122102" in concept_codes
      refute "121071" in concept_codes
      refute "121077" in concept_codes
      refute "121073" in concept_codes
      refute "121058" in concept_codes
    end
  end

  describe "IVUSReport" do
    @ivus_uids [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402"
    ]

    test "builds a basic report with observer only" do
      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [observer_name: "IVUS^ALICE"]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "125200"
      assert template_identifier(data_set) == "3250"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Language + observer type + observer name
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
    end

    test "builds a report with vessel and lesion data" do
      lad = Code.new("91748002", "SCT", "Left anterior descending coronary artery")
      diagonal = Code.new("244252002", "SCT", "First diagonal branch")

      lumen_measurement =
        Measurement.new(
          Codes.lumen_area(),
          5.2,
          Code.new("mm2", "UCUM", "mm2")
        )

      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [
              observer_name: "IVUS^BOB",
              vessels: [%{name: lad, branch: diagonal}],
              lesions: [
                %{
                  identifier: "Lesion-1",
                  measurements: [lumen_measurement],
                  assessments: ["Mild plaque buildup"]
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # vessel container (59820001) and lesion container (52988006)
      assert "59820001" in concept_codes
      assert "52988006" in concept_codes
    end

    test "builds a report with measurements including vessel and plaque burden" do
      vessel_measurement =
        Measurement.new(
          Codes.vessel_area(),
          12.4,
          Code.new("mm2", "UCUM", "mm2")
        )

      plaque_measurement =
        Measurement.new(
          Codes.plaque_burden(),
          58,
          Code.new("%", "UCUM", "percent")
        )

      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [
              observer_name: "IVUS^CAROL",
              lesions: [
                %{
                  identifier: "Lesion-A",
                  measurements: [vessel_measurement, plaque_measurement]
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      # Verify lesion container is present with measurements
      content_items = DataSet.get(data_set, Tag.content_sequence())

      lesion_items =
        Enum.filter(
          content_items,
          &(code_value(&1, Tag.concept_name_code_sequence()) == "52988006")
        )

      assert length(lesion_items) == 1

      [lesion] = lesion_items
      lesion_children = lesion[Tag.content_sequence()].value

      lesion_child_codes =
        Enum.map(lesion_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Tracking identifier + two measurements
      assert "112039" in lesion_child_codes
      assert "122153" in lesion_child_codes
      assert "122155" in lesion_child_codes
    end

    test "builds a report with multiple lesions" do
      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [
              observer_name: "IVUS^DAVE",
              lesions: [
                %{identifier: "Lesion-1"},
                %{identifier: "Lesion-2"},
                %{identifier: "Lesion-3"}
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      lesion_items =
        Enum.filter(
          content_items,
          &(code_value(&1, Tag.concept_name_code_sequence()) == "52988006")
        )

      assert length(lesion_items) == 3
    end

    test "builds a report with findings and impressions as both Code and text" do
      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [
              observer_name: "IVUS^EVE",
              findings: [
                "Diffuse calcification noted",
                Code.new("233970002", "SCT", "Coronary artery stenosis")
              ],
              impressions: [
                "Significant stenosis at mid-LAD",
                Code.new("194842008", "SCT", "Severe atherosclerosis")
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
      assert "121073" in concept_codes
    end

    test "document metadata includes template_identifier 3250" do
      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [observer_name: "IVUS^META"]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert template_identifier(data_set) == "3250"
      assert DataSet.get(data_set, Tag.series_description()) == "IVUS Report"
    end

    test "builds a report with procedure reported" do
      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [
              observer_name: "IVUS^FRANK",
              procedure_reported: Code.new("37851004", "SCT", "Intravascular ultrasound")
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121058" in concept_codes
    end

    test "builds a report with volume measurements" do
      volume_measurement =
        Measurement.new(
          Codes.lumen_area(),
          128.5,
          Code.new("mm3", "UCUM", "mm3")
        )

      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [
              observer_name: "IVUS^GRACE",
              volume_measurements: [volume_measurement]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # imaging measurements container for volume measurements
      assert "126010" in concept_codes
    end

    test "serializes to P10 binary and round-trips" do
      lumen_measurement =
        Measurement.new(
          Codes.lumen_area(),
          5.2,
          Code.new("mm2", "UCUM", "mm2")
        )

      {:ok, document} =
        IVUSReport.new(
          @ivus_uids ++
            [
              observer_name: "IVUS^ROUNDTRIP",
              procedure_reported: Code.new("37851004", "SCT", "Intravascular ultrasound"),
              vessels: [%{name: Code.new("91748002", "SCT", "LAD")}],
              lesions: [%{identifier: "L1", measurements: [lumen_measurement]}],
              findings: ["Calcified plaque"],
              impressions: ["Moderate stenosis"]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "125200"
      assert template_identifier(parsed) == "3250"
    end
  end

  describe "MacularGridReport" do
    @uid_base "1.2.826.0.1.3680043.10.1137.2100"

    test "builds a central subfield only report" do
      {:ok, document} =
        MacularGridReport.new(
          study_instance_uid: "#{@uid_base}.100",
          series_instance_uid: "#{@uid_base}.101",
          sop_instance_uid: "#{@uid_base}.102",
          observer_name: "OPHTHALMOLOGIST^ALICE",
          grid_measurements: [
            %{sector: :center, thickness: 265, volume: 0.21}
          ],
          central_subfield_thickness: 265
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "OPT Macular Grid"
      assert template_identifier(parsed) == "2100"

      content = DataSet.get(parsed, Tag.content_sequence())

      grid_items =
        Enum.filter(content, fn item ->
          String.trim(code_value(item, Tag.concept_name_code_sequence())) == "111700"
        end)

      assert length(grid_items) == 1

      [center_grid] = grid_items
      grid_children = center_grid[Tag.content_sequence()].value

      sector_code =
        Enum.find(
          grid_children,
          &(String.trim(code_value(&1, Tag.concept_name_code_sequence())) == "363698007")
        )

      assert String.trim(code_value(sector_code, Tag.concept_code_sequence())) == "110860"

      thickness_item =
        Enum.find(
          grid_children,
          &(String.trim(code_value(&1, Tag.concept_name_code_sequence())) == "410668003")
        )

      assert thickness_item != nil

      # central_subfield_thickness as top-level summary measurement
      csf_item =
        Enum.find(
          content,
          &(String.trim(code_value(&1, Tag.concept_name_code_sequence())) == "410669006")
        )

      assert csf_item != nil
    end

    test "builds a full 9-sector grid report" do
      sectors = [
        :center,
        :inner_superior,
        :inner_nasal,
        :inner_inferior,
        :inner_temporal,
        :outer_superior,
        :outer_nasal,
        :outer_inferior,
        :outer_temporal
      ]

      grid_measurements =
        Enum.map(sectors, fn sector ->
          %{
            sector: sector,
            thickness: 260 + :rand.uniform(40),
            volume: 0.18 + :rand.uniform() * 0.10
          }
        end)

      {:ok, document} =
        MacularGridReport.new(
          study_instance_uid: "#{@uid_base}.110",
          series_instance_uid: "#{@uid_base}.111",
          sop_instance_uid: "#{@uid_base}.112",
          observer_name: "OPHTHALMOLOGIST^BOB",
          grid_measurements: grid_measurements,
          total_volume: 8.12
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      grid_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111700"
        end)

      assert length(grid_items) == 9

      # verify total volume summary measurement
      total_vol_item =
        Enum.find(content, &(code_value(&1, Tag.concept_name_code_sequence()) == "121217"))

      assert total_vol_item != nil
    end

    test "builds a report with quality rating" do
      {:ok, document} =
        MacularGridReport.new(
          study_instance_uid: "#{@uid_base}.120",
          series_instance_uid: "#{@uid_base}.121",
          sop_instance_uid: "#{@uid_base}.122",
          observer_name: "OPHTHALMOLOGIST^CAROL",
          quality_rating: 8,
          grid_measurements: [
            %{sector: :center, thickness: 270}
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      quality_item =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "363679005"
        end)

      assert quality_item != nil
      assert quality_item[Tag.value_type()].value == "NUM"
    end

    test "document metadata for macular grid report" do
      {:ok, document} =
        MacularGridReport.new(
          study_instance_uid: "#{@uid_base}.130",
          series_instance_uid: "#{@uid_base}.131",
          sop_instance_uid: "#{@uid_base}.132",
          observer_name: "OPHTHALMOLOGIST^DAVE",
          grid_measurements: [%{sector: :center, thickness: 260}],
          patient_name: "PATIENT^OCT",
          patient_id: "P002"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.patient_name()) |> String.trim() == "PATIENT^OCT"
      assert DataSet.get(parsed, Tag.patient_id()) == "P002"

      assert DataSet.get(parsed, Tag.series_description()) |> String.trim() ==
               "Macular Grid Thickness and Volume Report"
    end
  end

  describe "OBGYNUltrasoundReport" do
    @obgyn_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.5000",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.5001",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.5002",
      observer_name: "SONOGRAPHER^ALICE"
    ]

    test "builds a basic TID 5000 document with observer context" do
      {:ok, document} = OBGYNUltrasoundReport.new(@obgyn_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert code_value(data_set, Tag.concept_name_code_sequence()) == "11525-3"
      assert template_identifier(data_set) == "5000"

      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.get(parsed, Tag.completion_flag()) == "COMPLETE"
      assert DataSet.get(parsed, Tag.verification_flag()) == "UNVERIFIED"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"

      [language, observer_type, observer_name] =
        DataSet.get(data_set, Tag.content_sequence())

      assert code_value(language, Tag.concept_name_code_sequence()) == "121049"
      assert code_value(observer_type, Tag.concept_name_code_sequence()) == "121005"
      assert code_value(observer_type, Tag.concept_code_sequence()) == "121006"
      assert observer_name[Tag.person_name_value()].value == "SONOGRAPHER^ALICE"
    end

    test "builds a single fetus with biometry measurements" do
      opts =
        @obgyn_base_opts ++
          [
            fetuses: [
              %{
                number: 1,
                biometry: %{bpd: 85.2, hc: 310.0, ac: 290.5, fl: 62.1}
              }
            ]
          ]

      {:ok, document} = OBGYNUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      fetus_summary =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      assert fetus_summary != nil

      fetus_children = fetus_summary[Tag.content_sequence()].value

      # Fetal number
      fetal_number =
        Enum.find(fetus_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "11878-6"
        end)

      assert fetal_number != nil
      assert String.trim(fetal_number[Tag.value_type()].value) == "NUM"

      # Biometry container
      biometry =
        Enum.find(fetus_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121069"
        end)

      assert biometry != nil
      biometry_children = biometry[Tag.content_sequence()].value

      biometry_codes =
        Enum.map(biometry_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # BPD, HC, AC, FL
      assert "11820-8" in biometry_codes
      assert "11984-2" in biometry_codes
      assert "11979-2" in biometry_codes
      assert "11963-6" in biometry_codes
    end

    test "builds multiple fetus summaries" do
      opts =
        @obgyn_base_opts ++
          [
            fetuses: [
              %{
                number: 1,
                presentation: Code.new("70028003", "SCT", "Vertex presentation"),
                heart_activity: Code.new("249043002", "SCT", "Fetal heart activity present"),
                biometry: %{bpd: 85.0, hc: 308.0, ac: 288.0, fl: 61.0}
              },
              %{
                number: 2,
                presentation: Code.new("6096002", "SCT", "Breech presentation"),
                heart_activity: Code.new("249043002", "SCT", "Fetal heart activity present"),
                biometry: %{bpd: 83.0, hc: 302.0, ac: 280.0, fl: 59.0}
              }
            ]
          ]

      {:ok, document} = OBGYNUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      fetus_summaries =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      assert length(fetus_summaries) == 2

      # Each fetus has presentation and heart activity
      Enum.each(fetus_summaries, fn fetus ->
        children = fetus[Tag.content_sequence()].value
        child_codes = Enum.map(children, &code_value(&1, Tag.concept_name_code_sequence()))

        assert "11876-0" in child_codes
        assert "11948-7" in child_codes
      end)
    end

    test "builds with amniotic fluid measurements" do
      opts =
        @obgyn_base_opts ++
          [
            amniotic_fluid: %{afi: 14.2, sdp: 5.8}
          ]

      {:ok, document} = OBGYNUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      amniotic_sac =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121072"
        end)

      assert amniotic_sac != nil
      children = amniotic_sac[Tag.content_sequence()].value
      child_codes = Enum.map(children, &code_value(&1, Tag.concept_name_code_sequence()))

      # AFI and SDP
      assert "11818-2" in child_codes
      assert "11817-4" in child_codes
    end

    test "builds with patient characteristics" do
      opts =
        @obgyn_base_opts ++
          [
            patient_characteristics: %{
              lmp: ~D[2025-06-15],
              edd: ~D[2026-03-22],
              gravidity: 2,
              parity: 1
            }
          ]

      {:ok, document} = OBGYNUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      # Patient Characteristics container uses DCM 121070
      patient_chars =
        Enum.find(content, fn item ->
          item[Tag.relationship_type()] &&
            item[Tag.relationship_type()].value == "HAS OBS CONTEXT" &&
            code_value(item, Tag.concept_name_code_sequence()) == "121070"
        end)

      assert patient_chars != nil
      children = patient_chars[Tag.content_sequence()].value
      child_codes = Enum.map(children, &code_value(&1, Tag.concept_name_code_sequence()))

      # LMP, EDD, gravidity, parity
      assert "11955-2" in child_codes
      assert "11778-8" in child_codes
      assert "11996-6" in child_codes
      assert "11977-6" in child_codes

      # Verify LMP is a DATE item
      lmp_item =
        Enum.find(children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "11955-2"
        end)

      assert String.trim(lmp_item[Tag.value_type()].value) == "DATE"
      assert lmp_item[Tag.sr_date()].value == "20250615"
    end

    test "builds a full report with all sections" do
      opts =
        @obgyn_base_opts ++
          [
            procedure_reported: Code.new("11525-3", "LN", "US OB Study"),
            patient_characteristics: %{
              lmp: ~D[2025-06-10],
              edd: ~D[2026-03-17],
              gravidity: 3,
              parity: 2
            },
            fetuses: [
              %{
                number: 1,
                presentation: Code.new("70028003", "SCT", "Vertex presentation"),
                heart_activity: Code.new("249043002", "SCT", "Fetal heart activity present"),
                biometry: %{bpd: 86.0, hc: 312.0, ac: 292.0, fl: 63.0},
                estimated_weight: 2450,
                gestational_age: 245
              }
            ],
            amniotic_fluid: %{afi: 15.0, sdp: 6.2},
            pelvis_uterus: %{cervical_length: 35.0},
            placenta: %{location: Code.new("44793003", "SCT", "Anterior placenta")},
            findings: ["Single live intrauterine pregnancy"],
            impressions: ["Normal interval growth"],
            recommendations: ["Routine follow-up in 4 weeks"]
          ]

      {:ok, document} = OBGYNUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      assert code_value(data_set, Tag.concept_name_code_sequence()) == "11525-3"
      assert template_identifier(data_set) == "5000"

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure reported
      assert "121058" in concept_codes
      # Patient characteristics
      assert "121070" in concept_codes
      # Fetus summary
      assert "121070" in concept_codes
      # Amniotic sac
      assert "121072" in concept_codes
      # Pelvis and uterus
      assert "121074" in concept_codes
      # Placenta location
      assert "11969-3" in concept_codes
      # Finding, impression, recommendation
      assert "121071" in concept_codes
      assert "121073" in concept_codes
      assert "121075" in concept_codes

      # Verify fetus has EFW and gestational age
      fetus =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121070" &&
            item[Tag.relationship_type()] &&
            item[Tag.relationship_type()].value == "CONTAINS"
        end)

      fetus_children = fetus[Tag.content_sequence()].value
      fetus_codes = Enum.map(fetus_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # EFW and gestational age
      assert "11727-5" in fetus_codes
      assert "11884-4" in fetus_codes

      # Verify full P10 roundtrip works
      {:ok, binary} = Dicom.write(data_set)
      {:ok, _parsed} = Dicom.parse(binary)
    end

    test "document metadata uses template identifier 5000" do
      {:ok, document} = OBGYNUltrasoundReport.new(@obgyn_base_opts)
      assert document.template_identifier == "5000"
      assert document.series_description == "OB-GYN Ultrasound Procedure Report"
    end

    test "omits device observer context when observer_device is nil" do
      {:ok, document} =
        OBGYNUltrasoundReport.new(@obgyn_base_opts ++ [observer_device: nil])

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end

    test "builds with pelvis and uterus measurements" do
      opts =
        @obgyn_base_opts ++
          [
            pelvis_uterus: %{cervical_length: 32.5}
          ]

      {:ok, document} = OBGYNUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      pelvis =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121074"
        end)

      assert pelvis != nil
      children = pelvis[Tag.content_sequence()].value
      child_codes = Enum.map(children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "11957-8" in child_codes
    end
  end

  describe "PatientRadiationDose" do
    test "builds a minimal TID 10030 document with observer only" do
      {:ok, document} =
        PatientRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.500",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.501",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.502",
          observer_name: "PHYSICIST^DOSE"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113701"
      assert String.trim(template_identifier(parsed)) == "10030"
    end

    test "builds a TID 10030 document with dose estimates" do
      {:ok, document} =
        PatientRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.510",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.511",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.512",
          observer_name: "PHYSICIST^DOSE",
          dose_estimates: [
            %{
              dose_type: Codes.effective_dose(),
              dose_value: %{value: 8.2, units: Code.new("mSv", "UCUM", "millisievert")},
              methodology: "Monte Carlo simulation",
              parameters: ["Body weight: 70 kg", "Body height: 175 cm"]
            }
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "113703" in concept_codes

      dose_estimate =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113703"
        end)

      estimate_children = dose_estimate[Tag.content_sequence()].value

      estimate_child_codes =
        Enum.map(estimate_children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "113813" in estimate_child_codes
      assert "113835" in estimate_child_codes
      assert "113834" in estimate_child_codes

      parameter_items =
        Enum.filter(estimate_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113834"
        end)

      assert length(parameter_items) == 2
    end

    test "builds a TID 10030 document with multiple dose estimates" do
      {:ok, document} =
        PatientRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.520",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.521",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.522",
          observer_name: "PHYSICIST^DOSE",
          dose_estimates: [
            %{
              dose_type: Codes.effective_dose(),
              dose_value: %{value: 8.2, units: Code.new("mSv", "UCUM", "millisievert")}
            },
            %{
              dose_type: Codes.organ_dose(),
              dose_value: %{value: 15.3, units: Code.new("mSv", "UCUM", "millisievert")},
              methodology: Code.new("113841", "DCM", "ICRP Publication 103")
            }
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      dose_estimates =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113703"
        end)

      assert length(dose_estimates) == 2

      coded_methodology_estimate = Enum.at(dose_estimates, 1)

      methodology_item =
        coded_methodology_estimate[Tag.content_sequence()].value
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113835"
        end)

      assert String.trim(methodology_item[Tag.value_type()].value) == "CODE"
    end

    test "handles code-based parameters and nil optional fields" do
      {:ok, document} =
        PatientRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.540",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.541",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.542",
          observer_name: "PHYSICIST^DOSE",
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.543"],
          dose_estimates: [
            %{
              parameters: [
                Code.new("113842", "DCM", "Standard adult phantom"),
                "Custom parameter"
              ]
            }
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
      assert "113703" in concept_codes

      dose_estimate =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113703"
        end)

      parameter_items =
        dose_estimate[Tag.content_sequence()].value
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113834"
        end)

      assert length(parameter_items) == 2

      value_types =
        Enum.map(parameter_items, fn item ->
          String.trim(item[Tag.value_type()].value)
        end)

      assert "CODE" in value_types
      assert "TEXT" in value_types
    end

    test "serializes to P10 binary and round-trips" do
      {:ok, document} =
        PatientRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.530",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.531",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.532",
          observer_name: "PHYSICIST^DOSE",
          dose_estimates: [
            %{
              dose_type: Codes.effective_dose(),
              dose_value: %{value: 5.0, units: Code.new("mSv", "UCUM", "millisievert")}
            }
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert String.trim(DataSet.get(parsed, Tag.series_description())) ==
               "Patient Radiation Dose Report"
    end
  end

  describe "PerformedImagingAgentAdministration" do
    test "builds a basic TID 11020 performed administration document" do
      {:ok, document} =
        PerformedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.500",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.501",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.502",
          observer_name: "NURSE^FRANK",
          agent_name: "Visipaque 320"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113520"
      assert String.trim(template_identifier(parsed)) == "11020"

      content = DataSet.get(parsed, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
      assert "113500" in concept_codes

      agent_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113500"
        end)

      [agent_name_item] = agent_container[Tag.content_sequence()].value
      assert String.trim(agent_name_item[Tag.text_value()].value) == "Visipaque 320"
    end

    test "builds a TID 11020 document with actual volumes and times" do
      ml_units = Code.new("ml", "UCUM", "milliliter")
      ml_per_s_units = Code.new("ml/s", "UCUM", "milliliter per second")

      {:ok, document} =
        PerformedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.510",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.511",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.512",
          observer_name: "NURSE^FRANK",
          agent_name: "Visipaque 320",
          dose: {95, ml_units},
          volume: {100, ml_units},
          flow_rate: {3.5, ml_per_s_units},
          start_time: ~N[2026-03-22 09:30:00],
          end_time: ~N[2026-03-22 09:31:30],
          injection_site: "Right antecubital fossa",
          route: Codes.intravenous_route()
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Agent info and activity containers
      assert "113500" in concept_codes
      assert "113521" in concept_codes

      activity_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113521"
        end)

      activity_children = activity_container[Tag.content_sequence()].value

      activity_codes =
        Enum.map(activity_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Actual dose, actual volume, flow rate, start datetime, end datetime, injection site
      assert "113521" in activity_codes
      assert "113522" in activity_codes
      assert "424254007" in activity_codes
      assert "113509" in activity_codes
      assert "113510" in activity_codes
      assert "246513007" in activity_codes
    end

    test "builds a TID 11020 document with adverse events" do
      {:ok, document} =
        PerformedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.520",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.521",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.522",
          observer_name: "NURSE^FRANK",
          agent_name: "Visipaque 320",
          adverse_events: [
            "Mild nausea",
            Code.new("271807003", "SCT", "Eruption of skin")
          ],
          consumables: ["20G IV catheter", "Power injector syringe 200ml"]
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Adverse events (Codes.adverse_event() = "121071") and consumables are present
      assert Enum.count(concept_codes, &(&1 == "121071")) == 2
      assert Enum.count(concept_codes, &(&1 == "113541")) == 2

      # Verify text and code adverse events
      adverse_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121071"
        end)

      value_types = Enum.map(adverse_items, fn item -> item[Tag.value_type()].value end)
      assert "TEXT" in value_types
      assert "CODE" in value_types
    end

    test "supports concentration, code-based injection site, and empty optional lists" do
      mg_per_ml = Code.new("mg/ml", "UCUM", "milligram per milliliter")
      ml_units = Code.new("ml", "UCUM", "milliliter")
      left_arm = Code.new("368208006", "SCT", "Left upper arm structure")

      {:ok, document} =
        PerformedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.540",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.541",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.542",
          observer_name: "NURSE^FRANK",
          agent_name: "Gadovist",
          concentration: {604.72, mg_per_ml},
          dose: {10, ml_units},
          injection_site: left_arm,
          adverse_events: [],
          consumables: []
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Agent container has concentration
      agent_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113500"
        end)

      agent_child_codes =
        agent_container[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "118555000" in agent_child_codes

      # Activity container has code-based injection site
      activity_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113521"
        end)

      activity_children = activity_container[Tag.content_sequence()].value

      injection_item =
        Enum.find(activity_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "246513007"
        end)

      assert injection_item[Tag.value_type()].value == "CODE"

      # Empty adverse_events and consumables are omitted
      refute "113540" in concept_codes
      refute "113541" in concept_codes
    end

    test "document metadata has correct series description and template identifier" do
      {:ok, document} =
        PerformedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.530",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.531",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.532",
          observer_name: "NURSE^FRANK",
          agent_name: "Gadovist"
        )

      assert document.template_identifier == "11020"
      assert document.series_description == "Performed Imaging Agent Administration"

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.series_description()) ==
               "Performed Imaging Agent Administration"
    end
  end

  describe "PlannedImagingAgentAdministration" do
    test "builds a basic TID 11001 planned administration document" do
      {:ok, document} =
        PlannedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402",
          observer_name: "RADIOLOGIST^EVE",
          agent_name: "Omnipaque 350"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113501"
      assert String.trim(template_identifier(parsed)) == "11001"

      content = DataSet.get(parsed, Tag.content_sequence())

      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Language, Observer Type, Observer Name, Agent Information container
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
      assert "113500" in concept_codes

      agent_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113500"
        end)

      [agent_name_item] = agent_container[Tag.content_sequence()].value
      assert String.trim(agent_name_item[Tag.text_value()].value) == "Omnipaque 350"
    end

    test "builds a TID 11001 document with dose, flow rate, and concentration" do
      ml_units = Code.new("ml", "UCUM", "milliliter")
      ml_per_s_units = Code.new("ml/s", "UCUM", "milliliter per second")
      mg_per_ml = Code.new("mg/ml", "UCUM", "milligram per milliliter")

      {:ok, document} =
        PlannedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.410",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.411",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.412",
          observer_name: "RADIOLOGIST^EVE",
          agent_name: "Omnipaque 350",
          concentration: {350, mg_per_ml},
          dose: {100, ml_units},
          volume: {120, ml_units},
          flow_rate: {4.5, ml_per_s_units},
          route: Codes.intravenous_route()
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Agent info container is present
      assert "113500" in concept_codes
      # Administration activity container is present (uses Planned Dose as container concept)
      assert "113502" in concept_codes

      agent_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113500"
        end)

      agent_children = agent_container[Tag.content_sequence()].value

      agent_child_codes =
        Enum.map(agent_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Agent name, concentration, route
      assert "113500" in agent_child_codes
      assert "118555000" in agent_child_codes
      assert "410675002" in agent_child_codes

      activity_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113502"
        end)

      activity_children = activity_container[Tag.content_sequence()].value

      activity_codes =
        Enum.map(activity_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Planned dose, planned volume, flow rate
      assert "113502" in activity_codes
      assert "113503" in activity_codes
      assert "424254007" in activity_codes
    end

    test "builds a TID 11001 document with patient characteristics" do
      kg_units = Code.new("kg", "UCUM", "kilogram")

      ml_per_min_units =
        Code.new("ml/min/{1.73_m2}", "UCUM", "milliliter per minute per 1.73 sq m")

      {:ok, document} =
        PlannedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.420",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.421",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.422",
          observer_name: "RADIOLOGIST^EVE",
          agent_name: "Omnipaque 350",
          patient_weight: {75.5, kg_units},
          kidney_function: {90, ml_per_min_units}
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Patient characteristics container (uses patient_weight as container concept)
      assert "27113001" in concept_codes

      patient_container =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "27113001"
        end)

      patient_children = patient_container[Tag.content_sequence()].value

      patient_codes =
        Enum.map(patient_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Body weight, GFR
      assert "27113001" in patient_codes
      assert "80274001" in patient_codes
    end

    test "document metadata has correct series description and template identifier" do
      {:ok, document} =
        PlannedImagingAgentAdministration.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.430",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.431",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.432",
          observer_name: "RADIOLOGIST^EVE",
          agent_name: "Gadovist"
        )

      assert document.template_identifier == "11001"
      assert document.series_description == "Planned Imaging Agent Administration"

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.series_description()) ==
               "Planned Imaging Agent Administration"
    end
  end

  describe "ProcedureLog" do
    test "builds a TID 3001 document with a single log entry and serializes to P10" do
      entry =
        LogEntry.new(
          ~N[2026-03-22 09:15:30],
          :image_acquisition,
          "Fluoroscopy run 1"
        )

      {:ok, document} =
        ProcedureLog.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402",
          observer_name: "OPERATOR^DAVID",
          log_entries: [entry]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "121145"
      assert template_identifier(parsed) == "3001"

      [language, observer_type, observer_name, log_entry] =
        DataSet.get(parsed, Tag.content_sequence())

      assert code_value(language, Tag.concept_name_code_sequence()) == "121049"
      assert code_value(observer_type, Tag.concept_name_code_sequence()) == "121005"
      assert observer_name[Tag.person_name_value()].value == "OPERATOR^DAVID"
      assert code_value(log_entry, Tag.concept_name_code_sequence()) == "121146"

      [entry_datetime, action] = log_entry[Tag.content_sequence()].value
      assert code_value(entry_datetime, Tag.concept_name_code_sequence()) == "121147"
      assert code_value(action, Tag.concept_name_code_sequence()) == "121149"
      assert String.trim(action[Tag.text_value()].value) == "Fluoroscopy run 1"
    end

    test "builds a TID 3001 document with multiple log entries" do
      entries = [
        LogEntry.new(~N[2026-03-22 09:00:00], :image_acquisition, "Scout image"),
        LogEntry.new(~N[2026-03-22 09:05:00], :drug_administered, "Contrast 50ml"),
        LogEntry.new(~N[2026-03-22 09:10:00], :measurement, "Pressure reading"),
        LogEntry.new(~N[2026-03-22 09:15:00], :text, "Patient repositioned")
      ]

      {:ok, document} =
        ProcedureLog.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.410",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.411",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.412",
          observer_name: "OPERATOR^DAVID",
          log_entries: entries
        )

      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      log_entry_items =
        Enum.filter(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121146"
        end)

      assert length(log_entry_items) == 4
    end

    test "builds log entries with different action types using correct codes" do
      image_entry = LogEntry.new(~N[2026-03-22 09:00:00], :image_acquisition, "Scout")
      drug_entry = LogEntry.new(~N[2026-03-22 09:05:00], :drug_administered, "Contrast")
      measurement_entry = LogEntry.new(~N[2026-03-22 09:10:00], :measurement, "BP reading")
      text_entry = LogEntry.new(~N[2026-03-22 09:15:00], :text, "Note")

      image_item = LogEntry.to_content_item(image_entry) |> ContentItem.to_item()
      drug_item = LogEntry.to_content_item(drug_entry) |> ContentItem.to_item()
      measurement_item = LogEntry.to_content_item(measurement_entry) |> ContentItem.to_item()
      text_item = LogEntry.to_content_item(text_entry) |> ContentItem.to_item()

      [_dt, image_action] = image_item[Tag.content_sequence()].value
      assert code_value(image_action, Tag.concept_name_code_sequence()) == "121149"

      [_dt, drug_action] = drug_item[Tag.content_sequence()].value
      assert code_value(drug_action, Tag.concept_name_code_sequence()) == "121150"

      [_dt, measurement_action] = measurement_item[Tag.content_sequence()].value
      assert code_value(measurement_action, Tag.concept_name_code_sequence()) == "121148"

      [_dt, text_action] = text_item[Tag.content_sequence()].value
      assert code_value(text_action, Tag.concept_name_code_sequence()) == "121148"
    end

    test "supports code-based action descriptions" do
      action_code = Code.new("P5-09051", "SRT", "Chest CT")
      entry = LogEntry.new(~N[2026-03-22 09:00:00], :image_acquisition, action_code)
      item = LogEntry.to_content_item(entry) |> ContentItem.to_item()

      [_dt, action] = item[Tag.content_sequence()].value
      assert action[Tag.value_type()].value == "CODE"
      assert code_value(action, Tag.concept_code_sequence()) == "P5-09051"
    end

    test "supports optional procedure_reported codes" do
      entry = LogEntry.new(~N[2026-03-22 09:00:00], :text, "Start")

      {:ok, document} =
        ProcedureLog.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.420",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.421",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.422",
          observer_name: "OPERATOR^DAVID",
          log_entries: [entry],
          procedure_reported: Code.new("77477000", "SCT", "CT scan")
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121058" in concept_codes
    end

    test "supports log entry details with consumable items" do
      entry =
        LogEntry.new(
          ~N[2026-03-22 09:10:00],
          :drug_administered,
          "Contrast injection",
          consumable: "Iodinated contrast 100ml"
        )

      item = LogEntry.to_content_item(entry) |> ContentItem.to_item()
      [_dt, _action, consumable] = item[Tag.content_sequence()].value
      assert code_value(consumable, Tag.concept_name_code_sequence()) == "121170"
      assert consumable[Tag.text_value()].value == "Iodinated contrast 100ml"
    end

    test "supports code-based consumable details" do
      consumable_code = Code.new("44588005", "SCT", "Iodinated contrast media")

      entry =
        LogEntry.new(
          ~N[2026-03-22 09:10:00],
          :drug_administered,
          "Contrast injection",
          consumable: consumable_code
        )

      item = LogEntry.to_content_item(entry) |> ContentItem.to_item()
      [_dt, _action, consumable] = item[Tag.content_sequence()].value
      assert code_value(consumable, Tag.concept_name_code_sequence()) == "121170"
      assert consumable[Tag.value_type()].value == "CODE"
      assert code_value(consumable, Tag.concept_code_sequence()) == "44588005"
    end

    test "omits device observer context when observer_device is nil" do
      entry = LogEntry.new(~N[2026-03-22 09:00:00], :text, "Start")

      {:ok, document} =
        ProcedureLog.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.440",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.441",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.442",
          observer_name: "OPERATOR^DAVID",
          log_entries: [entry],
          observer_device: nil
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
    end

    test "includes device observer context when observer_device is provided" do
      entry = LogEntry.new(~N[2026-03-22 09:00:00], :text, "Start")

      {:ok, document} =
        ProcedureLog.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.450",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.451",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.452",
          observer_name: "OPERATOR^DAVID",
          log_entries: [entry],
          observer_device: [
            uid: "1.2.826.0.1.3680043.10.1137.453",
            name: "SCANNER-01"
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
    end

    test "round-trips a procedure log through P10 serialization" do
      entries = [
        LogEntry.new(~N[2026-03-22 08:00:00], :image_acquisition, "Pre-procedure scout"),
        LogEntry.new(~N[2026-03-22 08:30:00], :drug_administered, "Lidocaine 2% 5ml")
      ]

      {:ok, document} =
        ProcedureLog.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.430",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.431",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.432",
          observer_name: "OPERATOR^DAVID",
          log_entries: entries,
          procedure_reported: [
            Code.new("77477000", "SCT", "CT scan"),
            Code.new("71651007", "SCT", "Mammography")
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert code_value(parsed, Tag.concept_name_code_sequence()) == "121145"
      assert template_identifier(parsed) == "3001"

      content_items = DataSet.get(parsed, Tag.content_sequence())

      procedure_codes =
        content_items
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121058"
        end)

      assert length(procedure_codes) == 2

      log_entries =
        Enum.filter(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121146"
        end)

      assert length(log_entries) == 2

      [first_entry | _] = log_entries
      first_children = first_entry[Tag.content_sequence()].value

      datetime_item =
        Enum.find(first_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121147"
        end)

      assert datetime_item[Tag.value_type()].value == "DATETIME"
    end
  end

  describe "ProstateMRReport" do
    @prostate_uid_prefix "1.2.826.0.1.3680043.10.1137.4300"

    defp prostate_base_opts(suffix) do
      [
        study_instance_uid: "#{@prostate_uid_prefix}.#{suffix}.1",
        series_instance_uid: "#{@prostate_uid_prefix}.#{suffix}.2",
        sop_instance_uid: "#{@prostate_uid_prefix}.#{suffix}.3",
        observer_name: "RADIOLOGIST^SMITH"
      ]
    end

    test "builds a basic report with observer context and serializes to P10" do
      {:ok, document} = ProstateMRReport.new(prostate_base_opts("10"))
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"

      # Verify on pre-roundtrip data_set for exact code matching
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "72230-6"
      assert template_identifier(data_set) == "4300"

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
    end

    test "includes PSA and prostate volume in imaging findings" do
      psa =
        Measurement.new(
          Codes.psa_level(),
          4.5,
          Code.new("ng/mL", "UCUM", "nanograms per milliliter")
        )

      vol =
        Measurement.new(
          Codes.prostate_volume(),
          35,
          Code.new("mL", "UCUM", "milliliters")
        )

      opts =
        prostate_base_opts("20")
        |> Keyword.merge(
          patient_history: %{psa: psa},
          prostate_volume: vol
        )

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      # Patient history container
      history =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121060"
        end)

      assert history != nil
      history_children = history[Tag.content_sequence()].value

      history_codes =
        Enum.map(history_children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "2857-1" in history_codes

      # Prostate imaging findings container
      findings =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126200"
        end)

      assert findings != nil
      findings_children = findings[Tag.content_sequence()].value

      assert Enum.any?(findings_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 code_value(item, Tag.concept_name_code_sequence()) == "118565006"
             end)
    end

    test "builds a single PI-RADS lesion with sector location" do
      opts =
        prostate_base_opts("30")
        |> Keyword.merge(
          localized_findings: [
            %{
              location: Codes.peripheral_zone(),
              size: 12,
              t2w_score: 4,
              dwi_score: 5,
              dce_score: 1,
              pirads_category: 4
            }
          ]
        )

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      findings =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126200"
        end)

      assert findings != nil
      findings_children = findings[Tag.content_sequence()].value

      localized =
        Enum.find(findings_children, fn item ->
          item[Tag.value_type()].value == "CONTAINER" and
            code_value(item, Tag.concept_name_code_sequence()) == "126403"
        end)

      assert localized != nil
      localized_children = localized[Tag.content_sequence()].value

      # Finding site (location)
      assert Enum.any?(localized_children, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "363698007" and
                 code_value(item, Tag.concept_code_sequence()) == "279706003"
             end)

      # Lesion size
      assert Enum.any?(localized_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 code_value(item, Tag.concept_name_code_sequence()) == "246120007"
             end)

      # T2W score
      assert Enum.any?(localized_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 code_value(item, Tag.concept_name_code_sequence()) == "126420"
             end)

      # DWI score
      assert Enum.any?(localized_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 code_value(item, Tag.concept_name_code_sequence()) == "126421"
             end)

      # DCE score
      assert Enum.any?(localized_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 code_value(item, Tag.concept_name_code_sequence()) == "126422"
             end)

      # PI-RADS assessment category (4 = "High" = 126413)
      assert Enum.any?(localized_children, fn item ->
               item[Tag.value_type()].value == "CODE" and
                 code_value(item, Tag.concept_name_code_sequence()) == "126400" and
                 code_value(item, Tag.concept_code_sequence()) == "126413"
             end)
    end

    test "builds multiple lesions with different sector locations" do
      opts =
        prostate_base_opts("40")
        |> Keyword.merge(
          localized_findings: [
            %{
              location: Codes.peripheral_zone(),
              size: 15,
              t2w_score: 4,
              dwi_score: 5,
              dce_score: 1,
              pirads_category: 4
            },
            %{
              location: Codes.transition_zone(),
              size: 8,
              t2w_score: 3,
              dwi_score: 3,
              dce_score: 1,
              pirads_category: 3
            },
            %{
              location: Codes.central_zone(),
              pirads_category: Codes.pirads_category_2()
            }
          ]
        )

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      findings =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126200"
        end)

      findings_children = findings[Tag.content_sequence()].value

      localized_count =
        Enum.count(findings_children, fn item ->
          item[Tag.value_type()].value == "CONTAINER" and
            code_value(item, Tag.concept_name_code_sequence()) == "126403"
        end)

      assert localized_count == 3

      # Verify different zones are represented
      zones =
        findings_children
        |> Enum.filter(fn item ->
          item[Tag.value_type()].value == "CONTAINER" and
            code_value(item, Tag.concept_name_code_sequence()) == "126403"
        end)
        |> Enum.map(fn lesion ->
          site =
            lesion[Tag.content_sequence()].value
            |> Enum.find(fn child ->
              code_value(child, Tag.concept_name_code_sequence()) == "363698007"
            end)

          code_value(site, Tag.concept_code_sequence())
        end)

      assert "279706003" in zones
      assert "279709005" in zones
      assert "279710000" in zones
    end

    test "includes extraprostatic findings" do
      opts =
        prostate_base_opts("50")
        |> Keyword.merge(
          extraprostatic_findings: [
            Codes.seminal_vesicle_invasion(),
            Codes.extraprostatic_extension(),
            "Suspicious pelvic lymph node"
          ]
        )

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      findings =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126200"
        end)

      findings_children = findings[Tag.content_sequence()].value

      extraprostatic =
        Enum.filter(findings_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126404"
        end)

      assert length(extraprostatic) == 3

      code_items = Enum.count(extraprostatic, &(&1[Tag.value_type()].value == "CODE"))
      text_items = Enum.count(extraprostatic, &(&1[Tag.value_type()].value == "TEXT"))
      assert code_items == 2
      assert text_items == 1
    end

    test "builds a full report with all sections" do
      psa =
        Measurement.new(
          Codes.psa_level(),
          8.2,
          Code.new("ng/mL", "UCUM", "nanograms per milliliter")
        )

      vol =
        Measurement.new(
          Codes.prostate_volume(),
          42,
          Code.new("mL", "UCUM", "milliliters")
        )

      psa_density =
        Measurement.new(
          Codes.psa_density(),
          0.195,
          Code.new("ng/mL2", "UCUM", "ng/mL/mL")
        )

      opts =
        prostate_base_opts("60")
        |> Keyword.merge(
          procedure_reported: Code.new("72230-6", "LN", "MR Prostate"),
          patient_history: %{
            psa: psa,
            prior_biopsies: "Negative biopsy 2024",
            family_history: "Brother diagnosed with prostate cancer at 62"
          },
          prostate_volume: vol,
          psa_density: psa_density,
          overall_assessment: Codes.pirads_category_4(),
          localized_findings: [
            %{
              location: Codes.peripheral_zone(),
              size: 18,
              t2w_score: 4,
              dwi_score: 5,
              dce_score: 1,
              pirads_category: 5,
              likert_score: 5
            },
            %{
              location: Codes.transition_zone(),
              size: 9,
              t2w_score: 3,
              dwi_score: 3,
              dce_score: 1,
              pirads_category: 3
            }
          ],
          extraprostatic_findings: [
            Codes.extraprostatic_extension()
          ],
          findings: ["Dominant lesion in right peripheral zone"],
          impressions: ["PI-RADS 5: Very high suspicion for clinically significant cancer"],
          recommendations: ["Recommend targeted MR-guided biopsy"]
        )

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert template_identifier(data_set) == "4300"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "72230-6"

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Language + Observer context
      assert "121049" in concept_codes
      assert "121005" in concept_codes

      # Procedure reported
      assert "121058" in concept_codes

      # Patient history
      assert "121060" in concept_codes

      # Prostate imaging findings
      assert "126200" in concept_codes

      # Findings / Impressions / Recommendations
      assert "121071" in concept_codes
      assert "121073" in concept_codes
      assert "121075" in concept_codes

      # Verify overall assessment is within imaging findings
      findings =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126200"
        end)

      findings_children = findings[Tag.content_sequence()].value

      findings_codes =
        Enum.map(findings_children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "118565006" in findings_codes
      assert "126401" in findings_codes
      # Overall assessment (Codes.overall_assessment() = "111037")
      assert "111037" in findings_codes
      assert "126403" in findings_codes
      assert "126404" in findings_codes

      # Verify patient history children
      history =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121060"
        end)

      history_children = history[Tag.content_sequence()].value

      history_codes =
        Enum.map(history_children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "2857-1" in history_codes
      assert "65854-2" in history_codes
      assert "10157-6" in history_codes

      # Verify likert score is present in first lesion
      first_lesion =
        Enum.find(findings_children, fn item ->
          item[Tag.value_type()].value == "CONTAINER" and
            code_value(item, Tag.concept_name_code_sequence()) == "126403"
        end)

      lesion_children = first_lesion[Tag.content_sequence()].value

      assert Enum.any?(lesion_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 code_value(item, Tag.concept_name_code_sequence()) == "126423"
             end)

      # Verify full round-trip through P10
      {:ok, binary} = Dicom.write(data_set)
      {:ok, _parsed} = Dicom.parse(binary)
    end

    test "supports Measurement struct for lesion size" do
      size_measurement =
        Measurement.new(
          Codes.lesion_size(),
          14.5,
          Code.new("mm", "UCUM", "millimeters")
        )

      opts =
        prostate_base_opts("75")
        |> Keyword.merge(
          localized_findings: [
            %{
              location: Codes.anterior_fibromuscular_stroma(),
              size: size_measurement,
              pirads_category: 2
            }
          ]
        )

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      findings =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126200"
        end)

      localized =
        Enum.find(findings[Tag.content_sequence()].value, fn item ->
          item[Tag.value_type()].value == "CONTAINER" and
            code_value(item, Tag.concept_name_code_sequence()) == "126403"
        end)

      localized_children = localized[Tag.content_sequence()].value

      # AFS zone
      assert Enum.any?(localized_children, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "363698007" and
                 code_value(item, Tag.concept_code_sequence()) == "253718006"
             end)

      # Size as NUM
      assert Enum.any?(localized_children, fn item ->
               item[Tag.value_type()].value == "NUM" and
                 code_value(item, Tag.concept_name_code_sequence()) == "246120007"
             end)

      # PI-RADS 2 = "Low" = 126411
      assert Enum.any?(localized_children, fn item ->
               item[Tag.value_type()].value == "CODE" and
                 code_value(item, Tag.concept_code_sequence()) == "126411"
             end)
    end

    test "omits empty patient history and imaging findings containers" do
      {:ok, document} =
        ProstateMRReport.new(
          prostate_base_opts("80")
          |> Keyword.merge(patient_history: %{})
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Empty patient_history map should not produce a container
      refute "121060" in concept_codes

      # No imaging findings options should not produce a container
      refute "126200" in concept_codes
    end

    test "supports code-based findings, impressions, and recommendations" do
      opts =
        prostate_base_opts("85")
        |> Keyword.merge(
          findings: [Code.new("111111", "99LOCAL", "Suspicious lesion")],
          impressions: [Code.new("222222", "99LOCAL", "Clinically significant")],
          recommendations: [Code.new("333333", "99LOCAL", "Biopsy recommended")]
        )

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
      assert "121073" in concept_codes
      assert "121075" in concept_codes

      finding =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121071"
        end)

      assert finding[Tag.value_type()].value == "CODE"
      assert code_value(finding, Tag.concept_code_sequence()) == "111111"
    end

    test "supports PI-RADS category 1 integer shorthand" do
      opts =
        prostate_base_opts("90")
        |> Keyword.merge(localized_findings: [%{pirads_category: 1}])

      {:ok, document} = ProstateMRReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      findings =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "126200"
        end)

      localized =
        Enum.find(findings[Tag.content_sequence()].value, fn item ->
          item[Tag.value_type()].value == "CONTAINER" and
            code_value(item, Tag.concept_name_code_sequence()) == "126403"
        end)

      # PI-RADS 1 = "Very low" = 126410
      assert Enum.any?(localized[Tag.content_sequence()].value, fn item ->
               item[Tag.value_type()].value == "CODE" and
                 code_value(item, Tag.concept_code_sequence()) == "126410"
             end)
    end

    test "document metadata includes template_identifier 4300" do
      {:ok, document} = ProstateMRReport.new(prostate_base_opts("70"))

      assert document.template_identifier == "4300"
      assert document.series_description == "Prostate Multiparametric MR Imaging Report"
    end
  end

  describe "RadiopharmaceuticalRadiationDose" do
    test "builds a minimal TID 10021 document with observer only" do
      {:ok, document} =
        RadiopharmaceuticalRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.400",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.401",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.402",
          observer_name: "PHYSICIST^NUKE"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113500"
      assert String.trim(template_identifier(parsed)) == "10021"

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
    end

    test "builds a TID 10021 document with administration events and organ doses" do
      {:ok, document} =
        RadiopharmaceuticalRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.410",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.411",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.412",
          observer_name: "PHYSICIST^NUKE",
          procedure_reported: Code.new("40701008", "SCT", "Nuclear medicine procedure"),
          administration_events: [
            %{
              radiopharmaceutical: Code.new("35321007", "SCT", "Fluorodeoxyglucose"),
              radionuclide: Code.new("21613005", "SCT", "Fluorine-18"),
              administered_activity: %{
                value: 370,
                units: Code.new("MBq", "UCUM", "megabecquerel")
              },
              route_of_administration: Code.new("47625008", "SCT", "Intravenous route"),
              administration_datetime: ~N[2026-03-20 09:30:00]
            }
          ],
          organ_doses: [
            %{
              target_organ: Code.new("64033007", "SCT", "Kidney"),
              dose: %{value: 12.5, units: Code.new("mSv", "UCUM", "millisievert")}
            }
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121058" in concept_codes
      assert "113502" in concept_codes
      assert "113504" in concept_codes

      admin_event =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113502"
        end)

      admin_children = admin_event[Tag.content_sequence()].value

      admin_child_codes =
        admin_children
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
        |> Enum.map(&String.trim/1)

      assert "349358000" in admin_child_codes
      assert "89457008" in admin_child_codes
      assert "113508" in admin_child_codes
      assert "410675002" in admin_child_codes
      assert "113507" in admin_child_codes

      organ_item =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          String.trim(code_value(item, Tag.concept_name_code_sequence())) == "113504"
        end)

      organ_children = organ_item[Tag.content_sequence()].value

      organ_child_codes =
        organ_children
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
        |> Enum.map(&String.trim/1)

      assert "363698007" in organ_child_codes
      assert "113840" in organ_child_codes
    end

    test "builds a TID 10021 document with partial administration event data" do
      {:ok, document} =
        RadiopharmaceuticalRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.430",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.431",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.432",
          observer_name: "PHYSICIST^NUKE",
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.433"],
          administration_events: [
            %{
              radiopharmaceutical: Code.new("35321007", "SCT", "Fluorodeoxyglucose")
            }
          ],
          organ_doses: [
            %{
              target_organ: Code.new("64033007", "SCT", "Kidney")
            }
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121012" in concept_codes
      assert "113502" in concept_codes
      assert "113504" in concept_codes
    end

    test "builds a TID 10021 document with multiple administration events" do
      events =
        for i <- 1..3 do
          %{
            radiopharmaceutical: Code.new("35321007", "SCT", "Fluorodeoxyglucose"),
            administered_activity: %{
              value: 300 + i * 10,
              units: Code.new("MBq", "UCUM", "megabecquerel")
            }
          }
        end

      {:ok, document} =
        RadiopharmaceuticalRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.420",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.421",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.422",
          observer_name: "PHYSICIST^NUKE",
          administration_events: events
        )

      {:ok, data_set} = Document.to_data_set(document)

      admin_events =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113502"
        end)

      assert length(admin_events) == 3
    end
  end

  describe "SpectaclePrescriptionReport" do
    @uid_base "1.2.826.0.1.3680043.10.1137.2020"

    test "builds a single-eye prescription" do
      {:ok, document} =
        SpectaclePrescriptionReport.new(
          study_instance_uid: "#{@uid_base}.100",
          series_instance_uid: "#{@uid_base}.101",
          sop_instance_uid: "#{@uid_base}.102",
          observer_name: "OPTOMETRIST^ALICE",
          prescriptions: [
            %{eye: :right, sphere: -2.50, cylinder: -0.75, axis: 180}
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert String.trim(code_value(parsed, Tag.concept_name_code_sequence())) == "70946-7"
      assert template_identifier(parsed) == "2020"

      content = DataSet.get(parsed, Tag.content_sequence())
      # language, observer_type, observer_name, prescription
      assert length(content) == 4

      prescription = List.last(content)
      assert String.trim(prescription[Tag.value_type()].value) == "CONTAINER"
      assert String.trim(code_value(prescription, Tag.concept_name_code_sequence())) == "70947-5"

      rx_children = prescription[Tag.content_sequence()].value

      laterality_item =
        Enum.find(
          rx_children,
          &(String.trim(code_value(&1, Tag.concept_name_code_sequence())) == "272741003")
        )

      assert String.trim(code_value(laterality_item, Tag.concept_code_sequence())) == "81745001"

      sphere_item =
        Enum.find(
          rx_children,
          &(String.trim(code_value(&1, Tag.concept_name_code_sequence())) == "251795007")
        )

      assert sphere_item != nil

      cylinder_item =
        Enum.find(
          rx_children,
          &(String.trim(code_value(&1, Tag.concept_name_code_sequence())) == "251797004")
        )

      assert cylinder_item != nil

      axis_item =
        Enum.find(
          rx_children,
          &(String.trim(code_value(&1, Tag.concept_name_code_sequence())) == "251799001")
        )

      assert axis_item != nil
    end

    test "builds a bilateral prescription" do
      {:ok, document} =
        SpectaclePrescriptionReport.new(
          study_instance_uid: "#{@uid_base}.110",
          series_instance_uid: "#{@uid_base}.111",
          sop_instance_uid: "#{@uid_base}.112",
          observer_name: "OPTOMETRIST^BOB",
          prescriptions: [
            %{eye: :right, sphere: -1.00, cylinder: -0.50, axis: 90},
            %{eye: :left, sphere: -1.25, cylinder: -0.75, axis: 85}
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      prescription_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "70947-5"
        end)

      assert length(prescription_items) == 2

      [right_rx, left_rx] = prescription_items

      right_laterality =
        Enum.find(
          right_rx[Tag.content_sequence()].value,
          &(code_value(&1, Tag.concept_name_code_sequence()) == "272741003")
        )

      assert code_value(right_laterality, Tag.concept_code_sequence()) == "81745001"

      left_laterality =
        Enum.find(
          left_rx[Tag.content_sequence()].value,
          &(code_value(&1, Tag.concept_name_code_sequence()) == "272741003")
        )

      assert code_value(left_laterality, Tag.concept_code_sequence()) == "8966001"
    end

    test "builds a prescription with add power (progressive lens)" do
      {:ok, document} =
        SpectaclePrescriptionReport.new(
          study_instance_uid: "#{@uid_base}.120",
          series_instance_uid: "#{@uid_base}.121",
          sop_instance_uid: "#{@uid_base}.122",
          observer_name: "OPTOMETRIST^CAROL",
          prescriptions: [
            %{
              eye: :right,
              sphere: -2.00,
              cylinder: -0.50,
              axis: 175,
              add_power: 2.00,
              prism_power: 1.5,
              prism_base: "IN",
              interpupillary_distance: 32.0
            }
          ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      prescription =
        Enum.find(content, &(code_value(&1, Tag.concept_name_code_sequence()) == "70947-5"))

      rx_children = prescription[Tag.content_sequence()].value

      concept_codes = Enum.map(rx_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # add power (251718005)
      assert "251718005" in concept_codes
      # prism power (246223004)
      assert "246223004" in concept_codes
      # prism base (246224005)
      assert "246224005" in concept_codes
      # interpupillary distance (251762001)
      assert "251762001" in concept_codes

      prism_base_item =
        Enum.find(rx_children, &(code_value(&1, Tag.concept_name_code_sequence()) == "246224005"))

      assert prism_base_item[Tag.text_value()].value == "IN"
    end

    test "document metadata for spectacle prescription" do
      {:ok, document} =
        SpectaclePrescriptionReport.new(
          study_instance_uid: "#{@uid_base}.130",
          series_instance_uid: "#{@uid_base}.131",
          sop_instance_uid: "#{@uid_base}.132",
          observer_name: "OPTOMETRIST^DAVE",
          prescriptions: [%{eye: :left, sphere: 0.50}],
          patient_name: "PATIENT^TEST",
          patient_id: "P001"
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.patient_name()) |> String.trim() == "PATIENT^TEST"
      assert DataSet.get(parsed, Tag.patient_id()) == "P001"

      assert DataSet.get(parsed, Tag.series_description()) |> String.trim() ==
               "Spectacle Prescription Report"
    end
  end

  describe "TranscribedDiagnosticImagingReport" do
    @study_uid "1.2.826.0.1.3680043.10.1137.2005.1"
    @series_uid "1.2.826.0.1.3680043.10.1137.2005.2"
    @sop_uid "1.2.826.0.1.3680043.10.1137.2005.3"

    defp base_opts(extra \\ []) do
      Keyword.merge(
        [
          study_instance_uid: @study_uid,
          series_instance_uid: @series_uid,
          sop_instance_uid: @sop_uid,
          observer_name: "SMITH^JOHN",
          narrative: "The chest radiograph shows no acute cardiopulmonary disease."
        ],
        extra
      )
    end

    test "builds a TID 2005 document with required fields only" do
      {:ok, document} = TranscribedDiagnosticImagingReport.new(base_opts())

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"

      assert DataSet.decoded_value(data_set, Tag.sop_class_uid()) ==
               Dicom.UID.basic_text_sr_storage()

      assert code_value(data_set, Tag.concept_name_code_sequence()) == "18782-3"
      assert template_identifier(data_set) == "2005"

      content = DataSet.get(data_set, Tag.content_sequence())

      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Language
      assert "121049" in concept_codes
      # Observer Type (person)
      assert "121005" in concept_codes
      # Person Observer Name
      assert "121008" in concept_codes
      # Narrative Summary
      assert "111412" in concept_codes
    end

    test "builds a TID 2005 document with all optional fields" do
      {:ok, document} =
        TranscribedDiagnosticImagingReport.new(
          base_opts(
            procedure_reported: Code.new("P5-09051", "SRT", "Chest CT"),
            clinical_information: "Patient presents with shortness of breath.",
            transcriber_name: "DOE^JANE"
          )
        )

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure Reported
      assert "121058" in concept_codes
      # Clinical Information
      assert "55752-0" in concept_codes
      # Transcriber observer (second person observer)
      observer_name_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121008"
        end)

      assert length(observer_name_items) == 2
    end

    test "narrative text is properly encoded as TEXT content item" do
      narrative = "Findings: No acute abnormality.\nImpression: Normal study."

      {:ok, document} = TranscribedDiagnosticImagingReport.new(base_opts(narrative: narrative))
      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      narrative_item =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111412"
        end)

      assert narrative_item[Tag.value_type()].value == "TEXT"
      assert narrative_item[Tag.text_value()].value == narrative
    end

    test "procedure reported accepts a single Code" do
      procedure = Code.new("P5-09051", "SRT", "Chest CT")

      {:ok, document} =
        TranscribedDiagnosticImagingReport.new(base_opts(procedure_reported: procedure))

      {:ok, data_set} = Document.to_data_set(document)

      content = DataSet.get(data_set, Tag.content_sequence())

      procedure_item =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121058"
        end)

      assert procedure_item[Tag.relationship_type()].value == "HAS CONCEPT MOD"
      assert code_value(procedure_item, Tag.concept_code_sequence()) == "P5-09051"
    end

    test "document metadata uses template identifier 2005" do
      {:ok, document} = TranscribedDiagnosticImagingReport.new(base_opts())
      assert document.template_identifier == "2005"
      assert document.sop_class_uid == Dicom.UID.basic_text_sr_storage()
    end

    test "round-trip: build, serialize to data set, write P10, parse back" do
      {:ok, document} =
        TranscribedDiagnosticImagingReport.new(
          base_opts(
            procedure_reported: [Code.new("P5-09051", "SRT", "Chest CT")],
            clinical_information: "Cough for 3 weeks."
          )
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.basic_text_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert String.trim(code_value(parsed, Tag.concept_name_code_sequence())) == "18782-3"
      assert String.trim(template_identifier(parsed)) == "2005"

      content = DataSet.get(parsed, Tag.content_sequence())

      concept_codes =
        Enum.map(content, fn item ->
          String.trim(code_value(item, Tag.concept_name_code_sequence()))
        end)

      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "121008" in concept_codes
      assert "121058" in concept_codes
      assert "111412" in concept_codes
      assert "55752-0" in concept_codes

      narrative_item =
        Enum.find(content, fn item ->
          String.trim(code_value(item, Tag.concept_name_code_sequence())) == "111412"
        end)

      assert narrative_item[Tag.text_value()].value ==
               "The chest radiograph shows no acute cardiopulmonary disease."

      clinical_item =
        Enum.find(content, fn item ->
          String.trim(code_value(item, Tag.concept_name_code_sequence())) == "55752-0"
        end)

      assert clinical_item[Tag.text_value()].value == "Cough for 3 weeks."
    end
  end

  describe "VascularUltrasoundReport" do
    @base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.500",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.501",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.502",
      observer_name: "VASCULAR^DR"
    ]

    test "builds a basic report with only observer" do
      {:ok, document} = VascularUltrasoundReport.new(@base_opts)
      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "36440-4"
      assert template_identifier(data_set) == "5100"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Language + observer type + observer name = 3 items minimum
      assert "121049" in concept_codes
      assert "121005" in concept_codes
    end

    test "builds a single vascular section with velocity measurements" do
      psv =
        Measurement.new(
          Codes.peak_systolic_velocity(),
          125.0,
          Code.new("cm/s", "UCUM", "centimeters per second")
        )

      edv =
        Measurement.new(
          Codes.end_diastolic_velocity(),
          40.0,
          Code.new("cm/s", "UCUM", "centimeters per second")
        )

      section = %{
        location: Code.new("69105007", "SCT", "Carotid artery"),
        measurements: [psv, edv]
      }

      opts = Keyword.put(@base_opts, :vascular_sections, [section])
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Vascular section container present (DCM 121196)
      assert "121196" in concept_codes

      # Drill into vascular section
      vascular = find_by_concept_code(data_set, "121196")
      section_children = vascular[Tag.content_sequence()].value

      # Finding site (anatomical location)
      assert Enum.any?(section_children, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "363698007"
             end)

      # Measurement group with measurements
      mg =
        Enum.find(section_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "125007"
        end)

      assert mg != nil
      mg_children = mg[Tag.content_sequence()].value

      mg_codes =
        Enum.map(mg_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence())
        end)

      # PSV measurement (LN 11726-7)
      assert "11726-7" in mg_codes
      # EDV measurement (LN 11653-3)
      assert "11653-3" in mg_codes
    end

    test "builds multiple vascular sections for bilateral carotid study" do
      right_section = %{
        location: Code.new("31101003", "SCT", "Right carotid artery"),
        measurements: [
          Measurement.new(
            Codes.peak_systolic_velocity(),
            80.0,
            Code.new("cm/s", "UCUM", "centimeters per second")
          )
        ]
      }

      left_section = %{
        location: Code.new("63117004", "SCT", "Left carotid artery"),
        measurements: [
          Measurement.new(
            Codes.peak_systolic_velocity(),
            130.0,
            Code.new("cm/s", "UCUM", "centimeters per second")
          )
        ]
      }

      opts = Keyword.put(@base_opts, :vascular_sections, [right_section, left_section])
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      vascular_sections =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.filter(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121196"
        end)

      assert length(vascular_sections) == 2
    end

    test "includes stenosis grade in vascular section" do
      stenosis =
        Measurement.new(
          Codes.stenosis_grade(),
          70,
          Code.new("%", "UCUM", "percent")
        )

      section = %{
        location: Code.new("69105007", "SCT", "Carotid artery"),
        measurements: [stenosis]
      }

      opts = Keyword.put(@base_opts, :vascular_sections, [section])
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      vascular = find_by_concept_code(data_set, "121196")
      mg = find_child_by_concept_code(vascular, "125007")
      mg_children = mg[Tag.content_sequence()].value

      mg_codes = Enum.map(mg_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Stenosis grade (LN 18228-7)
      assert "18228-7" in mg_codes
    end

    test "includes graft section" do
      graft_measurement =
        Measurement.new(
          Codes.peak_systolic_velocity(),
          95.0,
          Code.new("cm/s", "UCUM", "centimeters per second")
        )

      graft = %{
        location: Code.new("181347005", "SCT", "Bypass graft"),
        measurements: [graft_measurement]
      }

      opts = Keyword.put(@base_opts, :graft_sections, [graft])
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Graft section (SCT 12101003)
      assert "12101003" in concept_codes

      graft_item = find_by_concept_code(data_set, "12101003")
      graft_children = graft_item[Tag.content_sequence()].value

      # Finding site
      assert Enum.any?(graft_children, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "363698007"
             end)

      # Measurement group
      assert Enum.any?(graft_children, fn item ->
               code_value(item, Tag.concept_name_code_sequence()) == "125007"
             end)
    end

    test "builds a full report with all sections" do
      psv =
        Measurement.new(
          Codes.peak_systolic_velocity(),
          125.0,
          Code.new("cm/s", "UCUM", "centimeters per second")
        )

      edv =
        Measurement.new(
          Codes.end_diastolic_velocity(),
          40.0,
          Code.new("cm/s", "UCUM", "centimeters per second")
        )

      ri =
        Measurement.new(
          Codes.resistive_index(),
          0.68,
          Code.new("1", "UCUM", "no units")
        )

      section = %{
        location: Code.new("69105007", "SCT", "Carotid artery"),
        measurements: [psv, edv, ri],
        assessments: [
          Code.new("441574008", "SCT", "Patent"),
          Code.new("263654008", "SCT", "Antegrade flow")
        ]
      }

      graft = %{
        location: Code.new("181347005", "SCT", "Bypass graft"),
        measurements: [
          Measurement.new(
            Codes.peak_systolic_velocity(),
            95.0,
            Code.new("cm/s", "UCUM", "centimeters per second")
          )
        ],
        assessments: [Code.new("441574008", "SCT", "Patent")]
      }

      patient_chars = [
        {Code.new("30525-0", "LN", "Age"), "67"},
        {Code.new("46098-0", "LN", "Sex"), Code.new("248153007", "SCT", "Male")}
      ]

      opts =
        @base_opts
        |> Keyword.put(:procedure_reported, Code.new("12200-0", "LN", "Vascular US Duplex"))
        |> Keyword.put(:patient_characteristics, patient_chars)
        |> Keyword.put(:vascular_sections, [section])
        |> Keyword.put(:graft_sections, [graft])
        |> Keyword.put(:findings, ["Moderate stenosis of the right ICA."])
        |> Keyword.put(:impressions, [Code.new("64572001", "SCT", "Moderate stenosis")])
        |> Keyword.put(:recommendations, ["Follow-up duplex in 6 months."])

      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      # Code value "36440-4" is 7 chars; DICOM SH VR pads to even length after roundtrip
      assert String.trim(code_value(parsed, Tag.concept_name_code_sequence())) == "36440-4"
      assert template_identifier(parsed) == "5100"

      concept_codes =
        parsed
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&(&1 |> code_value(Tag.concept_name_code_sequence()) |> String.trim()))

      # Language
      assert "121049" in concept_codes
      # Observer type
      assert "121005" in concept_codes
      # Procedure reported
      assert "121058" in concept_codes
      # Patient characteristics (Codes.patient_characteristics() = "121070")
      assert "121070" in concept_codes
      # Vascular section
      assert "121196" in concept_codes
      # Graft section
      assert "12101003" in concept_codes
      # Finding
      assert "121071" in concept_codes
      # Impression
      assert "121073" in concept_codes
      # Recommendation
      assert "121075" in concept_codes
    end

    test "document metadata includes template identifier 5100 and series description" do
      {:ok, document} = VascularUltrasoundReport.new(@base_opts)
      {:ok, data_set} = Document.to_data_set(document)

      assert template_identifier(data_set) == "5100"
      assert DataSet.get(data_set, Tag.series_description()) == "Vascular Ultrasound Report"
    end

    test "includes qualitative assessments in vascular section" do
      section = %{
        location: Code.new("69105007", "SCT", "Carotid artery"),
        assessments: [
          Code.new("441574008", "SCT", "Patent"),
          Code.new("263654008", "SCT", "Antegrade flow")
        ]
      }

      opts = Keyword.put(@base_opts, :vascular_sections, [section])
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      vascular = find_by_concept_code(data_set, "121196")
      section_children = vascular[Tag.content_sequence()].value

      # Qualitative assessments are encoded as Finding CODE items
      finding_items =
        Enum.filter(section_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "121071"
        end)

      assert length(finding_items) == 2
    end

    test "omits device observer context when observer_device is nil" do
      opts = Keyword.put(@base_opts, :observer_device, nil)
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end

    test "supports code-based findings, text impressions, code recommendations, and device observer" do
      opts =
        @base_opts
        |> Keyword.put(:observer_device,
          uid: "1.2.826.0.1.3680043.10.1137.514",
          name: "DUPLEX-01"
        )
        |> Keyword.put(:findings, [Code.new("64572001", "SCT", "Moderate stenosis")])
        |> Keyword.put(:impressions, ["Moderate stenosis of right ICA."])
        |> Keyword.put(:recommendations, [Code.new("710830005", "SCT", "Clinical follow-up")])

      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
      assert "121073" in concept_codes
      assert "121075" in concept_codes
      # Device observer UID present
      assert "121012" in concept_codes
    end

    test "handles empty patient characteristics list" do
      opts = Keyword.put(@base_opts, :patient_characteristics, [])
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121118" in concept_codes
    end

    test "handles vascular section without measurements" do
      section = %{
        location: Code.new("69105007", "SCT", "Carotid artery")
      }

      opts = Keyword.put(@base_opts, :vascular_sections, [section])
      {:ok, document} = VascularUltrasoundReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)

      vascular = find_by_concept_code(data_set, "121196")
      section_children = vascular[Tag.content_sequence()].value

      # Only finding site, no measurement group
      assert length(section_children) == 1
      assert code_value(hd(section_children), Tag.concept_name_code_sequence()) == "363698007"
    end
  end

  describe "ProjectionXRayRadiationDose (TID 10001)" do
    test "builds a basic report with accumulated dose only" do
      {:ok, document} =
        ProjectionXRayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.5000",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.5001",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.5002",
          observer_name: "RADTECH^ALICE",
          accumulated_dose: %{total_dap: 3.45}
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.xray_radiation_dose_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113701"
      assert template_identifier(parsed) == "10001"

      content_items = DataSet.get(parsed, Tag.content_sequence())
      concept_codes = Enum.map(content_items, &code_value(&1, Tag.concept_name_code_sequence()))

      # Language, observer type, observer name, accumulated dose
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "113702" in concept_codes
    end

    test "builds a report with fluoro dose totals" do
      {:ok, document} =
        ProjectionXRayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.5010",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.5011",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.5012",
          observer_name: "RADTECH^ALICE",
          accumulated_dose: %{
            total_dap: 12.5,
            fluoro_dap: 8.3,
            acquisition_dap: 4.2,
            total_fluoro_time: 180.5,
            total_number_of_radiographic_frames: 42
          }
        )

      {:ok, data_set} = Document.to_data_set(document)

      accumulated_container =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.find(fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113702"
        end)

      accumulated_codes =
        accumulated_container[Tag.content_sequence()].value
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Total DAP, Fluoro DAP, Acquisition DAP, Fluoro Time, Radiographic Frames
      assert "113725" in accumulated_codes
      assert "113726" in accumulated_codes
      assert "113727" in accumulated_codes
      assert "113730" in accumulated_codes
      assert "113731" in accumulated_codes
    end

    test "builds a report with multiple irradiation events" do
      events = [
        %{
          irradiation_event_uid: "1.2.826.0.1.3680043.10.1137.5020",
          datetime_started: ~N[2026-03-22 10:30:00],
          dose_rp: 1.2,
          dap: 0.45,
          kvp: 80.0,
          tube_current: 250.0,
          exposure_time: 0.5
        },
        %{
          irradiation_event_uid: "1.2.826.0.1.3680043.10.1137.5021",
          dose_rp: 2.1,
          dap: 0.78,
          kvp: 100.0,
          tube_current: 320.0,
          exposure_time: 1.2
        }
      ]

      {:ok, document} =
        ProjectionXRayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.5030",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.5031",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.5032",
          observer_name: "RADTECH^ALICE",
          procedure_reported: Code.new("77067", "CPT", "Fluoroscopy procedure"),
          accumulated_dose: %{total_dap: 1.23},
          irradiation_events: events
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      content_items = DataSet.get(parsed, Tag.content_sequence())
      concept_codes = Enum.map(content_items, &code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure reported
      assert "121058" in concept_codes

      # Two irradiation event containers
      event_containers =
        Enum.filter(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113706"
        end)

      assert length(event_containers) == 2

      # First event has datetime, UID, dose_rp, dap, kvp, tube_current, exposure_time
      first_event = hd(event_containers)
      first_children = first_event[Tag.content_sequence()].value
      first_codes = Enum.map(first_children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "113769" in first_codes
      assert "113809" in first_codes
      assert "113738" in first_codes
      assert "113725" in first_codes
      assert "113733" in first_codes
      assert "113734" in first_codes
      assert "113735" in first_codes

      # Check the irradiation event UID value
      uid_item =
        Enum.find(first_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113769"
        end)

      assert uid_item[Tag.uid_value()].value == "1.2.826.0.1.3680043.10.1137.5020"
    end

    test "document metadata uses correct SOP class and series description" do
      {:ok, document} =
        ProjectionXRayRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.5040",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.5041",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.5042",
          observer_name: "RADTECH^ALICE",
          accumulated_dose: %{total_dap: 1.0}
        )

      assert document.sop_class_uid == Dicom.UID.xray_radiation_dose_sr_storage()
      assert document.series_description == "X-Ray Radiation Dose Report"
      assert document.template_identifier == "10001"
    end
  end

  describe "CTRadiationDose (TID 10011)" do
    test "builds a basic CT dose report with accumulated dose" do
      {:ok, document} =
        CTRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.6000",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.6001",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.6002",
          observer_name: "RADTECH^BOB",
          accumulated_dose: %{total_dlp: 450.0}
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.xray_radiation_dose_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113811"
      assert template_identifier(parsed) == "10011"

      content_items = DataSet.get(parsed, Tag.content_sequence())
      concept_codes = Enum.map(content_items, &code_value(&1, Tag.concept_name_code_sequence()))

      # Language, observer type, observer name, CT accumulated dose
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "113811" in concept_codes

      # Check accumulated dose container has DLP total
      accumulated_container =
        Enum.find(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113811"
        end)

      accumulated_children = accumulated_container[Tag.content_sequence()].value

      accumulated_codes =
        Enum.map(accumulated_children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "113813" in accumulated_codes
    end

    test "builds a report with CT irradiation events (CTDIvol, DLP)" do
      events = [
        %{
          irradiation_event_uid: "1.2.826.0.1.3680043.10.1137.6010",
          ct_acquisition_type: Codes.helical_acquisition(),
          ctdi_vol: 15.2,
          dlp: 350.0,
          scanning_length: 500.0,
          phantom_type: Codes.body_phantom()
        }
      ]

      {:ok, document} =
        CTRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.6020",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.6021",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.6022",
          observer_name: "RADTECH^BOB",
          accumulated_dose: %{total_dlp: 350.0},
          irradiation_events: events
        )

      {:ok, data_set} = Document.to_data_set(document)

      content_items = DataSet.get(data_set, Tag.content_sequence())

      event_containers =
        Enum.filter(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113819"
        end)

      assert length(event_containers) == 1

      event_children = hd(event_containers)[Tag.content_sequence()].value
      event_codes = Enum.map(event_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # UID, acquisition type, CTDIvol, DLP, scanning length, phantom type
      assert "113769" in event_codes
      assert "113820" in event_codes
      assert "113830" in event_codes
      assert "113838" in event_codes
      assert "113825" in event_codes
      assert "113835" in event_codes

      # Check acquisition type is helical
      acq_type_item =
        Enum.find(event_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113820"
        end)

      assert code_value(acq_type_item, Tag.concept_code_sequence()) == "P5-08001"
    end

    test "supports helical vs axial acquisitions" do
      events = [
        %{
          irradiation_event_uid: "1.2.826.0.1.3680043.10.1137.6030",
          ct_acquisition_type: Codes.helical_acquisition(),
          ctdi_vol: 15.2,
          dlp: 350.0
        },
        %{
          irradiation_event_uid: "1.2.826.0.1.3680043.10.1137.6031",
          ct_acquisition_type: Codes.axial_acquisition(),
          ctdi_vol: 8.5,
          dlp: 120.0
        }
      ]

      {:ok, document} =
        CTRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.6040",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.6041",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.6042",
          observer_name: "RADTECH^BOB",
          accumulated_dose: %{total_dlp: 470.0},
          irradiation_events: events
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      content_items = DataSet.get(parsed, Tag.content_sequence())

      event_containers =
        Enum.filter(content_items, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113819"
        end)

      assert length(event_containers) == 2

      # First event should be helical
      first_children = hd(event_containers)[Tag.content_sequence()].value

      first_acq_type =
        Enum.find(first_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113820"
        end)

      assert code_value(first_acq_type, Tag.concept_code_sequence()) == "P5-08001"

      # Second event should be axial
      second_children = Enum.at(event_containers, 1)[Tag.content_sequence()].value

      second_acq_type =
        Enum.find(second_children, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113820"
        end)

      assert code_value(second_acq_type, Tag.concept_code_sequence()) == "113804"
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} =
        CTRadiationDose.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.6050",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.6051",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.6052",
          observer_name: "RADTECH^BOB",
          accumulated_dose: %{total_dlp: 100.0}
        )

      assert document.sop_class_uid == Dicom.UID.xray_radiation_dose_sr_storage()
      assert document.series_description == "CT Radiation Dose Report"
      assert document.template_identifier == "10011"
    end
  end

  describe "ColonCAD" do
    @colon_cad_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.7100",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.7101",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.7102",
      observer_device: [uid: "1.2.826.0.1.3680043.10.1137.7103", name: "CAD_ENGINE"]
    ]

    test "builds a minimal report with device observer only" do
      {:ok, document} = ColonCAD.new(@colon_cad_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "111060"
      assert template_identifier(data_set) == "4120"

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Language
      assert "121049" in concept_codes
      # Observer type (device)
      assert "121005" in concept_codes
    end

    test "builds a full report with polyp findings, summary, and person observer" do
      ascending_colon = Code.new("T-59200", "SRT", "Ascending colon")

      opts =
        Keyword.merge(@colon_cad_base_opts,
          observer_name: "RADIOLOGIST^JANE",
          findings_summary: ["Two polyp candidates detected"],
          polyp_findings: [
            %{
              size_mm: 8.5,
              segment: ascending_colon,
              confidence: 92.0
            },
            %{
              size_mm: 4.2,
              segment: Code.new("T-59470", "SRT", "Sigmoid colon"),
              confidence: 75.0
            }
          ]
        )

      {:ok, document} = ColonCAD.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # CAD Processing and Findings Summary
      assert "111017" in concept_codes
      # Single Image Findings (2 polyps)
      finding_count = Enum.count(concept_codes, &(&1 == "111059"))
      assert finding_count == 2
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} = ColonCAD.new(@colon_cad_base_opts)

      assert document.sop_class_uid == Dicom.UID.comprehensive_sr_storage()
      assert document.series_description == "Colon CAD Report"
      assert document.template_identifier == "4120"
    end

    test "serializes to valid P10 binary and round-trips" do
      opts =
        Keyword.merge(@colon_cad_base_opts,
          polyp_findings: [
            %{size_mm: 6.0, segment: Code.new("T-59200", "SRT", "Ascending colon")}
          ]
        )

      {:ok, document} = ColonCAD.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "111060"
      assert template_identifier(parsed) == "4120"
    end

    test "supports image library references" do
      ref =
        Reference.new(
          Dicom.UID.ct_image_storage(),
          "1.2.826.0.1.3680043.10.1137.7120"
        )

      opts = Keyword.merge(@colon_cad_base_opts, image_library: [ref])

      {:ok, document} = ColonCAD.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Image Library container
      assert "111028" in concept_codes
    end

    test "supports Code-based findings summary and polyp with minimal fields" do
      opts =
        Keyword.merge(@colon_cad_base_opts,
          findings_summary: [Code.new("112172", "DCM", "Polyp")],
          polyp_findings: [%{}]
        )

      {:ok, document} = ColonCAD.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "111017" in concept_codes
      assert "111059" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = ColonCAD.new(@colon_cad_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # No findings summary
      refute "111017" in concept_codes
      # No single image findings
      refute "111059" in concept_codes
    end
  end

  describe "ImagingReport" do
    @imaging_report_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.7200",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.7201",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.7202",
      observer_name: "RADIOLOGIST^SMITH"
    ]

    test "builds a minimal report with observer only" do
      {:ok, document} = ImagingReport.new(@imaging_report_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "18748-4"
      assert template_identifier(data_set) == "2006"
    end

    test "builds a full report with narrative, impressions, recommendations, and radiation exposure" do
      opts =
        Keyword.merge(@imaging_report_base_opts,
          procedure_reported: [Code.new("P5-09051", "SRT", "Chest CT")],
          procedure_description: "CT scan of the chest without contrast",
          narrative: "No acute cardiopulmonary findings.",
          impressions: ["Normal chest CT"],
          recommendations: ["Routine follow-up in 12 months"],
          radiation_exposure: [ctdivol: 12.5, dlp: 450.0]
        )

      {:ok, document} = ImagingReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure reported
      assert "121058" in concept_codes
      # Procedure description
      assert "121065" in concept_codes
      # Narrative summary
      assert "111412" in concept_codes
      # Impression
      assert "121073" in concept_codes
      # Recommendation
      assert "121075" in concept_codes
      # CT Radiation Dose container
      assert "113507" in concept_codes
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} = ImagingReport.new(@imaging_report_base_opts)

      assert document.sop_class_uid == Dicom.UID.comprehensive_sr_storage()
      assert document.series_description == "Imaging Report"
      assert document.template_identifier == "2006"
    end

    test "serializes to valid P10 binary and round-trips" do
      opts =
        Keyword.merge(@imaging_report_base_opts,
          narrative: "Unremarkable exam.",
          impressions: ["No acute findings"]
        )

      {:ok, document} = ImagingReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) |> String.trim() == "18748-4"
      assert template_identifier(parsed) == "2006"
    end

    test "supports partial radiation exposure with only CTDIvol" do
      opts =
        Keyword.merge(@imaging_report_base_opts,
          radiation_exposure: [ctdivol: 15.0]
        )

      {:ok, document} = ImagingReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "113507" in concept_codes
    end

    test "supports Code-based impressions, recommendations, and device observer" do
      opts =
        Keyword.merge(@imaging_report_base_opts,
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.7210", name: "CT_SCANNER"],
          impressions: [Code.new("399067008", "SCT", "Normal study")],
          recommendations: [Code.new("399013003", "SCT", "Follow-up")]
        )

      {:ok, document} = ImagingReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121073" in concept_codes
      assert "121075" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = ImagingReport.new(@imaging_report_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # No procedure reported
      refute "121058" in concept_codes
      # No procedure description
      refute "121065" in concept_codes
      # No narrative
      refute "111412" in concept_codes
      # No impressions
      refute "121073" in concept_codes
      # No recommendations
      refute "121075" in concept_codes
      # No radiation exposure
      refute "113507" in concept_codes
    end
  end

  describe "ImplantationPlan" do
    @implant_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.7300",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.7301",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.7302",
      observer_name: "SURGEON^JONES"
    ]

    test "builds a minimal report with observer only" do
      {:ok, document} = ImplantationPlan.new(@implant_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "122361"
      assert template_identifier(data_set) == "7000"
    end

    test "builds a full report with templates, measurements, site, findings, and impressions" do
      mm_unit = Code.new("mm", "UCUM", "mm")

      opts =
        Keyword.merge(@implant_base_opts,
          procedure_reported: Code.new("27687-1", "LN", "Total hip replacement"),
          implant_templates: ["Acme Hip Stem Size 12"],
          planning_measurements: [
            %{
              concept: Code.new("122346", "DCM", "Planning measurement"),
              value: 45.0,
              units: mm_unit
            }
          ],
          implantation_site: Code.new("71341001", "SCT", "Left hip"),
          findings: ["Adequate bone stock"],
          impressions: ["Suitable for total hip arthroplasty"],
          recommendations: [Code.new("306807008", "SCT", "Proceed with surgery")]
        )

      {:ok, document} = ImplantationPlan.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure reported
      assert "121058" in concept_codes
      # Implant template
      assert "122349" in concept_codes
      # Implantation site
      assert "111176" in concept_codes
      # Finding
      assert "121071" in concept_codes
      # Impression
      assert "121073" in concept_codes
      # Recommendation
      assert "121075" in concept_codes
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} = ImplantationPlan.new(@implant_base_opts)

      assert document.sop_class_uid == Dicom.UID.comprehensive_sr_storage()
      assert document.series_description == "Implantation Plan"
      assert document.template_identifier == "7000"
    end

    test "serializes to valid P10 binary and round-trips" do
      opts =
        Keyword.merge(@implant_base_opts,
          findings: ["Normal bone density"],
          impressions: ["Plan approved"]
        )

      {:ok, document} = ImplantationPlan.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "122361"
      assert template_identifier(parsed) == "7000"
    end

    test "supports Reference-based implant templates and device observer" do
      ref =
        Reference.new(
          "1.2.840.10008.5.1.4.43.1",
          "1.2.826.0.1.3680043.10.1137.7310"
        )

      opts =
        Keyword.merge(@implant_base_opts,
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.7320", name: "PLANNER"],
          implant_templates: [ref]
        )

      {:ok, document} = ImplantationPlan.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "122349" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = ImplantationPlan.new(@implant_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121058" in concept_codes
      refute "122349" in concept_codes
      refute "111176" in concept_codes
      refute "121071" in concept_codes
      refute "121073" in concept_codes
      refute "121075" in concept_codes
    end
  end

  describe "PediatricCardiacUSReport" do
    @peds_cardiac_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.7400",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.7401",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.7402",
      observer_name: "CARDIOLOGIST^PATEL"
    ]

    test "builds a minimal report with observer only" do
      {:ok, document} = PediatricCardiacUSReport.new(@peds_cardiac_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "125200"
      assert template_identifier(data_set) == "5220"
    end

    test "builds a full report with procedure, characteristics, summary, findings, and impressions" do
      opts =
        Keyword.merge(@peds_cardiac_base_opts,
          procedure_reported: Code.new("40701008", "SCT", "Echocardiography"),
          patient_characteristics: ["Neonate, 3.2 kg"],
          summary: ["Normal cardiac anatomy"],
          findings: [
            "Normal biventricular function",
            Code.new("27550009", "SCT", "Patent foramen ovale")
          ],
          impressions: ["Structurally normal heart"]
        )

      {:ok, document} = PediatricCardiacUSReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure reported
      assert "121058" in concept_codes
      # Patient characteristics container
      assert "121070" in concept_codes
      # Summary container
      assert "121077" in concept_codes
      # Finding
      assert "121071" in concept_codes
      # Impression
      assert "121073" in concept_codes
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} = PediatricCardiacUSReport.new(@peds_cardiac_base_opts)

      assert document.sop_class_uid == Dicom.UID.comprehensive_sr_storage()
      assert document.series_description == "Pediatric Cardiac Ultrasound Report"
      assert document.template_identifier == "5220"
    end

    test "serializes to valid P10 binary and round-trips" do
      opts =
        Keyword.merge(@peds_cardiac_base_opts,
          findings: ["Normal study"],
          impressions: ["No abnormality detected"]
        )

      {:ok, document} = PediatricCardiacUSReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "125200"
      assert template_identifier(parsed) == "5220"
    end

    test "supports Code-based items, cardiac sections, and device observer" do
      measurement =
        Measurement.new(
          Code.new("18083-2", "LN", "LV Internal Diastolic Dimension"),
          42.0,
          Code.new("mm", "UCUM", "mm")
        )

      opts =
        Keyword.merge(@peds_cardiac_base_opts,
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.7410", name: "US_MACHINE"],
          patient_characteristics: [Code.new("133931009", "SCT", "Neonate")],
          cardiac_sections: [
            %{name: "Left Ventricle", measurements: [measurement], findings: ["Normal"]}
          ],
          summary: [Code.new("17621005", "SCT", "Normal")],
          findings: [Code.new("27550009", "SCT", "Patent foramen ovale")],
          impressions: [Code.new("399067008", "SCT", "Normal study")]
        )

      {:ok, document} = PediatricCardiacUSReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121070" in concept_codes
      assert "121077" in concept_codes
      assert "121071" in concept_codes
      assert "121073" in concept_codes
      # Cardiac measurement group
      assert "125007" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = PediatricCardiacUSReport.new(@peds_cardiac_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121058" in concept_codes
      refute "121070" in concept_codes
      refute "121077" in concept_codes
      refute "121071" in concept_codes
      refute "121073" in concept_codes
    end
  end

  describe "PreclinicalAcquisitionContext" do
    @preclinical_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.7500",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.7501",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.7502",
      observer_name: "RESEARCHER^CHEN"
    ]

    test "builds a minimal report with observer only" do
      {:ok, document} = PreclinicalAcquisitionContext.new(@preclinical_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "128101"
      assert template_identifier(data_set) == "8101"
    end

    test "builds a full report with biosafety, housing, anesthesia, and monitoring" do
      heart_rate =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          350,
          Code.new("/min", "UCUM", "beats per minute")
        )

      opts =
        Keyword.merge(@preclinical_base_opts,
          biosafety: [Code.new("BSL-1", "99LOCAL", "Biosafety Level 1")],
          animal_housing: ["Standard cage with bedding"],
          anesthesia: [Code.new("387260003", "SCT", "Isoflurane")],
          physiological_monitoring: [heart_rate]
        )

      {:ok, document} = PreclinicalAcquisitionContext.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Biosafety conditions container
      assert "128110" in concept_codes
      # Animal housing container
      assert "128121" in concept_codes
      # Anesthesia container
      assert "128130" in concept_codes
      # Physiological monitoring container
      assert "128170" in concept_codes
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} = PreclinicalAcquisitionContext.new(@preclinical_base_opts)

      assert document.sop_class_uid == Dicom.UID.comprehensive_sr_storage()

      assert document.series_description ==
               "Preclinical Small Animal Acquisition Context"

      assert document.template_identifier == "8101"
    end

    test "serializes to valid P10 binary and round-trips" do
      opts =
        Keyword.merge(@preclinical_base_opts,
          biosafety: ["BSL-2 containment"],
          anesthesia: ["Ketamine/Xylazine"]
        )

      {:ok, document} = PreclinicalAcquisitionContext.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "128101"
      assert template_identifier(parsed) == "8101"
    end

    test "supports Code-based housing, Measurement anesthesia, and mixed monitoring" do
      anesthesia_dose =
        Measurement.new(
          Code.new("128131", "DCM", "Anesthesia Agent"),
          2.0,
          Code.new("%", "UCUM", "%")
        )

      heart_rate =
        Measurement.new(
          Code.new("8867-4", "LN", "Heart rate"),
          380,
          Code.new("/min", "UCUM", "beats per minute")
        )

      opts =
        Keyword.merge(@preclinical_base_opts,
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.7510", name: "SCANNER"],
          animal_housing: [Code.new("128123", "DCM", "Single housing")],
          anesthesia: [anesthesia_dose],
          physiological_monitoring: [
            heart_rate,
            Code.new("128172", "DCM", "Body temperature"),
            "Respiration monitored"
          ]
        )

      {:ok, document} = PreclinicalAcquisitionContext.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "128121" in concept_codes
      assert "128130" in concept_codes
      assert "128170" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = PreclinicalAcquisitionContext.new(@preclinical_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "128110" in concept_codes
      refute "128121" in concept_codes
      refute "128130" in concept_codes
      refute "128170" in concept_codes
    end
  end

  describe "SimplifiedEchoReport" do
    @echo_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.7600",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.7601",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.7602",
      observer_name: "SONOG^MARIA"
    ]

    test "builds a minimal report with observer only" do
      {:ok, document} = SimplifiedEchoReport.new(@echo_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "125300"
      assert template_identifier(data_set) == "5300"
    end

    test "builds a full report with measurement sections, findings, and impressions" do
      lv_edd =
        Measurement.new(
          Code.new("18083-2", "LN", "LV Internal Diastolic Dimension"),
          48.0,
          Code.new("mm", "UCUM", "mm")
        )

      ef =
        Measurement.new(
          Code.new("10230-1", "LN", "Ejection Fraction"),
          62.0,
          Code.new("%", "UCUM", "%")
        )

      opts =
        Keyword.merge(@echo_base_opts,
          pre_coordinated_measurements: [lv_edd],
          post_coordinated_measurements: [ef],
          findings: ["Normal LV size and function"],
          impressions: [
            "Normal echocardiogram",
            Code.new("399067008", "SCT", "Normal study")
          ]
        )

      {:ok, document} = SimplifiedEchoReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Pre-coordinated measurements container
      assert "125301" in concept_codes
      # Post-coordinated measurements container
      assert "125302" in concept_codes
      # Finding
      assert "121071" in concept_codes
      # Impression
      assert "121073" in concept_codes
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} = SimplifiedEchoReport.new(@echo_base_opts)

      assert document.sop_class_uid == Dicom.UID.comprehensive_sr_storage()
      assert document.series_description == "Simplified Echo Procedure Report"
      assert document.template_identifier == "5300"
    end

    test "serializes to valid P10 binary and round-trips" do
      lv_edd =
        Measurement.new(
          Code.new("18083-2", "LN", "LV Internal Diastolic Dimension"),
          50.0,
          Code.new("mm", "UCUM", "mm")
        )

      opts =
        Keyword.merge(@echo_base_opts,
          pre_coordinated_measurements: [lv_edd],
          findings: ["Normal study"]
        )

      {:ok, document} = SimplifiedEchoReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "125300"
      assert template_identifier(parsed) == "5300"
    end

    test "supports Code-based findings and device observer" do
      opts =
        Keyword.merge(@echo_base_opts,
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.7610", name: "ECHO_MACHINE"],
          findings: [Code.new("399067008", "SCT", "Normal study")]
        )

      {:ok, document} = SimplifiedEchoReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = SimplifiedEchoReport.new(@echo_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "125301" in concept_codes
      refute "125302" in concept_codes
      refute "125303" in concept_codes
      refute "121071" in concept_codes
      refute "121073" in concept_codes
    end
  end

  describe "StructuralHeartReport" do
    @structural_heart_base_opts [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.7700",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.7701",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.7702",
      observer_name: "INTERVENTIONAL^WONG"
    ]

    test "builds a minimal report with observer only" do
      {:ok, document} = StructuralHeartReport.new(@structural_heart_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "125320"
      assert template_identifier(data_set) == "5320"
    end

    test "builds a full report with procedure, measurements, findings, and impressions" do
      annulus_diameter =
        Measurement.new(
          Code.new("M-02550", "SRT", "Annulus diameter"),
          23.5,
          Code.new("mm", "UCUM", "mm")
        )

      device_size =
        Measurement.new(
          Code.new("122350", "DCM", "Device size"),
          26.0,
          Code.new("mm", "UCUM", "mm")
        )

      opts =
        Keyword.merge(@structural_heart_base_opts,
          procedure_reported: Code.new("64915003", "SCT", "TAVR"),
          annular_measurements: [annulus_diameter],
          device_measurements: [device_size],
          findings: [
            "Severe aortic stenosis",
            Code.new("60573004", "SCT", "Aortic valve stenosis")
          ],
          impressions: ["Suitable for TAVR with 26mm prosthesis"]
        )

      {:ok, document} = StructuralHeartReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      # Procedure reported
      assert "121058" in concept_codes
      # Annular measurements container
      assert "125321" in concept_codes
      # Device measurements container
      assert "125322" in concept_codes
      # Finding
      assert "121071" in concept_codes
      # Impression
      assert "121073" in concept_codes
    end

    test "document metadata uses correct template and series description" do
      {:ok, document} = StructuralHeartReport.new(@structural_heart_base_opts)

      assert document.sop_class_uid == Dicom.UID.comprehensive_sr_storage()
      assert document.series_description == "Structural Heart Measurement Report"
      assert document.template_identifier == "5320"
    end

    test "serializes to valid P10 binary and round-trips" do
      annulus =
        Measurement.new(
          Code.new("M-02550", "SRT", "Annulus diameter"),
          24.0,
          Code.new("mm", "UCUM", "mm")
        )

      opts =
        Keyword.merge(@structural_heart_base_opts,
          annular_measurements: [annulus],
          findings: ["Severe aortic stenosis"]
        )

      {:ok, document} = StructuralHeartReport.new(opts)
      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               Dicom.UID.comprehensive_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "125320"
      assert template_identifier(parsed) == "5320"
    end

    test "supports Code-based findings, impressions, and device observer" do
      opts =
        Keyword.merge(@structural_heart_base_opts,
          observer_device: [uid: "1.2.826.0.1.3680043.10.1137.7710", name: "CT_SCANNER"],
          findings: [Code.new("60573004", "SCT", "Aortic valve stenosis")],
          impressions: [Code.new("399067008", "SCT", "Normal study")]
        )

      {:ok, document} = StructuralHeartReport.new(opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in concept_codes
      assert "121073" in concept_codes
    end

    test "omits optional sections when not provided" do
      {:ok, document} = StructuralHeartReport.new(@structural_heart_base_opts)

      {:ok, data_set} = Document.to_data_set(document)

      concept_codes =
        data_set
        |> DataSet.get(Tag.content_sequence())
        |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))

      refute "121058" in concept_codes
      refute "125321" in concept_codes
      refute "125322" in concept_codes
      refute "121071" in concept_codes
      refute "121073" in concept_codes
    end
  end
end
