defmodule Dicom.CharacterSetTest do
  use ExUnit.Case, async: true

  alias Dicom.CharacterSet

  describe "decode/2 — default character repertoire" do
    test "decodes ASCII text with nil charset" do
      assert {:ok, "JOHN"} = CharacterSet.decode("JOHN", nil)
    end

    test "decodes ASCII text with empty charset" do
      assert {:ok, "DOE^JOHN"} = CharacterSet.decode("DOE^JOHN", "")
    end

    test "decodes ASCII text with explicit ISO_IR 6" do
      assert {:ok, "SMITH^ALICE"} = CharacterSet.decode("SMITH^ALICE", "ISO_IR 6")
    end

    test "accepts ISO 2022 IR 6 when no escape sequences are present" do
      assert {:ok, "TEST"} = CharacterSet.decode("TEST", "ISO 2022 IR 6")
    end

    test "rejects non-ASCII bytes with nil charset" do
      assert {:error, {:decode_failed, :ascii}} = CharacterSet.decode(<<0xC4>>, nil)
    end

    test "rejects non-ASCII bytes with ISO_IR 6" do
      assert {:error, {:decode_failed, :ascii}} = CharacterSet.decode(<<0xC4>>, "ISO_IR 6")
    end
  end

  describe "decode/2 — ISO_IR 100 (Latin-1)" do
    test "decodes Latin-1 characters" do
      assert {:ok, "ÄÖÜ"} = CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 100")
    end

    test "decodes umlauts in patient name" do
      binary = <<0x4D, 0xDC, 0x4C, 0x4C, 0x45, 0x52, 0x5E, 0x48, 0x41, 0x4E, 0x53>>
      assert {:ok, "MÜLLER^HANS"} = CharacterSet.decode(binary, "ISO_IR 100")
    end

    test "accepts ISO 2022 IR 100 when no escape sequences are present" do
      assert {:ok, "ÄÖÜ"} = CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, "ISO 2022 IR 100")
    end

    test "handles accented characters" do
      binary = <<0xE0, 0xE9, 0xEE, 0xF5, 0xFC>>
      assert {:ok, "àéîõü"} = CharacterSet.decode(binary, "ISO_IR 100")
    end
  end

  describe "decode/2 — ISO 8859-2 (Latin-2, Central European)" do
    test "decodes known ISO 8859-2 characters" do
      # Ą = 0xA1 in ISO 8859-2 (U+0104)
      assert {:ok, "Ą"} = CharacterSet.decode(<<0xA1>>, "ISO_IR 101")
      # ą = 0xB1 in ISO 8859-2 (U+0105)
      assert {:ok, "ą"} = CharacterSet.decode(<<0xB1>>, "ISO_IR 101")
      # Ł = 0xA3 in ISO 8859-2 (U+0141)
      assert {:ok, "Ł"} = CharacterSet.decode(<<0xA3>>, "ISO_IR 101")
      # Ž = 0xAE in ISO 8859-2 (U+017D)
      assert {:ok, "Ž"} = CharacterSet.decode(<<0xAE>>, "ISO_IR 101")
      # č = 0xE8 in ISO 8859-2 (U+010D)
      assert {:ok, "č"} = CharacterSet.decode(<<0xE8>>, "ISO_IR 101")
    end

    test "ASCII range unchanged in ISO 8859-2" do
      assert {:ok, "HELLO"} = CharacterSet.decode("HELLO", "ISO_IR 101")
    end
  end

  describe "decode/2 — ISO 8859-3 (Latin-3, South European)" do
    test "decodes known ISO 8859-3 characters" do
      # Ħ = 0xA1 in ISO 8859-3 (U+0126)
      assert {:ok, "Ħ"} = CharacterSet.decode(<<0xA1>>, "ISO_IR 109")
      # ĥ = 0xB6 in ISO 8859-3 (U+0125)
      assert {:ok, "ĥ"} = CharacterSet.decode(<<0xB6>>, "ISO_IR 109")
    end
  end

  describe "decode/2 — ISO 8859-4 (Latin-4, North European)" do
    test "decodes known ISO 8859-4 characters" do
      # Ą = 0xA1 in ISO 8859-4 (U+0104)
      assert {:ok, "Ą"} = CharacterSet.decode(<<0xA1>>, "ISO_IR 110")
      # ē = 0xBA in ISO 8859-4 (U+0113)
      assert {:ok, "ē"} = CharacterSet.decode(<<0xBA>>, "ISO_IR 110")
    end
  end

  describe "decode/2 — ISO 8859-5 (Cyrillic)" do
    test "decodes Cyrillic characters" do
      # А = 0xB0 in ISO 8859-5 (U+0410)
      assert {:ok, "А"} = CharacterSet.decode(<<0xB0>>, "ISO_IR 144")
      # Б = 0xB1 (U+0411)
      assert {:ok, "Б"} = CharacterSet.decode(<<0xB1>>, "ISO_IR 144")
      # Я = 0xCF (U+042F)
      assert {:ok, "Я"} = CharacterSet.decode(<<0xCF>>, "ISO_IR 144")
      # а = 0xD0 (U+0430)
      assert {:ok, "а"} = CharacterSet.decode(<<0xD0>>, "ISO_IR 144")
      # я = 0xEF (U+044F)
      assert {:ok, "я"} = CharacterSet.decode(<<0xEF>>, "ISO_IR 144")
    end
  end

  describe "decode/2 — ISO 8859-6 (Arabic)" do
    test "decodes Arabic characters" do
      # ء = 0xC1 in ISO 8859-6 (U+0621)
      assert {:ok, "ء"} = CharacterSet.decode(<<0xC1>>, "ISO_IR 127")
      # ب = 0xC8 (U+0628)
      assert {:ok, "ب"} = CharacterSet.decode(<<0xC8>>, "ISO_IR 127")
    end
  end

  describe "decode/2 — ISO 8859-7 (Greek)" do
    test "decodes Greek characters" do
      # Α = 0xC1 in ISO 8859-7 (U+0391)
      assert {:ok, "Α"} = CharacterSet.decode(<<0xC1>>, "ISO_IR 126")
      # Ω = 0xD9 (U+03A9)
      assert {:ok, "Ω"} = CharacterSet.decode(<<0xD9>>, "ISO_IR 126")
      # α = 0xE1 (U+03B1)
      assert {:ok, "α"} = CharacterSet.decode(<<0xE1>>, "ISO_IR 126")
    end
  end

  describe "decode/2 — ISO 8859-8 (Hebrew)" do
    test "decodes Hebrew characters" do
      # א = 0xE0 in ISO 8859-8 (U+05D0)
      assert {:ok, "א"} = CharacterSet.decode(<<0xE0>>, "ISO_IR 138")
      # ת = 0xFA (U+05EA)
      assert {:ok, "ת"} = CharacterSet.decode(<<0xFA>>, "ISO_IR 138")
    end
  end

  describe "decode/2 — ISO 8859-9 (Latin-5, Turkish)" do
    test "decodes Turkish-specific characters" do
      # Ş = 0xDE in ISO 8859-9 (U+015E)
      assert {:ok, "Ş"} = CharacterSet.decode(<<0xDE>>, "ISO_IR 148")
      # ş = 0xFE (U+015F)
      assert {:ok, "ş"} = CharacterSet.decode(<<0xFE>>, "ISO_IR 148")
      # İ = 0xDD (U+0130)
      assert {:ok, "İ"} = CharacterSet.decode(<<0xDD>>, "ISO_IR 148")
      # Most 8859-9 chars are same as 8859-1
      assert {:ok, "ÄÖÜ"} = CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 148")
    end
  end

  describe "decode/2 — ISO_IR 13 (JIS X 0201)" do
    test "decodes ASCII range" do
      assert {:ok, "HELLO"} = CharacterSet.decode("HELLO", "ISO_IR 13")
    end

    test "decodes Yen sign (0x5C = U+00A5)" do
      assert {:ok, "¥"} = CharacterSet.decode(<<0x5C>>, "ISO_IR 13")
    end

    test "decodes overline (0x7E = U+203E)" do
      assert {:ok, "‾"} = CharacterSet.decode(<<0x7E>>, "ISO_IR 13")
    end

    test "decodes half-width katakana" do
      # ｱ = 0xB1 in JIS X 0201 (U+FF71)
      assert {:ok, "ｱ"} = CharacterSet.decode(<<0xB1>>, "ISO_IR 13")
      # ｶ = 0xB6 (U+FF76)
      assert {:ok, "ｶ"} = CharacterSet.decode(<<0xB6>>, "ISO_IR 13")
    end
  end

  describe "decode/2 — ISO_IR 192 (UTF-8)" do
    test "decodes valid UTF-8" do
      assert {:ok, "日本語"} = CharacterSet.decode("日本語", "ISO_IR 192")
    end

    test "decodes ASCII as UTF-8" do
      assert {:ok, "JOHN"} = CharacterSet.decode("JOHN", "ISO_IR 192")
    end

    test "returns error for invalid UTF-8 bytes" do
      assert {:error, :invalid_utf8} = CharacterSet.decode(<<0xFF, 0xFE>>, "ISO_IR 192")
    end
  end

  describe "decode/2 — unsupported charsets" do
    test "returns error for ISO 2022 escape sequences in IR 100" do
      assert {:error, {:unsupported_iso2022_escape_sequences, "ISO 2022 IR 100"}} =
               CharacterSet.decode(<<0x1B, 0x2D, 0x41, 0xC4>>, "ISO 2022 IR 100")
    end

    test "returns error for ISO 2022 escape sequences in IR 6" do
      assert {:error, {:unsupported_iso2022_escape_sequences, "ISO 2022 IR 6"}} =
               CharacterSet.decode(<<0x1B, 0x28, 0x42, ?A>>, "ISO 2022 IR 6")
    end

    test "returns error for JIS X 0208 (multibyte)" do
      assert {:error, {:unsupported_charset, "ISO 2022 IR 87"}} =
               CharacterSet.decode("test", "ISO 2022 IR 87")
    end

    test "returns error for Korean charset" do
      assert {:error, {:unsupported_charset, "ISO 2022 IR 149"}} =
               CharacterSet.decode("test", "ISO 2022 IR 149")
    end

    test "returns error for GB18030" do
      assert {:error, {:unsupported_charset, "GB18030"}} =
               CharacterSet.decode("test", "GB18030")
    end
  end

  describe "decode_lossy/2" do
    test "returns decoded string for supported charset" do
      assert "ÄÖÜ" = CharacterSet.decode_lossy(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 100")
    end

    test "returns raw binary for unsupported charset" do
      binary = <<0xAB, 0xCD>>
      assert ^binary = CharacterSet.decode_lossy(binary, "ISO 2022 IR 87")
    end
  end

  describe "supported?/1" do
    test "default charsets are supported" do
      assert CharacterSet.supported?(nil)
      assert CharacterSet.supported?("")
      assert CharacterSet.supported?("ISO_IR 6")
    end

    test "Latin-1 is supported" do
      assert CharacterSet.supported?("ISO_IR 100")
      assert CharacterSet.supported?("ISO 2022 IR 100")
    end

    test "UTF-8 is supported" do
      assert CharacterSet.supported?("ISO_IR 192")
    end

    test "ISO 8859 variants are supported" do
      for charset <- [
            "ISO_IR 101",
            "ISO_IR 109",
            "ISO_IR 110",
            "ISO_IR 144",
            "ISO_IR 127",
            "ISO_IR 126",
            "ISO_IR 138",
            "ISO_IR 148"
          ] do
        assert CharacterSet.supported?(charset), "#{charset} should be supported"
      end
    end

    test "JIS X 0201 is supported" do
      assert CharacterSet.supported?("ISO_IR 13")
    end

    test "JIS/Korean/GB multibyte charsets are not yet supported" do
      refute CharacterSet.supported?("ISO 2022 IR 87")
      refute CharacterSet.supported?("ISO 2022 IR 149")
      refute CharacterSet.supported?("GB18030")
    end
  end

  describe "extract/1" do
    test "extracts charset from elements map" do
      elem = Dicom.DataElement.new({0x0008, 0x0005}, :CS, "ISO_IR 100")
      elements = %{{0x0008, 0x0005} => elem}
      assert "ISO_IR 100" = CharacterSet.extract(elements)
    end

    test "extracts first charset from multi-valued" do
      elem = Dicom.DataElement.new({0x0008, 0x0005}, :CS, "ISO_IR 100\\ISO_IR 101")
      elements = %{{0x0008, 0x0005} => elem}
      assert "ISO_IR 100" = CharacterSet.extract(elements)
    end

    test "returns nil when charset tag absent" do
      assert nil == CharacterSet.extract(%{})
    end

    test "trims whitespace from charset value" do
      elem = Dicom.DataElement.new({0x0008, 0x0005}, :CS, "ISO_IR 100 ")
      elements = %{{0x0008, 0x0005} => elem}
      assert "ISO_IR 100" = CharacterSet.extract(elements)
    end

    test "returns nil when element value is not binary" do
      # Element with non-binary value (e.g. already-decoded integer)
      elem = %Dicom.DataElement{tag: {0x0008, 0x0005}, vr: :CS, value: 42, length: 0}
      elements = %{{0x0008, 0x0005} => elem}
      assert nil == CharacterSet.extract(elements)
    end
  end

  describe "extract_all/1" do
    test "returns all charsets from a multi-valued element" do
      elem = Dicom.DataElement.new({0x0008, 0x0005}, :CS, "ISO_IR 100\\ISO_IR 101")
      elements = %{{0x0008, 0x0005} => elem}

      assert CharacterSet.extract_all(elements) == ["ISO_IR 100", "ISO_IR 101"]
    end

    test "returns an empty list when charset tag absent" do
      assert CharacterSet.extract_all(%{}) == []
    end
  end

  describe "decode/2 — charset with leading/trailing whitespace" do
    test "trims whitespace from charset before lookup" do
      assert {:ok, "ÄÖÜ"} = CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, " ISO_IR 100 ")
    end
  end

  describe "decode/2 — ISO 8859 control character range" do
    test "passes control characters 0x80-0x9F through unchanged" do
      assert {:ok, result} = CharacterSet.decode(<<0x80, 0x9F>>, "ISO_IR 101")
      assert <<0x80::utf8, 0x9F::utf8>> == result
    end
  end

  describe "decode/2 — decode_lossy fallback for invalid UTF-8" do
    test "returns raw binary when UTF-8 validation fails" do
      binary = <<0xFF, 0xFE>>
      result = Dicom.CharacterSet.decode_lossy(binary, "ISO_IR 192")
      assert result == binary
    end
  end

  describe "decode/2 — JIS X 0201 full coverage" do
    test "decodes all ASCII printable via JIS X 0201" do
      # Regular ASCII chars should pass through
      assert {:ok, "A"} = Dicom.CharacterSet.decode("A", "ISO_IR 13")
      assert {:ok, "0"} = Dicom.CharacterSet.decode("0", "ISO_IR 13")
      assert {:ok, " "} = Dicom.CharacterSet.decode(" ", "ISO_IR 13")
    end

    test "decodes various half-width katakana" do
      # ｲ = 0xB2, ｳ = 0xB3, ｴ = 0xB4
      assert {:ok, "ｲ"} = Dicom.CharacterSet.decode(<<0xB2>>, "ISO_IR 13")
      assert {:ok, "ｳ"} = Dicom.CharacterSet.decode(<<0xB3>>, "ISO_IR 13")
      assert {:ok, "ｴ"} = Dicom.CharacterSet.decode(<<0xB4>>, "ISO_IR 13")
    end
  end

  describe "supported?/1 edge cases" do
    test "nil is supported (default repertoire)" do
      assert Dicom.CharacterSet.supported?(nil)
    end

    test "whitespace-only charset maps to supported (empty = default)" do
      assert Dicom.CharacterSet.supported?("  ")
    end
  end

  describe "decode/2 — JIS X 0201 undefined byte ranges" do
    test "bytes 0x80-0xA0 pass through (undefined in JIS X 0201)" do
      # These bytes are not mapped in JIS X 0201 — they should pass through
      assert {:ok, result} = CharacterSet.decode(<<0x80>>, "ISO_IR 13")
      assert <<0x80::utf8>> == result

      assert {:ok, result} = CharacterSet.decode(<<0xA0>>, "ISO_IR 13")
      assert <<0xA0::utf8>> == result
    end

    test "bytes 0xE0-0xFF pass through (undefined in JIS X 0201)" do
      assert {:ok, result} = CharacterSet.decode(<<0xE0>>, "ISO_IR 13")
      assert <<0xE0::utf8>> == result

      assert {:ok, result} = CharacterSet.decode(<<0xFF>>, "ISO_IR 13")
      assert <<0xFF::utf8>> == result
    end
  end

  describe "textual VR padding/whitespace behavior" do
    test "PN with Latin-1 charset: padding preserved until Value.decode trims" do
      binary = <<0x4D, 0xDC, 0x4C, 0x4C, 0x45, 0x52, 0x20>>
      {:ok, decoded} = CharacterSet.decode(binary, "ISO_IR 100")
      assert decoded == "MÜLLER "
    end

    test "LO with default charset preserves content" do
      assert {:ok, "Some Description "} =
               CharacterSet.decode("Some Description ", nil)
    end
  end
end
