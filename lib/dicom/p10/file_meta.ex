defmodule Dicom.P10.FileMeta do
  @moduledoc """
  DICOM P10 File Meta Information (Group 0002).

  The File Meta Information header is always encoded in Explicit VR Little Endian
  regardless of the Transfer Syntax used for the data set.

  Reference: DICOM PS3.10 Section 7.1.
  """

  @preamble_size 128
  @magic "DICM"

  @doc """
  Validates and skips the 128-byte preamble and "DICM" magic.

  Returns the remaining binary after the preamble, or an error.
  """
  @spec skip_preamble(binary()) :: {:ok, binary()} | {:error, :invalid_preamble}
  def skip_preamble(<<_preamble::binary-size(@preamble_size), @magic, rest::binary>>) do
    {:ok, rest}
  end

  def skip_preamble(_), do: {:error, :invalid_preamble}

  @doc """
  Generates a P10 preamble (128 zero bytes + "DICM").
  """
  @spec preamble() :: binary()
  def preamble do
    <<0::size(@preamble_size * 8), @magic>>
  end

  @doc """
  Sanitizes the preamble by zeroing it out.

  Per PS3.10 Section 7.5, the preamble can contain malicious content.
  This function replaces the 128-byte preamble with zeros while
  preserving the DICM prefix and all subsequent data.
  """
  @spec sanitize_preamble(binary()) :: {:ok, binary()} | {:error, :invalid_preamble}
  def sanitize_preamble(<<_preamble::binary-size(@preamble_size), @magic, rest::binary>>) do
    {:ok, <<0::size(@preamble_size * 8), @magic, rest::binary>>}
  end

  def sanitize_preamble(_), do: {:error, :invalid_preamble}
end
