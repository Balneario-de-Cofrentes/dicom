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

    test "accepts ISO 2022 IR 100 without escape sequences" do
      assert {:ok, "ÄÖÜ"} = CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, "ISO 2022 IR 100")
    end

    test "accepts ISO 2022 IR 100 with escape sequence switching to Latin-1" do
      # ESC - A (switch to Latin-1 G1) followed by 0xC4 (Ä)
      binary = <<0x1B, 0x2D, 0x41, 0xC4>>
      assert {:ok, "Ä"} = CharacterSet.decode(binary, "ISO 2022 IR 100")
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
    test "returns unsupported_charset for truly unknown labels" do
      assert {:error, {:unsupported_charset, "UNKNOWN_CHARSET"}} =
               CharacterSet.decode("test", "UNKNOWN_CHARSET")
    end
  end

  describe "decode/2 — ISO 2022 charsets with multi-byte tables not yet implemented" do
    test "returns not_yet_implemented for JIS X 0208 with data" do
      # "ISO 2022 IR 87" as default charset, with non-empty data
      # The default encoding is :jis_x0208, and any data triggers not_yet_implemented
      assert {:error, :not_yet_implemented} =
               CharacterSet.decode(<<0x30, 0x21>>, "ISO 2022 IR 87")
    end

    test "returns not_yet_implemented for Korean charset with data" do
      assert {:error, :not_yet_implemented} =
               CharacterSet.decode(<<0xB0, 0xA1>>, "ISO 2022 IR 149")
    end

    test "returns not_yet_implemented for GB18030 with data" do
      assert {:error, :not_yet_implemented} =
               CharacterSet.decode(<<0xC4, 0xE3>>, "GB18030")
    end

    test "decodes empty binary for multi-byte charset labels" do
      assert {:ok, ""} = CharacterSet.decode(<<>>, "ISO 2022 IR 87")
      assert {:ok, ""} = CharacterSet.decode(<<>>, "ISO 2022 IR 149")
      assert {:ok, ""} = CharacterSet.decode(<<>>, "GB18030")
    end
  end

  describe "decode_lossy/2" do
    test "returns decoded string for supported charset" do
      assert "ÄÖÜ" = CharacterSet.decode_lossy(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 100")
    end

    test "returns raw binary when decode fails (multi-byte not yet implemented)" do
      binary = <<0xAB, 0xCD>>
      assert ^binary = CharacterSet.decode_lossy(binary, "ISO 2022 IR 87")
    end

    test "returns raw binary for truly unsupported charset" do
      binary = <<0xAB, 0xCD>>
      assert ^binary = CharacterSet.decode_lossy(binary, "UNKNOWN_CHARSET")
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

    test "ISO 2022 multi-byte charsets are recognized" do
      assert CharacterSet.supported?("ISO 2022 IR 87")
      assert CharacterSet.supported?("ISO 2022 IR 149")
      assert CharacterSet.supported?("ISO 2022 IR 159")
      assert CharacterSet.supported?("ISO 2022 IR 58")
      assert CharacterSet.supported?("GB18030")
    end

    test "ISO 2022 single-byte variants are recognized" do
      assert CharacterSet.supported?("ISO 2022 IR 6")
      assert CharacterSet.supported?("ISO 2022 IR 100")
      assert CharacterSet.supported?("ISO 2022 IR 101")
      assert CharacterSet.supported?("ISO 2022 IR 13")
    end

    test "truly unknown charsets are not supported" do
      refute CharacterSet.supported?("UNKNOWN_CHARSET")
      refute CharacterSet.supported?("ISO_IR 999")
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

  describe "decode_bytewise/3 — rescue branch when lookup raises" do
    test "returns decode_failed error when lookup function raises" do
      # Pass a lookup function that always raises, exercising the rescue on line 214
      raising_fn = fn _byte -> raise "boom" end

      assert {:error, {:decode_failed, :test_encoding}} =
               CharacterSet.decode_bytewise(<<0x41>>, raising_fn, :test_encoding)
    end

    test "returns decode_failed error with the provided encoding label" do
      raising_fn = fn _byte -> raise ArgumentError, "invalid codepoint" end

      assert {:error, {:decode_failed, {:iso8859, 99}}} =
               CharacterSet.decode_bytewise(<<0xFF>>, raising_fn, {:iso8859, 99})
    end

    test "succeeds when lookup function returns valid codepoints" do
      identity_fn = fn byte -> byte end
      assert {:ok, "A"} = CharacterSet.decode_bytewise(<<0x41>>, identity_fn, :test)
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

  # ----------------------------------------------------------------
  # ISO 2022 escape sequence support
  # ----------------------------------------------------------------

  describe "decode_iso2022/2 — escape-free text (passthrough)" do
    test "ASCII text with :ascii default passes through" do
      assert {:ok, "HELLO"} = CharacterSet.decode_iso2022("HELLO", :ascii)
    end

    test "Latin-1 text with :latin1 default decodes correctly" do
      assert {:ok, "ÄÖÜ"} =
               CharacterSet.decode_iso2022(<<0xC4, 0xD6, 0xDC>>, :latin1)
    end

    test "JIS X 0201 text with :jis_x0201 default decodes katakana" do
      assert {:ok, "ｱｶ"} =
               CharacterSet.decode_iso2022(<<0xB1, 0xB6>>, :jis_x0201)
    end

    test "empty binary returns empty string" do
      assert {:ok, ""} = CharacterSet.decode_iso2022(<<>>, :ascii)
    end
  end

  describe "decode_iso2022/2 — G0 escape sequences" do
    test "ESC ( B switches to ASCII" do
      # Start in JIS X 0201, switch to ASCII via ESC ( B, then ASCII text
      binary = <<0xB1, 0x1B, 0x28, 0x42, ?A, ?B>>
      assert {:ok, "ｱAB"} = CharacterSet.decode_iso2022(binary, :jis_x0201)
    end

    test "ESC ( J switches to JIS X 0201 Roman" do
      # Start in ASCII, switch to JIS X 0201 via ESC ( J
      # 0x5C in JIS X 0201 = Yen sign
      binary = <<0x41, 0x1B, 0x28, 0x4A, 0x5C>>
      assert {:ok, "A¥"} = CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "decode_iso2022/2 — G1 escape sequences (single-byte)" do
    test "ESC - A switches to Latin-1" do
      # Start in ASCII, switch to Latin-1 via ESC - A
      binary = <<0x41, 0x1B, 0x2D, 0x41, 0xC4>>
      assert {:ok, "AÄ"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - F switches to Greek (ISO 8859-7)" do
      # Start in ASCII, switch to Greek via ESC - F
      # 0xC1 in ISO 8859-7 = Alpha (U+0391)
      binary = <<0x41, 0x1B, 0x2D, 0x46, 0xC1>>
      assert {:ok, "AΑ"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - H switches to Hebrew (ISO 8859-8)" do
      # 0xE0 in ISO 8859-8 = Alef (U+05D0)
      binary = <<0x1B, 0x2D, 0x48, 0xE0>>
      assert {:ok, "א"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC ) I switches to JIS X 0201 Katakana" do
      # Start in ASCII, switch to katakana via ESC ) I
      binary = <<0x41, 0x1B, 0x29, 0x49, 0xB1>>
      assert {:ok, "Aｱ"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - B switches to Latin-2 (ISO 8859-2)" do
      # 0xA1 in ISO 8859-2 = Ą (U+0104)
      binary = <<0x1B, 0x2D, 0x42, 0xA1>>
      assert {:ok, "Ą"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - C switches to Latin-3 (ISO 8859-3)" do
      # 0xA1 in ISO 8859-3 = Ħ (U+0126)
      binary = <<0x1B, 0x2D, 0x43, 0xA1>>
      assert {:ok, "Ħ"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - D switches to Latin-4 (ISO 8859-4)" do
      # 0xA1 in ISO 8859-4 = Ą (U+0104)
      binary = <<0x1B, 0x2D, 0x44, 0xA1>>
      assert {:ok, "Ą"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - L switches to Cyrillic (ISO 8859-5)" do
      # 0xB0 in ISO 8859-5 = А (U+0410)
      binary = <<0x1B, 0x2D, 0x4C, 0xB0>>
      assert {:ok, "А"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - G switches to Arabic (ISO 8859-6)" do
      # 0xC1 in ISO 8859-6 = Hamza (U+0621)
      binary = <<0x1B, 0x2D, 0x47, 0xC1>>
      assert {:ok, "ء"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC - M switches to Latin-5 (ISO 8859-9)" do
      # 0xDE in ISO 8859-9 = Ş (U+015E)
      binary = <<0x1B, 0x2D, 0x4D, 0xDE>>
      assert {:ok, "Ş"} = CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "decode_iso2022/2 — multi-byte escape sequences" do
    test "ESC $ B (JIS X 0208) returns not_yet_implemented" do
      binary = <<0x1B, 0x24, 0x42, 0x30, 0x21>>

      assert {:error, :not_yet_implemented} =
               CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC $ ( D (JIS X 0212) returns not_yet_implemented" do
      binary = <<0x1B, 0x24, 0x28, 0x44, 0x30, 0x21>>

      assert {:error, :not_yet_implemented} =
               CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC $ ) C (KS X 1001) returns not_yet_implemented" do
      binary = <<0x1B, 0x24, 0x29, 0x43, 0xB0, 0xA1>>

      assert {:error, :not_yet_implemented} =
               CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC $ ) A (GB2312) returns not_yet_implemented" do
      binary = <<0x1B, 0x24, 0x29, 0x41, 0xC4, 0xE3>>

      assert {:error, :not_yet_implemented} =
               CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "decode_iso2022/2 — multiple switches" do
    test "ASCII -> Latin-1 -> back to ASCII" do
      # A, ESC - A, 0xC4 (Ä), ESC ( B, B
      binary = <<0x41, 0x1B, 0x2D, 0x41, 0xC4, 0x1B, 0x28, 0x42, 0x42>>
      assert {:ok, "AÄB"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "JIS X 0201 -> ASCII -> JIS X 0201" do
      # 0xB1 (ｱ), ESC ( B, A, ESC ( J, 0x5C (¥)
      binary = <<0xB1, 0x1B, 0x28, 0x42, 0x41, 0x1B, 0x28, 0x4A, 0x5C>>
      assert {:ok, "ｱA¥"} = CharacterSet.decode_iso2022(binary, :jis_x0201)
    end

    test "ASCII -> Greek -> Hebrew" do
      # A, ESC - F, 0xC1 (Alpha), ESC - H, 0xE0 (Alef)
      binary =
        <<0x41, 0x1B, 0x2D, 0x46, 0xC1, 0x1B, 0x2D, 0x48, 0xE0>>

      assert {:ok, "AΑא"} = CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "decode_iso2022/2 — unknown escape sequences" do
    test "unknown ESC bytes are included verbatim in current segment" do
      # ESC followed by unknown bytes (0x3F = ?) — not a valid ISO 2022 sequence
      # Should include ESC in the output as a raw byte (0x1B is <= 0x7F so valid ASCII)
      binary = <<0x41, 0x1B, 0x3F, 0x42>>
      assert {:ok, result} = CharacterSet.decode_iso2022(binary, :ascii)
      # The ESC byte (0x1B) is within ASCII range, so it passes through
      assert result == <<0x41, 0x1B, 0x3F, 0x42>>
    end
  end

  describe "decode/2 — ISO 2022 routing via charset labels" do
    test "ISO 2022 IR 6 with escape to Latin-1 decodes correctly" do
      binary = <<0x41, 0x1B, 0x2D, 0x41, 0xC4>>
      assert {:ok, "AÄ"} = CharacterSet.decode(binary, "ISO 2022 IR 6")
    end

    test "ISO 2022 IR 6 without escapes decodes as ASCII" do
      assert {:ok, "TEST"} = CharacterSet.decode("TEST", "ISO 2022 IR 6")
    end

    test "ISO 2022 IR 13 decodes JIS X 0201 without escapes" do
      assert {:ok, "ｱ"} = CharacterSet.decode(<<0xB1>>, "ISO 2022 IR 13")
    end

    test "ISO 2022 IR 13 with escape to ASCII" do
      binary = <<0xB1, 0x1B, 0x28, 0x42, 0x41>>
      assert {:ok, "ｱA"} = CharacterSet.decode(binary, "ISO 2022 IR 13")
    end

    test "ISO 2022 IR 87 with ASCII-only text returns not_yet_implemented" do
      # Default encoding is :jis_x0208, any non-empty data triggers it
      assert {:error, :not_yet_implemented} =
               CharacterSet.decode(<<0x30, 0x21>>, "ISO 2022 IR 87")
    end

    test "ISO 2022 IR 101 decodes Latin-2 without escapes" do
      # 0xA1 in ISO 8859-2 = Ą (U+0104)
      assert {:ok, "Ą"} = CharacterSet.decode(<<0xA1>>, "ISO 2022 IR 101")
    end

    test "ISO 2022 IR 126 decodes Greek without escapes" do
      # 0xC1 in ISO 8859-7 = Alpha (U+0391)
      assert {:ok, "Α"} = CharacterSet.decode(<<0xC1>>, "ISO 2022 IR 126")
    end
  end
end
