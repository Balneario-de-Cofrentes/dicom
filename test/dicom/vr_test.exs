defmodule Dicom.VRTest do
  use ExUnit.Case, async: true

  describe "pad_value/2" do
    test "does not pad even-length values" do
      assert Dicom.VR.pad_value("AB", :PN) == "AB"
      assert Dicom.VR.pad_value(<<1, 2>>, :OB) == <<1, 2>>
    end

    test "pads odd-length string VRs with space (0x20)" do
      assert Dicom.VR.pad_value("ABC", :PN) == "ABC "
      assert Dicom.VR.pad_value("A", :LO) == "A "
      assert Dicom.VR.pad_value("X", :SH) == "X "
    end

    test "pads odd-length UI values with null byte (0x00)" do
      assert Dicom.VR.pad_value("1.2.3", :UI) == <<"1.2.3", 0>>
    end

    test "pads odd-length binary VRs with null byte (0x00)" do
      assert Dicom.VR.pad_value(<<1>>, :OB) == <<1, 0>>
      assert Dicom.VR.pad_value(<<1, 2, 3>>, :OW) == <<1, 2, 3, 0>>
    end

    test "does not pad empty values" do
      assert Dicom.VR.pad_value("", :PN) == ""
      assert Dicom.VR.pad_value(<<>>, :OB) == <<>>
    end
  end

  describe "padding_byte/1" do
    test "UI pads with null" do
      assert Dicom.VR.padding_byte(:UI) == 0x00
    end

    test "string VRs pad with space" do
      for vr <- [:AE, :CS, :DA, :DS, :DT, :IS, :LO, :LT, :PN, :SH, :ST, :TM] do
        assert Dicom.VR.padding_byte(vr) == 0x20, "Expected space padding for #{vr}"
      end
    end

    test "binary and numeric VRs pad with null" do
      for vr <- [:OB, :OW, :OV, :UN, :US, :SS, :UL, :SL, :FL, :FD, :AT, :SQ, :SV, :UV] do
        assert Dicom.VR.padding_byte(vr) == 0x00, "Expected null padding for #{vr}"
      end
    end
  end

  describe "from_binary/1" do
    test "parses OV, UV, SV VR types" do
      assert {:ok, :OV} = Dicom.VR.from_binary("OV")
      assert {:ok, :UV} = Dicom.VR.from_binary("UV")
      assert {:ok, :SV} = Dicom.VR.from_binary("SV")
    end
  end

  describe "long_length?/1" do
    test "OV and UV use 4-byte length (long format)" do
      assert Dicom.VR.long_length?(:OV)
      assert Dicom.VR.long_length?(:UV)
    end

    test "SV uses 4-byte length (long format)" do
      assert Dicom.VR.long_length?(:SV)
    end

    test "short VRs use 2-byte length" do
      for vr <- [
            :AE,
            :AS,
            :AT,
            :CS,
            :DA,
            :DS,
            :DT,
            :FL,
            :FD,
            :IS,
            :LO,
            :LT,
            :PN,
            :SH,
            :SL,
            :SS,
            :ST,
            :TM,
            :UI,
            :UL,
            :US
          ] do
        refute Dicom.VR.long_length?(vr), "#{vr} should use short length"
      end
    end
  end
end
