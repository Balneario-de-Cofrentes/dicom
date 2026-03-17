defmodule Dicom.TransferSyntax do
  @moduledoc """
  Transfer Syntax definitions and properties.

  A Transfer Syntax specifies how DICOM data is encoded: byte order,
  whether VR is explicit or implicit, and pixel data compression.

  Reference: DICOM PS3.5 Section 10.
  """

  @type endianness :: :little | :big
  @type vr_encoding :: :implicit | :explicit

  @type t :: %__MODULE__{
          uid: String.t(),
          name: String.t(),
          endianness: endianness(),
          vr_encoding: vr_encoding(),
          compressed: boolean()
        }

  defstruct [:uid, :name, :endianness, :vr_encoding, compressed: false]

  # Registry computed once at compile time — no per-call allocation.
  # Uses raw map form because %__MODULE__{} syntax is unavailable in module attributes.
  @registry [
              {Dicom.UID.implicit_vr_little_endian(), "Implicit VR Little Endian", :little,
               :implicit, false},
              {Dicom.UID.explicit_vr_little_endian(), "Explicit VR Little Endian", :little,
               :explicit, false},
              {Dicom.UID.deflated_explicit_vr_little_endian(),
               "Deflated Explicit VR Little Endian", :little, :explicit, false},
              {Dicom.UID.explicit_vr_big_endian(), "Explicit VR Big Endian (Retired)", :big,
               :explicit, false},
              {Dicom.UID.jpeg_baseline(), "JPEG Baseline (Process 1)", :little, :explicit, true},
              {Dicom.UID.jpeg_lossless(),
               "JPEG Lossless, Non-Hierarchical, First-Order Prediction", :little, :explicit,
               true},
              {Dicom.UID.jpeg_2000_lossless(), "JPEG 2000 Image Compression (Lossless Only)",
               :little, :explicit, true},
              {Dicom.UID.jpeg_2000(), "JPEG 2000 Image Compression", :little, :explicit, true},
              {Dicom.UID.rle_lossless(), "RLE Lossless", :little, :explicit, true}
            ]
            |> Map.new(fn {uid, name, endian, vr_enc, compressed} ->
              {uid,
               %{
                 __struct__: __MODULE__,
                 uid: uid,
                 name: name,
                 endianness: endian,
                 vr_encoding: vr_enc,
                 compressed: compressed
               }}
            end)

  @doc """
  Returns the transfer syntax definition for the given UID.
  """
  @spec from_uid(String.t()) :: {:ok, t()} | {:error, :unknown_transfer_syntax}
  def from_uid(uid) do
    case Map.get(@registry, uid) do
      nil -> {:error, :unknown_transfer_syntax}
      ts -> {:ok, ts}
    end
  end

  @doc """
  Returns true if the transfer syntax uses implicit VR encoding.
  """
  @spec implicit_vr?(String.t()) :: boolean()
  def implicit_vr?(uid), do: uid == Dicom.UID.implicit_vr_little_endian()

  @doc """
  Returns true if the transfer syntax uses compressed pixel data.
  """
  @spec compressed?(String.t()) :: boolean()
  def compressed?(uid) do
    case from_uid(uid) do
      {:ok, %{compressed: compressed}} -> compressed
      _ -> false
    end
  end

  @doc """
  Returns the VR encoding and endianness for a given transfer syntax UID.

  Falls back to Explicit VR Little Endian for unknown UIDs (e.g., compressed
  transfer syntaxes not in the registry still use explicit VR LE for metadata).
  """
  @spec encoding(String.t()) :: {vr_encoding(), endianness()}
  def encoding(uid) do
    case from_uid(uid) do
      {:ok, %{vr_encoding: vr_enc, endianness: endian}} -> {vr_enc, endian}
      _ -> {:explicit, :little}
    end
  end

  @doc """
  Extracts the transfer syntax UID from a file meta elements map.

  Falls back to Implicit VR Little Endian if the tag is absent.
  """
  @spec extract_uid(%{Dicom.Tag.t() => Dicom.DataElement.t()}) :: String.t()
  def extract_uid(file_meta) do
    case Map.get(file_meta, Dicom.Tag.transfer_syntax_uid()) do
      %Dicom.DataElement{value: uid} -> String.trim_trailing(uid, <<0>>)
      nil -> Dicom.UID.implicit_vr_little_endian()
    end
  end
end
