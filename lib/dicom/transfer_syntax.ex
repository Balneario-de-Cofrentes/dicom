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

  @doc """
  Returns the transfer syntax definition for the given UID.
  """
  @spec from_uid(String.t()) :: {:ok, t()} | {:error, :unknown_transfer_syntax}
  def from_uid(uid) do
    case Map.get(registry(), uid) do
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

  defp registry do
    %{
      Dicom.UID.implicit_vr_little_endian() => %__MODULE__{
        uid: Dicom.UID.implicit_vr_little_endian(),
        name: "Implicit VR Little Endian",
        endianness: :little,
        vr_encoding: :implicit,
        compressed: false
      },
      Dicom.UID.explicit_vr_little_endian() => %__MODULE__{
        uid: Dicom.UID.explicit_vr_little_endian(),
        name: "Explicit VR Little Endian",
        endianness: :little,
        vr_encoding: :explicit,
        compressed: false
      },
      Dicom.UID.explicit_vr_big_endian() => %__MODULE__{
        uid: Dicom.UID.explicit_vr_big_endian(),
        name: "Explicit VR Big Endian (Retired)",
        endianness: :big,
        vr_encoding: :explicit,
        compressed: false
      },
      Dicom.UID.jpeg_baseline() => %__MODULE__{
        uid: Dicom.UID.jpeg_baseline(),
        name: "JPEG Baseline (Process 1)",
        endianness: :little,
        vr_encoding: :explicit,
        compressed: true
      },
      Dicom.UID.jpeg_lossless() => %__MODULE__{
        uid: Dicom.UID.jpeg_lossless(),
        name: "JPEG Lossless, Non-Hierarchical, First-Order Prediction",
        endianness: :little,
        vr_encoding: :explicit,
        compressed: true
      },
      Dicom.UID.jpeg_2000_lossless() => %__MODULE__{
        uid: Dicom.UID.jpeg_2000_lossless(),
        name: "JPEG 2000 Image Compression (Lossless Only)",
        endianness: :little,
        vr_encoding: :explicit,
        compressed: true
      },
      Dicom.UID.jpeg_2000() => %__MODULE__{
        uid: Dicom.UID.jpeg_2000(),
        name: "JPEG 2000 Image Compression",
        endianness: :little,
        vr_encoding: :explicit,
        compressed: true
      },
      Dicom.UID.rle_lossless() => %__MODULE__{
        uid: Dicom.UID.rle_lossless(),
        name: "RLE Lossless",
        endianness: :little,
        vr_encoding: :explicit,
        compressed: true
      }
    }
  end
end
