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

  describe "all/0" do
    test "returns exactly 34 VR atoms" do
      assert length(Dicom.VR.all()) == 34
    end

    test "returns unique values" do
      all = Dicom.VR.all()
      assert length(all) == length(Enum.uniq(all))
    end

    test "is sorted" do
      all = Dicom.VR.all()
      assert all == Enum.sort(all)
    end

    test "includes all known VR categories" do
      all = MapSet.new(Dicom.VR.all())

      for vr <-
            Dicom.VR.string_vrs() ++ Dicom.VR.binary_vrs() ++ Dicom.VR.numeric_vrs() ++ [:SQ, :AT] do
        assert MapSet.member?(all, vr), "#{vr} missing from all/0"
      end
    end
  end

  describe "description/1" do
    test "returns human name for each VR" do
      for vr <- Dicom.VR.all() do
        desc = Dicom.VR.description(vr)
        assert is_binary(desc), "description/1 should return a string for #{vr}"
        assert String.length(desc) > 0, "description/1 should not be empty for #{vr}"
      end
    end

    test "known descriptions match PS3.5 Table 6.2-1" do
      assert Dicom.VR.description(:PN) == "Person Name"
      assert Dicom.VR.description(:DA) == "Date"
      assert Dicom.VR.description(:SQ) == "Sequence of Items"
      assert Dicom.VR.description(:OB) == "Other Byte"
      assert Dicom.VR.description(:UI) == "Unique Identifier"
    end
  end

  describe "max_length/1" do
    test "returns known max lengths" do
      assert Dicom.VR.max_length(:PN) == 64
      assert Dicom.VR.max_length(:US) == 2
      assert Dicom.VR.max_length(:SS) == 2
      assert Dicom.VR.max_length(:UL) == 4
      assert Dicom.VR.max_length(:DA) == 8
      assert Dicom.VR.max_length(:UI) == 64
      assert Dicom.VR.max_length(:LO) == 64
      assert Dicom.VR.max_length(:SH) == 16
      assert Dicom.VR.max_length(:CS) == 16
    end

    test "returns :unlimited for unbounded VRs" do
      for vr <- [:UT, :OB, :OW, :UN, :SQ, :UC, :UR, :OV, :OD, :OF, :OL] do
        assert Dicom.VR.max_length(vr) == :unlimited, "#{vr} should be :unlimited"
      end
    end

    test "every VR has a max_length" do
      for vr <- Dicom.VR.all() do
        result = Dicom.VR.max_length(vr)
        assert is_integer(result) or result == :unlimited, "max_length/1 invalid for #{vr}"
      end
    end
  end

  describe "fixed_length?/1" do
    test "true for fixed-width numeric VRs" do
      for vr <- [:AT, :FL, :FD, :SL, :SS, :UL, :US, :SV, :UV] do
        assert Dicom.VR.fixed_length?(vr), "#{vr} should be fixed length"
      end
    end

    test "false for string, binary, and sequence VRs" do
      for vr <- [:PN, :DA, :LO, :OB, :OW, :SQ, :UN, :UT, :CS, :UI] do
        refute Dicom.VR.fixed_length?(vr), "#{vr} should not be fixed length"
      end
    end
  end
end
