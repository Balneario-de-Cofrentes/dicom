defmodule Dicom.CharacterSet do
  @moduledoc """
  DICOM Specific Character Set handling.

  Supports decoding of text values according to the character set specified
  by tag (0008,0005) SpecificCharacterSet. See DICOM PS3.5 Section 6.1.

  ## Supported Character Sets

  - Default character repertoire (ISO IR 6 / ASCII) — always supported
  - `ISO_IR 100` (Latin-1 / ISO 8859-1)
  - `ISO_IR 101` (Latin-2 / ISO 8859-2)
  - `ISO_IR 109` (Latin-3 / ISO 8859-3)
  - `ISO_IR 110` (Latin-4 / ISO 8859-4)
  - `ISO_IR 144` (Cyrillic / ISO 8859-5)
  - `ISO_IR 127` (Arabic / ISO 8859-6)
  - `ISO_IR 126` (Greek / ISO 8859-7)
  - `ISO_IR 138` (Hebrew / ISO 8859-8)
  - `ISO_IR 148` (Latin-5 / ISO 8859-9)
  - `ISO_IR 13` (JIS X 0201 — Roman + half-width Katakana)
  - `ISO_IR 192` (UTF-8)

  ## ISO 2022 Code Extension Support

  The labels `ISO 2022 IR 6` and `ISO 2022 IR 100` are accepted both with and
  without ISO 2022 escape sequences.

  ISO 2022 escape sequence parsing is supported per DICOM PS3.5 Section 6.1.2.5.
  Multi-valued Specific Character Set declarations (e.g. `"ISO 2022 IR 13\\ISO 2022 IR 87"`)
  use escape sequences to switch between character repertoires within a single
  text value. The following ISO 2022 charsets are recognized:

  - `ISO 2022 IR 6` (ASCII, G0)
  - `ISO 2022 IR 13` (JIS X 0201 — Roman G0 + Katakana G1)
  - `ISO 2022 IR 87` (JIS X 0208 — multi-byte Kanji/Kana)
  - `ISO 2022 IR 100` through `ISO 2022 IR 148` (ISO 8859 variants, G1)
  - `ISO 2022 IR 149` (KS X 1001 — multi-byte, not yet decodable)
  - `ISO 2022 IR 159` (JIS X 0212 — multi-byte, not yet decodable)
  - `ISO 2022 IR 58` (GB2312-80 — multi-byte, not yet decodable)
  - `GB18030` (Chinese national standard — not yet decodable)

  JIS X 0208 (ISO 2022 IR 87) is fully decodable with a 6879-entry lookup
  table from the Unicode consortium's JIS0208.TXT mapping. The remaining
  multi-byte charsets (JIS X 0212, KS X 1001, GB2312) are parsed at the
  escape-sequence level but return `{:error, :not_yet_implemented}` when
  actual decoding of their code points is needed.

  All other character sets return `{:error, {:unsupported_charset, term}}`.
  """

  @type charset :: String.t()

  # Maps DICOM Specific Character Set values to encoding descriptors.
  #
  # Single-value charsets map to atoms or tuples used by decode/2.
  # ISO 2022 charsets map to {:iso2022, descriptor} tuples handled by
  # decode_iso2022/2 and the escape-sequence parser.
  @charset_map %{
    # Default repertoire (ISO IR 6 = ASCII subset of UTF-8)
    "" => :ascii,
    "ISO_IR 6" => :ascii,
    "ISO 2022 IR 6" => {:iso2022, :ascii},
    # Latin-1 (Western European)
    "ISO_IR 100" => :latin1,
    "ISO 2022 IR 100" => {:iso2022, :latin1},
    # Latin-2 (Central European)
    "ISO_IR 101" => {:iso8859, 2},
    "ISO 2022 IR 101" => {:iso2022, {:iso8859, 2}},
    # Latin-3 (South European)
    "ISO_IR 109" => {:iso8859, 3},
    "ISO 2022 IR 109" => {:iso2022, {:iso8859, 3}},
    # Latin-4 (North European)
    "ISO_IR 110" => {:iso8859, 4},
    "ISO 2022 IR 110" => {:iso2022, {:iso8859, 4}},
    # Cyrillic
    "ISO_IR 144" => {:iso8859, 5},
    "ISO 2022 IR 144" => {:iso2022, {:iso8859, 5}},
    # Arabic
    "ISO_IR 127" => {:iso8859, 6},
    "ISO 2022 IR 127" => {:iso2022, {:iso8859, 6}},
    # Greek
    "ISO_IR 126" => {:iso8859, 7},
    "ISO 2022 IR 126" => {:iso2022, {:iso8859, 7}},
    # Hebrew
    "ISO_IR 138" => {:iso8859, 8},
    "ISO 2022 IR 138" => {:iso2022, {:iso8859, 8}},
    # Latin-5 (Turkish)
    "ISO_IR 148" => {:iso8859, 9},
    "ISO 2022 IR 148" => {:iso2022, {:iso8859, 9}},
    # JIS X 0201 (Roman + half-width Katakana)
    "ISO_IR 13" => :jis_x0201,
    "ISO 2022 IR 13" => {:iso2022, :jis_x0201},
    # JIS X 0208 (multi-byte, G0)
    "ISO 2022 IR 87" => {:iso2022, :jis_x0208},
    # JIS X 0212 (multi-byte, G0)
    "ISO 2022 IR 159" => {:iso2022, :jis_x0212},
    # KS X 1001 (Korean, multi-byte, G1)
    "ISO 2022 IR 149" => {:iso2022, :ks_x1001},
    # GB2312-80 (Chinese, multi-byte, G1)
    "ISO 2022 IR 58" => {:iso2022, :gb2312},
    # GB18030 (Chinese national standard)
    "GB18030" => {:iso2022, :gb18030},
    # UTF-8
    "ISO_IR 192" => :utf8
  }

  @doc """
  Decodes a binary value according to the given character set.

  If `charset` is nil or empty, the default character repertoire is assumed
  (ISO IR 6 / ASCII, which is a subset of Latin-1 and UTF-8).

  Returns `{:ok, string}` or `{:error, reason}`.

  ## Examples

      iex> Dicom.CharacterSet.decode("JOHN", nil)
      {:ok, "JOHN"}

      iex> Dicom.CharacterSet.decode(<<0xC4, 0xD6, 0xDC>>, "ISO_IR 100")
      {:ok, "ÄÖÜ"}
  """
  @spec decode(binary(), charset() | nil) :: {:ok, String.t()} | {:error, term()}
  def decode(binary, charset) when is_binary(binary) do
    charset_key = normalize_charset(charset)

    case Map.get(@charset_map, charset_key) do
      nil ->
        {:error, {:unsupported_charset, charset_key}}

      :utf8 ->
        if String.valid?(binary) do
          {:ok, binary}
        else
          {:error, :invalid_utf8}
        end

      :ascii ->
        decode_ascii(binary)

      :latin1 ->
        {:ok, :unicode.characters_to_binary(binary, :latin1)}

      {:iso2022, default_encoding} ->
        decode_iso2022(binary, default_encoding)

      {:iso8859, _n} = encoding ->
        decode_iso8859(binary, encoding)

      :jis_x0201 ->
        decode_jis_x0201(binary)
    end
  end

  @doc """
  Decodes a binary value, returning the original binary on failure instead of an error.

  This is a convenience function for use in the parser where we want to
  attempt charset decoding but fall back to the undecoded bytes rather than
  failing. Successful decodes return a UTF-8 Elixir string; failed decodes
  return the original binary unchanged.
  """
  @spec decode_lossy(binary(), charset() | nil) :: binary()
  def decode_lossy(binary, charset) when is_binary(binary) do
    case decode(binary, charset) do
      {:ok, string} -> string
      {:error, _} -> binary
    end
  end

  @doc """
  Returns true if the given character set label is recognized by the decoder.

  ISO 2022 labels (e.g. `"ISO 2022 IR 87"`) are recognized even when their
  multi-byte lookup tables are not yet implemented. `decode/2` will return
  `{:error, :not_yet_implemented}` for those, but `supported?/1` returns true
  because the charset is known and the escape-sequence infrastructure exists.
  """
  @spec supported?(charset() | nil) :: boolean()
  def supported?(charset) do
    Map.has_key?(@charset_map, normalize_charset(charset))
  end

  @doc """
  Extracts the primary character set from a parsed data set's elements map.

  Returns the first (or only) character set value, or nil if absent.
  Use `extract_all/1` when you need the full Specific Character Set list.
  """
  @spec extract(map()) :: charset() | nil
  def extract(elements) when is_map(elements) do
    case extract_all(elements) do
      [charset | _] -> charset
      [] -> nil
    end
  end

  @doc """
  Extracts all Specific Character Set values from a parsed data set's elements map.
  """
  @spec extract_all(map()) :: [charset()]
  def extract_all(elements) when is_map(elements) do
    case Map.get(elements, {0x0008, 0x0005}) do
      %Dicom.DataElement{value: value} when is_binary(value) ->
        value
        |> String.trim()
        |> String.split("\\", trim: true)
        |> Enum.map(&String.trim/1)

      _ ->
        []
    end
  end

  alias Dicom.CharacterSet.{JisX0208, Tables}

  @doc """
  Decodes a binary containing ISO 2022 escape sequences.

  Takes a binary and a default encoding (from the first value of a
  multi-valued Specific Character Set). Parses ESC sequences per
  DICOM PS3.5 Table C.12-3, splits the text into segments, and decodes
  each segment with the appropriate charset.

  Returns `{:ok, utf8_string}` or `{:error, reason}`.

  ## Examples

      iex> Dicom.CharacterSet.decode_iso2022("HELLO", :ascii)
      {:ok, "HELLO"}

      iex> Dicom.CharacterSet.decode_iso2022(<<0xB1, 0xB6>>, :jis_x0201)
      {:ok, "ｱｶ"}
  """
  @spec decode_iso2022(binary(), atom() | tuple()) :: {:ok, String.t()} | {:error, term()}
  def decode_iso2022(binary, default_encoding) do
    segments = parse_iso2022_segments(binary, default_encoding)
    decode_iso2022_segments(segments, [])
  end

  # --- ISO 2022 escape sequence mapping ---
  # Per DICOM PS3.5 Table C.12-3.
  #
  # ESC sequences designate character sets into G0 or G1.
  # G0: invoked by GL (0x21-0x7E), G1: invoked by GR (0xA1-0xFE).
  #
  # Format: {escape_bytes_after_ESC, encoding_atom}

  # G0 designations (single-byte 94-char sets via ESC 02/08 F)
  @esc_g0_ascii <<0x28, 0x42>>
  @esc_g0_jis_roman <<0x28, 0x4A>>

  # G1 designations (single-byte 96-char sets via ESC 02/13 F)
  @esc_g1_latin1 <<0x2D, 0x41>>
  @esc_g1_latin2 <<0x2D, 0x42>>
  @esc_g1_latin3 <<0x2D, 0x43>>
  @esc_g1_latin4 <<0x2D, 0x44>>
  @esc_g1_cyrillic <<0x2D, 0x4C>>
  @esc_g1_arabic <<0x2D, 0x47>>
  @esc_g1_greek <<0x2D, 0x46>>
  @esc_g1_hebrew <<0x2D, 0x48>>
  @esc_g1_latin5 <<0x2D, 0x4D>>
  @esc_g1_katakana <<0x29, 0x49>>

  # G0 multi-byte designations (ESC 02/04 F or ESC 02/04 02/08 F)
  @esc_g0_jis_x0208 <<0x24, 0x42>>
  @esc_g0_jis_x0212 <<0x24, 0x28, 0x44>>

  # G1 multi-byte designations (ESC 02/04 02/09 F)
  @esc_g1_ks_x1001 <<0x24, 0x29, 0x43>>
  @esc_g1_gb2312 <<0x24, 0x29, 0x41>>

  @multibyte_encodings [:jis_x0212, :ks_x1001, :gb2312, :gb18030]

  # --- ISO 2022 segment decoding ---

  defp decode_iso2022_segments([], acc) do
    {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}
  end

  defp decode_iso2022_segments([{encoding, bytes} | rest], acc) do
    case decode_segment(encoding, bytes) do
      {:ok, decoded} -> decode_iso2022_segments(rest, [decoded | acc])
      {:error, _} = err -> err
    end
  end

  defp decode_segment(_encoding, <<>>), do: {:ok, <<>>}

  defp decode_segment(:ascii, bytes) do
    if ascii_binary?(bytes), do: {:ok, bytes}, else: {:error, {:decode_failed, :ascii}}
  end

  defp decode_segment(:latin1, bytes) do
    {:ok, :unicode.characters_to_binary(bytes, :latin1)}
  end

  defp decode_segment(:jis_x0201, bytes) do
    decode_bytewise(bytes, &Tables.jis_x0201/1, :jis_x0201)
  end

  defp decode_segment({:iso8859, n}, bytes) do
    decode_bytewise(bytes, &iso8859_to_unicode(&1, n), {:iso8859, n})
  end

  defp decode_segment(:jis_x0208, bytes) do
    JisX0208.decode_binary(bytes)
  end

  defp decode_segment(encoding, _bytes) when encoding in @multibyte_encodings do
    {:error, :not_yet_implemented}
  end

  # --- ISO 2022 escape sequence parser ---
  #
  # Splits a binary into [{encoding, bytes}] segments by parsing ESC sequences.
  # Each ESC switches the active encoding for subsequent bytes until the next ESC.

  defp parse_iso2022_segments(binary, default_encoding) do
    do_parse_segments(binary, default_encoding, default_encoding, <<>>, [])
  end

  # End of input: flush current segment
  defp do_parse_segments(<<>>, _default, current, buf, acc) do
    [{current, buf} | acc] |> Enum.reverse()
  end

  # ESC detected: try to match a known escape sequence
  defp do_parse_segments(<<0x1B, rest::binary>>, default, current, buf, acc) do
    case match_escape(rest) do
      {encoding, remaining} ->
        # Flush current segment, switch encoding
        new_acc = if buf == <<>>, do: acc, else: [{current, buf} | acc]
        do_parse_segments(remaining, default, encoding, <<>>, new_acc)

      :nomatch ->
        # Unknown ESC sequence — include ESC byte in current segment
        do_parse_segments(rest, default, current, <<buf::binary, 0x1B>>, acc)
    end
  end

  # Regular byte: accumulate in current segment
  defp do_parse_segments(<<byte, rest::binary>>, default, current, buf, acc) do
    do_parse_segments(rest, default, current, <<buf::binary, byte>>, acc)
  end

  # Match known escape sequences (longest first for 4-byte sequences)
  # 4-byte ESC sequences (after ESC): ESC $ ( D and ESC $ ) C and ESC $ ) A
  defp match_escape(<<@esc_g0_jis_x0212, rest::binary>>), do: {:jis_x0212, rest}
  defp match_escape(<<@esc_g1_ks_x1001, rest::binary>>), do: {:ks_x1001, rest}
  defp match_escape(<<@esc_g1_gb2312, rest::binary>>), do: {:gb2312, rest}

  # 2-byte ESC sequences (after ESC): G0 single-byte
  defp match_escape(<<@esc_g0_ascii, rest::binary>>), do: {:ascii, rest}
  defp match_escape(<<@esc_g0_jis_roman, rest::binary>>), do: {:jis_x0201, rest}

  # 2-byte ESC sequences (after ESC): G0 multi-byte
  defp match_escape(<<@esc_g0_jis_x0208, rest::binary>>), do: {:jis_x0208, rest}

  # 2-byte ESC sequences (after ESC): G1 single-byte
  defp match_escape(<<@esc_g1_latin1, rest::binary>>), do: {:latin1, rest}
  defp match_escape(<<@esc_g1_latin2, rest::binary>>), do: {{:iso8859, 2}, rest}
  defp match_escape(<<@esc_g1_latin3, rest::binary>>), do: {{:iso8859, 3}, rest}
  defp match_escape(<<@esc_g1_latin4, rest::binary>>), do: {{:iso8859, 4}, rest}
  defp match_escape(<<@esc_g1_cyrillic, rest::binary>>), do: {{:iso8859, 5}, rest}
  defp match_escape(<<@esc_g1_arabic, rest::binary>>), do: {{:iso8859, 6}, rest}
  defp match_escape(<<@esc_g1_greek, rest::binary>>), do: {{:iso8859, 7}, rest}
  defp match_escape(<<@esc_g1_hebrew, rest::binary>>), do: {{:iso8859, 8}, rest}
  defp match_escape(<<@esc_g1_latin5, rest::binary>>), do: {{:iso8859, 9}, rest}
  defp match_escape(<<@esc_g1_katakana, rest::binary>>), do: {:jis_x0201, rest}

  # Unknown escape sequence
  defp match_escape(_), do: :nomatch

  defp decode_ascii(binary) do
    if ascii_binary?(binary) do
      {:ok, binary}
    else
      {:error, {:decode_failed, :ascii}}
    end
  end

  defp decode_iso8859(binary, {:iso8859, n}) do
    decode_bytewise(binary, &iso8859_to_unicode(&1, n), {:iso8859, n})
  end

  defp decode_jis_x0201(binary) do
    decode_bytewise(binary, &Tables.jis_x0201/1, :jis_x0201)
  end

  # Exposed for testing the rescue branch (lookup functions that raise)
  @doc false
  def decode_bytewise(binary, lookup_fn, encoding_label) do
    try do
      result = for <<byte <- binary>>, into: <<>>, do: <<lookup_fn.(byte)::utf8>>
      {:ok, result}
    rescue
      _ -> {:error, {:decode_failed, encoding_label}}
    end
  end

  # Characters 0x00-0x7F are the same across all ISO 8859 variants
  defp iso8859_to_unicode(byte, _n) when byte <= 0x7F, do: byte
  # Characters 0x80-0x9F are control characters (same across variants)
  defp iso8859_to_unicode(byte, _n) when byte <= 0x9F, do: byte
  # For ISO 8859-{2..9}, use full lookup tables
  defp iso8859_to_unicode(byte, n), do: Tables.lookup(byte, n)

  defp ascii_binary?(binary), do: Enum.all?(:binary.bin_to_list(binary), &(&1 <= 0x7F))

  defp normalize_charset(nil), do: ""
  defp normalize_charset(charset) when is_binary(charset), do: String.trim(charset)
end
