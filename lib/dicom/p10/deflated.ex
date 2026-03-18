defmodule Dicom.P10.Deflated do
  @moduledoc false

  @spec compress(iodata()) :: binary()
  def compress(data) do
    z = :zlib.open()

    try do
      :ok = :zlib.deflateInit(z, :default, :deflated, -15, 8, :default)
      compressed = z |> :zlib.deflate(data, :finish) |> IO.iodata_to_binary()
      :ok = :zlib.deflateEnd(z)
      compressed
    after
      :zlib.close(z)
    end
  end

  @spec decompress(binary()) :: {:ok, binary()} | {:error, :invalid_deflated_data}
  def decompress(binary) when is_binary(binary) do
    z = :zlib.open()

    try do
      :ok = :zlib.inflateInit(z, -15)
      decompressed = z |> :zlib.inflate(binary) |> IO.iodata_to_binary()
      :ok = :zlib.inflateEnd(z)
      {:ok, decompressed}
    rescue
      ErlangError -> {:error, :invalid_deflated_data}
    after
      :zlib.close(z)
    end
  end
end
