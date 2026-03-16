defmodule DicomTest do
  use ExUnit.Case, async: true

  doctest Dicom
  doctest Dicom.Tag
  doctest Dicom.VR

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
  end

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

  describe "Tag" do
    test "constants return correct tuples" do
      assert Dicom.Tag.patient_name() == {0x0010, 0x0010}
      assert Dicom.Tag.study_instance_uid() == {0x0020, 0x000D}
      assert Dicom.Tag.pixel_data() == {0x7FE0, 0x0010}
    end

    test "format produces hex string" do
      assert Dicom.Tag.format({0x0010, 0x0010}) == "(0010,0010)"
      assert Dicom.Tag.format({0x7FE0, 0x0010}) == "(7FE0,0010)"
    end

    test "private? detects private tags" do
      assert Dicom.Tag.private?({0x0009, 0x0010})
      refute Dicom.Tag.private?({0x0010, 0x0010})
    end

    test "name looks up dictionary" do
      assert Dicom.Tag.name({0x0010, 0x0010}) == "PatientName"
      assert Dicom.Tag.name({0x0099, 0x0099}) == "(0099,0099)"
    end
  end

  describe "Dictionary.Registry" do
    test "lookup returns known tags" do
      assert {:ok, "PatientName", :PN, "1"} = Dicom.Dictionary.Registry.lookup({0x0010, 0x0010})
      assert {:ok, "Modality", :CS, "1"} = Dicom.Dictionary.Registry.lookup({0x0008, 0x0060})
    end

    test "lookup returns :error for unknown tags" do
      assert :error = Dicom.Dictionary.Registry.lookup({0x9999, 0x9999})
    end
  end

  describe "UID" do
    test "transfer syntax UIDs" do
      assert Dicom.UID.implicit_vr_little_endian() == "1.2.840.10008.1.2"
      assert Dicom.UID.explicit_vr_little_endian() == "1.2.840.10008.1.2.1"
    end

    test "storage SOP class UIDs" do
      assert Dicom.UID.ct_image_storage() == "1.2.840.10008.5.1.4.1.1.2"
    end

    test "transfer_syntax? classification" do
      assert Dicom.UID.transfer_syntax?("1.2.840.10008.1.2.1")
      refute Dicom.UID.transfer_syntax?("1.2.840.10008.5.1.4.1.1.2")
    end
  end

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

  describe "TransferSyntax" do
    test "from_uid returns known transfer syntaxes" do
      assert {:ok, %Dicom.TransferSyntax{vr_encoding: :implicit}} =
               Dicom.TransferSyntax.from_uid("1.2.840.10008.1.2")

      assert {:ok, %Dicom.TransferSyntax{vr_encoding: :explicit}} =
               Dicom.TransferSyntax.from_uid("1.2.840.10008.1.2.1")
    end

    test "compressed? detects compressed transfer syntaxes" do
      assert Dicom.TransferSyntax.compressed?("1.2.840.10008.1.2.4.50")
      refute Dicom.TransferSyntax.compressed?("1.2.840.10008.1.2.1")
    end
  end
end
