defmodule Dicom.TransferSyntax do
  @moduledoc """
  Transfer Syntax definitions and properties.

  A Transfer Syntax specifies how DICOM data is encoded: byte order,
  whether VR is explicit or implicit, and pixel data compression.

  Registers 49 DICOM transfer syntaxes currently tracked by this library
  (34 active + 15 retired).
  Unknown transfer syntaxes are rejected by default — use `encoding/2` with
  `lenient: true` to fall back to Explicit VR Little Endian for
  unrecognized UIDs.

  Reference: DICOM PS3.5 Section 10, PS3.6 Table A-1.
  """

  @type endianness :: :little | :big
  @type vr_encoding :: :implicit | :explicit

  @type t :: %__MODULE__{
          uid: String.t(),
          name: String.t(),
          endianness: endianness(),
          vr_encoding: vr_encoding(),
          compressed: boolean(),
          retired: boolean(),
          fragmentable: boolean()
        }

  defstruct [
    :uid,
    :name,
    :endianness,
    :vr_encoding,
    compressed: false,
    retired: false,
    fragmentable: false
  ]

  # Registry: {uid, name, endianness, vr_encoding, compressed, retired, fragmentable}
  @registry [
              # ── Uncompressed ──────────────────────────────────────────
              {"1.2.840.10008.1.2", "Implicit VR Little Endian", :little, :implicit, false, false,
               false},
              {"1.2.840.10008.1.2.1", "Explicit VR Little Endian", :little, :explicit, false,
               false, false},
              {"1.2.840.10008.1.2.1.99", "Deflated Explicit VR Little Endian", :little, :explicit,
               false, false, false},
              {"1.2.840.10008.1.2.2", "Explicit VR Big Endian (Retired)", :big, :explicit, false,
               true, false},

              # ── JPEG (Active) ─────────────────────────────────────────
              {"1.2.840.10008.1.2.4.50", "JPEG Baseline (Process 1)", :little, :explicit, true,
               false, false},
              {"1.2.840.10008.1.2.4.51", "JPEG Extended (Process 2 & 4)", :little, :explicit,
               true, false, false},
              {"1.2.840.10008.1.2.4.57", "JPEG Lossless, Non-Hierarchical (Process 14)", :little,
               :explicit, true, false, false},
              {"1.2.840.10008.1.2.4.70",
               "JPEG Lossless, Non-Hierarchical, First-Order Prediction", :little, :explicit,
               true, false, false},

              # ── JPEG (Retired Processes) ──────────────────────────────
              {"1.2.840.10008.1.2.4.52", "JPEG Extended (Process 3 & 5) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.53",
               "JPEG Spectral Selection, Non-Hierarchical (Process 6 & 8) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.54",
               "JPEG Spectral Selection, Non-Hierarchical (Process 7 & 9) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.55",
               "JPEG Full Progression, Non-Hierarchical (Process 10 & 12) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.56",
               "JPEG Full Progression, Non-Hierarchical (Process 11 & 13) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.58", "JPEG Lossless, Non-Hierarchical (Process 15) (Retired)",
               :little, :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.59",
               "JPEG Extended, Hierarchical (Process 16 & 18) (Retired)", :little, :explicit,
               true, true, false},
              {"1.2.840.10008.1.2.4.60",
               "JPEG Extended, Hierarchical (Process 17 & 19) (Retired)", :little, :explicit,
               true, true, false},
              {"1.2.840.10008.1.2.4.61",
               "JPEG Spectral Selection, Hierarchical (Process 20 & 22) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.62",
               "JPEG Spectral Selection, Hierarchical (Process 21 & 23) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.63",
               "JPEG Full Progression, Hierarchical (Process 24 & 26) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.64",
               "JPEG Full Progression, Hierarchical (Process 25 & 27) (Retired)", :little,
               :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.65", "JPEG Lossless, Hierarchical (Process 28) (Retired)",
               :little, :explicit, true, true, false},
              {"1.2.840.10008.1.2.4.66", "JPEG Lossless, Hierarchical (Process 29) (Retired)",
               :little, :explicit, true, true, false},

              # ── JPEG-LS ───────────────────────────────────────────────
              {"1.2.840.10008.1.2.4.80", "JPEG-LS Lossless Image Compression", :little, :explicit,
               true, false, false},
              {"1.2.840.10008.1.2.4.81", "JPEG-LS Lossy (Near-Lossless) Image Compression",
               :little, :explicit, true, false, false},

              # ── JPEG 2000 ─────────────────────────────────────────────
              {"1.2.840.10008.1.2.4.90", "JPEG 2000 Image Compression (Lossless Only)", :little,
               :explicit, true, false, false},
              {"1.2.840.10008.1.2.4.91", "JPEG 2000 Image Compression", :little, :explicit, true,
               false, false},
              {"1.2.840.10008.1.2.4.92", "JPEG 2000 Part 2 Multi-component (Lossless Only)",
               :little, :explicit, true, false, false},
              {"1.2.840.10008.1.2.4.93", "JPEG 2000 Part 2 Multi-component", :little, :explicit,
               true, false, false},

              # ── JPIP ──────────────────────────────────────────────────
              {"1.2.840.10008.1.2.4.94", "JPIP Referenced", :little, :explicit, true, false,
               false},
              {"1.2.840.10008.1.2.4.95", "JPIP Referenced Deflate", :little, :explicit, true,
               false, false},

              # ── MPEG / HEVC (all fragmentable) ────────────────────────
              {"1.2.840.10008.1.2.4.100", "MPEG2 Main Profile / Main Level", :little, :explicit,
               true, false, true},
              {"1.2.840.10008.1.2.4.101", "MPEG2 Main Profile / High Level", :little, :explicit,
               true, false, true},
              {"1.2.840.10008.1.2.4.102", "MPEG-4 AVC/H.264 High Profile / Level 4.1", :little,
               :explicit, true, false, true},
              {"1.2.840.10008.1.2.4.103",
               "MPEG-4 AVC/H.264 BD-compatible High Profile / Level 4.1", :little, :explicit,
               true, false, true},
              {"1.2.840.10008.1.2.4.104",
               "MPEG-4 AVC/H.264 High Profile / Level 4.2 For 2D Video", :little, :explicit, true,
               false, true},
              {"1.2.840.10008.1.2.4.105",
               "MPEG-4 AVC/H.264 High Profile / Level 4.2 For 3D Video", :little, :explicit, true,
               false, true},
              {"1.2.840.10008.1.2.4.106", "MPEG-4 AVC/H.264 Stereo High Profile / Level 4.2",
               :little, :explicit, true, false, true},
              {"1.2.840.10008.1.2.4.107", "HEVC/H.265 Main Profile / Level 5.1", :little,
               :explicit, true, false, true},
              {"1.2.840.10008.1.2.4.108", "HEVC/H.265 Main 10 Profile / Level 5.1", :little,
               :explicit, true, false, true},

              # ── JPEG XL ───────────────────────────────────────────────
              {"1.2.840.10008.1.2.4.110", "JPEG XL Lossless", :little, :explicit, true, false,
               false},
              {"1.2.840.10008.1.2.4.111", "JPEG XL JPEG Recompression", :little, :explicit, true,
               false, false},
              {"1.2.840.10008.1.2.4.112", "JPEG XL", :little, :explicit, true, false, false},

              # ── HTJ2K ─────────────────────────────────────────────────
              {"1.2.840.10008.1.2.4.201", "High-Throughput JPEG 2000 (Lossless Only)", :little,
               :explicit, true, false, false},
              {"1.2.840.10008.1.2.4.202", "High-Throughput JPEG 2000 with RPCL (Lossless Only)",
               :little, :explicit, true, false, false},
              {"1.2.840.10008.1.2.4.203", "High-Throughput JPEG 2000", :little, :explicit, true,
               false, false},

              # ── RLE ───────────────────────────────────────────────────
              {"1.2.840.10008.1.2.5", "RLE Lossless", :little, :explicit, true, false, false},

              # ── SMPTE ST 2110 ─────────────────────────────────────────
              {"1.2.840.10008.1.2.7.1", "SMPTE ST 2110-20 Uncompressed Progressive Active Video",
               :little, :explicit, false, false, false},
              {"1.2.840.10008.1.2.7.2", "SMPTE ST 2110-20 Uncompressed Interlaced Active Video",
               :little, :explicit, false, false, false},
              {"1.2.840.10008.1.2.7.3", "SMPTE ST 2110-30 PCM Digital Audio", :little, :explicit,
               false, false, false}
            ]
            |> Map.new(fn {uid, name, endian, vr_enc, compressed, retired, fragmentable} ->
              {uid,
               %{
                 __struct__: __MODULE__,
                 uid: uid,
                 name: name,
                 endianness: endian,
                 vr_encoding: vr_enc,
                 compressed: compressed,
                 retired: retired,
                 fragmentable: fragmentable
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
  Returns true if the given UID is a known transfer syntax.
  """
  @spec known?(String.t()) :: boolean()
  def known?(uid), do: Map.has_key?(@registry, uid)

  @all_syntaxes Map.values(@registry)
  @active_syntaxes Enum.filter(@all_syntaxes, &(not &1.retired))

  @doc """
  Returns all registered transfer syntaxes.
  """
  @spec all() :: [t()]
  def all, do: @all_syntaxes

  @doc """
  Returns only active (non-retired) transfer syntaxes.
  """
  @spec active() :: [t()]
  def active, do: @active_syntaxes

  @doc """
  Returns true if the transfer syntax is retired.
  """
  @spec retired?(String.t()) :: boolean()
  def retired?(uid) do
    case from_uid(uid) do
      {:ok, %{retired: retired}} -> retired
      _ -> false
    end
  end

  @doc """
  Returns true if the transfer syntax uses fragmentable encapsulation.

  Fragmentable transfer syntaxes (MPEG, HEVC) may have pixel data
  fragments that do not correspond one-to-one with frames.
  """
  @spec fragmentable?(String.t()) :: boolean()
  def fragmentable?(uid) do
    case from_uid(uid) do
      {:ok, %{fragmentable: frag}} -> frag
      _ -> false
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
