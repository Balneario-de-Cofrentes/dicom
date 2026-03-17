defmodule Dicom.ValueTest do
  use ExUnit.Case, async: true

  alias Dicom.Value

  describe "decode/2 numeric types" do
    test "US decodes unsigned 16-bit integer" do
      assert Value.decode(<<512::little-16>>, :US) == 512
    end

    test "US decodes VM>1 as list" do
      assert Value.decode(<<1::little-16, 2::little-16>>, :US) == [1, 2]
    end

    test "SS decodes signed 16-bit integer" do
      assert Value.decode(<<-1::little-signed-16>>, :SS) == -1
    end

    test "UL decodes unsigned 32-bit integer" do
      assert Value.decode(<<100_000::little-32>>, :UL) == 100_000
    end

    test "SL decodes signed 32-bit integer" do
      assert Value.decode(<<-100::little-signed-32>>, :SL) == -100
    end

    test "FL decodes 32-bit float" do
      <<encoded::binary-size(4)>> = <<1.5::little-float-32>>
      assert_in_delta Value.decode(encoded, :FL), 1.5, 0.001
    end

    test "FD decodes 64-bit float" do
      <<encoded::binary-size(8)>> = <<3.14159::little-float-64>>
      assert_in_delta Value.decode(encoded, :FD), 3.14159, 0.00001
    end

    test "AT decodes attribute tag" do
      assert Value.decode(<<0x0010::little-16, 0x0010::little-16>>, :AT) == {0x0010, 0x0010}
    end
  end

  describe "decode/2 string types" do
    test "DA trims padding" do
      assert Value.decode("20240101 ", :DA) == "20240101"
    end

    test "TM trims padding" do
      assert Value.decode("120000.000 ", :TM) == "120000.000"
    end

    test "UI trims null padding" do
      assert Value.decode("1.2.3.4\0", :UI) == "1.2.3.4"
    end

    test "PN trims padding" do
      assert Value.decode("DOE^JOHN ", :PN) == "DOE^JOHN"
    end

    test "CS handles backslash-separated multi-values" do
      assert Value.decode("CT\\MR ", :CS) == ["CT", "MR"]
    end

    test "DS decodes decimal string" do
      assert Value.decode("3.14 ", :DS) == 3.14
    end

    test "DS multi-value" do
      assert Value.decode("1.0\\2.0 ", :DS) == [1.0, 2.0]
    end

    test "IS decodes integer string" do
      assert Value.decode("42 ", :IS) == 42
    end

    test "IS multi-value" do
      assert Value.decode("1\\2\\3 ", :IS) == [1, 2, 3]
    end

    test "UT preserves leading spaces while trimming trailing padding" do
      assert Value.decode("  leading text  ", :UT) == "  leading text"
    end

    test "LT preserves leading spaces while trimming trailing padding" do
      assert Value.decode("  long text  ", :LT) == "  long text"
    end
  end

  describe "decode/2 empty values" do
    test "returns nil for empty binary" do
      assert Value.decode(<<>>, :US) == nil
      assert Value.decode("", :DA) == nil
    end
  end

  describe "encode/2" do
    test "US encodes 16-bit unsigned" do
      assert Value.encode(512, :US) == <<512::little-16>>
    end

    test "SS encodes 16-bit signed" do
      assert Value.encode(-1, :SS) == <<-1::little-signed-16>>
    end

    test "UL encodes 32-bit unsigned" do
      assert Value.encode(100_000, :UL) == <<100_000::little-32>>
    end

    test "SL encodes 32-bit signed" do
      assert Value.encode(-100, :SL) == <<-100::little-signed-32>>
    end

    test "FL encodes 32-bit float" do
      assert Value.encode(1.5, :FL) == <<1.5::little-float-32>>
    end

    test "FD encodes 64-bit float" do
      assert Value.encode(3.14, :FD) == <<3.14::little-float-64>>
    end

    test "AT encodes tag tuple" do
      assert Value.encode({0x0010, 0x0010}, :AT) == <<0x0010::little-16, 0x0010::little-16>>
    end

    test "string types pass through" do
      assert Value.encode("DOE^JOHN", :PN) == "DOE^JOHN"
    end
  end

  describe "decode/2 64-bit types" do
    test "UV decodes unsigned 64-bit integer" do
      assert Value.decode(<<42::little-unsigned-64>>, :UV) == 42
    end

    test "UV multi-value" do
      assert Value.decode(<<1::little-unsigned-64, 2::little-unsigned-64>>, :UV) == [1, 2]
    end

    test "SV decodes signed 64-bit integer" do
      assert Value.decode(<<-100::little-signed-64>>, :SV) == -100
    end

    test "SV multi-value" do
      assert Value.decode(<<-1::little-signed-64, 1::little-signed-64>>, :SV) == [-1, 1]
    end

    test "OV returns binary as-is" do
      data = <<1, 2, 3, 4, 5, 6, 7, 8>>
      assert Value.decode(data, :OV) == data
    end
  end

  describe "decode/2 multi-value numerics" do
    test "SS multi-value decodes signed 16-bit list" do
      assert Value.decode(<<-1::little-signed-16, 42::little-signed-16>>, :SS) == [-1, 42]
    end

    test "UL multi-value decodes unsigned 32-bit list" do
      assert Value.decode(<<100::little-32, 200::little-32>>, :UL) == [100, 200]
    end

    test "SL multi-value decodes signed 32-bit list" do
      assert Value.decode(<<-50::little-signed-32, 50::little-signed-32>>, :SL) == [-50, 50]
    end

    test "FL multi-value decodes 32-bit float list" do
      result = Value.decode(<<1.0::little-float-32, 2.0::little-float-32>>, :FL)
      assert is_list(result)
      assert length(result) == 2
      assert_in_delta hd(result), 1.0, 0.001
    end

    test "FD multi-value decodes 64-bit float list" do
      result = Value.decode(<<1.0::little-float-64, 2.0::little-float-64>>, :FD)
      assert is_list(result)
      assert length(result) == 2
      assert_in_delta hd(result), 1.0, 0.00001
    end
  end

  describe "decode/2 edge cases" do
    test "DS with whitespace-only returns nil-like" do
      result = Value.decode("   ", :DS)
      assert result == ""
    end

    test "IS with whitespace-only returns nil-like" do
      result = Value.decode("   ", :IS)
      assert result == ""
    end

    test "CS single value returns string not list" do
      assert Value.decode("CT", :CS) == "CT"
    end

    test "binary VR (OB) returns raw binary" do
      data = <<0xFF, 0xD8, 0xFF, 0xE0>>
      assert Value.decode(data, :OB) == data
    end

    test "UN returns raw binary" do
      data = <<1, 2, 3, 4>>
      assert Value.decode(data, :UN) == data
    end
  end

  describe "encode/2 64-bit types" do
    test "UV encodes unsigned 64-bit" do
      assert Value.encode(42, :UV) == <<42::little-unsigned-64>>
    end

    test "SV encodes signed 64-bit" do
      assert Value.encode(-100, :SV) == <<-100::little-signed-64>>
    end
  end

  describe "decode/3 endianness-aware numeric decoding" do
    test "US decodes big-endian values" do
      assert Value.decode(<<512::big-16>>, :US, :big) == 512
    end

    test "AT decodes big-endian tag tuples" do
      assert Value.decode(<<0x0010::big-16, 0x0010::big-16>>, :AT, :big) == {0x0010, 0x0010}
    end
  end

  describe "encode/3 endianness-aware numeric encoding" do
    test "US encodes big-endian values" do
      assert Value.encode(512, :US, :big) == <<512::big-16>>
    end

    test "AT encodes big-endian tag tuples" do
      assert Value.encode({0x0010, 0x0010}, :AT, :big) == <<0x0010::big-16, 0x0010::big-16>>
    end
  end

  describe "encode/2 fallback" do
    test "non-binary non-integer falls back to to_string" do
      assert Value.encode(42, :LO) == "42"
    end
  end

  describe "decode/2 remaining string VRs" do
    test "LO trims padding" do
      assert Value.decode("SOME_VALUE  ", :LO) == "SOME_VALUE"
    end

    test "SH trims padding" do
      assert Value.decode("SHORT ", :SH) == "SHORT"
    end

    test "LT trims padding" do
      assert Value.decode("Long text value  ", :LT) == "Long text value"
    end

    test "ST trims padding" do
      assert Value.decode("Short text  ", :ST) == "Short text"
    end

    test "AE trims padding" do
      assert Value.decode("MY_AET  ", :AE) == "MY_AET"
    end

    test "DT trims padding" do
      assert Value.decode("20240101120000.000000+0000 ", :DT) ==
               "20240101120000.000000+0000"
    end

    test "UC trims padding" do
      assert Value.decode("unlimited chars  ", :UC) == "unlimited chars"
    end

    test "UR trims padding" do
      assert Value.decode("https://example.com  ", :UR) == "https://example.com"
    end

    test "UT trims padding" do
      assert Value.decode("unlimited text  ", :UT) == "unlimited text"
    end

    test "AS trims padding" do
      assert Value.decode("045Y ", :AS) == "045Y"
    end
  end
end
