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

  The labels `ISO 2022 IR 6` and `ISO 2022 IR 100` are accepted only when the
  value contains no ISO 2022 escape sequences. Actual code-extension switching
  is not implemented.

  All other character sets return `{:error, {:unsupported_charset, term}}`.
  """

  @type charset :: String.t()

  # Maps DICOM Specific Character Set values to Erlang encoding atoms
  @charset_map %{
    # Default repertoire (ISO IR 6 = ASCII subset of UTF-8)
    "" => :ascii,
    "ISO_IR 6" => :ascii,
    "ISO 2022 IR 6" => {:iso2022_single, :ascii},
    # Latin-1 (Western European)
    "ISO_IR 100" => :latin1,
    "ISO 2022 IR 100" => {:iso2022_single, :latin1},
    # Latin-2 (Central European)
    "ISO_IR 101" => {:iso8859, 2},
    # Latin-3 (South European)
    "ISO_IR 109" => {:iso8859, 3},
    # Latin-4 (North European)
    "ISO_IR 110" => {:iso8859, 4},
    # Cyrillic
    "ISO_IR 144" => {:iso8859, 5},
    # Arabic
    "ISO_IR 127" => {:iso8859, 6},
    # Greek
    "ISO_IR 126" => {:iso8859, 7},
    # Hebrew
    "ISO_IR 138" => {:iso8859, 8},
    # Latin-5 (Turkish)
    "ISO_IR 148" => {:iso8859, 9},
    # JIS X 0201 (Roman + half-width Katakana)
    "ISO_IR 13" => :jis_x0201,
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

      {:iso2022_single, encoding} ->
        decode_iso2022_single(binary, charset_key, encoding)

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

  For `ISO 2022 IR 6` and `ISO 2022 IR 100`, this means only the non-switching
  single-byte subset is accepted. Values containing ISO 2022 escape sequences
  still return an error from `decode/2`.
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

  alias Dicom.CharacterSet.Tables

  defp decode_iso2022_single(binary, charset_key, :ascii) do
    if contains_iso2022_escape?(binary) do
      {:error, {:unsupported_iso2022_escape_sequences, charset_key}}
    else
      decode_ascii(binary)
    end
  end

  defp decode_iso2022_single(binary, charset_key, :latin1) do
    if contains_iso2022_escape?(binary) do
      {:error, {:unsupported_iso2022_escape_sequences, charset_key}}
    else
      {:ok, :unicode.characters_to_binary(binary, :latin1)}
    end
  end

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

  # Shared byte-by-byte decoder: maps each byte through a lookup function
  defp decode_bytewise(binary, lookup_fn, encoding_label) do
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

  defp contains_iso2022_escape?(binary), do: :binary.match(binary, <<0x1B>>) != :nomatch

  defp ascii_binary?(binary), do: Enum.all?(:binary.bin_to_list(binary), &(&1 <= 0x7F))

  defp normalize_charset(nil), do: ""
  defp normalize_charset(charset) when is_binary(charset), do: String.trim(charset)
end
