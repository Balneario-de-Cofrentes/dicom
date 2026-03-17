defmodule Dicom.Value do
  @moduledoc """
  DICOM value decoding and encoding.

  Converts between raw binary data element values and native Elixir types
  based on the Value Representation (VR).

  Reference: DICOM PS3.5 Section 6.2.
  """

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
  Encodes a native Elixir value to binary for a given VR.
  """
  @spec encode(term(), Dicom.VR.t()) :: binary()
  def encode(value, vr), do: encode(value, vr, :little)

  @doc """
  Encodes a native Elixir value using the given endianness.
  """
  @spec encode(term(), Dicom.VR.t(), :little | :big) :: binary()
  def encode(value, :US, :little) when is_integer(value), do: <<value::little-unsigned-16>>
  def encode(value, :US, :big) when is_integer(value), do: <<value::big-unsigned-16>>
  def encode(value, :SS, :little) when is_integer(value), do: <<value::little-signed-16>>
  def encode(value, :SS, :big) when is_integer(value), do: <<value::big-signed-16>>
  def encode(value, :UL, :little) when is_integer(value), do: <<value::little-unsigned-32>>
  def encode(value, :UL, :big) when is_integer(value), do: <<value::big-unsigned-32>>
  def encode(value, :SL, :little) when is_integer(value), do: <<value::little-signed-32>>
  def encode(value, :SL, :big) when is_integer(value), do: <<value::big-signed-32>>
  def encode(value, :FL, :little) when is_number(value), do: <<value::little-float-32>>
  def encode(value, :FL, :big) when is_number(value), do: <<value::big-float-32>>
  def encode(value, :FD, :little) when is_number(value), do: <<value::little-float-64>>
  def encode(value, :FD, :big) when is_number(value), do: <<value::big-float-64>>
  def encode(value, :UV, :little) when is_integer(value), do: <<value::little-unsigned-64>>
  def encode(value, :UV, :big) when is_integer(value), do: <<value::big-unsigned-64>>
  def encode(value, :SV, :little) when is_integer(value), do: <<value::little-signed-64>>
  def encode(value, :SV, :big) when is_integer(value), do: <<value::big-signed-64>>
  def encode({group, element}, :AT, :little), do: <<group::little-16, element::little-16>>
  def encode({group, element}, :AT, :big), do: <<group::big-16, element::big-16>>
  def encode(value, _vr, _endianness) when is_binary(value), do: value
  def encode(value, _vr, _endianness), do: to_string(value)

  # Private helpers

  defp decode_multi_value(str, parser) do
    case String.split(str, "\\") do
      [single] -> parser.(single)
      multiple -> Enum.map(multiple, &parser.(String.trim(&1)))
    end
  end

  defp parse_float(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error -> str
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {i, _} -> i
      :error -> str
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
end
