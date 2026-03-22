defmodule Dicom.SR.DocumentReaderTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataElement, DataSet, Tag}
  alias Dicom.SR.DocumentReader

  # Builds an item map (as stored inside a sequence) from a keyword list
  # of {tag, vr, value} tuples.
  defp build_item(entries) do
    Map.new(entries, fn {tag, vr, value} ->
      {tag, DataElement.new(tag, vr, value)}
    end)
  end

  describe "from_data_set/1 — basic extraction" do
    test "extracts all document-level metadata from a well-formed SR data set" do
      template_item =
        build_item([
          {Tag.template_identifier(), :CS, "2000"},
          {Tag.mapping_resource(), :CS, "DCMR"}
        ])

      observer_item =
        build_item([{Tag.verifying_observer_name(), :PN, "SMITH^ALICE"}])

      ds =
        DataSet.new()
        |> DataSet.put(Tag.completion_flag(), :CS, "COMPLETE")
        |> DataSet.put(Tag.verification_flag(), :CS, "VERIFIED")
        |> DataSet.put(Tag.content_date(), :DA, "20240101")
        |> DataSet.put(Tag.content_time(), :TM, "120000")
        |> DataSet.put(Tag.content_template_sequence(), :SQ, [template_item])
        |> DataSet.put(Tag.sop_class_uid(), :UI, "1.2.840.10008.5.1.4.1.1.88.33")
        |> DataSet.put(Tag.sop_instance_uid(), :UI, "1.2.3.4.5")
        |> DataSet.put(Tag.study_instance_uid(), :UI, "1.2.3.4")
        |> DataSet.put(Tag.series_instance_uid(), :UI, "1.2.3.5")
        |> DataSet.put(Tag.modality(), :CS, "SR")
        |> DataSet.put(Tag.verification_date_time(), :DT, "20240101120000")
        |> DataSet.put(Tag.verifying_observer_sequence(), :SQ, [observer_item])

      assert {:ok, meta} = DocumentReader.from_data_set(ds)

      assert meta.completion_flag == "COMPLETE"
      assert meta.verification_flag == "VERIFIED"
      assert meta.content_date == "20240101"
      assert meta.content_time == "120000"
      assert meta.template_identifier == "2000"
      assert meta.mapping_resource == "DCMR"
      assert meta.modality == "SR"
      assert meta.verification_datetime == "20240101120000"
      assert meta.verifying_observer_name == "SMITH^ALICE"
    end

    test "returns nils for absent optional fields" do
      ds = DataSet.new()

      assert {:ok, meta} = DocumentReader.from_data_set(ds)

      assert meta.completion_flag == nil
      assert meta.verification_flag == nil
      assert meta.template_identifier == nil
      assert meta.mapping_resource == nil
      assert meta.verification_datetime == nil
      assert meta.verifying_observer_name == nil
    end
  end

  describe "from_data_set/1 — get_item_trimmed catch-all (line 109)" do
    test "returns nil for template_identifier when sequence item has non-binary value" do
      # Template item with an integer value instead of a binary string
      item = %{
        Tag.template_identifier() => %DataElement{
          tag: Tag.template_identifier(),
          vr: :CS,
          value: 42,
          length: 0
        }
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.content_template_sequence(), :SQ, [item])

      assert {:ok, meta} = DocumentReader.from_data_set(ds)

      assert meta.template_identifier == nil
      assert meta.mapping_resource == nil
    end

    test "returns nil for template_identifier when sequence item has nil value" do
      item = %{
        Tag.template_identifier() => %DataElement{
          tag: Tag.template_identifier(),
          vr: :CS,
          value: nil,
          length: 0
        }
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.content_template_sequence(), :SQ, [item])

      assert {:ok, meta} = DocumentReader.from_data_set(ds)
      assert meta.template_identifier == nil
    end

    test "returns nil for verifying_observer_name when item has non-binary value" do
      observer_item = %{
        Tag.verifying_observer_name() => %DataElement{
          tag: Tag.verifying_observer_name(),
          vr: :PN,
          value: 0,
          length: 0
        }
      }

      ds =
        DataSet.new()
        |> DataSet.put(Tag.verifying_observer_sequence(), :SQ, [observer_item])

      assert {:ok, meta} = DocumentReader.from_data_set(ds)
      assert meta.verifying_observer_name == nil
    end

    test "returns nil when tag is missing from sequence item" do
      # Empty item map — tag not present at all
      ds =
        DataSet.new()
        |> DataSet.put(Tag.content_template_sequence(), :SQ, [%{}])

      assert {:ok, meta} = DocumentReader.from_data_set(ds)
      assert meta.template_identifier == nil
      assert meta.mapping_resource == nil
    end
  end
end
