defmodule Dicom.Dictionary.RegistryTest do
  use ExUnit.Case, async: true

  alias Dicom.Dictionary.Registry

  import Dicom.TestHelpers,
    only: [pad_to_even: 1, elem_explicit: 3, build_group_length_element: 1]

  describe "expanded dictionary coverage" do
    test "registry contains >4000 entries" do
      assert Registry.size() > 4000
    end

    test "looks up tags that were NOT in the old hand-written dictionary" do
      # These tags were missing from the old ~95-entry dictionary
      new_tags = [
        {{0x0008, 0x0006}, "LanguageCodeSequence", :SQ},
        {{0x0008, 0x0014}, "InstanceCreatorUID", :UI},
        {{0x0008, 0x0022}, "AcquisitionDate", :DA},
        {{0x0008, 0x0023}, "ContentDate", :DA},
        {{0x0008, 0x0032}, "AcquisitionTime", :TM},
        {{0x0008, 0x0033}, "ContentTime", :TM},
        {{0x0008, 0x0081}, "InstitutionAddress", :ST},
        {{0x0008, 0x1010}, "StationName", :SH},
        {{0x0008, 0x1040}, "InstitutionalDepartmentName", :LO},
        {{0x0008, 0x1090}, "ManufacturerModelName", :LO},
        {{0x0010, 0x0021}, "IssuerOfPatientID", :LO},
        {{0x0010, 0x1000}, "OtherPatientIDs", :LO},
        {{0x0010, 0x2160}, "EthnicGroup", :SH},
        {{0x0018, 0x0020}, "ScanningSequence", :CS},
        {{0x0018, 0x0021}, "SequenceVariant", :CS},
        {{0x0018, 0x0022}, "ScanOptions", :CS},
        {{0x0018, 0x0023}, "MRAcquisitionType", :CS},
        {{0x0018, 0x0080}, "RepetitionTime", :DS},
        {{0x0018, 0x0081}, "EchoTime", :DS},
        {{0x0018, 0x0082}, "InversionTime", :DS},
        {{0x0018, 0x0083}, "NumberOfAverages", :DS},
        {{0x0018, 0x0084}, "ImagingFrequency", :DS},
        {{0x0018, 0x0085}, "ImagedNucleus", :SH},
        {{0x0018, 0x0087}, "MagneticFieldStrength", :DS},
        {{0x0018, 0x0093}, "PercentSampling", :DS},
        {{0x0018, 0x0094}, "PercentPhaseFieldOfView", :DS},
        {{0x0018, 0x1030}, "ProtocolName", :LO},
        {{0x0018, 0x1310}, "AcquisitionMatrix", :US},
        {{0x0020, 0x0012}, "AcquisitionNumber", :IS},
        {{0x0020, 0x0060}, "Laterality", :CS},
        {{0x0020, 0x1002}, "ImagesInAcquisition", :IS},
        {{0x0020, 0x4000}, "ImageComments", :LT},
        {{0x0032, 0x1060}, "RequestedProcedureDescription", :LO},
        {{0x0038, 0x0010}, "AdmissionID", :LO},
        {{0x0040, 0x0244}, "PerformedProcedureStepStartDate", :DA},
        {{0x0040, 0x0245}, "PerformedProcedureStepStartTime", :TM},
        {{0x0040, 0x0253}, "PerformedProcedureStepID", :SH},
        {{0x0040, 0x1001}, "RequestedProcedureID", :SH},
        {{0x0088, 0x0140}, "StorageMediaFileSetUID", :UI}
      ]

      for {tag, expected_keyword, expected_vr} <- new_tags do
        assert {:ok, ^expected_keyword, ^expected_vr, _vm} = Registry.lookup(tag),
               "Missing or wrong for #{Dicom.Tag.format(tag)} (#{expected_keyword})"
      end
    end

    test "sequence tags resolve to :SQ for implicit VR parsing" do
      # These SQ tags were NOT in the old dictionary and would have defaulted to :UN
      sq_tags = [
        {0x0008, 0x0006},
        {0x0008, 0x0051},
        {0x0008, 0x0082},
        {0x0008, 0x0096},
        {0x0008, 0x0110},
        {0x0008, 0x1111},
        {0x0008, 0x1250},
        {0x0010, 0x0024},
        {0x0010, 0x0026},
        {0x0040, 0x0008},
        {0x0040, 0x0100},
        {0x0040, 0x0260},
        {0x0040, 0x0555},
        {0x0054, 0x0016},
        {0x0054, 0x0022}
      ]

      for tag <- sq_tags do
        assert {:ok, _name, :SQ, _vm} = Registry.lookup(tag),
               "Tag #{Dicom.Tag.format(tag)} should be SQ in the dictionary"
      end
    end

    test "overlay repeating group tags resolve correctly" do
      assert {:ok, "OverlayRows", :US, "1"} = Registry.lookup({0x6000, 0x0010})
      assert {:ok, "OverlayType", :CS, "1"} = Registry.lookup({0x6002, 0x0040})
      assert {:ok, "OverlayData", :OB, "1"} = Registry.lookup({0x600E, 0x3000})
      # Non-overlay even group should not match
      assert :error = Registry.lookup({0x6020, 0x0010})
      # Unknown overlay element
      assert :error = Registry.lookup({0x6000, 0x9999})
    end

    test "returns :error for private tags" do
      assert :error = Registry.lookup({0x0009, 0x0010})
      assert :error = Registry.lookup({0x0011, 0x0001})
    end
  end

  describe "implicit VR parsing with expanded dictionary" do
    test "previously unknown SQ tag parses as sequence in implicit VR" do
      # ScheduledProcedureStepSequence (0040,0100) was NOT in old dictionary.
      # In Implicit VR, the reader relies on dictionary to know it's SQ.
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.840.10008.1.2"))

      # Inner element: ScheduledStationAETitle (0040,0001) CS
      inner_value = pad_to_even("SCANNER1")
      inner_elem = <<0x40, 0x00, 0x01, 0x00, byte_size(inner_value)::little-32>> <> inner_value

      # Item
      item = <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner_elem)::little-32>> <> inner_elem

      # Sequence (0040,0100) in implicit VR
      sq = <<0x40, 0x00, 0x00, 0x01, byte_size(item)::little-32>> <> item

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> sq

      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      seq_value = Dicom.DataSet.get(ds, {0x0040, 0x0100})
      assert is_list(seq_value), "Expected sequence items list, got: #{inspect(seq_value)}"
      assert length(seq_value) == 1
    end

    test "previously unknown standard tag gets correct VR in implicit VR" do
      # ProtocolName (0018,1030) LO — was NOT in old dictionary
      ts_elem = elem_explicit({0x0002, 0x0010}, :UI, pad_to_even("1.2.840.10008.1.2"))

      proto_value = pad_to_even("T1_BRAIN")
      implicit_elem = <<0x18, 0x00, 0x30, 0x10, byte_size(proto_value)::little-32>> <> proto_value

      binary =
        <<0::1024, "DICM">> <>
          build_group_length_element(ts_elem) <>
          ts_elem <> implicit_elem

      {:ok, ds} = Dicom.P10.Reader.parse(binary)

      elem = Dicom.DataSet.get_element(ds, {0x0018, 0x1030})
      assert elem.vr == :LO
    end
  end
end
