defmodule Dicom.Value do
  @moduledoc """
  DICOM value decoding and encoding.

  Converts between raw binary data element values and native Elixir types
  based on the Value Representation (VR).

  Reference: DICOM PS3.5 Section 6.2.
  """

  @string_vrs Dicom.VR.string_vrs()
  @numeric_vrs Dicom.VR.numeric_vrs()

  @doc """
  Decodes a raw binary value to a native Elixir type based on VR.

  Returns `nil` for empty binaries.
  """
  @spec decode(binary(), Dicom.VR.t()) :: term()
  def decode(binary, vr), do: decode(binary, vr, :little)

  @doc """
  Decodes a raw binary value using the given endianness.
  """
  @spec decode(binary(), Dicom.VR.t(), :little | :big) :: term()
  def decode(<<>>, _vr, _endianness), do: nil

  # Numeric types
  def decode(<<value::little-unsigned-16>>, :US, :little), do: value
  def decode(<<value::big-unsigned-16>>, :US, :big), do: value

  def decode(binary, :US, :little) when rem(byte_size(binary), 2) == 0 do
    for <<v::little-unsigned-16 <- binary>>, do: v
  end

  def decode(binary, :US, :big) when rem(byte_size(binary), 2) == 0 do
    for <<v::big-unsigned-16 <- binary>>, do: v
  end

  def decode(<<value::little-signed-16>>, :SS, :little), do: value
  def decode(<<value::big-signed-16>>, :SS, :big), do: value

  def decode(binary, :SS, :little) when rem(byte_size(binary), 2) == 0 do
    for <<v::little-signed-16 <- binary>>, do: v
  end

  def decode(binary, :SS, :big) when rem(byte_size(binary), 2) == 0 do
    for <<v::big-signed-16 <- binary>>, do: v
  end

  def decode(<<value::little-unsigned-32>>, :UL, :little), do: value
  def decode(<<value::big-unsigned-32>>, :UL, :big), do: value

  def decode(binary, :UL, :little) when rem(byte_size(binary), 4) == 0 do
    for <<v::little-unsigned-32 <- binary>>, do: v
  end

  def decode(binary, :UL, :big) when rem(byte_size(binary), 4) == 0 do
    for <<v::big-unsigned-32 <- binary>>, do: v
  end

  def decode(<<value::little-signed-32>>, :SL, :little), do: value
  def decode(<<value::big-signed-32>>, :SL, :big), do: value

  def decode(binary, :SL, :little) when rem(byte_size(binary), 4) == 0 do
    for <<v::little-signed-32 <- binary>>, do: v
  end

  def decode(binary, :SL, :big) when rem(byte_size(binary), 4) == 0 do
    for <<v::big-signed-32 <- binary>>, do: v
  end

  def decode(<<value::little-float-32>>, :FL, :little), do: value
  def decode(<<value::big-float-32>>, :FL, :big), do: value

  def decode(binary, :FL, :little) when rem(byte_size(binary), 4) == 0 do
    for <<v::little-float-32 <- binary>>, do: v
  end

  def decode(binary, :FL, :big) when rem(byte_size(binary), 4) == 0 do
    for <<v::big-float-32 <- binary>>, do: v
  end

  def decode(<<value::little-float-64>>, :FD, :little), do: value
  def decode(<<value::big-float-64>>, :FD, :big), do: value

  def decode(binary, :FD, :little) when rem(byte_size(binary), 8) == 0 do
    for <<v::little-float-64 <- binary>>, do: v
  end

  def decode(binary, :FD, :big) when rem(byte_size(binary), 8) == 0 do
    for <<v::big-float-64 <- binary>>, do: v
  end

  # 64-bit integer types
  def decode(<<value::little-unsigned-64>>, :UV, :little), do: value
  def decode(<<value::big-unsigned-64>>, :UV, :big), do: value

  def decode(binary, :UV, :little) when rem(byte_size(binary), 8) == 0 do
    for <<v::little-unsigned-64 <- binary>>, do: v
  end

  def decode(binary, :UV, :big) when rem(byte_size(binary), 8) == 0 do
    for <<v::big-unsigned-64 <- binary>>, do: v
  end

  def decode(<<value::little-signed-64>>, :SV, :little), do: value
  def decode(<<value::big-signed-64>>, :SV, :big), do: value

  def decode(binary, :SV, :little) when rem(byte_size(binary), 8) == 0 do
    for <<v::little-signed-64 <- binary>>, do: v
  end

  def decode(binary, :SV, :big) when rem(byte_size(binary), 8) == 0 do
    for <<v::big-signed-64 <- binary>>, do: v
  end

  # Attribute Tag
  def decode(<<group::little-16, element::little-16>>, :AT, :little), do: {group, element}
  def decode(<<group::big-16, element::big-16>>, :AT, :big), do: {group, element}

  def decode(binary, :AT, :little) when rem(byte_size(binary), 4) == 0 do
    for <<group::little-16, element::little-16 <- binary>>, do: {group, element}
  end

  def decode(binary, :AT, :big) when rem(byte_size(binary), 4) == 0 do
    for <<group::big-16, element::big-16 <- binary>>, do: {group, element}
  end

  # UI — trim null padding
  def decode(binary, :UI, _endianness), do: trim_trailing_byte(binary, 0x00)

  # DS — Decimal String
  def decode(binary, :DS, _endianness) do
    binary
    |> String.trim()
    |> decode_multi_value(&parse_float/1)
  end

  # IS — Integer String
  def decode(binary, :IS, _endianness) do
    binary
    |> String.trim()
    |> decode_multi_value(&parse_integer/1)
  end

  # String VRs with multi-value support (CS)
  def decode(binary, :CS, _endianness) do
    binary
    |> String.trim()
    |> decode_multi_value(&Function.identity/1)
  end

  # Other string VRs — just trim
  def decode(binary, vr, _endianness)
      when vr in [:AE, :DA, :DT, :LO, :LT, :PN, :SH, :ST, :TM, :UC, :UR, :UT, :AS] do
    trim_trailing_byte(binary, 0x20)
  end

  # Binary VRs — return as-is
  def decode(binary, _vr, _endianness), do: binary

  @doc """
  Converts a DICOM DA string ("YYYYMMDD") to an Elixir `Date`.

  ## Examples

      iex> Dicom.Value.to_date("20240315")
      {:ok, ~D[2024-03-15]}

      iex> Dicom.Value.to_date("invalid")
      {:error, :invalid_date}
  """
  @spec to_date(String.t()) :: {:ok, Date.t()} | {:error, :invalid_date}
  def to_date(<<y1, y2, y3, y4, m1, m2, d1, d2>>)
      when y1 in ?0..?9 and y2 in ?0..?9 and y3 in ?0..?9 and y4 in ?0..?9 and
             m1 in ?0..?9 and m2 in ?0..?9 and d1 in ?0..?9 and d2 in ?0..?9 do
    case Date.new(
           list_to_int([y1, y2, y3, y4]),
           list_to_int([m1, m2]),
           list_to_int([d1, d2])
         ) do
      {:ok, _date} = ok -> ok
      {:error, _} -> {:error, :invalid_date}
    end
  end

  def to_date(_), do: {:error, :invalid_date}

  @doc """
  Converts a DICOM TM string to an Elixir `Time`.

  Supports full ("HHMMSS.FFFFFF") and partial ("HHMM", "HH") formats.

  ## Examples

      iex> Dicom.Value.to_time("143022")
      {:ok, ~T[14:30:22]}

      iex> Dicom.Value.to_time("1430")
      {:ok, ~T[14:30:00]}
  """
  @spec to_time(String.t()) :: {:ok, Time.t()} | {:error, :invalid_time}
  def to_time(str) when is_binary(str) do
    trimmed = String.trim(str)
    parse_dicom_time(trimmed)
  end

  def to_time(_), do: {:error, :invalid_time}

  @doc """
  Converts a DICOM DT string to `DateTime` (with TZ offset) or `NaiveDateTime` (without).

  ## Examples

      iex> Dicom.Value.to_datetime("20240315143022")
      {:ok, ~N[2024-03-15 14:30:22]}
  """
  @spec to_datetime(String.t()) ::
          {:ok, DateTime.t() | NaiveDateTime.t()} | {:error, :invalid_datetime}
  def to_datetime(str) when is_binary(str) do
    trimmed = String.trim(str)
    parse_dicom_datetime(trimmed)
  end

  def to_datetime(_), do: {:error, :invalid_datetime}

  @doc """
  Converts an Elixir `Date` to a DICOM DA string ("YYYYMMDD").

  ## Examples

      iex> Dicom.Value.from_date(~D[2024-03-15])
      "20240315"
  """
  @spec from_date(Date.t()) :: String.t()
  def from_date(%Date{year: y, month: m, day: d}) do
    pad4(y) <> pad2(m) <> pad2(d)
  end

  @doc """
  Converts an Elixir `Time` to a DICOM TM string.

  Includes fractional seconds if microsecond precision > 0.

  ## Examples

      iex> Dicom.Value.from_time(~T[14:30:22])
      "143022"
  """
  @spec from_time(Time.t()) :: String.t()
  def from_time(%Time{hour: h, minute: m, second: s, microsecond: {us, precision}}) do
    base = pad2(h) <> pad2(m) <> pad2(s)

    if precision > 0 and us > 0 do
      frac = us |> Integer.to_string() |> String.pad_leading(6, "0") |> String.slice(0, precision)
      base <> "." <> frac
    else
      base
    end
  end

  @doc """
  Converts a `DateTime` or `NaiveDateTime` to a DICOM DT string.

  ## Examples

      iex> Dicom.Value.from_datetime(~N[2024-03-15 14:30:22])
      "20240315143022"
  """
  @spec from_datetime(DateTime.t() | NaiveDateTime.t()) :: String.t()
  def from_datetime(%NaiveDateTime{} = ndt) do
    from_date(NaiveDateTime.to_date(ndt)) <> from_time(NaiveDateTime.to_time(ndt))
  end

  def from_datetime(%DateTime{} = dt) do
    base = from_date(DateTime.to_date(dt)) <> from_time(DateTime.to_time(dt))
    offset = format_tz_offset(dt.utc_offset + dt.std_offset)
    base <> offset
  end

  @doc """
  Encodes a native Elixir value to binary for a given VR.
  """
  @spec encode(term(), Dicom.VR.t()) :: binary()
  def encode(value, vr), do: encode(value, vr, :little)

  @doc """
  Encodes a native Elixir value using the given endianness.
  """
  @spec encode(term(), Dicom.VR.t(), :little | :big) :: binary()
  def encode(value, :US, :little) when is_integer(value) and value >= 0 and value <= 0xFFFF,
    do: <<value::little-unsigned-16>>

  def encode(value, :US, :big) when is_integer(value) and value >= 0 and value <= 0xFFFF,
    do: <<value::big-unsigned-16>>

  def encode(value, :SS, :little)
      when is_integer(value) and value >= -0x8000 and value <= 0x7FFF,
      do: <<value::little-signed-16>>

  def encode(value, :SS, :big)
      when is_integer(value) and value >= -0x8000 and value <= 0x7FFF,
      do: <<value::big-signed-16>>

  def encode(value, :UL, :little) when is_integer(value) and value >= 0 and value <= 0xFFFFFFFF,
    do: <<value::little-unsigned-32>>

  def encode(value, :UL, :big) when is_integer(value) and value >= 0 and value <= 0xFFFFFFFF,
    do: <<value::big-unsigned-32>>

  def encode(value, :SL, :little)
      when is_integer(value) and value >= -0x80000000 and value <= 0x7FFFFFFF,
      do: <<value::little-signed-32>>

  def encode(value, :SL, :big)
      when is_integer(value) and value >= -0x80000000 and value <= 0x7FFFFFFF,
      do: <<value::big-signed-32>>

  def encode(value, :FL, :little) when is_number(value), do: <<value::little-float-32>>
  def encode(value, :FL, :big) when is_number(value), do: <<value::big-float-32>>
  def encode(value, :FD, :little) when is_number(value), do: <<value::little-float-64>>
  def encode(value, :FD, :big) when is_number(value), do: <<value::big-float-64>>

  def encode(value, :UV, :little)
      when is_integer(value) and value >= 0 and value <= 0xFFFFFFFFFFFFFFFF,
      do: <<value::little-unsigned-64>>

  def encode(value, :UV, :big)
      when is_integer(value) and value >= 0 and value <= 0xFFFFFFFFFFFFFFFF,
      do: <<value::big-unsigned-64>>

  def encode(value, :SV, :little)
      when is_integer(value) and value >= -0x8000000000000000 and value <= 0x7FFFFFFFFFFFFFFF,
      do: <<value::little-signed-64>>

  def encode(value, :SV, :big)
      when is_integer(value) and value >= -0x8000000000000000 and value <= 0x7FFFFFFFFFFFFFFF,
      do: <<value::big-signed-64>>

  def encode({group, element}, :AT, :little)
      when group >= 0 and group <= 0xFFFF and element >= 0 and element <= 0xFFFF,
      do: <<group::little-16, element::little-16>>

  def encode({group, element}, :AT, :big)
      when group >= 0 and group <= 0xFFFF and element >= 0 and element <= 0xFFFF,
      do: <<group::big-16, element::big-16>>

  def encode(value, _vr, _endianness) when is_binary(value), do: value
  def encode(value, vr, _endianness) when vr in @string_vrs, do: to_string(value)

  def encode(_value, vr, _endianness) when vr in @numeric_vrs or vr == :AT do
    raise ArgumentError, "unsupported value for VR #{vr}"
  end

  def encode(_value, vr, _endianness) do
    raise ArgumentError, "unsupported value for VR #{vr}"
  end

  # Private helpers

  defp decode_multi_value(str, parser) do
    case String.split(str, "\\") do
      [single] -> parser.(single)
      multiple -> Enum.map(multiple, &parser.(String.trim(&1)))
    end
  end

  defp parse_float(str) do
    case Float.parse(str) do
      {f, ""} -> f
      :error -> str
      _ -> str
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {i, ""} -> i
      :error -> str
      _ -> str
    end
  end

  defp trim_trailing_byte(binary, byte), do: trim_trailing_byte(binary, byte, byte_size(binary))

  defp trim_trailing_byte(_binary, _byte, 0), do: <<>>

  defp trim_trailing_byte(binary, byte, size) do
    if :binary.last(binary) == byte do
      trim_trailing_byte(binary_part(binary, 0, size - 1), byte, size - 1)
    else
      binary
    end
  end

  # Date/time helpers

  defp list_to_int(chars), do: chars |> to_string() |> String.to_integer()

  defp pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
  defp pad4(n), do: n |> Integer.to_string() |> String.pad_leading(4, "0")

  defp parse_dicom_time(<<h1, h2, m1, m2, s1, s2, ".", frac::binary>>)
       when h1 in ?0..?9 and h2 in ?0..?9 and m1 in ?0..?9 and m2 in ?0..?9 and
              s1 in ?0..?9 and s2 in ?0..?9 do
    h = list_to_int([h1, h2])
    m = list_to_int([m1, m2])
    s = list_to_int([s1, s2])
    {us, precision} = parse_fractional_seconds(frac)

    case Time.new(h, m, s, {us, precision}) do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, :invalid_time}
    end
  end

  defp parse_dicom_time(<<h1, h2, m1, m2, s1, s2>>)
       when h1 in ?0..?9 and h2 in ?0..?9 and m1 in ?0..?9 and m2 in ?0..?9 and
              s1 in ?0..?9 and s2 in ?0..?9 do
    case Time.new(list_to_int([h1, h2]), list_to_int([m1, m2]), list_to_int([s1, s2])) do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, :invalid_time}
    end
  end

  defp parse_dicom_time(<<h1, h2, m1, m2>>)
       when h1 in ?0..?9 and h2 in ?0..?9 and m1 in ?0..?9 and m2 in ?0..?9 do
    case Time.new(list_to_int([h1, h2]), list_to_int([m1, m2]), 0) do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, :invalid_time}
    end
  end

  defp parse_dicom_time(<<h1, h2>>) when h1 in ?0..?9 and h2 in ?0..?9 do
    case Time.new(list_to_int([h1, h2]), 0, 0) do
      {:ok, _} = ok -> ok
      {:error, _} -> {:error, :invalid_time}
    end
  end

  defp parse_dicom_time(_), do: {:error, :invalid_time}

  defp parse_fractional_seconds(frac) do
    padded = String.pad_trailing(frac, 6, "0") |> String.slice(0, 6)
    precision = min(byte_size(frac), 6)
    {String.to_integer(padded), precision}
  end

  defp parse_dicom_datetime(str) when byte_size(str) >= 8 do
    {date_part, rest} = String.split_at(str, 8)

    with {:ok, date} <- to_date(date_part) do
      parse_dt_time_and_offset(date, rest)
    else
      _ -> {:error, :invalid_datetime}
    end
  end

  defp parse_dicom_datetime(_), do: {:error, :invalid_datetime}

  defp parse_dt_time_and_offset(date, "") do
    {:ok, NaiveDateTime.new!(date, ~T[00:00:00])}
  end

  defp parse_dt_time_and_offset(date, time_str) do
    {time_part, offset_part} = split_tz_offset(time_str)

    with {:ok, time} <- parse_dicom_time(time_part) do
      if offset_part == "" do
        {:ok, NaiveDateTime.new!(date, time)}
      else
        build_datetime_with_offset(date, time, offset_part)
      end
    else
      _ -> {:error, :invalid_datetime}
    end
  end

  defp split_tz_offset(str) do
    case Regex.run(~r/^(.*?)([+-]\d{4})$/, str) do
      [_, time, offset] -> {time, offset}
      nil -> {str, ""}
    end
  end

  defp build_datetime_with_offset(date, time, <<sign, h1, h2, m1, m2>>)
       when sign in [?+, ?-] do
    hours = list_to_int([h1, h2])
    minutes = list_to_int([m1, m2])
    total_seconds = hours * 3600 + minutes * 60
    offset = if sign == ?+, do: total_seconds, else: -total_seconds

    ndt = NaiveDateTime.new!(date, time)
    utc_ndt = NaiveDateTime.add(ndt, -offset, :second)

    {:ok, utc_dt} = DateTime.from_naive(utc_ndt, "Etc/UTC")

    {:ok,
     DateTime.add(utc_dt, offset, :second)
     |> Map.put(:utc_offset, offset)
     |> Map.put(:std_offset, 0)}
  end

  defp build_datetime_with_offset(_, _, _), do: {:error, :invalid_datetime}

  defp format_tz_offset(total_seconds) do
    sign = if total_seconds >= 0, do: "+", else: "-"
    abs_seconds = abs(total_seconds)
    hours = div(abs_seconds, 3600)
    minutes = rem(abs_seconds, 3600) |> div(60)
    sign <> pad2(hours) <> pad2(minutes)
  end
end
