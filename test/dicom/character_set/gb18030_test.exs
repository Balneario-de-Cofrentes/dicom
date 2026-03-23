defmodule Dicom.CharacterSet.GB18030Test do
  use ExUnit.Case, async: true

  alias Dicom.CharacterSet.GB18030

  describe "decode/1 — ASCII passthrough" do
    test "decodes empty binary" do
      assert {:ok, ""} = GB18030.decode(<<>>)
    end

    test "decodes pure ASCII" do
      assert {:ok, "Hello, World!"} = GB18030.decode("Hello, World!")
    end

    test "decodes all printable ASCII" do
      ascii = for i <- 0x20..0x7E, into: <<>>, do: <<i>>
      assert {:ok, ^ascii} = GB18030.decode(ascii)
    end

    test "decodes ASCII control characters" do
      assert {:ok, "\t\n\r"} = GB18030.decode(<<0x09, 0x0A, 0x0D>>)
    end

    test "decodes NUL byte" do
      assert {:ok, <<0x00>>} = GB18030.decode(<<0x00>>)
    end
  end

  describe "decode/1 — 2-byte sequences" do
    test "decodes common Chinese character ni (you)" do
      # 0xC4E3 = U+4F60 (你)
      assert {:ok, "\u4F60"} = GB18030.decode(<<0xC4, 0xE3>>)
    end

    test "decodes nihao (hello)" do
      # 0xC4E3 = 你 (U+4F60), 0xBAC3 = 好 (U+597D)
      assert {:ok, "\u4F60\u597D"} = GB18030.decode(<<0xC4, 0xE3, 0xBA, 0xC3>>)
    end

    test "decodes CJK punctuation" do
      # 0xA1A2 = 、 (U+3001, ideographic comma)
      assert {:ok, "\u3001"} = GB18030.decode(<<0xA1, 0xA2>>)
    end

    test "decodes fullwidth Latin capital A" do
      # 0xA3C1 = Ａ (U+FF21)
      assert {:ok, "\uFF21"} = GB18030.decode(<<0xA3, 0xC1>>)
    end

    test "decodes Chinese surname Wang" do
      # 0xCDF5 = 王 (U+738B)
      assert {:ok, "\u738B"} = GB18030.decode(<<0xCD, 0xF5>>)
    end

    test "decodes XiaoMing" do
      # 0xD0A1 = 小 (U+5C0F), 0xC3F7 = 明 (U+660E)
      assert {:ok, "\u5C0F\u660E"} = GB18030.decode(<<0xD0, 0xA1, 0xC3, 0xF7>>)
    end

    test "decodes zhong (middle/China)" do
      # 0xD6D0 = 中 (U+4E2D)
      assert {:ok, "\u4E2D"} = GB18030.decode(<<0xD6, 0xD0>>)
    end

    test "decodes guo (country)" do
      # 0xB9FA = 国 (U+56FD)
      assert {:ok, "\u56FD"} = GB18030.decode(<<0xB9, 0xFA>>)
    end

    test "decodes ren (person)" do
      # 0xC8CB = 人 (U+4EBA)
      assert {:ok, "\u4EBA"} = GB18030.decode(<<0xC8, 0xCB>>)
    end

    test "decodes trail byte in 0x40-0x7E range" do
      # 0x8140 = 丂 (U+4E02)
      assert {:ok, "\u4E02"} = GB18030.decode(<<0x81, 0x40>>)
    end

    test "decodes trail byte in 0x80-0xFE range" do
      assert {:ok, decoded} = GB18030.decode(<<0x81, 0x80>>)
      assert String.valid?(decoded)
    end

    test "decodes zhongguo renmin (Chinese people)" do
      # 中国人民 = 0xD6D0 0xB9FA 0xC8CB 0xC3F1
      binary = <<0xD6, 0xD0, 0xB9, 0xFA, 0xC8, 0xCB, 0xC3, 0xF1>>
      assert {:ok, "\u4E2D\u56FD\u4EBA\u6C11"} = GB18030.decode(binary)
    end

    test "decodes Euro sign (GB18030 extension over GBK)" do
      # 0xA2E3 = U+20AC (Euro sign) — in GB18030 2-byte range but not in GBK
      assert {:ok, "\u20AC"} = GB18030.decode(<<0xA2, 0xE3>>)
    end
  end

  describe "decode/1 — mixed ASCII and Chinese" do
    test "decodes ASCII followed by Chinese" do
      assert {:ok, "Hi\u4F60"} = GB18030.decode(<<0x48, 0x69, 0xC4, 0xE3>>)
    end

    test "decodes Chinese followed by ASCII" do
      assert {:ok, "\u4F60Hi"} = GB18030.decode(<<0xC4, 0xE3, 0x48, 0x69>>)
    end

    test "decodes interleaved ASCII and Chinese" do
      binary = <<0x41, 0xC4, 0xE3, 0x42, 0xBA, 0xC3>>
      assert {:ok, "A\u4F60B\u597D"} = GB18030.decode(binary)
    end

    test "decodes DICOM patient name format" do
      # Wang^XiaoMing = 王^小明
      binary = <<0xCD, 0xF5, 0x5E, 0xD0, 0xA1, 0xC3, 0xF7>>
      assert {:ok, "\u738B^\u5C0F\u660E"} = GB18030.decode(binary)
    end

    test "decodes DICOM patient name with ASCII and Chinese components" do
      ascii_part = "WANG^XIAOMING="
      chinese_part = <<0xCD, 0xF5, 0x5E, 0xD0, 0xA1, 0xC3, 0xF7>>
      binary = <<ascii_part::binary, chinese_part::binary>>
      assert {:ok, "WANG^XIAOMING=\u738B^\u5C0F\u660E"} = GB18030.decode(binary)
    end
  end

  describe "decode/1 — 4-byte sequences (BMP gaps)" do
    test "decodes U+0080 (first 4-byte codepoint)" do
      # Linear offset 0 -> U+0080, bytes: 0x81 0x30 0x81 0x30
      assert {:ok, <<0xC2, 0x80>>} = GB18030.decode(<<0x81, 0x30, 0x81, 0x30>>)
    end

    test "decodes U+0081" do
      # Linear offset 1 -> U+0081, bytes: 0x81 0x30 0x81 0x31
      assert {:ok, <<0xC2, 0x81>>} = GB18030.decode(<<0x81, 0x30, 0x81, 0x31>>)
    end

    test "decodes U+00C0 (A with grave)" do
      # 4-byte: 0x81 0x30 0x86 0x38
      assert {:ok, "\u00C0"} = GB18030.decode(<<0x81, 0x30, 0x86, 0x38>>)
    end

    test "decodes U+00C9 (E with acute)" do
      # 4-byte: 0x81 0x30 0x87 0x37
      assert {:ok, "\u00C9"} = GB18030.decode(<<0x81, 0x30, 0x87, 0x37>>)
    end

    test "decodes U+01CF (I with caron)" do
      # 4-byte: 0x81 0x30 0x9F 0x36
      assert {:ok, "\u01CF"} = GB18030.decode(<<0x81, 0x30, 0x9F, 0x36>>)
    end

    test "decodes 4-byte mixed with 2-byte and ASCII" do
      # ASCII "X" + 4-byte U+0080 + 2-byte 你
      binary = <<0x58, 0x81, 0x30, 0x81, 0x30, 0xC4, 0xE3>>
      assert {:ok, "X" <> <<0xC2, 0x80>> <> "\u4F60"} = GB18030.decode(binary)
    end
  end

  describe "decode/1 — 4-byte sequences (supplementary planes)" do
    test "decodes U+10000" do
      # Offset 39420 -> U+10000
      # (0x84-0x81)*12600 + (0x31-0x30)*1260 + (0xA5-0x81)*10 + (0x30-0x30)
      # = 3*12600 + 1260 + 360 = 39420
      assert {:ok, result} = GB18030.decode(<<0x84, 0x31, 0xA5, 0x30>>)
      # U+10000 in UTF-8: F0 90 80 80
      assert result == <<0xF0, 0x90, 0x80, 0x80>>
    end

    test "decodes U+10001" do
      assert {:ok, result} = GB18030.decode(<<0x84, 0x31, 0xA5, 0x31>>)
      assert result == <<0xF0, 0x90, 0x80, 0x81>>
    end

    test "decodes U+20000 (CJK Extension B)" do
      # Offset = 39420 + (0x20000 - 0x10000) = 104956
      # b4 = 104956%10 + 0x30 = 6+0x30 = 0x36
      # 10495/126 = 83 rem 37, b3 = 37+0x81 = 0xA6
      # 83/10 = 8 rem 3, b2 = 3+0x30 = 0x33
      # b1 = 8+0x81 = 0x89
      assert {:ok, result} = GB18030.decode(<<0x89, 0x33, 0xA6, 0x36>>)
      assert result == <<0xF0, 0xA0, 0x80, 0x80>>
    end

    test "returns error for offset beyond U+10FFFF" do
      # Max 4-byte: 0xFE 0x39 0xFE 0x39 = offset 1587599
      # 1587599 - 39420 + 0x10000 = way past U+10FFFF
      assert {:error, {:decode_failed, :gb18030}} =
               GB18030.decode(<<0xFE, 0x39, 0xFE, 0x39>>)
    end
  end

  describe "decode/1 — error cases" do
    test "returns error for lone lead byte at end" do
      assert {:error, {:decode_failed, :gb18030}} = GB18030.decode(<<0xC4>>)
    end

    test "returns error for 0xFF (invalid in GB18030)" do
      assert {:error, {:decode_failed, :gb18030}} = GB18030.decode(<<0xFF>>)
    end

    test "returns error for lead byte with trail 0x3F (gap between ranges)" do
      # 0x3F is between 0x30-0x39 (4-byte trail) and 0x40-0x7E (2-byte trail)
      assert {:error, {:decode_failed, :gb18030}} = GB18030.decode(<<0x81, 0x3F>>)
    end

    test "returns error for incomplete 4-byte sequence (3 bytes)" do
      assert {:error, {:decode_failed, :gb18030}} = GB18030.decode(<<0x81, 0x30, 0x81>>)
    end

    test "error propagates after valid prefix" do
      # Valid 你 followed by invalid lone byte
      assert {:error, {:decode_failed, :gb18030}} =
               GB18030.decode(<<0xC4, 0xE3, 0xC4>>)
    end
  end

  describe "decode/1 — medical/DICOM context" do
    test "decodes huanzhe (patient)" do
      # 患者 = 0xBBBC 0xD5DF -> U+60A3 U+8005
      binary = <<0xBB, 0xBC, 0xD5, 0xDF>>
      assert {:ok, "\u60A3\u8005"} = GB18030.decode(binary)
    end

    test "decodes yiyuan (hospital)" do
      # 医院 = 0xD2BD 0xD4BA -> U+533B U+9662
      binary = <<0xD2, 0xBD, 0xD4, 0xBA>>
      assert {:ok, "\u533B\u9662"} = GB18030.decode(binary)
    end

    test "decodes tou (head)" do
      # 头 = 0xCDB7 -> U+5934
      assert {:ok, "\u5934"} = GB18030.decode(<<0xCD, 0xB7>>)
    end

    test "decodes mixed DICOM value with padding" do
      # "CT " + 头部 + " " (space padded)
      binary = <<0x43, 0x54, 0x20, 0xCD, 0xB7, 0xB2, 0xBF, 0x20>>
      assert {:ok, "CT \u5934\u90E8 "} = GB18030.decode(binary)
    end
  end

  describe "decode_four_byte/4" do
    test "decodes last BMP offset (U+FFFF)" do
      # Offset for U+FFFF: verify bytes 0x84 0x31 0xA4 0x39
      assert {:ok, 0xFFFF} = GB18030.decode_four_byte(0x84, 0x31, 0xA4, 0x39)
    end

    test "decodes first supplementary codepoint (U+10000)" do
      assert {:ok, 0x10000} = GB18030.decode_four_byte(0x84, 0x31, 0xA5, 0x30)
    end

    test "returns error for codepoint beyond Unicode max" do
      # Use max possible 4-byte values
      assert :error = GB18030.decode_four_byte(0xFE, 0x39, 0xFE, 0x39)
    end
  end
end
