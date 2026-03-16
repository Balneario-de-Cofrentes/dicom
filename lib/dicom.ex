defmodule Dicom do
  @moduledoc """
  Pure Elixir DICOM P10 parser and writer.

  Provides functions to parse DICOM Part 10 files into structured data sets
  and serialize them back. Built on Elixir's binary pattern matching for
  fast, streaming-capable parsing.

  ## Quick Start

      # Parse a DICOM file
      {:ok, data_set} = Dicom.parse_file("/path/to/image.dcm")

      # Access patient name
      patient_name = Dicom.DataSet.get(data_set, Dicom.Tag.patient_name())

      # Write back to file
      :ok = Dicom.write_file(data_set, "/path/to/output.dcm")

  ## DICOM Standard Coverage

  - PS3.5 — Data Structures and Encoding
  - PS3.6 — Data Dictionary
  - PS3.10 — Media Storage and File Format
  """

  @doc """
  Parses a DICOM P10 binary into a `Dicom.DataSet`.

  The binary must start with the 128-byte preamble followed by the "DICM"
  magic bytes, then File Meta Information and the data set.

  ## Examples

      {:ok, data_set} = Dicom.parse(binary)
      {:error, :invalid_preamble} = Dicom.parse(<<"not dicom">>)
  """
  @spec parse(binary()) :: {:ok, Dicom.DataSet.t()} | {:error, term()}
  def parse(binary) when is_binary(binary) do
    Dicom.P10.Reader.parse(binary)
  end

  @doc """
  Parses a DICOM P10 file from disk.

  ## Examples

      {:ok, data_set} = Dicom.parse_file("/path/to/image.dcm")
      {:error, :enoent} = Dicom.parse_file("/nonexistent.dcm")
  """
  @spec parse_file(Path.t()) :: {:ok, Dicom.DataSet.t()} | {:error, term()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, binary} -> parse(binary)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Serializes a `Dicom.DataSet` to DICOM P10 binary format.
  """
  @spec write(Dicom.DataSet.t()) :: {:ok, binary()} | {:error, term()}
  def write(%Dicom.DataSet{} = data_set) do
    Dicom.P10.Writer.serialize(data_set)
  end

  @doc """
  Writes a `Dicom.DataSet` to a DICOM P10 file on disk.
  """
  @spec write_file(Dicom.DataSet.t(), Path.t()) :: :ok | {:error, term()}
  def write_file(%Dicom.DataSet{} = data_set, path) do
    case write(data_set) do
      {:ok, binary} -> File.write(path, binary)
      {:error, reason} -> {:error, reason}
    end
  end
end
