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
end
