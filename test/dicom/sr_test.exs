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
    Scoord2D
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
  end

  describe "ContentItem" do
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
  end

  describe "MeasurementReport" do
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
  end

  describe "ECGReport" do
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
  end

  describe "StressTestingReport" do
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
