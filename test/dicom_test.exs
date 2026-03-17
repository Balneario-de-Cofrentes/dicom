defmodule DicomTest do
  use ExUnit.Case, async: true

  import Dicom.TestHelpers, only: [minimal_data_set: 0]

  doctest Dicom
  doctest Dicom.Tag
  doctest Dicom.VR

  # ── Dicom (main API) ────────────────────────────────────────────

  describe "Dicom.parse/1" do
    test "parses valid P10 binary" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.write(ds)
      assert {:ok, %Dicom.DataSet{}} = Dicom.parse(binary)
    end

    test "returns error for invalid binary" do
      assert {:error, :invalid_preamble} = Dicom.parse(<<"not dicom">>)
    end
  end

  describe "Dicom.write/1" do
    test "serializes a data set to P10 binary" do
      ds = minimal_data_set()
      assert {:ok, binary} = Dicom.write(ds)
      assert is_binary(binary)
      assert byte_size(binary) >= 132
    end
  end

  describe "Dicom.parse_file/1 and write_file/2" do
    @tag :tmp_dir
    test "roundtrips through file I/O", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "test.dcm")
      ds = minimal_data_set() |> Dicom.DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      assert :ok = Dicom.write_file(ds, path)
      assert {:ok, parsed} = Dicom.parse_file(path)
      assert Dicom.DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
    end

    test "parse_file returns error for nonexistent file" do
      assert {:error, :enoent} = Dicom.parse_file("/nonexistent/path/file.dcm")
    end
  end

  # ── DataSet ─────────────────────────────────────────────────────

  describe "DataSet" do
    test "new creates empty data set" do
      ds = Dicom.DataSet.new()
      assert Dicom.DataSet.size(ds) == 0
    end

    test "put and get roundtrip" do
      ds =
        Dicom.DataSet.new()
        |> Dicom.DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> Dicom.DataSet.put({0x0010, 0x0020}, :LO, "12345")

      assert Dicom.DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
      assert Dicom.DataSet.get(ds, {0x0010, 0x0020}) == "12345"
      assert Dicom.DataSet.get(ds, {0x0010, 0x0030}) == nil
    end

    test "file meta elements stored separately" do
      ds =
        Dicom.DataSet.new()
        |> Dicom.DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> Dicom.DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      assert Dicom.DataSet.get(ds, {0x0002, 0x0010}) == "1.2.840.10008.1.2.1"
      assert Dicom.DataSet.size(ds) == 2
    end

    test "to_map returns all values" do
      ds =
        Dicom.DataSet.new()
        |> Dicom.DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      map = Dicom.DataSet.to_map(ds)
      assert map[{0x0010, 0x0010}] == "DOE^JOHN"
    end

    test "tags returns sorted list of all tags" do
      ds =
        Dicom.DataSet.new()
        |> Dicom.DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> Dicom.DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> Dicom.DataSet.put({0x0008, 0x0060}, :CS, "CT")

      tags = Dicom.DataSet.tags(ds)
      assert tags == [{0x0002, 0x0010}, {0x0008, 0x0060}, {0x0010, 0x0010}]
    end

    test "get_element returns DataElement struct" do
      ds = Dicom.DataSet.new() |> Dicom.DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
      elem = Dicom.DataSet.get_element(ds, {0x0010, 0x0010})
      assert %Dicom.DataElement{tag: {0x0010, 0x0010}, vr: :PN, value: "DOE^JOHN"} = elem
    end

    test "get_element returns nil for missing tag" do
      ds = Dicom.DataSet.new()
      assert Dicom.DataSet.get_element(ds, {0x0010, 0x0010}) == nil
    end
  end

  # ── VR ──────────────────────────────────────────────────────────

  describe "VR" do
    test "from_binary parses known VRs" do
      assert {:ok, :PN} = Dicom.VR.from_binary("PN")
      assert {:ok, :UI} = Dicom.VR.from_binary("UI")
      assert {:ok, :OB} = Dicom.VR.from_binary("OB")
    end

    test "from_binary rejects unknown VRs" do
      assert {:error, :unknown_vr} = Dicom.VR.from_binary("XX")
    end

    test "long_length? identifies long VRs" do
      assert Dicom.VR.long_length?(:OB)
      assert Dicom.VR.long_length?(:SQ)
      refute Dicom.VR.long_length?(:PN)
      refute Dicom.VR.long_length?(:US)
    end
  end

  # ── Tag ─────────────────────────────────────────────────────────

  describe "Tag constants" do
    test "file meta information tags" do
      assert Dicom.Tag.file_meta_information_group_length() == {0x0002, 0x0000}
      assert Dicom.Tag.file_meta_information_version() == {0x0002, 0x0001}
      assert Dicom.Tag.media_storage_sop_class_uid() == {0x0002, 0x0002}
      assert Dicom.Tag.media_storage_sop_instance_uid() == {0x0002, 0x0003}
      assert Dicom.Tag.transfer_syntax_uid() == {0x0002, 0x0010}
      assert Dicom.Tag.implementation_class_uid() == {0x0002, 0x0012}
      assert Dicom.Tag.implementation_version_name() == {0x0002, 0x0013}
      assert Dicom.Tag.source_application_entity_title() == {0x0002, 0x0016}
      assert Dicom.Tag.sending_application_entity_title() == {0x0002, 0x0017}
      assert Dicom.Tag.receiving_application_entity_title() == {0x0002, 0x0018}
      assert Dicom.Tag.source_presentation_address() == {0x0002, 0x0026}
      assert Dicom.Tag.sending_presentation_address() == {0x0002, 0x0027}
      assert Dicom.Tag.receiving_presentation_address() == {0x0002, 0x0028}
      assert Dicom.Tag.private_information_creator_uid() == {0x0002, 0x0100}
      assert Dicom.Tag.private_information() == {0x0002, 0x0102}
    end

    test "patient tags" do
      assert Dicom.Tag.patient_name() == {0x0010, 0x0010}
      assert Dicom.Tag.patient_id() == {0x0010, 0x0020}
      assert Dicom.Tag.patient_birth_date() == {0x0010, 0x0030}
      assert Dicom.Tag.patient_sex() == {0x0010, 0x0040}
      assert Dicom.Tag.patient_age() == {0x0010, 0x1010}
    end

    test "study and series tags" do
      assert Dicom.Tag.study_date() == {0x0008, 0x0020}
      assert Dicom.Tag.study_time() == {0x0008, 0x0030}
      assert Dicom.Tag.accession_number() == {0x0008, 0x0050}
      assert Dicom.Tag.referring_physician_name() == {0x0008, 0x0090}
      assert Dicom.Tag.study_description() == {0x0008, 0x1030}
      assert Dicom.Tag.study_instance_uid() == {0x0020, 0x000D}
      assert Dicom.Tag.study_id() == {0x0020, 0x0010}
      assert Dicom.Tag.modality() == {0x0008, 0x0060}
      assert Dicom.Tag.series_description() == {0x0008, 0x103E}
      assert Dicom.Tag.series_instance_uid() == {0x0020, 0x000E}
      assert Dicom.Tag.series_number() == {0x0020, 0x0011}
      assert Dicom.Tag.body_part_examined() == {0x0018, 0x0015}
    end

    test "instance and SOP tags" do
      assert Dicom.Tag.sop_class_uid() == {0x0008, 0x0016}
      assert Dicom.Tag.sop_instance_uid() == {0x0008, 0x0018}
      assert Dicom.Tag.instance_number() == {0x0020, 0x0013}
      assert Dicom.Tag.instance_creation_date() == {0x0008, 0x0012}
      assert Dicom.Tag.instance_creation_time() == {0x0008, 0x0013}
    end

    test "image tags" do
      assert Dicom.Tag.rows() == {0x0028, 0x0010}
      assert Dicom.Tag.columns() == {0x0028, 0x0011}
      assert Dicom.Tag.bits_allocated() == {0x0028, 0x0100}
      assert Dicom.Tag.bits_stored() == {0x0028, 0x0101}
      assert Dicom.Tag.high_bit() == {0x0028, 0x0102}
      assert Dicom.Tag.pixel_representation() == {0x0028, 0x0103}
      assert Dicom.Tag.samples_per_pixel() == {0x0028, 0x0002}
      assert Dicom.Tag.photometric_interpretation() == {0x0028, 0x0004}
      assert Dicom.Tag.pixel_data() == {0x7FE0, 0x0010}
      assert Dicom.Tag.number_of_frames() == {0x0028, 0x0008}
    end

    test "delimiter tags" do
      assert Dicom.Tag.data_set_trailing_padding() == {0xFFFC, 0xFFFC}
      assert Dicom.Tag.item() == {0xFFFE, 0xE000}
      assert Dicom.Tag.item_delimitation() == {0xFFFE, 0xE00D}
      assert Dicom.Tag.sequence_delimitation() == {0xFFFE, 0xE0DD}
    end
  end

  describe "Tag utilities" do
    test "format produces hex string" do
      assert Dicom.Tag.format({0x0010, 0x0010}) == "(0010,0010)"
      assert Dicom.Tag.format({0x7FE0, 0x0010}) == "(7FE0,0010)"
    end

    test "private? detects private tags (odd group)" do
      assert Dicom.Tag.private?({0x0009, 0x0010})
      assert Dicom.Tag.private?({0x0011, 0x0001})
      refute Dicom.Tag.private?({0x0010, 0x0010})
      refute Dicom.Tag.private?({0x0008, 0x0060})
    end

    test "group_length? detects group length tags" do
      assert Dicom.Tag.group_length?({0x0002, 0x0000})
      assert Dicom.Tag.group_length?({0x0008, 0x0000})
      refute Dicom.Tag.group_length?({0x0002, 0x0010})
      refute Dicom.Tag.group_length?({0x0010, 0x0010})
    end

    test "name looks up dictionary" do
      assert Dicom.Tag.name({0x0010, 0x0010}) == "PatientName"
      assert Dicom.Tag.name({0x0099, 0x0099}) == "(0099,0099)"
    end
  end

  # ── Dictionary.Registry ─────────────────────────────────────────

  describe "Dictionary.Registry" do
    test "looks up every registered tag" do
      # Exhaustive list of all tags in the registry to ensure 100% clause coverage
      all_tags = [
        # File Meta Information
        {{0x0002, 0x0000}, "FileMetaInformationGroupLength", :UL, "1"},
        {{0x0002, 0x0001}, "FileMetaInformationVersion", :OB, "1"},
        {{0x0002, 0x0002}, "MediaStorageSOPClassUID", :UI, "1"},
        {{0x0002, 0x0003}, "MediaStorageSOPInstanceUID", :UI, "1"},
        {{0x0002, 0x0010}, "TransferSyntaxUID", :UI, "1"},
        {{0x0002, 0x0012}, "ImplementationClassUID", :UI, "1"},
        {{0x0002, 0x0013}, "ImplementationVersionName", :SH, "1"},
        {{0x0002, 0x0016}, "SourceApplicationEntityTitle", :AE, "1"},
        {{0x0002, 0x0017}, "SendingApplicationEntityTitle", :AE, "1"},
        {{0x0002, 0x0018}, "ReceivingApplicationEntityTitle", :AE, "1"},
        {{0x0002, 0x0026}, "SourcePresentationAddress", :UR, "1"},
        {{0x0002, 0x0027}, "SendingPresentationAddress", :UR, "1"},
        {{0x0002, 0x0028}, "ReceivingPresentationAddress", :UR, "1"},
        {{0x0002, 0x0100}, "PrivateInformationCreatorUID", :UI, "1"},
        {{0x0002, 0x0102}, "PrivateInformation", :OB, "1"},
        # SOP Common
        {{0x0008, 0x0005}, "SpecificCharacterSet", :CS, "1-n"},
        {{0x0008, 0x0008}, "ImageType", :CS, "2-n"},
        {{0x0008, 0x0012}, "InstanceCreationDate", :DA, "1"},
        {{0x0008, 0x0013}, "InstanceCreationTime", :TM, "1"},
        {{0x0008, 0x0016}, "SOPClassUID", :UI, "1"},
        {{0x0008, 0x0018}, "SOPInstanceUID", :UI, "1"},
        {{0x0008, 0x0020}, "StudyDate", :DA, "1"},
        {{0x0008, 0x0021}, "SeriesDate", :DA, "1"},
        {{0x0008, 0x0030}, "StudyTime", :TM, "1"},
        {{0x0008, 0x0031}, "SeriesTime", :TM, "1"},
        {{0x0008, 0x0050}, "AccessionNumber", :SH, "1"},
        {{0x0008, 0x0060}, "Modality", :CS, "1"},
        {{0x0008, 0x0070}, "Manufacturer", :LO, "1"},
        {{0x0008, 0x0080}, "InstitutionName", :LO, "1"},
        {{0x0008, 0x0090}, "ReferringPhysicianName", :PN, "1"},
        {{0x0008, 0x1030}, "StudyDescription", :LO, "1"},
        {{0x0008, 0x103E}, "SeriesDescription", :LO, "1"},
        # Patient
        {{0x0010, 0x0010}, "PatientName", :PN, "1"},
        {{0x0010, 0x0020}, "PatientID", :LO, "1"},
        {{0x0010, 0x0030}, "PatientBirthDate", :DA, "1"},
        {{0x0010, 0x0040}, "PatientSex", :CS, "1"},
        {{0x0010, 0x1010}, "PatientAge", :AS, "1"},
        {{0x0010, 0x1020}, "PatientSize", :DS, "1"},
        {{0x0010, 0x1030}, "PatientWeight", :DS, "1"},
        # Equipment
        {{0x0018, 0x0015}, "BodyPartExamined", :CS, "1"},
        {{0x0018, 0x0050}, "SliceThickness", :DS, "1"},
        {{0x0018, 0x0060}, "KVP", :DS, "1"},
        {{0x0018, 0x0088}, "SpacingBetweenSlices", :DS, "1"},
        {{0x0018, 0x1100}, "ReconstructionDiameter", :DS, "1"},
        {{0x0018, 0x1150}, "ExposureTime", :IS, "1"},
        {{0x0018, 0x1151}, "XRayTubeCurrent", :IS, "1"},
        {{0x0018, 0x1152}, "Exposure", :IS, "1"},
        {{0x0018, 0x5100}, "PatientPosition", :CS, "1"},
        # Study/Series/Instance
        {{0x0020, 0x000D}, "StudyInstanceUID", :UI, "1"},
        {{0x0020, 0x000E}, "SeriesInstanceUID", :UI, "1"},
        {{0x0020, 0x0010}, "StudyID", :SH, "1"},
        {{0x0020, 0x0011}, "SeriesNumber", :IS, "1"},
        {{0x0020, 0x0013}, "InstanceNumber", :IS, "1"},
        {{0x0020, 0x0032}, "ImagePositionPatient", :DS, "3"},
        {{0x0020, 0x0037}, "ImageOrientationPatient", :DS, "6"},
        {{0x0020, 0x0052}, "FrameOfReferenceUID", :UI, "1"},
        {{0x0020, 0x1041}, "SliceLocation", :DS, "1"},
        # Image Pixel
        {{0x0028, 0x0002}, "SamplesPerPixel", :US, "1"},
        {{0x0028, 0x0004}, "PhotometricInterpretation", :CS, "1"},
        {{0x0028, 0x0008}, "NumberOfFrames", :IS, "1"},
        {{0x0028, 0x0010}, "Rows", :US, "1"},
        {{0x0028, 0x0011}, "Columns", :US, "1"},
        {{0x0028, 0x0030}, "PixelSpacing", :DS, "2"},
        {{0x0028, 0x0100}, "BitsAllocated", :US, "1"},
        {{0x0028, 0x0101}, "BitsStored", :US, "1"},
        {{0x0028, 0x0102}, "HighBit", :US, "1"},
        {{0x0028, 0x0103}, "PixelRepresentation", :US, "1"},
        {{0x0028, 0x1050}, "WindowCenter", :DS, "1-n"},
        {{0x0028, 0x1051}, "WindowWidth", :DS, "1-n"},
        {{0x0028, 0x1052}, "RescaleIntercept", :DS, "1"},
        {{0x0028, 0x1053}, "RescaleSlope", :DS, "1"},
        # Common Sequences (SQ VM is always "1" per PS3.6; multiplicity is via items)
        {{0x0008, 0x1115}, "ReferencedSeriesSequence", :SQ, "1"},
        {{0x0008, 0x1120}, "ReferencedPatientSequence", :SQ, "1"},
        {{0x0008, 0x1140}, "ReferencedImageSequence", :SQ, "1"},
        {{0x0008, 0x1150}, "ReferencedSOPClassUID", :UI, "1"},
        {{0x0008, 0x1155}, "ReferencedSOPInstanceUID", :UI, "1"},
        {{0x0040, 0x0275}, "RequestAttributesSequence", :SQ, "1"},
        {{0x0040, 0xA730}, "ContentSequence", :SQ, "1"},
        # Pixel Data and Trailing Padding (PS3.6: OB or OW; OW used as default)
        {{0x7FE0, 0x0010}, "PixelData", :OW, "1"},
        {{0xFFFC, 0xFFFC}, "DataSetTrailingPadding", :OB, "1"}
      ]

      for {tag, expected_name, expected_vr, expected_vm} <- all_tags do
        assert {:ok, ^expected_name, ^expected_vr, ^expected_vm} =
                 Dicom.Dictionary.Registry.lookup(tag),
               "Failed lookup for #{Dicom.Tag.format(tag)} (#{expected_name})"
      end
    end

    test "returns :error for unknown tags" do
      assert :error = Dicom.Dictionary.Registry.lookup({0x9999, 0x9999})
    end
  end

  # ── UID ─────────────────────────────────────────────────────────

  describe "UID constants" do
    test "transfer syntax UIDs" do
      assert Dicom.UID.implicit_vr_little_endian() == "1.2.840.10008.1.2"
      assert Dicom.UID.explicit_vr_little_endian() == "1.2.840.10008.1.2.1"
      assert Dicom.UID.explicit_vr_big_endian() == "1.2.840.10008.1.2.2"
      assert Dicom.UID.deflated_explicit_vr_little_endian() == "1.2.840.10008.1.2.1.99"
      assert Dicom.UID.jpeg_baseline() == "1.2.840.10008.1.2.4.50"
      assert Dicom.UID.jpeg_extended() == "1.2.840.10008.1.2.4.51"
      assert Dicom.UID.jpeg_lossless() == "1.2.840.10008.1.2.4.70"
      assert Dicom.UID.jpeg_lossless_first_order() == "1.2.840.10008.1.2.4.57"
      assert Dicom.UID.jpeg_ls_lossless() == "1.2.840.10008.1.2.4.80"
      assert Dicom.UID.jpeg_ls_lossy() == "1.2.840.10008.1.2.4.81"
      assert Dicom.UID.jpeg_2000_lossless() == "1.2.840.10008.1.2.4.90"
      assert Dicom.UID.jpeg_2000() == "1.2.840.10008.1.2.4.91"
      assert Dicom.UID.rle_lossless() == "1.2.840.10008.1.2.5"
    end

    test "storage SOP class UIDs" do
      assert Dicom.UID.ct_image_storage() == "1.2.840.10008.5.1.4.1.1.2"
      assert Dicom.UID.mr_image_storage() == "1.2.840.10008.5.1.4.1.1.4"
      assert Dicom.UID.cr_image_storage() == "1.2.840.10008.5.1.4.1.1.1"
      assert Dicom.UID.dx_image_storage() == "1.2.840.10008.5.1.4.1.1.1.1"
      assert Dicom.UID.us_image_storage() == "1.2.840.10008.5.1.4.1.1.6.1"
      assert Dicom.UID.nm_image_storage() == "1.2.840.10008.5.1.4.1.1.20"
      assert Dicom.UID.sc_image_storage() == "1.2.840.10008.5.1.4.1.1.7"
      assert Dicom.UID.enhanced_ct_image_storage() == "1.2.840.10008.5.1.4.1.1.2.1"
      assert Dicom.UID.enhanced_mr_image_storage() == "1.2.840.10008.5.1.4.1.1.4.1"
      assert Dicom.UID.rt_plan_storage() == "1.2.840.10008.5.1.4.1.1.481.5"
      assert Dicom.UID.rt_dose_storage() == "1.2.840.10008.5.1.4.1.1.481.2"
      assert Dicom.UID.rt_structure_set_storage() == "1.2.840.10008.5.1.4.1.1.481.3"
      assert Dicom.UID.basic_text_sr_storage() == "1.2.840.10008.5.1.4.1.1.88.11"
      assert Dicom.UID.enhanced_sr_storage() == "1.2.840.10008.5.1.4.1.1.88.22"
      assert Dicom.UID.comprehensive_sr_storage() == "1.2.840.10008.5.1.4.1.1.88.33"
      assert Dicom.UID.encapsulated_pdf_storage() == "1.2.840.10008.5.1.4.1.1.104.1"
      assert Dicom.UID.segmentation_storage() == "1.2.840.10008.5.1.4.1.1.66.4"
    end

    test "query/retrieve and verification SOP class UIDs" do
      assert Dicom.UID.verification_sop_class() == "1.2.840.10008.1.1"
      assert Dicom.UID.patient_root_qr_find() == "1.2.840.10008.5.1.4.1.2.1.1"
      assert Dicom.UID.patient_root_qr_move() == "1.2.840.10008.5.1.4.1.2.1.2"
      assert Dicom.UID.patient_root_qr_get() == "1.2.840.10008.5.1.4.1.2.1.3"
      assert Dicom.UID.study_root_qr_find() == "1.2.840.10008.5.1.4.1.2.2.1"
      assert Dicom.UID.study_root_qr_move() == "1.2.840.10008.5.1.4.1.2.2.2"
      assert Dicom.UID.study_root_qr_get() == "1.2.840.10008.5.1.4.1.2.2.3"
      assert Dicom.UID.modality_worklist_find() == "1.2.840.10008.5.1.4.31"
    end
  end

  describe "UID classification" do
    test "transfer_syntax? identifies transfer syntax UIDs" do
      assert Dicom.UID.transfer_syntax?("1.2.840.10008.1.2.1")
      assert Dicom.UID.transfer_syntax?("1.2.840.10008.1.2.4.50")
      refute Dicom.UID.transfer_syntax?("1.2.840.10008.5.1.4.1.1.2")
      refute Dicom.UID.transfer_syntax?("1.2.3.4.5.6")
    end

    test "storage_sop_class? identifies storage SOP classes" do
      assert Dicom.UID.storage_sop_class?("1.2.840.10008.5.1.4.1.1.2")
      assert Dicom.UID.storage_sop_class?("1.2.840.10008.5.1.4.1.1.4")
      refute Dicom.UID.storage_sop_class?("1.2.840.10008.1.2.1")
      refute Dicom.UID.storage_sop_class?("1.2.3.4.5.6")
    end
  end

  # ── TransferSyntax ──────────────────────────────────────────────

  describe "TransferSyntax" do
    test "from_uid returns known transfer syntaxes" do
      assert {:ok, %Dicom.TransferSyntax{vr_encoding: :implicit}} =
               Dicom.TransferSyntax.from_uid("1.2.840.10008.1.2")

      assert {:ok, %Dicom.TransferSyntax{vr_encoding: :explicit}} =
               Dicom.TransferSyntax.from_uid("1.2.840.10008.1.2.1")

      assert {:ok, %Dicom.TransferSyntax{endianness: :big}} =
               Dicom.TransferSyntax.from_uid("1.2.840.10008.1.2.2")
    end

    test "from_uid returns error for unknown transfer syntax" do
      assert {:error, :unknown_transfer_syntax} = Dicom.TransferSyntax.from_uid("1.2.3.4.5.6")
    end

    test "implicit_vr? detects implicit VR" do
      assert Dicom.TransferSyntax.implicit_vr?("1.2.840.10008.1.2")
      refute Dicom.TransferSyntax.implicit_vr?("1.2.840.10008.1.2.1")
      refute Dicom.TransferSyntax.implicit_vr?("1.2.840.10008.1.2.2")
    end

    test "compressed? detects compressed transfer syntaxes" do
      assert Dicom.TransferSyntax.compressed?("1.2.840.10008.1.2.4.50")
      assert Dicom.TransferSyntax.compressed?("1.2.840.10008.1.2.5")
      refute Dicom.TransferSyntax.compressed?("1.2.840.10008.1.2.1")
      refute Dicom.TransferSyntax.compressed?("1.2.840.10008.1.2")
    end

    test "compressed? returns false for unknown UID" do
      refute Dicom.TransferSyntax.compressed?("1.2.3.4.5.6.7.8.9")
    end

    test "encoding returns VR encoding and endianness" do
      assert {:ok, {:implicit, :little}} = Dicom.TransferSyntax.encoding("1.2.840.10008.1.2")
      assert {:ok, {:explicit, :little}} = Dicom.TransferSyntax.encoding("1.2.840.10008.1.2.1")
      assert {:ok, {:explicit, :big}} = Dicom.TransferSyntax.encoding("1.2.840.10008.1.2.2")
    end

    test "encoding returns error for unknown UID by default" do
      assert {:error, :unknown_transfer_syntax} =
               Dicom.TransferSyntax.encoding("1.2.3.4.5.6.7.8.9")
    end

    test "encoding with lenient: true falls back to explicit LE for unknown UID" do
      assert {:ok, {:explicit, :little}} =
               Dicom.TransferSyntax.encoding("1.2.3.4.5.6.7.8.9", lenient: true)
    end

    test "extract_uid extracts transfer syntax from file meta" do
      elem = Dicom.DataElement.new({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      file_meta = %{{0x0002, 0x0010} => elem}
      assert Dicom.TransferSyntax.extract_uid(file_meta) == "1.2.840.10008.1.2.1"
    end

    test "extract_uid trims null padding from UID" do
      elem = Dicom.DataElement.new({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1\0")
      file_meta = %{{0x0002, 0x0010} => elem}
      assert Dicom.TransferSyntax.extract_uid(file_meta) == "1.2.840.10008.1.2.1"
    end

    test "extract_uid falls back to implicit VR LE when tag absent" do
      assert Dicom.TransferSyntax.extract_uid(%{}) == "1.2.840.10008.1.2"
    end
  end

  # ── P10.FileMeta ────────────────────────────────────────────────

  describe "P10.FileMeta" do
    test "preamble generates 132 bytes" do
      preamble = Dicom.P10.FileMeta.preamble()
      assert byte_size(preamble) == 132
      assert binary_part(preamble, 128, 4) == "DICM"
    end

    test "skip_preamble validates magic" do
      valid = <<0::1024, "DICM", "rest">>
      assert {:ok, "rest"} = Dicom.P10.FileMeta.skip_preamble(valid)

      assert {:error, :invalid_preamble} = Dicom.P10.FileMeta.skip_preamble(<<"not dicom">>)
    end
  end
end
