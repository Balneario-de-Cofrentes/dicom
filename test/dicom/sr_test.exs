defmodule Dicom.SRTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, Tag}
  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, MeasurementGroup, Observer}
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
