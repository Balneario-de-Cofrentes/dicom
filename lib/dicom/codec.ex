defmodule Dicom.Codec do
  @moduledoc """
  Behaviour for DICOM pixel data codecs.

  Codecs decode compressed pixel data frames to raw (uncompressed) pixel data,
  and encode raw pixel data to compressed form.

  ## Implementing a codec

      defmodule MyJPEGCodec do
        @behaviour Dicom.Codec

        @impl true
        def decode(frame_binary, metadata) do
          # decode JPEG to raw pixels
          {:ok, raw_pixels}
        end

        @impl true
        def encode(raw_pixels, metadata) do
          {:ok, compressed}
        end

        @impl true
        def transfer_syntax_uids do
          ["1.2.840.10008.1.2.4.50", "1.2.840.10008.1.2.4.51"]
        end
      end

  ## Metadata

  The `metadata` map carries image parameters needed for decoding/encoding:

  - `:rows` - image height
  - `:columns` - image width
  - `:bits_allocated` - bits per pixel sample (8, 16, 32)
  - `:bits_stored` - meaningful bits within allocated
  - `:high_bit` - most significant bit position
  - `:pixel_representation` - 0 for unsigned, 1 for signed
  - `:samples_per_pixel` - 1 for grayscale, 3 for RGB
  - `:photometric_interpretation` - e.g., "MONOCHROME2", "RGB"
  - `:planar_configuration` - 0 for interleaved, 1 for separate planes
  """

  @type metadata :: %{
          optional(:rows) => non_neg_integer(),
          optional(:columns) => non_neg_integer(),
          optional(:bits_allocated) => non_neg_integer(),
          optional(:bits_stored) => non_neg_integer(),
          optional(:high_bit) => non_neg_integer(),
          optional(:pixel_representation) => 0 | 1,
          optional(:samples_per_pixel) => non_neg_integer(),
          optional(:photometric_interpretation) => String.t(),
          optional(:planar_configuration) => 0 | 1
        }

  @doc """
  Decodes a single compressed frame to raw (uncompressed) pixel data.
  """
  @callback decode(binary(), metadata()) :: {:ok, binary()} | {:error, term()}

  @doc """
  Encodes raw (uncompressed) pixel data to compressed form.
  """
  @callback encode(binary(), metadata()) :: {:ok, binary()} | {:error, term()}

  @doc """
  Returns the list of Transfer Syntax UIDs this codec handles.
  """
  @callback transfer_syntax_uids() :: [String.t()]
end
