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
    test "parses all 34 standard VR types" do
      all_vrs = [
        {"AE", :AE},
        {"AS", :AS},
        {"AT", :AT},
        {"CS", :CS},
        {"DA", :DA},
        {"DS", :DS},
        {"DT", :DT},
        {"FL", :FL},
        {"FD", :FD},
        {"IS", :IS},
        {"LO", :LO},
        {"LT", :LT},
        {"OB", :OB},
        {"OD", :OD},
        {"OF", :OF},
        {"OL", :OL},
        {"OV", :OV},
        {"OW", :OW},
        {"PN", :PN},
        {"SH", :SH},
        {"SL", :SL},
        {"SQ", :SQ},
        {"SS", :SS},
        {"ST", :ST},
        {"SV", :SV},
        {"TM", :TM},
        {"UC", :UC},
        {"UI", :UI},
        {"UL", :UL},
        {"UN", :UN},
        {"UR", :UR},
        {"US", :US},
        {"UT", :UT},
        {"UV", :UV}
      ]

      for {binary, expected} <- all_vrs do
        assert {:ok, ^expected} = Dicom.VR.from_binary(binary), "Failed to parse VR #{binary}"
      end
    end

    test "rejects unknown VR strings" do
      assert {:error, :unknown_vr} = Dicom.VR.from_binary("XX")
      assert {:error, :unknown_vr} = Dicom.VR.from_binary("ZZ")
      assert {:error, :unknown_vr} = Dicom.VR.from_binary("00")
    end
  end

  describe "to_binary/1" do
    test "converts all VR atoms to 2-byte strings" do
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
            :OB,
            :OD,
            :OF,
            :OL,
            :OV,
            :OW,
            :PN,
            :SH,
            :SL,
            :SQ,
            :SS,
            :ST,
            :SV,
            :TM,
            :UC,
            :UI,
            :UL,
            :UN,
            :UR,
            :US,
            :UT,
            :UV
          ] do
        binary = Dicom.VR.to_binary(vr)
        assert byte_size(binary) == 2, "VR #{vr} should be 2 bytes"
        assert {:ok, ^vr} = Dicom.VR.from_binary(binary), "Roundtrip failed for #{vr}"
      end
    end
  end

  describe "string?/1" do
    test "identifies all string VRs" do
      string_vrs = [
        :AE,
        :AS,
        :CS,
        :DA,
        :DS,
        :DT,
        :IS,
        :LO,
        :LT,
        :PN,
        :SH,
        :ST,
        :TM,
        :UC,
        :UI,
        :UR,
        :UT
      ]

      for vr <- string_vrs do
        assert Dicom.VR.string?(vr), "#{vr} should be a string VR"
      end
    end

    test "rejects non-string VRs" do
      for vr <- [
            :OB,
            :OW,
            :UN,
            :US,
            :SS,
            :UL,
            :SL,
            :FL,
            :FD,
            :SQ,
            :AT,
            :SV,
            :UV,
            :OV,
            :OD,
            :OF,
            :OL
          ] do
        refute Dicom.VR.string?(vr), "#{vr} should not be a string VR"
      end
    end
  end

  describe "binary?/1" do
    test "identifies all binary VRs" do
      for vr <- [:OB, :OD, :OF, :OL, :OV, :OW, :UN] do
        assert Dicom.VR.binary?(vr), "#{vr} should be a binary VR"
      end
    end

    test "rejects non-binary VRs" do
      refute Dicom.VR.binary?(:PN)
      refute Dicom.VR.binary?(:US)
      refute Dicom.VR.binary?(:SQ)
    end
  end

  describe "numeric?/1" do
    test "identifies all numeric VRs" do
      for vr <- [:FL, :FD, :SL, :SS, :SV, :UL, :US, :UV] do
        assert Dicom.VR.numeric?(vr), "#{vr} should be a numeric VR"
      end
    end

    test "rejects non-numeric VRs" do
      refute Dicom.VR.numeric?(:PN)
      refute Dicom.VR.numeric?(:OB)
      refute Dicom.VR.numeric?(:SQ)
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
