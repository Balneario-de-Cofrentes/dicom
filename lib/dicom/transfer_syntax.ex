defmodule Dicom.TransferSyntax do
  @moduledoc """
  Transfer Syntax definitions and properties.

  A Transfer Syntax specifies how DICOM data is encoded: byte order,
  whether VR is explicit or implicit, and pixel data compression.

  All known DICOM transfer syntaxes are registered. Unknown transfer
  syntaxes are rejected by default — use `encoding/2` with
  `lenient: true` to fall back to Explicit VR Little Endian for
  unrecognized compressed transfer syntaxes.

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
  # All standard DICOM transfer syntaxes including compressed variants.
  @registry [
              # Uncompressed
              {Dicom.UID.implicit_vr_little_endian(), "Implicit VR Little Endian", :little,
               :implicit, false},
              {Dicom.UID.explicit_vr_little_endian(), "Explicit VR Little Endian", :little,
               :explicit, false},
              {Dicom.UID.deflated_explicit_vr_little_endian(),
               "Deflated Explicit VR Little Endian", :little, :explicit, false},
              {Dicom.UID.explicit_vr_big_endian(), "Explicit VR Big Endian (Retired)", :big,
               :explicit, false},
              # JPEG
              {Dicom.UID.jpeg_baseline(), "JPEG Baseline (Process 1)", :little, :explicit, true},
              {"1.2.840.10008.1.2.4.51", "JPEG Extended (Process 2 & 4)", :little, :explicit,
               true},
              {"1.2.840.10008.1.2.4.57", "JPEG Lossless, Non-Hierarchical (Process 14)", :little,
               :explicit, true},
              {Dicom.UID.jpeg_lossless(),
               "JPEG Lossless, Non-Hierarchical, First-Order Prediction", :little, :explicit,
               true},
              # JPEG-LS
              {"1.2.840.10008.1.2.4.80", "JPEG-LS Lossless Image Compression", :little, :explicit,
               true},
              {"1.2.840.10008.1.2.4.81", "JPEG-LS Lossy (Near-Lossless) Image Compression",
               :little, :explicit, true},
              # JPEG 2000
              {Dicom.UID.jpeg_2000_lossless(), "JPEG 2000 Image Compression (Lossless Only)",
               :little, :explicit, true},
              {Dicom.UID.jpeg_2000(), "JPEG 2000 Image Compression", :little, :explicit, true},
              {"1.2.840.10008.1.2.4.92", "JPEG 2000 Part 2 Multi-component (Lossless)", :little,
               :explicit, true},
              {"1.2.840.10008.1.2.4.93", "JPEG 2000 Part 2 Multi-component", :little, :explicit,
               true},
              # MPEG / HEVC
              {"1.2.840.10008.1.2.4.100", "MPEG2 Main Profile / Main Level", :little, :explicit,
               true},
              {"1.2.840.10008.1.2.4.101", "MPEG2 Main Profile / High Level", :little, :explicit,
               true},
              {"1.2.840.10008.1.2.4.102", "MPEG-4 AVC/H.264 High Profile / Level 4.1", :little,
               :explicit, true},
              {"1.2.840.10008.1.2.4.103",
               "MPEG-4 AVC/H.264 BD-compatible High Profile / Level 4.1", :little, :explicit,
               true},
              {"1.2.840.10008.1.2.4.104",
               "MPEG-4 AVC/H.264 High Profile / Level 4.2 For 2D Video", :little, :explicit,
               true},
              {"1.2.840.10008.1.2.4.105",
               "MPEG-4 AVC/H.264 High Profile / Level 4.2 For 3D Video", :little, :explicit,
               true},
              {"1.2.840.10008.1.2.4.106", "MPEG-4 AVC/H.264 Stereo High Profile / Level 4.2",
               :little, :explicit, true},
              {"1.2.840.10008.1.2.4.107", "HEVC/H.265 Main Profile / Level 5.1", :little,
               :explicit, true},
              {"1.2.840.10008.1.2.4.108", "HEVC/H.265 Main 10 Profile / Level 5.1", :little,
               :explicit, true},
              # HTJ2K
              {"1.2.840.10008.1.2.4.201", "High-Throughput JPEG 2000 (Lossless Only)", :little,
               :explicit, true},
              {"1.2.840.10008.1.2.4.202", "High-Throughput JPEG 2000 with RPCL (Lossless Only)",
               :little, :explicit, true},
              {"1.2.840.10008.1.2.4.203", "High-Throughput JPEG 2000", :little, :explicit, true},
              # JPIP
              {"1.2.840.10008.1.2.4.94", "JPIP Referenced", :little, :explicit, true},
              {"1.2.840.10008.1.2.4.95", "JPIP Referenced Deflate", :little, :explicit, true},
              # RLE
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

  Returns `{:ok, {vr_encoding, endianness}}` for known transfer syntaxes,
  or `{:error, :unknown_transfer_syntax}` for unknown UIDs.

  ## Options

  - `lenient: true` — falls back to `{:ok, {:explicit, :little}}` for
    unknown UIDs instead of returning an error. Use this only when you
    need to attempt parsing files with unrecognized private or future
    transfer syntaxes.
  """
  @spec encoding(String.t(), keyword()) ::
          {:ok, {vr_encoding(), endianness()}} | {:error, :unknown_transfer_syntax}
  def encoding(uid, opts \\ []) do
    case from_uid(uid) do
      {:ok, %{vr_encoding: vr_enc, endianness: endian}} ->
        {:ok, {vr_enc, endian}}

      {:error, :unknown_transfer_syntax} ->
        if Keyword.get(opts, :lenient, false) do
          {:ok, {:explicit, :little}}
        else
          {:error, :unknown_transfer_syntax}
        end
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
