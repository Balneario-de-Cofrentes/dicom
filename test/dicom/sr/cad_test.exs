defmodule Dicom.SR.CADTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, Tag, UID}

  alias Dicom.SR.{
    Code,
    Codes,
    Document,
    Reference,
    Scoord2D
  }

  alias Dicom.SR.Templates.{MammographyCAD, ChestCAD}

  # -- Helpers ---------------------------------------------------------------

  defp code_value(item, sequence_tag) do
    [code_item] = sequence_value(item, sequence_tag)
    code_item[Tag.code_value()].value
  end

  defp template_identifier(data_set) do
    [template_item] = DataSet.get(data_set, Tag.content_template_sequence())
    template_item[Tag.template_identifier()].value
  end

  defp sequence_value(%DataSet{} = data_set, tag), do: DataSet.get(data_set, tag)
  defp sequence_value(item, tag) when is_map(item), do: item[tag].value

  defp content_codes(data_set) do
    data_set
    |> DataSet.get(Tag.content_sequence())
    |> Enum.map(&code_value(&1, Tag.concept_name_code_sequence()))
  end

  defp make_reference(instance_suffix) do
    Reference.new(
      UID.dx_image_storage(),
      "1.2.826.0.1.3680043.10.1137.#{instance_suffix}"
    )
  end

  defp base_device_opts do
    [uid: "1.2.826.0.1.3680043.10.1137.5000", name: "CAD-ENGINE-01"]
  end

  defp base_uids(prefix) do
    [
      study_instance_uid: "1.2.826.0.1.3680043.10.1137.#{prefix}0",
      series_instance_uid: "1.2.826.0.1.3680043.10.1137.#{prefix}1",
      sop_instance_uid: "1.2.826.0.1.3680043.10.1137.#{prefix}2"
    ]
  end

  # -- TID 4000 Mammography CAD ---------------------------------------------

  describe "MammographyCAD" do
    test "basic creation with device observer" do
      {:ok, document} =
        MammographyCAD.new(
          base_uids(400) ++
            [
              device_observer: base_device_opts(),
              detections_performed: [
                Code.new("F-01775", "SRT", "Calcification Detection")
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.decoded_value(data_set, Tag.sop_class_uid()) ==
               UID.mammography_cad_sr_storage()

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "111023"
      assert template_identifier(data_set) == "4000"

      codes = content_codes(data_set)

      # Language
      assert "121049" in codes
      # Device observer type
      assert "121005" in codes
      # Device observer UID
      assert "121012" in codes
      # CAD Processing and Findings Summary
      assert "111017" in codes
    end

    test "with single image findings (calcification, mass)" do
      ref = make_reference(4010)
      scoord = Scoord2D.new(ref, "POINT", [150.0, 220.0])

      {:ok, document} =
        MammographyCAD.new(
          base_uids(401) ++
            [
              device_observer: base_device_opts(),
              findings: [
                %{
                  finding: Codes.calcification_cluster(),
                  scoord: scoord,
                  probability: 78.5,
                  rendering_intent: :required
                },
                %{
                  finding: Codes.mass(),
                  probability: 42.0
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())

      finding_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111059"
        end)

      assert length(finding_items) == 2

      # First finding has SCOORD, probability, and rendering intent
      [first_finding | _] = finding_items
      first_children = first_finding[Tag.content_sequence()].value

      first_child_codes =
        Enum.map(first_children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Finding code (calcification cluster)
      assert "121071" in first_child_codes
      # Image Region (SCOORD)
      assert "111030" in first_child_codes
      # Probability
      assert "111047" in first_child_codes
      # Rendering Intent
      assert "111056" in first_child_codes

      # Verify probability value
      prob_item =
        Enum.find(first_children, fn child ->
          code_value(child, Tag.concept_name_code_sequence()) == "111047"
        end)

      [measured] = prob_item[Tag.measured_value_sequence()].value
      assert measured[Tag.numeric_value()].value == "78.5"

      # Verify the SCOORD
      scoord_item =
        Enum.find(first_children, fn child ->
          code_value(child, Tag.concept_name_code_sequence()) == "111030"
        end)

      assert scoord_item[Tag.graphic_type()].value == "POINT"
      assert scoord_item[Tag.graphic_data()].value == [150.0, 220.0]
    end

    test "with composite features" do
      {:ok, document} =
        MammographyCAD.new(
          base_uids(402) ++
            [
              device_observer: base_device_opts(),
              findings: [
                %{
                  type: :composite,
                  finding: Codes.calcification_cluster(),
                  probability: 85.0
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())

      composite_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111058"
        end)

      assert length(composite_items) == 1

      [composite] = composite_items
      children = composite[Tag.content_sequence()].value
      child_codes = Enum.map(children, &code_value(&1, Tag.concept_name_code_sequence()))

      assert "121071" in child_codes
      assert "111047" in child_codes
    end

    test "with breast composition" do
      breast_density_code = Code.new("129700", "DCM", "Breast Density Category A")

      {:ok, document} =
        MammographyCAD.new(
          base_uids(403) ++
            [
              device_observer: base_device_opts(),
              breast_composition: breast_density_code
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      codes = content_codes(data_set)

      # Breast Composition (Codes.breast_composition() = "111031")
      assert "111031" in codes
    end

    test "with image library" do
      ref1 = make_reference(4040)
      ref2 = make_reference(4041)

      {:ok, document} =
        MammographyCAD.new(
          base_uids(404) ++
            [
              device_observer: base_device_opts(),
              image_library: [ref1, ref2]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      codes = content_codes(data_set)

      # Image Library
      assert "111028" in codes
    end

    test "with device observer as map" do
      {:ok, document} =
        MammographyCAD.new(
          base_uids(405) ++
            [
              device_observer: %{
                uid: "1.2.826.0.1.3680043.10.1137.5001",
                name: "CAD-ENGINE-02"
              }
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      codes = content_codes(data_set)

      assert "121012" in codes
      assert "121013" in codes
    end

    test "raises when device_observer is missing" do
      assert_raise KeyError, fn ->
        MammographyCAD.new(base_uids(406))
      end
    end

    test "round-trip: create -> write -> parse -> verify" do
      ref = make_reference(4050)
      scoord = Scoord2D.new(ref, "CIRCLE", [100.0, 100.0, 120.0, 100.0])

      {:ok, document} =
        MammographyCAD.new(
          base_uids(407) ++
            [
              device_observer: base_device_opts(),
              detections_performed: [
                Code.new("F-01775", "SRT", "Calcification Detection")
              ],
              image_library: [ref],
              findings: [
                %{
                  finding: Codes.calcification_cluster(),
                  scoord: scoord,
                  probability: 90.0
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               UID.mammography_cad_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.get(parsed, Tag.completion_flag()) == "COMPLETE"
      assert DataSet.get(parsed, Tag.verification_flag()) == "UNVERIFIED"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "111023"
      assert template_identifier(parsed) == "4000"
    end

    test "document metadata: series description defaults" do
      {:ok, document} =
        MammographyCAD.new(
          base_uids(408) ++
            [device_observer: base_device_opts()]
        )

      {:ok, data_set} = Document.to_data_set(document)
      assert DataSet.get(data_set, Tag.series_description()) == "Mammography CAD Report"
    end
  end

  # -- TID 4100 Chest CAD ---------------------------------------------------

  describe "ChestCAD" do
    test "basic creation with findings summary" do
      {:ok, document} =
        ChestCAD.new(
          base_uids(410) ++
            [
              device_observer: base_device_opts(),
              findings_summary: ["No significant findings detected"]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.decoded_value(data_set, Tag.sop_class_uid()) ==
               UID.chest_cad_sr_storage()

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "111036"
      assert template_identifier(data_set) == "4100"

      codes = content_codes(data_set)

      # Language
      assert "121049" in codes
      # Device observer type
      assert "121005" in codes
      # Findings summary
      assert "111035" in codes
    end

    test "with nodule findings and spatial coordinates" do
      ref = make_reference(4110)
      scoord = Scoord2D.new(ref, "CIRCLE", [250.0, 300.0, 265.0, 300.0])

      {:ok, document} =
        ChestCAD.new(
          base_uids(411) ++
            [
              device_observer: base_device_opts(),
              findings_summary: [
                Code.new("260385009", "SCT", "Abnormal")
              ],
              findings: [
                %{
                  finding: Codes.nodule(),
                  scoord: scoord,
                  probability: 67.3,
                  rendering_intent: :required
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())

      finding_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111059"
        end)

      assert length(finding_items) == 1

      [finding] = finding_items
      children = finding[Tag.content_sequence()].value
      child_codes = Enum.map(children, &code_value(&1, Tag.concept_name_code_sequence()))

      # Finding type (nodule)
      assert "121071" in child_codes
      # Image Region (SCOORD)
      assert "111030" in child_codes
      # Probability
      assert "111047" in child_codes
      # Rendering Intent
      assert "111056" in child_codes

      # Verify SCOORD data
      scoord_item =
        Enum.find(children, fn child ->
          code_value(child, Tag.concept_name_code_sequence()) == "111030"
        end)

      assert scoord_item[Tag.graphic_type()].value == "CIRCLE"
    end

    test "with composite features" do
      {:ok, document} =
        ChestCAD.new(
          base_uids(412) ++
            [
              device_observer: base_device_opts(),
              findings: [
                %{
                  type: :composite,
                  finding: Codes.mass(),
                  probability: 55.0
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())

      composite_items =
        Enum.filter(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "111058"
        end)

      assert length(composite_items) == 1
    end

    test "with image library" do
      ref = make_reference(4130)

      {:ok, document} =
        ChestCAD.new(
          base_uids(413) ++
            [
              device_observer: base_device_opts(),
              image_library: [ref]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      codes = content_codes(data_set)

      assert "111028" in codes
    end

    test "raises when device_observer is missing" do
      assert_raise KeyError, fn ->
        ChestCAD.new(base_uids(414))
      end
    end

    test "round-trip: create -> write -> parse -> verify" do
      ref = make_reference(4150)
      scoord = Scoord2D.new(ref, "POINT", [320.0, 180.0])

      {:ok, document} =
        ChestCAD.new(
          base_uids(415) ++
            [
              device_observer: base_device_opts(),
              findings_summary: ["Nodule detected in right upper lobe"],
              image_library: [ref],
              findings: [
                %{
                  finding: Codes.nodule(),
                  scoord: scoord,
                  probability: 72.0
                }
              ]
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               UID.chest_cad_sr_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.get(parsed, Tag.completion_flag()) == "COMPLETE"
      assert DataSet.get(parsed, Tag.verification_flag()) == "UNVERIFIED"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "111036"
      assert template_identifier(parsed) == "4100"
    end

    test "document metadata: series description defaults" do
      {:ok, document} =
        ChestCAD.new(
          base_uids(416) ++
            [device_observer: base_device_opts()]
        )

      {:ok, data_set} = Document.to_data_set(document)
      assert DataSet.get(data_set, Tag.series_description()) == "Chest CAD Report"
    end

    test "with device observer as map" do
      {:ok, document} =
        ChestCAD.new(
          base_uids(417) ++
            [
              device_observer: %{
                uid: "1.2.826.0.1.3680043.10.1137.5002",
                name: "LUNG-CAD-01"
              }
            ]
        )

      {:ok, data_set} = Document.to_data_set(document)
      codes = content_codes(data_set)

      assert "121012" in codes
      assert "121013" in codes
    end
  end
end
