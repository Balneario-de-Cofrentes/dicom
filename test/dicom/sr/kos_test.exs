defmodule Dicom.SR.KOSTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, Tag, UID}

  alias Dicom.SR.{
    Codes,
    ContentItem,
    Document,
    ImageLibrary,
    Reference
  }

  alias Dicom.SR.Templates.KeyObjectSelection

  # ── Helpers ──────────────────────────────────────────────────────────

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

  defp make_reference(instance_suffix, opts \\ []) do
    Reference.new(
      UID.ct_image_storage(),
      "1.2.826.0.1.3680043.10.1137.#{instance_suffix}",
      opts
    )
  end

  # ── Key Object Selection ────────────────────────────────────────────

  describe "KeyObjectSelection" do
    test "basic KOS creation with references and description" do
      ref1 = make_reference(9001)
      ref2 = make_reference(9002)

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.900",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.901",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.902",
          observer_name: "RADIOLOGIST^ANA",
          description: "Notable findings in lung parenchyma",
          references: [ref1, ref2]
        )

      {:ok, data_set} = Document.to_data_set(document)

      assert DataSet.decoded_value(data_set, Tag.sop_class_uid()) ==
               UID.key_object_selection_document_storage()

      assert DataSet.get(data_set, Tag.modality()) == "SR"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "113000"
      assert template_identifier(data_set) == "2000"

      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Language, observer type, observer name, description, image1, image2
      assert "121049" in concept_codes
      assert "121005" in concept_codes
      assert "113012" in concept_codes
      assert "260753009" in concept_codes

      description_item =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113012"
        end)

      assert description_item[Tag.text_value()].value == "Notable findings in lung parenchyma"

      image_items =
        Enum.filter(content, fn item ->
          String.trim(item[Tag.value_type()].value) == "IMAGE"
        end)

      assert length(image_items) == 2
    end

    test "KOS with device observer" do
      ref = make_reference(9010)

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.910",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.911",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.912",
          observer_name: "RADIOLOGIST^ANA",
          observer_device: [
            uid: "1.2.826.0.1.3680043.10.1137.913",
            name: "AI-SELECTOR-01",
            manufacturer: "Phaos AI",
            model_name: "SmartSelect v2",
            serial_number: "SS-100"
          ],
          references: [ref]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      # Device observer context items
      assert "121012" in concept_codes
      assert "121013" in concept_codes
      assert "121014" in concept_codes
      assert "121015" in concept_codes
      assert "121016" in concept_codes
    end

    test "KOS round-trip: create -> to_data_set -> write -> parse -> verify structure" do
      ref1 = make_reference(9020)
      ref2 = make_reference(9021)

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.920",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.921",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.922",
          observer_name: "RADIOLOGIST^ANA",
          description: "Significant mass in right lower lobe",
          references: [ref1, ref2]
        )

      {:ok, data_set} = Document.to_data_set(document)
      {:ok, binary} = Dicom.write(data_set)
      {:ok, parsed} = Dicom.parse(binary)

      assert DataSet.decoded_value(parsed, Tag.sop_class_uid()) ==
               UID.key_object_selection_document_storage()

      assert DataSet.get(parsed, Tag.modality()) == "SR"
      assert DataSet.get(parsed, Tag.completion_flag()) == "COMPLETE"
      assert DataSet.get(parsed, Tag.verification_flag()) == "UNVERIFIED"
      assert DataSet.decoded_value(parsed, Tag.value_type()) == "CONTAINER"
      assert code_value(parsed, Tag.concept_name_code_sequence()) == "113000"
      assert template_identifier(parsed) == "2000"

      content = DataSet.get(parsed, Tag.content_sequence())

      description_item =
        Enum.find(content, fn item ->
          code_value(item, Tag.concept_name_code_sequence()) == "113012"
        end)

      assert description_item[Tag.text_value()].value == "Significant mass in right lower lobe"

      image_items =
        Enum.filter(content, fn item ->
          String.trim(item[Tag.value_type()].value) == "IMAGE"
        end)

      assert length(image_items) == 2

      [sop_ref] = hd(image_items)[Tag.referenced_sop_sequence()].value

      assert String.trim_trailing(sop_ref[Tag.referenced_sop_class_uid()].value, <<0>>) ==
               UID.ct_image_storage()
    end

    test "KOS with multiple references including frames and segments" do
      ref_plain = make_reference(9030)
      ref_frames = make_reference(9031, frame_numbers: [1, 3, 5])

      ref_segments =
        Reference.new(
          UID.segmentation_storage(),
          "1.2.826.0.1.3680043.10.1137.9032",
          segment_numbers: [2, 4]
        )

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.930",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.931",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.932",
          observer_name: "RADIOLOGIST^ANA",
          references: [ref_plain, ref_frames, ref_segments]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())

      image_items =
        Enum.filter(content, fn item ->
          String.trim(item[Tag.value_type()].value) == "IMAGE"
        end)

      assert length(image_items) == 3

      frame_item =
        Enum.find(image_items, fn item ->
          [sop_ref] = item[Tag.referenced_sop_sequence()].value
          sop_ref[Tag.referenced_sop_instance_uid()].value == "1.2.826.0.1.3680043.10.1137.9031"
        end)

      [frame_ref] = frame_item[Tag.referenced_sop_sequence()].value
      assert frame_ref[Tag.referenced_frame_number()].value == "1\\3\\5"

      segment_item =
        Enum.find(image_items, fn item ->
          [sop_ref] = item[Tag.referenced_sop_sequence()].value
          sop_ref[Tag.referenced_sop_instance_uid()].value == "1.2.826.0.1.3680043.10.1137.9032"
        end)

      [segment_ref] = segment_item[Tag.referenced_sop_sequence()].value
      assert segment_ref[Tag.referenced_segment_number()].value == [2, 4]
    end

    test "KOS with rejection reason code" do
      ref = make_reference(9040)

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.940",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.941",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.942",
          observer_name: "RADIOLOGIST^ANA",
          title_code: Codes.rejected_for_quality_reasons(),
          description: "Patient motion artifact renders images non-diagnostic",
          references: [ref]
        )

      {:ok, data_set} = Document.to_data_set(document)

      # Root concept is the rejection code, not "Of Interest"
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "113001"
      assert template_identifier(data_set) == "2000"
    end

    test "KOS with best-in-set code" do
      ref = make_reference(9050)

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.950",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.951",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.952",
          observer_name: "RADIOLOGIST^ANA",
          title_code: Codes.best_in_set(),
          references: [ref]
        )

      {:ok, data_set} = Document.to_data_set(document)
      assert code_value(data_set, Tag.concept_name_code_sequence()) == "113018"
    end

    test "KOS without description omits text item" do
      ref = make_reference(9060)

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.960",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.961",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.962",
          observer_name: "RADIOLOGIST^ANA",
          references: [ref]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      refute "113012" in concept_codes
    end

    test "KOS omits device observer when not provided" do
      ref = make_reference(9070)

      {:ok, document} =
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.970",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.971",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.972",
          observer_name: "RADIOLOGIST^ANA",
          observer_device: nil,
          references: [ref]
        )

      {:ok, data_set} = Document.to_data_set(document)
      content = DataSet.get(data_set, Tag.content_sequence())
      concept_codes = Enum.map(content, &code_value(&1, Tag.concept_name_code_sequence()))

      refute "121012" in concept_codes
      refute "121013" in concept_codes
    end

    test "returns error when references list is empty" do
      assert {:error, :no_references} =
               KeyObjectSelection.new(
                 study_instance_uid: "1.2.826.0.1.3680043.10.1137.980",
                 series_instance_uid: "1.2.826.0.1.3680043.10.1137.981",
                 sop_instance_uid: "1.2.826.0.1.3680043.10.1137.982",
                 observer_name: "RADIOLOGIST^ANA",
                 references: []
               )
    end

    test "raises when observer_name is missing" do
      ref = make_reference(9090)

      assert_raise KeyError, fn ->
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.990",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.991",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.992",
          references: [ref]
        )
      end
    end

    test "raises when references key is missing" do
      assert_raise KeyError, fn ->
        KeyObjectSelection.new(
          study_instance_uid: "1.2.826.0.1.3680043.10.1137.993",
          series_instance_uid: "1.2.826.0.1.3680043.10.1137.994",
          sop_instance_uid: "1.2.826.0.1.3680043.10.1137.995",
          observer_name: "RADIOLOGIST^ANA"
        )
      end
    end
  end

  # ── Image Library ───────────────────────────────────────────────────

  describe "ImageLibrary" do
    test "builds a container with image references" do
      ref1 = make_reference(8001)
      ref2 = make_reference(8002)

      item = ImageLibrary.build([ref1, ref2]) |> ContentItem.to_item()

      assert item[Tag.value_type()].value == "CONTAINER"
      assert item[Tag.relationship_type()].value == "CONTAINS"
      assert code_value(item, Tag.concept_name_code_sequence()) == "111028"

      children = item[Tag.content_sequence()].value
      assert length(children) == 2

      Enum.each(children, fn child ->
        assert String.trim(child[Tag.value_type()].value) == "IMAGE"
        assert child[Tag.relationship_type()].value == "CONTAINS"
        assert code_value(child, Tag.concept_name_code_sequence()) == "260753009"
      end)
    end

    test "preserves reference details (SOP class, instance, frames)" do
      ref =
        make_reference(8010, frame_numbers: [2, 4], purpose: Codes.original_source())

      item = ImageLibrary.build([ref]) |> ContentItem.to_item()
      [child] = item[Tag.content_sequence()].value
      [sop_ref] = child[Tag.referenced_sop_sequence()].value

      assert sop_ref[Tag.referenced_sop_class_uid()].value == UID.ct_image_storage()

      assert sop_ref[Tag.referenced_sop_instance_uid()].value ==
               "1.2.826.0.1.3680043.10.1137.8010"

      assert sop_ref[Tag.referenced_frame_number()].value == "2\\4"
      assert code_value(child, Tag.purpose_of_reference_code_sequence()) == "111040"
    end

    test "raises on empty list (FunctionClauseError)" do
      assert_raise FunctionClauseError, fn ->
        ImageLibrary.build([])
      end
    end

    test "single reference produces a valid library container" do
      ref = make_reference(8020)
      item = ImageLibrary.build([ref]) |> ContentItem.to_item()

      children = item[Tag.content_sequence()].value
      assert length(children) == 1
    end
  end
end
