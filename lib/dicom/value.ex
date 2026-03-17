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
  def decode(<<>>, _vr), do: nil

  # Numeric types
  def decode(<<value::little-unsigned-16>>, :US), do: value

  def decode(binary, :US) when rem(byte_size(binary), 2) == 0 do
    for <<v::little-unsigned-16 <- binary>>, do: v
  end

  def decode(<<value::little-signed-16>>, :SS), do: value

  def decode(binary, :SS) when rem(byte_size(binary), 2) == 0 do
    for <<v::little-signed-16 <- binary>>, do: v
  end

  def decode(<<value::little-unsigned-32>>, :UL), do: value

  def decode(binary, :UL) when rem(byte_size(binary), 4) == 0 do
    for <<v::little-unsigned-32 <- binary>>, do: v
  end

  def decode(<<value::little-signed-32>>, :SL), do: value

  def decode(binary, :SL) when rem(byte_size(binary), 4) == 0 do
    for <<v::little-signed-32 <- binary>>, do: v
  end

  def decode(<<value::little-float-32>>, :FL), do: value

  def decode(binary, :FL) when rem(byte_size(binary), 4) == 0 do
    for <<v::little-float-32 <- binary>>, do: v
  end

  def decode(<<value::little-float-64>>, :FD), do: value

  def decode(binary, :FD) when rem(byte_size(binary), 8) == 0 do
    for <<v::little-float-64 <- binary>>, do: v
  end

  # Attribute Tag
  def decode(<<group::little-16, element::little-16>>, :AT), do: {group, element}

  # UI — trim null padding
  def decode(binary, :UI), do: String.trim_trailing(binary, <<0>>)

  # DS — Decimal String
  def decode(binary, :DS) do
    binary
    |> String.trim()
    |> decode_multi_value(&parse_float/1)
  end

  # IS — Integer String
  def decode(binary, :IS) do
    binary
    |> String.trim()
    |> decode_multi_value(&parse_integer/1)
  end

  # String VRs with multi-value support (CS)
  def decode(binary, :CS) do
    binary
    |> String.trim()
    |> decode_multi_value(&Function.identity/1)
  end

  # Other string VRs — just trim
  def decode(binary, vr)
      when vr in [:AE, :DA, :DT, :LO, :LT, :PN, :SH, :ST, :TM, :UC, :UR, :UT, :AS] do
    String.trim(binary)
  end

  # Binary VRs — return as-is
  def decode(binary, _vr), do: binary

  @doc """
  Encodes a native Elixir value to binary for a given VR.
  """
  @spec encode(term(), Dicom.VR.t()) :: binary()
  def encode(value, :US) when is_integer(value), do: <<value::little-unsigned-16>>
  def encode(value, :SS) when is_integer(value), do: <<value::little-signed-16>>
  def encode(value, :UL) when is_integer(value), do: <<value::little-unsigned-32>>
  def encode(value, :SL) when is_integer(value), do: <<value::little-signed-32>>
  def encode(value, :FL) when is_number(value), do: <<value::little-float-32>>
  def encode(value, :FD) when is_number(value), do: <<value::little-float-64>>

  def encode({group, element}, :AT) do
    <<group::little-16, element::little-16>>
  end

  def encode(value, _vr) when is_binary(value), do: value
  def encode(value, _vr), do: to_string(value)

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
end
