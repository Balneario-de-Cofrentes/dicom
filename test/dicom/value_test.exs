defmodule Dicom.ValueTest do
  use ExUnit.Case, async: true

  alias Dicom.Value

  doctest Dicom.Value

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

    test "DS does not partially parse malformed decimal strings" do
      assert Value.decode("1.2.3 ", :DS) == "1.2.3"
      assert Value.decode("12\\1.2.3 ", :DS) == [12.0, "1.2.3"]
    end

    test "IS does not partially parse malformed integer strings" do
      assert Value.decode("12A ", :IS) == "12A"
      assert Value.decode("12\\+34garbage ", :IS) == [12, "+34garbage"]
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

    test "raises for unsupported numeric VR value shapes" do
      assert_raise ArgumentError, ~r/unsupported value for VR US/, fn ->
        Value.encode([1, 2], :US)
      end
    end

    test "raises for out-of-range numeric VR values" do
      assert_raise ArgumentError, ~r/unsupported value for VR US/, fn ->
        Value.encode(-1, :US)
      end

      assert_raise ArgumentError, ~r/unsupported value for VR UL/, fn ->
        Value.encode(-1, :UL)
      end
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

    test "UI with all-null bytes trims to empty" do
      assert Value.decode(<<0, 0, 0>>, :UI) == ""
    end

    test "PN with all-space bytes trims to empty" do
      assert Value.decode(<<"   ">>, :PN) == ""
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

    test "US decodes big-endian multi-value" do
      assert Value.decode(<<1::big-16, 2::big-16>>, :US, :big) == [1, 2]
    end

    test "SS decodes big-endian values" do
      assert Value.decode(<<-1::big-signed-16>>, :SS, :big) == -1
    end

    test "SS decodes big-endian multi-value" do
      assert Value.decode(<<-1::big-signed-16, 42::big-signed-16>>, :SS, :big) == [-1, 42]
    end

    test "UL decodes big-endian values" do
      assert Value.decode(<<100_000::big-32>>, :UL, :big) == 100_000
    end

    test "UL decodes big-endian multi-value" do
      assert Value.decode(<<100::big-32, 200::big-32>>, :UL, :big) == [100, 200]
    end

    test "SL decodes big-endian values" do
      assert Value.decode(<<-100::big-signed-32>>, :SL, :big) == -100
    end

    test "SL decodes big-endian multi-value" do
      assert Value.decode(<<-50::big-signed-32, 50::big-signed-32>>, :SL, :big) == [-50, 50]
    end

    test "FL decodes big-endian values" do
      assert_in_delta Value.decode(<<1.5::big-float-32>>, :FL, :big), 1.5, 0.001
    end

    test "FL decodes big-endian multi-value" do
      result = Value.decode(<<1.0::big-float-32, 2.0::big-float-32>>, :FL, :big)
      assert is_list(result) and length(result) == 2
    end

    test "FD decodes big-endian values" do
      assert_in_delta Value.decode(<<3.14::big-float-64>>, :FD, :big), 3.14, 0.00001
    end

    test "FD decodes big-endian multi-value" do
      result = Value.decode(<<1.0::big-float-64, 2.0::big-float-64>>, :FD, :big)
      assert is_list(result) and length(result) == 2
    end

    test "UV decodes big-endian values" do
      assert Value.decode(<<42::big-unsigned-64>>, :UV, :big) == 42
    end

    test "UV decodes big-endian multi-value" do
      assert Value.decode(<<1::big-unsigned-64, 2::big-unsigned-64>>, :UV, :big) == [1, 2]
    end

    test "SV decodes big-endian values" do
      assert Value.decode(<<-100::big-signed-64>>, :SV, :big) == -100
    end

    test "SV decodes big-endian multi-value" do
      assert Value.decode(<<-1::big-signed-64, 1::big-signed-64>>, :SV, :big) == [-1, 1]
    end

    test "AT decodes big-endian tag tuples" do
      assert Value.decode(<<0x0010::big-16, 0x0010::big-16>>, :AT, :big) == {0x0010, 0x0010}
    end
  end

  describe "encode/3 endianness-aware numeric encoding" do
    test "US encodes big-endian values" do
      assert Value.encode(512, :US, :big) == <<512::big-16>>
    end

    test "SS encodes big-endian values" do
      assert Value.encode(-1, :SS, :big) == <<-1::big-signed-16>>
    end

    test "UL encodes big-endian values" do
      assert Value.encode(100_000, :UL, :big) == <<100_000::big-32>>
    end

    test "SL encodes big-endian values" do
      assert Value.encode(-100, :SL, :big) == <<-100::big-signed-32>>
    end

    test "FL encodes big-endian values" do
      assert Value.encode(1.5, :FL, :big) == <<1.5::big-float-32>>
    end

    test "FD encodes big-endian values" do
      assert Value.encode(3.14, :FD, :big) == <<3.14::big-float-64>>
    end

    test "UV encodes big-endian values" do
      assert Value.encode(42, :UV, :big) == <<42::big-unsigned-64>>
    end

    test "SV encodes big-endian values" do
      assert Value.encode(-100, :SV, :big) == <<-100::big-signed-64>>
    end

    test "AT encodes big-endian tag tuples" do
      assert Value.encode({0x0010, 0x0010}, :AT, :big) == <<0x0010::big-16, 0x0010::big-16>>
    end
  end

  describe "encode/2 fallback" do
    test "non-binary non-integer falls back to to_string" do
      assert Value.encode(42, :LO) == "42"
    end

    test "atom falls back to to_string" do
      assert Value.encode(:hello, :LO) == "hello"
    end
  end

  describe "to_date/1" do
    test "parses valid DICOM date" do
      assert {:ok, ~D[2024-03-15]} = Value.to_date("20240315")
    end

    test "parses leap year date" do
      assert {:ok, ~D[2024-02-29]} = Value.to_date("20240229")
    end

    test "rejects non-leap year Feb 29" do
      assert {:error, :invalid_date} = Value.to_date("20230229")
    end

    test "rejects invalid date" do
      assert {:error, :invalid_date} = Value.to_date("20241301")
    end

    test "rejects invalid format" do
      assert {:error, :invalid_date} = Value.to_date("not-a-date")
      assert {:error, :invalid_date} = Value.to_date("2024031")
      assert {:error, :invalid_date} = Value.to_date("")
    end
  end

  describe "to_time/1" do
    test "parses full time HHMMSS" do
      assert {:ok, ~T[14:30:22]} = Value.to_time("143022")
    end

    test "parses partial time HHMM" do
      assert {:ok, ~T[14:30:00]} = Value.to_time("1430")
    end

    test "parses hour-only HH" do
      assert {:ok, ~T[14:00:00]} = Value.to_time("14")
    end

    test "parses time with fractional seconds" do
      assert {:ok, time} = Value.to_time("143022.123456")
      assert time.hour == 14
      assert time.minute == 30
      assert time.second == 22
      assert time.microsecond == {123_456, 6}
    end

    test "parses time with partial fractional seconds" do
      assert {:ok, time} = Value.to_time("143022.12")
      assert time.microsecond == {120_000, 2}
    end

    test "handles trailing whitespace" do
      assert {:ok, ~T[14:30:22]} = Value.to_time("143022 ")
    end

    test "rejects invalid time" do
      assert {:error, :invalid_time} = Value.to_time("250000")
      assert {:error, :invalid_time} = Value.to_time("invalid")
    end
  end

  describe "to_datetime/1" do
    test "parses date-only DT as NaiveDateTime" do
      assert {:ok, ~N[2024-03-15 00:00:00]} = Value.to_datetime("20240315")
    end

    test "parses full DT without timezone as NaiveDateTime" do
      assert {:ok, ~N[2024-03-15 14:30:22]} = Value.to_datetime("20240315143022")
    end

    test "parses DT with timezone offset as DateTime" do
      assert {:ok, %DateTime{} = dt} = Value.to_datetime("20240315143022+0100")
      assert dt.hour == 14
      assert dt.minute == 30
      assert dt.utc_offset == 3600
    end

    test "parses DT with negative timezone offset" do
      assert {:ok, %DateTime{} = dt} = Value.to_datetime("20240315143022-0500")
      assert dt.utc_offset == -18000
    end

    test "parses DT with fractional seconds and timezone" do
      assert {:ok, %DateTime{} = dt} = Value.to_datetime("20240315143022.123+0000")
      assert dt.microsecond == {123_000, 3}
    end

    test "rejects invalid DT" do
      assert {:error, :invalid_datetime} = Value.to_datetime("invalid")
      assert {:error, :invalid_datetime} = Value.to_datetime("2024")
    end
  end

  describe "from_date/1" do
    test "converts Date to DICOM DA" do
      assert "20240315" = Value.from_date(~D[2024-03-15])
    end

    test "pads single-digit months and days" do
      assert "20240101" = Value.from_date(~D[2024-01-01])
    end
  end

  describe "from_time/1" do
    test "converts Time to DICOM TM" do
      assert "143022" = Value.from_time(~T[14:30:22])
    end

    test "includes fractional seconds when present" do
      assert "143022.123456" = Value.from_time(~T[14:30:22.123456])
    end

    test "omits fractional seconds when zero" do
      assert "000000" = Value.from_time(~T[00:00:00])
    end
  end

  describe "from_datetime/1" do
    test "converts NaiveDateTime to DICOM DT" do
      assert "20240315143022" = Value.from_datetime(~N[2024-03-15 14:30:22])
    end

    test "converts DateTime with UTC offset" do
      dt = DateTime.from_naive!(~N[2024-03-15 14:30:22], "Etc/UTC")
      assert "20240315143022+0000" = Value.from_datetime(dt)
    end
  end

  describe "to_time/1 edge cases" do
    test "rejects non-binary input" do
      assert {:error, :invalid_time} = Value.to_time(12345)
      assert {:error, :invalid_time} = Value.to_time(nil)
    end

    test "rejects invalid hour value" do
      assert {:error, :invalid_time} = Value.to_time("250000")
    end

    test "rejects invalid minute value" do
      assert {:error, :invalid_time} = Value.to_time("126000")
    end

    test "rejects invalid second value" do
      assert {:error, :invalid_time} = Value.to_time("123060")
    end

    test "rejects invalid time with fractional but bad HMS" do
      assert {:error, :invalid_time} = Value.to_time("259999.000000")
    end

    test "handles hour-only with invalid hour" do
      assert {:error, :invalid_time} = Value.to_time("25")
    end

    test "handles HHMM with invalid minute" do
      assert {:error, :invalid_time} = Value.to_time("1260")
    end
  end

  describe "to_datetime/1 edge cases" do
    test "rejects non-binary input" do
      assert {:error, :invalid_datetime} = Value.to_datetime(12345)
      assert {:error, :invalid_datetime} = Value.to_datetime(nil)
    end

    test "rejects string shorter than 8 chars" do
      assert {:error, :invalid_datetime} = Value.to_datetime("2024")
    end

    test "rejects DT with bad time portion" do
      assert {:error, :invalid_datetime} = Value.to_datetime("20240315XXXXXX")
    end

    test "rejects DT with invalid date portion" do
      assert {:error, :invalid_datetime} = Value.to_datetime("20241301143022")
    end

    test "rejects DT with malformed offset" do
      assert {:error, :invalid_datetime} = Value.to_datetime("20240315143022+XX")
    end

    test "parses DT with partial time (HHMM)" do
      assert {:ok, ndt} = Value.to_datetime("202403151430")
      assert ndt.hour == 14
      assert ndt.minute == 30
    end

    test "parses DT with zero offset" do
      assert {:ok, %DateTime{} = dt} = Value.to_datetime("20240315143022+0000")
      assert dt.utc_offset == 0
    end
  end

  describe "from_datetime/1 edge cases" do
    test "converts DateTime with negative offset" do
      ndt = ~N[2024-03-15 14:30:22]
      utc_dt = DateTime.from_naive!(ndt, "Etc/UTC")

      # Simulate a negative offset DateTime
      dt =
        utc_dt
        |> Map.put(:utc_offset, -18000)
        |> Map.put(:std_offset, 0)

      result = Value.from_datetime(dt)
      assert result =~ "-0500"
    end
  end

  describe "DS/IS parse error fallback" do
    test "DS with non-numeric string returns original" do
      assert Value.decode("abc", :DS) == "abc"
    end

    test "IS with non-numeric string returns original" do
      assert Value.decode("abc", :IS) == "abc"
    end

    test "DS multi-value with mixed valid/invalid" do
      result = Value.decode("1.5\\abc", :DS)
      assert result == [1.5, "abc"]
    end

    test "IS multi-value with mixed valid/invalid" do
      result = Value.decode("42\\abc", :IS)
      assert result == [42, "abc"]
    end
  end

  describe "date/time roundtrip" do
    test "from_date(to_date(s)) preserves the string" do
      for s <- ["20240315", "20001231", "19700101", "20240229"] do
        assert {:ok, date} = Value.to_date(s)
        assert Value.from_date(date) == s
      end
    end

    test "from_time(to_time(s)) preserves the string" do
      for s <- ["143022", "000000", "235959"] do
        assert {:ok, time} = Value.to_time(s)
        assert Value.from_time(time) == s
      end
    end

    test "microsecond preservation roundtrip" do
      assert {:ok, time} = Value.to_time("143022.123456")
      assert Value.from_time(time) == "143022.123456"
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
