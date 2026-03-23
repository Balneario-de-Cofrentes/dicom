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

  describe "decode/2 — ISO 2022 IR 87 (JIS X 0208)" do
    test "decodes kanji characters" do
      # {0x30, 0x21} = 亜 (U+4E9C)
      assert {:ok, "亜"} = CharacterSet.decode(<<0x30, 0x21>>, "ISO 2022 IR 87")
    end

    test "decodes hiragana" do
      # {0x24, 0x22} = あ (U+3042)
      assert {:ok, "あ"} = CharacterSet.decode(<<0x24, 0x22>>, "ISO 2022 IR 87")
    end

    test "decodes katakana" do
      # {0x25, 0x22} = ア (U+30A2)
      assert {:ok, "ア"} = CharacterSet.decode(<<0x25, 0x22>>, "ISO 2022 IR 87")
    end

    test "decodes empty binary" do
      assert {:ok, ""} = CharacterSet.decode(<<>>, "ISO 2022 IR 87")
    end

    test "returns error for odd-length binary" do
      assert {:error, {:decode_failed, :jis_x0208}} =
               CharacterSet.decode(<<0x30>>, "ISO 2022 IR 87")
    end

    test "returns error for unmapped byte pair" do
      # {0x7E, 0x7E} is not in the table
      assert {:error, {:decode_failed, :jis_x0208}} =
               CharacterSet.decode(<<0x7E, 0x7E>>, "ISO 2022 IR 87")
    end
  end

  describe "decode/2 — multi-byte charsets not yet implemented" do
    test "returns not_yet_implemented for JIS X 0212 charset with data" do
      assert {:error, :not_yet_implemented} =
               CharacterSet.decode(<<0x1B, 0x24, 0x28, 0x44, 0x30, 0x21>>, "ISO 2022 IR 159")
    end

    test "decodes empty binary for multi-byte charset labels" do
      assert {:ok, ""} = CharacterSet.decode(<<>>, "ISO 2022 IR 149")
      assert {:ok, ""} = CharacterSet.decode(<<>>, "GB18030")
    end
  end

  describe "decode/2 — GB18030" do
    test "decodes common Chinese characters (2-byte GBK)" do
      # 0xC4E3 = "you" (U+4F60), 0xBAC3 = "good" (U+597D)
      assert {:ok, "\u4F60\u597D"} = CharacterSet.decode(<<0xC4, 0xE3, 0xBA, 0xC3>>, "GB18030")
    end

    test "decodes ASCII passthrough" do
      assert {:ok, "HELLO"} = CharacterSet.decode("HELLO", "GB18030")
    end

    test "decodes mixed ASCII and Chinese" do
      # "Hi" + 0xC4E3 (U+4F60)
      assert {:ok, "Hi\u4F60"} = CharacterSet.decode(<<0x48, 0x69, 0xC4, 0xE3>>, "GB18030")
    end

    test "decodes empty binary" do
      assert {:ok, ""} = CharacterSet.decode(<<>>, "GB18030")
    end

    test "decodes DICOM patient name with Chinese characters" do
      # "Wang^XiaoMing" in Chinese: 0xCDF5 (U+738B) = Wang, ^ = separator,
      # 0xD0A1 (U+5C0F) = Xiao, 0xC3F7 (U+660E) = Ming
      binary = <<0xCD, 0xF5, 0x5E, 0xD0, 0xA1, 0xC3, 0xF7>>
      assert {:ok, "\u738B^\u5C0F\u660E"} = CharacterSet.decode(binary, "GB18030")
    end

    test "returns error for invalid byte sequence" do
      # 0xFF is not a valid lead byte in GB18030
      assert {:error, {:decode_failed, :gb18030}} = CharacterSet.decode(<<0xFF>>, "GB18030")
    end

    test "returns error for truncated 2-byte sequence" do
      # Lead byte 0xC4 without trail byte
      assert {:error, {:decode_failed, :gb18030}} = CharacterSet.decode(<<0xC4>>, "GB18030")
    end
  end

  describe "decode_lossy/2" do
    test "returns decoded string for supported charset" do
      assert "ÄÖÜ" = CharacterSet.decode_lossy(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 100")
    end

    test "returns raw binary when decode fails (unmapped JIS pair)" do
      # {0x7E, 0x7E} is not in the JIS X 0208 table
      binary = <<0x7E, 0x7E>>
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
    test "ESC $ B (JIS X 0208) decodes kanji" do
      # ESC $ B switches to JIS X 0208, then {0x30, 0x21} = 亜 (U+4E9C)
      binary = <<0x1B, 0x24, 0x42, 0x30, 0x21>>
      assert {:ok, "亜"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC $ ( D (JIS X 0212) returns not_yet_implemented" do
      binary = <<0x1B, 0x24, 0x28, 0x44, 0x30, 0x21>>

      assert {:error, :not_yet_implemented} =
               CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC $ ) C (KS X 1001) decodes Korean" do
      # ESC $ ) C switches to KS X 1001, then 0xB0A1 = 가 (U+AC00)
      binary = <<0x1B, 0x24, 0x29, 0x43, 0xB0, 0xA1>>
      assert {:ok, "가"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ESC $ ) A (GB2312) decodes simplified Chinese" do
      # ESC $ ) A switches to GB2312, then 0xC4E3 = 你 (U+4F60)
      binary = <<0x1B, 0x24, 0x29, 0x41, 0xC4, 0xE3>>
      assert {:ok, "你"} = CharacterSet.decode_iso2022(binary, :ascii)
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

    test "ISO 2022 IR 87 decodes JIS X 0208 kanji" do
      # {0x30, 0x21} = 亜 (U+4E9C) via default :jis_x0208 encoding
      assert {:ok, "亜"} = CharacterSet.decode(<<0x30, 0x21>>, "ISO 2022 IR 87")
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

  # ----------------------------------------------------------------
  # JIS X 0208 comprehensive tests
  # ----------------------------------------------------------------

  describe "JIS X 0208 — Hiragana decoding" do
    test "decodes individual hiragana characters" do
      # あ = {0x24, 0x22} -> U+3042
      assert {:ok, "あ"} = CharacterSet.decode(<<0x24, 0x22>>, "ISO 2022 IR 87")
      # い = {0x24, 0x24} -> U+3044
      assert {:ok, "い"} = CharacterSet.decode(<<0x24, 0x24>>, "ISO 2022 IR 87")
      # う = {0x24, 0x26} -> U+3046
      assert {:ok, "う"} = CharacterSet.decode(<<0x24, 0x26>>, "ISO 2022 IR 87")
    end

    test "decodes hiragana string" do
      # あいう = {0x24,0x22}{0x24,0x24}{0x24,0x26}
      binary = <<0x24, 0x22, 0x24, 0x24, 0x24, 0x26>>
      assert {:ok, "あいう"} = CharacterSet.decode(binary, "ISO 2022 IR 87")
    end
  end

  describe "JIS X 0208 — Katakana decoding" do
    test "decodes individual katakana characters" do
      # ア = {0x25, 0x22} -> U+30A2
      assert {:ok, "ア"} = CharacterSet.decode(<<0x25, 0x22>>, "ISO 2022 IR 87")
      # カ = {0x25, 0x2B} -> check
      assert {:ok, "イ"} = CharacterSet.decode(<<0x25, 0x24>>, "ISO 2022 IR 87")
    end

    test "decodes katakana patient name: ヤマダ^タロウ" do
      # ヤ={0x25,0x64} マ={0x25,0x5E} ダ={0x25,0x40}
      # ^=0x5E (ASCII, needs escape switching)
      # タ={0x25,0x3F} ロ={0x25,0x6D} ウ={0x25,0x26}
      #
      # In DICOM, this is encoded with ISO 2022 escape sequences:
      # ESC $ B (switch to JIS X 0208) + katakana bytes + ESC ( B (back to ASCII) + ^ + ESC $ B + more katakana
      yamada = <<0x25, 0x64, 0x25, 0x5E, 0x25, 0x40>>
      tarou = <<0x25, 0x3F, 0x25, 0x6D, 0x25, 0x26>>

      binary =
        <<0x1B, 0x24, 0x42>> <>
          yamada <>
          <<0x1B, 0x28, 0x42>> <>
          "^" <>
          <<0x1B, 0x24, 0x42>> <>
          tarou <>
          <<0x1B, 0x28, 0x42>>

      assert {:ok, "ヤマダ^タロウ"} = CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "JIS X 0208 — Kanji decoding" do
    test "decodes common kanji characters" do
      # 山 = {0x3B, 0x33} -> U+5C71
      assert {:ok, "山"} = CharacterSet.decode(<<0x3B, 0x33>>, "ISO 2022 IR 87")
      # 田 = {0x45, 0x44} -> U+7530
      assert {:ok, "田"} = CharacterSet.decode(<<0x45, 0x44>>, "ISO 2022 IR 87")
      # 太 = {0x42, 0x40} -> U+592A
      assert {:ok, "太"} = CharacterSet.decode(<<0x42, 0x40>>, "ISO 2022 IR 87")
      # 郎 = {0x4F, 0x3A} -> U+90CE
      assert {:ok, "郎"} = CharacterSet.decode(<<0x4F, 0x3A>>, "ISO 2022 IR 87")
    end

    test "decodes kanji string: 山田太郎" do
      binary = <<0x3B, 0x33, 0x45, 0x44, 0x42, 0x40, 0x4F, 0x3A>>
      assert {:ok, "山田太郎"} = CharacterSet.decode(binary, "ISO 2022 IR 87")
    end
  end

  describe "JIS X 0208 — symbols and fullwidth forms" do
    test "decodes ideographic space" do
      # {0x21, 0x21} = ideographic space U+3000
      assert {:ok, <<0x3000::utf8>>} = CharacterSet.decode(<<0x21, 0x21>>, "ISO 2022 IR 87")
    end

    test "decodes ideographic punctuation" do
      # {0x21, 0x22} = ideographic comma U+3001
      assert {:ok, "、"} = CharacterSet.decode(<<0x21, 0x22>>, "ISO 2022 IR 87")
      # {0x21, 0x23} = ideographic full stop U+3002
      assert {:ok, "。"} = CharacterSet.decode(<<0x21, 0x23>>, "ISO 2022 IR 87")
    end
  end

  describe "JIS X 0208 — mixed ASCII + Japanese with escape switching" do
    test "ASCII then JIS X 0208 then back to ASCII" do
      # "AB" + ESC $ B + {0x24,0x22}(あ) + ESC ( B + "CD"
      binary =
        "AB" <>
          <<0x1B, 0x24, 0x42, 0x24, 0x22, 0x1B, 0x28, 0x42>> <>
          "CD"

      assert {:ok, "ABあCD"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "realistic DICOM patient name with JIS X 0208 kanji and ASCII" do
      # DICOM PN format: family^given=ideographic^ideographic
      # "YAMADA^TAROU" in ASCII, then "=" separator, then kanji
      # 山田={0x3B,0x33}{0x45,0x44} 太郎={0x42,0x40}{0x4F,0x3A}
      kanji_family = <<0x3B, 0x33, 0x45, 0x44>>
      kanji_given = <<0x42, 0x40, 0x4F, 0x3A>>

      binary =
        "YAMADA^TAROU=" <>
          <<0x1B, 0x24, 0x42>> <>
          kanji_family <>
          <<0x1B, 0x28, 0x42>> <>
          "^" <>
          <<0x1B, 0x24, 0x42>> <>
          kanji_given <>
          <<0x1B, 0x28, 0x42>>

      assert {:ok, "YAMADA^TAROU=山田^太郎"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "JIS X 0201 katakana then JIS X 0208 kanji switching" do
      # Start in JIS X 0201, half-width katakana, then switch to JIS X 0208
      # ｱ (0xB1) in JIS X 0201, then ESC $ B, then 山 ({0x3B, 0x33})
      binary =
        <<0xB1, 0x1B, 0x24, 0x42, 0x3B, 0x33>>

      assert {:ok, "ｱ山"} = CharacterSet.decode_iso2022(binary, :jis_x0201)
    end

    test "multiple JIS X 0208 segments" do
      # kanji + ASCII + kanji
      binary =
        <<0x1B, 0x24, 0x42, 0x24, 0x22>> <>
          <<0x1B, 0x28, 0x42>> <>
          "+" <>
          <<0x1B, 0x24, 0x42, 0x25, 0x22>> <>
          <<0x1B, 0x28, 0x42>>

      assert {:ok, "あ+ア"} = CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "JisX0208 module — decode_pair/2" do
    test "returns {:ok, codepoint} for valid pair" do
      assert {:ok, 0x3042} = Dicom.CharacterSet.JisX0208.decode_pair(0x24, 0x22)
    end

    test "returns :error for unmapped pair" do
      assert :error = Dicom.CharacterSet.JisX0208.decode_pair(0x7E, 0x7E)
    end

    test "returns :error for out-of-range bytes" do
      assert :error = Dicom.CharacterSet.JisX0208.decode_pair(0x20, 0x21)
      assert :error = Dicom.CharacterSet.JisX0208.decode_pair(0x21, 0x7F)
      assert :error = Dicom.CharacterSet.JisX0208.decode_pair(0x80, 0x21)
    end
  end

  describe "JisX0208 module — decode_binary/1" do
    test "decodes empty binary" do
      assert {:ok, ""} = Dicom.CharacterSet.JisX0208.decode_binary(<<>>)
    end

    test "decodes single character" do
      assert {:ok, "あ"} = Dicom.CharacterSet.JisX0208.decode_binary(<<0x24, 0x22>>)
    end

    test "decodes multiple characters" do
      binary = <<0x3B, 0x33, 0x45, 0x44>>
      assert {:ok, "山田"} = Dicom.CharacterSet.JisX0208.decode_binary(binary)
    end

    test "returns error for odd-length binary" do
      assert {:error, {:decode_failed, :jis_x0208}} =
               Dicom.CharacterSet.JisX0208.decode_binary(<<0x24>>)
    end

    test "returns error for unmapped pair in binary" do
      assert {:error, {:decode_failed, :jis_x0208}} =
               Dicom.CharacterSet.JisX0208.decode_binary(<<0x7E, 0x7E>>)
    end
  end

  # GB2312-80 comprehensive tests
  describe "GB2312 — decode_pair/2" do
    test "decodes common Chinese character (ni/you)" do
      # 你 = U+4F60, row 0x44, cell 0x63
      assert {:ok, 0x4F60} = Dicom.CharacterSet.GB2312.decode_pair(0x44, 0x63)
    end

    test "decodes common Chinese character (hao/good)" do
      # 好 = U+597D, row 0x3A, cell 0x43
      assert {:ok, 0x597D} = Dicom.CharacterSet.GB2312.decode_pair(0x3A, 0x43)
    end

    test "decodes row 1 symbol (ideographic comma)" do
      # 、 = U+3001, row 0x21, cell 0x22
      assert {:ok, 0x3001} = Dicom.CharacterSet.GB2312.decode_pair(0x21, 0x22)
    end

    test "decodes row 1 symbol (ideographic space)" do
      # 　 = U+3000, row 0x21, cell 0x21
      assert {:ok, 0x3000} = Dicom.CharacterSet.GB2312.decode_pair(0x21, 0x21)
    end

    test "returns error for out-of-range row" do
      assert :error = Dicom.CharacterSet.GB2312.decode_pair(0x20, 0x21)
      assert :error = Dicom.CharacterSet.GB2312.decode_pair(0x7F, 0x21)
    end

    test "returns error for out-of-range cell" do
      assert :error = Dicom.CharacterSet.GB2312.decode_pair(0x21, 0x20)
      assert :error = Dicom.CharacterSet.GB2312.decode_pair(0x21, 0x7F)
    end

    test "returns error for unmapped pair in valid range" do
      # Row 10-15 (0x2A-0x2F) are unused in GB2312
      assert :error = Dicom.CharacterSet.GB2312.decode_pair(0x2A, 0x21)
    end
  end

  describe "GB2312 — decode_binary/1 with GL bytes (0x21-0x7E)" do
    test "decodes single character" do
      # 你 GL bytes: 0x44, 0x63
      assert {:ok, "你"} = Dicom.CharacterSet.GB2312.decode_binary(<<0x44, 0x63>>)
    end

    test "decodes nihao (hello)" do
      # 你好 GL: 0x44,0x63 + 0x3A,0x43
      binary = <<0x44, 0x63, 0x3A, 0x43>>
      assert {:ok, "你好"} = Dicom.CharacterSet.GB2312.decode_binary(binary)
    end

    test "decodes shijie (world)" do
      # 世界 GL: 0x4A,0x40 + 0x3D,0x67
      binary = <<0x4A, 0x40, 0x3D, 0x67>>
      assert {:ok, "世界"} = Dicom.CharacterSet.GB2312.decode_binary(binary)
    end

    test "decodes zhongguo (China)" do
      # 中国 GL: 0x56,0x50 + 0x39,0x7A
      binary = <<0x56, 0x50, 0x39, 0x7A>>
      assert {:ok, "中国"} = Dicom.CharacterSet.GB2312.decode_binary(binary)
    end

    test "returns error for odd-length binary" do
      assert {:error, {:decode_failed, :gb2312}} =
               Dicom.CharacterSet.GB2312.decode_binary(<<0x44>>)
    end

    test "returns error for unmapped pair" do
      # Row 10 (0x2A) is unused
      assert {:error, {:decode_failed, :gb2312}} =
               Dicom.CharacterSet.GB2312.decode_binary(<<0x2A, 0x21>>)
    end

    test "decodes empty binary" do
      assert {:ok, ""} = Dicom.CharacterSet.GB2312.decode_binary(<<>>)
    end
  end

  describe "GB2312 — decode_binary/1 with GR bytes (0xA1-0xFE)" do
    test "decodes single character with high bit set" do
      # 你 GR bytes: 0xC4, 0xE3
      assert {:ok, "你"} = Dicom.CharacterSet.GB2312.decode_binary(<<0xC4, 0xE3>>)
    end

    test "decodes nihao with high bit set" do
      # 你好 GR: 0xC4,0xE3 + 0xBA,0xC3
      binary = <<0xC4, 0xE3, 0xBA, 0xC3>>
      assert {:ok, "你好"} = Dicom.CharacterSet.GB2312.decode_binary(binary)
    end

    test "decodes zhongguo with high bit set" do
      # 中国 GR: 0xD6,0xD0 + 0xB9,0xFA
      binary = <<0xD6, 0xD0, 0xB9, 0xFA>>
      assert {:ok, "中国"} = Dicom.CharacterSet.GB2312.decode_binary(binary)
    end

    test "decodes zhang-san surname with high bit set" do
      # 张三 GR: 0xD5,0xC5 + 0xC8,0xFD
      binary = <<0xD5, 0xC5, 0xC8, 0xFD>>
      assert {:ok, "张三"} = Dicom.CharacterSet.GB2312.decode_binary(binary)
    end
  end

  describe "GB2312 — ISO 2022 integration via decode_iso2022/2" do
    test "ESC $ ) A switches to GB2312 and decodes Chinese" do
      # ESC $ ) A + 你好 (GR bytes)
      binary = <<0x1B, 0x24, 0x29, 0x41, 0xC4, 0xE3, 0xBA, 0xC3>>
      assert {:ok, "你好"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "mixed ASCII and GB2312 with escape switching" do
      # "ID" + ESC $ ) A + 张三 (GR) + ESC ( B + "^" + ESC $ ) A + 三 (GR)
      binary =
        <<0x49, 0x44>> <>
          <<0x1B, 0x24, 0x29, 0x41>> <>
          <<0xD5, 0xC5>> <>
          <<0x1B, 0x28, 0x42>> <>
          <<0x5E>> <>
          <<0x1B, 0x24, 0x29, 0x41>> <>
          <<0xC8, 0xFD>>

      assert {:ok, "ID张^三"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "DICOM patient name with Chinese ideographic component" do
      # DICOM PN format: 张^三 encoded as GB2312
      # ESC $ ) A + 张 + ESC ( B + ^ + ESC $ ) A + 三
      binary =
        <<0x1B, 0x24, 0x29, 0x41>> <>
          <<0xD5, 0xC5>> <>
          <<0x1B, 0x28, 0x42>> <>
          <<0x5E>> <>
          <<0x1B, 0x24, 0x29, 0x41>> <>
          <<0xC8, 0xFD>>

      assert {:ok, "张^三"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "pure ASCII before GB2312 escape" do
      # "HELLO" + ESC $ ) A + 你 (GR bytes)
      binary = <<0x48, 0x45, 0x4C, 0x4C, 0x4F, 0x1B, 0x24, 0x29, 0x41, 0xC4, 0xE3>>
      assert {:ok, "HELLO你"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "GB2312 followed by return to ASCII" do
      # ESC $ ) A + 好 (GR) + ESC ( B + "OK"
      binary =
        <<0x1B, 0x24, 0x29, 0x41>> <>
          <<0xBA, 0xC3>> <>
          <<0x1B, 0x28, 0x42>> <>
          <<0x4F, 0x4B>>

      assert {:ok, "好OK"} = CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "GB2312 — decode/2 via ISO 2022 IR 58" do
    test "decodes Chinese text with ISO 2022 IR 58 charset" do
      # ESC $ ) A + 你好 (GR)
      binary = <<0x1B, 0x24, 0x29, 0x41, 0xC4, 0xE3, 0xBA, 0xC3>>
      assert {:ok, "你好"} = CharacterSet.decode(binary, "ISO 2022 IR 58")
    end

    test "decodes four-character phrase nihao-shijie" do
      # ESC $ ) A + 你好世界
      binary =
        <<0x1B, 0x24, 0x29, 0x41>> <>
          <<0xC4, 0xE3, 0xBA, 0xC3, 0xCA, 0xC0, 0xBD, 0xE7>>

      assert {:ok, "你好世界"} = CharacterSet.decode(binary, "ISO 2022 IR 58")
    end
  end

  # ----------------------------------------------------------------
  # KS X 1001 (ISO 2022 IR 149) — Korean
  # ----------------------------------------------------------------

  describe "KsX1001.decode_pair/2" do
    alias Dicom.CharacterSet.KsX1001

    test "decodes Hangul syllable 가 (U+AC00) at row 0x30, cell 0x21" do
      assert {:ok, 0xAC00} = KsX1001.decode_pair(0x30, 0x21)
    end

    test "decodes Hangul syllable 한 (U+D55C) at row 0x47, cell 0x51" do
      assert {:ok, 0xD55C} = KsX1001.decode_pair(0x47, 0x51)
    end

    test "decodes Hangul syllable 국 (U+AD6D) at row 0x31, cell 0x39" do
      assert {:ok, 0xAD6D} = KsX1001.decode_pair(0x31, 0x39)
    end

    test "decodes symbol: ideographic space (U+3000) at row 0x21, cell 0x21" do
      assert {:ok, 0x3000} = KsX1001.decode_pair(0x21, 0x21)
    end

    test "decodes Hanja character at row 0x4A (first Hanja row)" do
      # Row 0x4A is the first Hanja row in KS X 1001
      assert {:ok, cp} = KsX1001.decode_pair(0x4A, 0x21)
      assert is_integer(cp) and cp > 0
    end

    test "returns error for out-of-range bytes" do
      assert :error = KsX1001.decode_pair(0x20, 0x21)
      assert :error = KsX1001.decode_pair(0x21, 0x7F)
      assert :error = KsX1001.decode_pair(0x7F, 0x21)
      assert :error = KsX1001.decode_pair(0xA1, 0xA1)
    end

    test "returns error for unmapped position" do
      # Row 0x7E, cell 0x7E is typically unmapped in KS X 1001
      assert :error = KsX1001.decode_pair(0x7E, 0x7E)
    end
  end

  describe "KsX1001.decode_binary/1" do
    alias Dicom.CharacterSet.KsX1001

    test "decodes empty binary" do
      assert {:ok, ""} = KsX1001.decode_binary(<<>>)
    end

    test "decodes GR-range bytes (0xA1-0xFE) -- standard DICOM Korean encoding" do
      # 가 in EUC-KR = 0xB0A1 (row 0x30 + 0x80, cell 0x21 + 0x80)
      assert {:ok, "가"} = KsX1001.decode_binary(<<0xB0, 0xA1>>)
    end

    test "decodes GL-range bytes (0x21-0x7E) directly" do
      # 가 = row 0x30, cell 0x21
      assert {:ok, "가"} = KsX1001.decode_binary(<<0x30, 0x21>>)
    end

    test "decodes 한국어 (Korean language) from GR bytes" do
      # 한=0xC7D1 국=0xB1B9 어=0xBEEE
      assert {:ok, "한국어"} = KsX1001.decode_binary(<<0xC7, 0xD1, 0xB1, 0xB9, 0xBE, 0xEE>>)
    end

    test "decodes 김 (surname Kim) from GR bytes" do
      # 김=0xB1E8
      assert {:ok, "김"} = KsX1001.decode_binary(<<0xB1, 0xE8>>)
    end

    test "decodes 철수 from GR bytes" do
      # 철=0xC3B6 수=0xBCF6
      assert {:ok, "철수"} = KsX1001.decode_binary(<<0xC3, 0xB6, 0xBC, 0xF6>>)
    end

    test "returns error for odd-length binary" do
      assert {:error, {:decode_failed, :ks_x1001}} = KsX1001.decode_binary(<<0xB0>>)
    end

    test "returns error for unmapped byte pair" do
      assert {:error, {:decode_failed, :ks_x1001}} = KsX1001.decode_binary(<<0xFE, 0xFE>>)
    end
  end

  describe "decode/2 — ISO 2022 IR 149 (KS X 1001) via charset label" do
    test "decodes Korean syllables with default KS X 1001 encoding" do
      # 가 in GR bytes
      assert {:ok, "가"} = CharacterSet.decode(<<0xB0, 0xA1>>, "ISO 2022 IR 149")
    end

    test "decodes empty binary" do
      assert {:ok, ""} = CharacterSet.decode(<<>>, "ISO 2022 IR 149")
    end

    test "decodes 한국어 via charset label" do
      assert {:ok, "한국어"} =
               CharacterSet.decode(
                 <<0xC7, 0xD1, 0xB1, 0xB9, 0xBE, 0xEE>>,
                 "ISO 2022 IR 149"
               )
    end
  end

  describe "KS X 1001 — escape sequence switching" do
    test "ESC $ ) C switches to KS X 1001 and decodes Hangul" do
      # ESC $ ) C + 한 (0xC7D1)
      binary = <<0x1B, 0x24, 0x29, 0x43, 0xC7, 0xD1>>
      assert {:ok, "한"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ASCII then Korean via escape" do
      # "A" + ESC $ ) C + 가 (0xB0A1)
      binary = <<0x41, 0x1B, 0x24, 0x29, 0x43, 0xB0, 0xA1>>
      assert {:ok, "A가"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "Korean then back to ASCII" do
      # ESC $ ) C + 가 (0xB0A1) + ESC ( B + "B"
      binary = <<0x1B, 0x24, 0x29, 0x43, 0xB0, 0xA1, 0x1B, 0x28, 0x42, 0x42>>
      assert {:ok, "가B"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "multiple Korean characters with escape" do
      # ESC $ ) C + 한국어 (0xC7D1 0xB1B9 0xBEEE)
      binary = <<0x1B, 0x24, 0x29, 0x43, 0xC7, 0xD1, 0xB1, 0xB9, 0xBE, 0xEE>>
      assert {:ok, "한국어"} = CharacterSet.decode_iso2022(binary, :ascii)
    end

    test "ASCII -> Korean -> ASCII round trip" do
      # "Hello" + ESC $ ) C + 한국어 + ESC ( B + "World"
      binary =
        "Hello" <>
          <<0x1B, 0x24, 0x29, 0x43, 0xC7, 0xD1, 0xB1, 0xB9, 0xBE, 0xEE>> <>
          <<0x1B, 0x28, 0x42>> <>
          "World"

      assert {:ok, "Hello한국어World"} = CharacterSet.decode_iso2022(binary, :ascii)
    end
  end

  describe "KS X 1001 — DICOM patient name scenarios" do
    test "Korean patient name: 김^철수" do
      # ESC $ ) C + 김 (0xB1E8) + ^ (stays as ASCII after ESC ( B) + ESC $ ) C + 철수 (0xC3B6 0xBCF6)
      binary =
        <<0x1B, 0x24, 0x29, 0x43, 0xB1, 0xE8>> <>
          <<0x1B, 0x28, 0x42, 0x5E>> <>
          <<0x1B, 0x24, 0x29, 0x43, 0xC3, 0xB6, 0xBC, 0xF6>>

      assert {:ok, "김^철수"} = CharacterSet.decode(binary, "ISO 2022 IR 149")
    end

    test "Korean patient name with ASCII given name: 김^John" do
      binary =
        <<0x1B, 0x24, 0x29, 0x43, 0xB1, 0xE8>> <>
          <<0x1B, 0x28, 0x42>> <>
          "^John"

      assert {:ok, "김^John"} = CharacterSet.decode(binary, "ISO 2022 IR 149")
    end

    test "Korean family name only" do
      # 박 = 0xB9DA in EUC-KR
      binary = <<0x1B, 0x24, 0x29, 0x43, 0xB9, 0xDA>>
      assert {:ok, "박"} = CharacterSet.decode(binary, "ISO 2022 IR 149")
    end
  end

  describe "KS X 1001 — character coverage" do
    alias Dicom.CharacterSet.KsX1001

    test "decodes symbols from rows 1-12 (row 0x21)" do
      # Ideographic comma (U+3001) at row 0x21, cell 0x22
      assert {:ok, 0x3001} = KsX1001.decode_pair(0x21, 0x22)
      # Ideographic period (U+3002) at row 0x21, cell 0x23
      assert {:ok, 0x3002} = KsX1001.decode_pair(0x21, 0x23)
      # Middle dot (U+00B7) at row 0x21, cell 0x24
      assert {:ok, 0x00B7} = KsX1001.decode_pair(0x21, 0x24)
    end

    test "decodes Hangul syllables from rows 16-40" do
      # 가 at row 0x30 (row 16 = 0x30), cell 0x21
      assert {:ok, 0xAC00} = KsX1001.decode_pair(0x30, 0x21)
      # Verify it's a Hangul syllable (U+AC00-U+D7A3)
      assert {:ok, cp} = KsX1001.decode_pair(0x30, 0x21)
      assert cp >= 0xAC00 and cp <= 0xD7A3
    end

    test "decodes Hanja from rows 42-93" do
      # Row 42 = 0x4A in KS X 1001 grid
      assert {:ok, cp} = KsX1001.decode_pair(0x4A, 0x21)
      # Hanja are CJK Unified Ideographs (U+4E00-U+9FFF range typically)
      assert cp >= 0x4E00
    end

    test "multiple Hangul syllables decode correctly as binary" do
      # 서울 (Seoul) in EUC-KR: 서=0xBCAD 울=0xBFEF (if mapped)
      # Let's decode 가나다 as a simpler test
      # 나=row 0x30, cell 0x22 -> check
      assert {:ok, na_cp} = KsX1001.decode_pair(0x30, 0x22)
      # 다=row 0x30, cell 0x23 -> check
      assert {:ok, da_cp} = KsX1001.decode_pair(0x30, 0x23)
      assert is_integer(na_cp) and na_cp > 0
      assert is_integer(da_cp) and da_cp > 0
    end
  end
end
