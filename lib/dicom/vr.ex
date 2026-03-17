defmodule Dicom.VR do
  @moduledoc """
  DICOM Value Representations (VR).

  Defines the data types used in DICOM attributes: Person Name (PN),
  Date (DA), Unique Identifier (UI), Other Byte (OB), etc.

  Reference: DICOM PS3.5 Section 6.2.
  """

  @type t ::
          :AE
          | :AS
          | :AT
          | :CS
          | :DA
          | :DS
          | :DT
          | :FL
          | :FD
          | :IS
          | :LO
          | :LT
          | :OB
          | :OD
          | :OF
          | :OL
          | :OV
          | :OW
          | :PN
          | :SH
          | :SL
          | :SQ
          | :SS
          | :ST
          | :SV
          | :TM
          | :UC
          | :UI
          | :UL
          | :UN
          | :UR
          | :US
          | :UT
          | :UV

  @string_vrs [
    :AE,
    :AS,
    :CS,
    :DA,
    :DS,
    :DT,
    :IS,
    :LO,
    :LT,
    :PN,
    :SH,
    :ST,
    :TM,
    :UC,
    :UI,
    :UR,
    :UT
  ]
  @binary_vrs [:OB, :OD, :OF, :OL, :OV, :OW, :UN]
  @numeric_vrs [:FL, :FD, :SL, :SS, :SV, :UL, :US, :UV]

  @doc """
  Returns true if the VR uses explicit length encoding with a 4-byte length field
  (the "long" VRs that use 2 reserved bytes + 4-byte length in Explicit VR).
  """
  @spec long_length?(t()) :: boolean()
  def long_length?(vr)
      when vr in [:OB, :OD, :OF, :OL, :OV, :OW, :SQ, :SV, :UC, :UN, :UR, :UT, :UV],
      do: true

  def long_length?(_vr), do: false

  @doc """
  Returns true if the VR represents a string type.
  """
  @spec string?(t()) :: boolean()
  def string?(vr) when vr in @string_vrs, do: true
  def string?(_), do: false

  @doc """
  Returns true if the VR represents binary/pixel data.
  """
  @spec binary?(t()) :: boolean()
  def binary?(vr) when vr in @binary_vrs, do: true
  def binary?(_), do: false

  @doc """
  Returns true if the VR represents a numeric type.
  """
  @spec numeric?(t()) :: boolean()
  def numeric?(vr) when vr in @numeric_vrs, do: true
  def numeric?(_), do: false

  @doc """
  Parses a 2-byte VR string into an atom.

  ## Examples

      iex> Dicom.VR.from_binary("PN")
      {:ok, :PN}

      iex> Dicom.VR.from_binary("XX")
      {:error, :unknown_vr}
  """
  @spec from_binary(binary()) :: {:ok, t()} | {:error, :unknown_vr}
  def from_binary(<<"AE">>), do: {:ok, :AE}
  def from_binary(<<"AS">>), do: {:ok, :AS}
  def from_binary(<<"AT">>), do: {:ok, :AT}
  def from_binary(<<"CS">>), do: {:ok, :CS}
  def from_binary(<<"DA">>), do: {:ok, :DA}
  def from_binary(<<"DS">>), do: {:ok, :DS}
  def from_binary(<<"DT">>), do: {:ok, :DT}
  def from_binary(<<"FL">>), do: {:ok, :FL}
  def from_binary(<<"FD">>), do: {:ok, :FD}
  def from_binary(<<"IS">>), do: {:ok, :IS}
  def from_binary(<<"LO">>), do: {:ok, :LO}
  def from_binary(<<"LT">>), do: {:ok, :LT}
  def from_binary(<<"OB">>), do: {:ok, :OB}
  def from_binary(<<"OD">>), do: {:ok, :OD}
  def from_binary(<<"OF">>), do: {:ok, :OF}
  def from_binary(<<"OL">>), do: {:ok, :OL}
  def from_binary(<<"OV">>), do: {:ok, :OV}
  def from_binary(<<"OW">>), do: {:ok, :OW}
  def from_binary(<<"PN">>), do: {:ok, :PN}
  def from_binary(<<"SH">>), do: {:ok, :SH}
  def from_binary(<<"SL">>), do: {:ok, :SL}
  def from_binary(<<"SQ">>), do: {:ok, :SQ}
  def from_binary(<<"SS">>), do: {:ok, :SS}
  def from_binary(<<"ST">>), do: {:ok, :ST}
  def from_binary(<<"SV">>), do: {:ok, :SV}
  def from_binary(<<"TM">>), do: {:ok, :TM}
  def from_binary(<<"UC">>), do: {:ok, :UC}
  def from_binary(<<"UI">>), do: {:ok, :UI}
  def from_binary(<<"UL">>), do: {:ok, :UL}
  def from_binary(<<"UN">>), do: {:ok, :UN}
  def from_binary(<<"UR">>), do: {:ok, :UR}
  def from_binary(<<"US">>), do: {:ok, :US}
  def from_binary(<<"UT">>), do: {:ok, :UT}
  def from_binary(<<"UV">>), do: {:ok, :UV}
  def from_binary(_), do: {:error, :unknown_vr}

  @doc """
  Converts a VR atom to its 2-byte binary representation.
  """
  @spec to_binary(t()) :: binary()
  def to_binary(vr) when is_atom(vr), do: Atom.to_string(vr)

  @doc """
  Returns the padding byte for this VR.

  Per PS3.5 Section 6.2: UI values are padded with NULL (0x00),
  other string VRs are padded with SPACE (0x20), and binary VRs
  are padded with 0x00.
  """
  @spec padding_byte(t()) :: byte()
  def padding_byte(:UI), do: 0x00
  def padding_byte(vr) when vr in @string_vrs, do: 0x20
  def padding_byte(_), do: 0x00

  @doc """
  Pads a binary value to even length per DICOM requirements.

  All DICOM value fields must have even length. If the value has
  odd length, a single padding byte is appended based on the VR.
  """
  @spec pad_value(binary(), t()) :: binary()
  def pad_value(value, _vr) when is_binary(value) and rem(byte_size(value), 2) == 0, do: value
  def pad_value(value, vr) when is_binary(value), do: value <> <<padding_byte(vr)>>
end
