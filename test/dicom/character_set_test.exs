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

    test "decodes ASCII text with ISO 2022 IR 6" do
      assert {:ok, "TEST"} = CharacterSet.decode("TEST", "ISO 2022 IR 6")
    end
  end

  describe "decode/2 — ISO_IR 100 (Latin-1)" do
    test "decodes Latin-1 characters" do
      # ÄÖÜ in Latin-1
      assert {:ok, "ÄÖÜ"} = CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 100")
    end

    test "decodes umlauts in patient name" do
      # MÜLLER^HANS in Latin-1
      binary = <<0x4D, 0xDC, 0x4C, 0x4C, 0x45, 0x52, 0x5E, 0x48, 0x41, 0x4E, 0x53>>
      assert {:ok, "MÜLLER^HANS"} = CharacterSet.decode(binary, "ISO_IR 100")
    end

    test "decodes ISO 2022 IR 100 (code extension variant)" do
      assert {:ok, "ÄÖÜ"} = CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, "ISO 2022 IR 100")
    end

    test "handles accented characters" do
      # àéîõü in Latin-1
      binary = <<0xE0, 0xE9, 0xEE, 0xF5, 0xFC>>
      assert {:ok, "àéîõü"} = CharacterSet.decode(binary, "ISO_IR 100")
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
    test "returns error for unsupported charset" do
      assert {:error, {:unsupported_charset, "ISO_IR 13"}} =
               CharacterSet.decode("test", "ISO_IR 13")
    end

    test "returns error for JIS charset" do
      assert {:error, {:unsupported_charset, "ISO 2022 IR 87"}} =
               CharacterSet.decode("test", "ISO 2022 IR 87")
    end

    test "returns error for Korean charset" do
      assert {:error, {:unsupported_charset, "ISO 2022 IR 149"}} =
               CharacterSet.decode("test", "ISO 2022 IR 149")
    end
  end

  describe "decode_lossy/2" do
    test "returns decoded string for supported charset" do
      assert "ÄÖÜ" = CharacterSet.decode_lossy(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 100")
    end

    test "returns raw binary for unsupported charset" do
      binary = <<0xAB, 0xCD>>
      assert ^binary = CharacterSet.decode_lossy(binary, "ISO_IR 13")
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

    test "JIS/Korean/GB charsets are not supported" do
      refute CharacterSet.supported?("ISO_IR 13")
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
  end

  describe "textual VR padding/whitespace behavior" do
    test "PN with Latin-1 charset: padding preserved until Value.decode trims" do
      # "MÜLLER " (with trailing space padding) in Latin-1
      binary = <<0x4D, 0xDC, 0x4C, 0x4C, 0x45, 0x52, 0x20>>
      {:ok, decoded} = CharacterSet.decode(binary, "ISO_IR 100")
      # CharacterSet decodes bytes, padding is trimmed by Value.decode
      assert decoded == "MÜLLER "
    end

    test "LO with default charset preserves content" do
      assert {:ok, "Some Description "} =
               CharacterSet.decode("Some Description ", nil)
    end
  end
end
