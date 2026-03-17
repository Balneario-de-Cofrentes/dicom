defmodule Dicom.TagTest do
  use ExUnit.Case, async: true

  doctest Dicom.Tag

  describe "parse/1" do
    test "parses parenthesized format (GGGG,EEEE)" do
      assert {:ok, {0x0010, 0x0010}} = Dicom.Tag.parse("(0010,0010)")
    end

    test "parses compact format GGGGEEEE" do
      assert {:ok, {0x0010, 0x0010}} = Dicom.Tag.parse("00100010")
    end

    test "handles uppercase hex" do
      assert {:ok, {0x7FE0, 0x0010}} = Dicom.Tag.parse("(7FE0,0010)")
    end

    test "handles lowercase hex" do
      assert {:ok, {0x7FE0, 0x0010}} = Dicom.Tag.parse("(7fe0,0010)")
    end

    test "parses boundary values" do
      assert {:ok, {0x0000, 0x0000}} = Dicom.Tag.parse("(0000,0000)")
      assert {:ok, {0xFFFF, 0xFFFF}} = Dicom.Tag.parse("(FFFF,FFFF)")
    end

    test "rejects invalid formats" do
      assert {:error, :invalid_tag_format} = Dicom.Tag.parse("invalid")
      assert {:error, :invalid_tag_format} = Dicom.Tag.parse("0010,0010")
      assert {:error, :invalid_tag_format} = Dicom.Tag.parse("(0010)")
      assert {:error, :invalid_tag_format} = Dicom.Tag.parse("")
      assert {:error, :invalid_tag_format} = Dicom.Tag.parse("(ZZZZ,0010)")
    end
  end

  describe "from_keyword/1" do
    test "finds known keywords" do
      assert {:ok, {0x0010, 0x0010}} = Dicom.Tag.from_keyword("PatientName")
      assert {:ok, {0x0008, 0x0060}} = Dicom.Tag.from_keyword("Modality")
    end

    test "returns :error for unknown keywords" do
      assert :error = Dicom.Tag.from_keyword("NotARealTag")
    end
  end

  describe "repeating?/1" do
    test "detects 50XX curve data groups" do
      assert Dicom.Tag.repeating?({0x5000, 0x0010})
      assert Dicom.Tag.repeating?({0x5002, 0x0010})
      assert Dicom.Tag.repeating?({0x501E, 0x0010})
    end

    test "detects 60XX overlay groups" do
      assert Dicom.Tag.repeating?({0x6000, 0x0010})
      assert Dicom.Tag.repeating?({0x6010, 0x0010})
    end

    test "detects 7FXX waveform groups" do
      assert Dicom.Tag.repeating?({0x7F00, 0x0010})
      assert Dicom.Tag.repeating?({0x7F0E, 0x0010})
    end

    test "rejects odd groups within repeating ranges" do
      refute Dicom.Tag.repeating?({0x5001, 0x0010})
      refute Dicom.Tag.repeating?({0x6001, 0x0010})
    end

    test "rejects non-repeating groups" do
      refute Dicom.Tag.repeating?({0x0010, 0x0010})
      refute Dicom.Tag.repeating?({0x0028, 0x0010})
      refute Dicom.Tag.repeating?({0x7FE0, 0x0010})
    end
  end

  describe "format/1" do
    test "formats tag as hex string" do
      assert Dicom.Tag.format({0x0010, 0x0010}) == "(0010,0010)"
      assert Dicom.Tag.format({0x7FE0, 0x0010}) == "(7FE0,0010)"
    end
  end

  describe "name/1" do
    test "returns known tag name" do
      assert Dicom.Tag.name({0x0010, 0x0010}) == "PatientName"
    end

    test "returns hex format for unknown tag" do
      assert Dicom.Tag.name({0x0099, 0x0099}) == "(0099,0099)"
    end
  end

  describe "private?/1" do
    test "detects private tags" do
      assert Dicom.Tag.private?({0x0009, 0x0010})
      refute Dicom.Tag.private?({0x0010, 0x0010})
    end
  end
end
