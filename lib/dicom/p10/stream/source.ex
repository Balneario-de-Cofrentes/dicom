defmodule Dicom.P10.Stream.Source do
  @moduledoc """
  Data source abstraction for the streaming DICOM parser.

  Provides a uniform interface over binary buffers and file I/O with
  read-ahead buffering. The source supports three operations:

  - `ensure/2` -- guarantee N bytes are available in the buffer
  - `consume/2` -- consume N bytes from the buffer
  - `peek/2` -- read N bytes without consuming

  ## Source Types

  - **Binary**: wraps an in-memory binary, no I/O
  - **File**: reads from a file handle with configurable read-ahead buffering

  ## Stability

  This module **may change**. It is an internal implementation detail of the
  streaming parser and should not be relied on directly by consumers.
  """

  @read_ahead_size 65_536

  @type io_device :: pid() | {:file_descriptor, atom(), term()}

  @type t :: %__MODULE__{
          buffer: binary(),
          io: :eof | io_device() | nil,
          offset: non_neg_integer(),
          read_ahead: pos_integer()
        }

  defstruct buffer: <<>>, io: nil, offset: 0, read_ahead: @read_ahead_size

  @doc """
  Creates a source from an in-memory binary.
  """
  @spec from_binary(binary()) :: t()
  def from_binary(binary) when is_binary(binary) do
    %__MODULE__{buffer: binary, io: :eof, offset: 0}
  end

  @doc """
  Creates a source from an open file handle (opened in `:raw, :binary, :read` mode).

  ## Options

  - `:read_ahead` -- preferred read-ahead buffer size in bytes (default: 65536)
  """
  @spec from_io(io_device(), keyword()) :: t()
  def from_io(io, opts \\ []) do
    %__MODULE__{
      buffer: <<>>,
      io: io,
      offset: 0,
      read_ahead: normalize_read_ahead(Keyword.get(opts, :read_ahead, @read_ahead_size))
    }
  end

  @doc """
  Ensures at least `n` bytes are available in the buffer.

  Returns `{:ok, source}` if the buffer has >= n bytes after filling,
  or `{:error, :unexpected_end}` if the source is exhausted.
  """
  @spec ensure(t(), non_neg_integer()) :: {:ok, t()} | {:error, :unexpected_end}
  def ensure(%__MODULE__{buffer: buffer} = source, n) when byte_size(buffer) >= n do
    {:ok, source}
  end

  def ensure(%__MODULE__{io: :eof}, _n), do: {:error, :unexpected_end}
  def ensure(%__MODULE__{io: nil}, _n), do: {:error, :unexpected_end}

  def ensure(%__MODULE__{io: io, buffer: buffer, read_ahead: read_ahead} = source, n) do
    needed = max(n - byte_size(buffer), read_ahead)

    case IO.binread(io, needed) do
      data when is_binary(data) and byte_size(data) > 0 ->
        new_source = %{source | buffer: buffer <> data}

        if byte_size(new_source.buffer) >= n do
          {:ok, new_source}
        else
          # Mark as EOF since we got less than requested
          ensure(%{new_source | io: :eof}, n)
        end

      _ ->
        ensure(%{source | io: :eof}, n)
    end
  end

  @doc """
  Consumes `n` bytes from the buffer, returning them and the updated source.
  """
  @spec consume(t(), non_neg_integer()) :: {:ok, binary(), t()}
  def consume(%__MODULE__{buffer: buffer, offset: offset} = source, n)
      when byte_size(buffer) >= n do
    <<data::binary-size(n), rest::binary>> = buffer
    {:ok, data, %{source | buffer: rest, offset: offset + n}}
  end

  @doc """
  Peeks at the next `n` bytes without consuming them.
  """
  @spec peek(t(), non_neg_integer()) :: {:ok, binary()} | {:error, :unexpected_end}
  def peek(%__MODULE__{buffer: buffer}, n) when byte_size(buffer) >= n do
    <<data::binary-size(n), _::binary>> = buffer
    {:ok, data}
  end

  def peek(_, _), do: {:error, :unexpected_end}

  @doc """
  Returns the number of bytes currently available in the buffer.
  """
  @spec available(t()) :: non_neg_integer()
  def available(%__MODULE__{buffer: buffer}), do: byte_size(buffer)

  @doc """
  Consumes bytes until `marker` is found, excluding the marker from the returned data.

  If the marker is not found before EOF, consumes and returns the remaining buffer.
  """
  @spec consume_until(t(), binary()) :: {:ok, binary(), t()}
  def consume_until(%__MODULE__{} = source, marker)
      when is_binary(marker) and byte_size(marker) > 0 do
    case :binary.match(source.buffer, marker) do
      {position, marker_size} ->
        <<data::binary-size(position), _marker::binary-size(marker_size), rest::binary>> =
          source.buffer

        {:ok, data, %{source | buffer: rest, offset: source.offset + position + marker_size}}

      :nomatch ->
        refill_until_marker(source, marker)
    end
  end

  @doc """
  Consumes bytes until `marker` is found, excluding the marker from the returned data.

  Returns `{:error, :unexpected_end}` if EOF is reached before the marker appears.
  """
  @spec consume_until_required(t(), binary()) :: {:ok, binary(), t()} | {:error, :unexpected_end}
  def consume_until_required(%__MODULE__{} = source, marker)
      when is_binary(marker) and byte_size(marker) > 0 do
    case :binary.match(source.buffer, marker) do
      {position, marker_size} ->
        <<data::binary-size(position), _marker::binary-size(marker_size), rest::binary>> =
          source.buffer

        {:ok, data, %{source | buffer: rest, offset: source.offset + position + marker_size}}

      :nomatch ->
        refill_until_required_marker(source, marker)
    end
  end

  @doc """
  Returns true if the source is exhausted (EOF and empty buffer).
  """
  @spec eof?(t()) :: boolean()
  def eof?(%__MODULE__{buffer: <<>>, io: :eof}), do: true
  def eof?(_), do: false

  @doc """
  Returns the total bytes consumed from this source.
  """
  @spec bytes_consumed(t()) :: non_neg_integer()
  def bytes_consumed(%__MODULE__{offset: offset}), do: offset

  defp refill_until_marker(
         %__MODULE__{io: :eof, buffer: buffer, offset: offset} = source,
         _marker
       ) do
    {:ok, buffer, %{source | buffer: <<>>, offset: offset + byte_size(buffer)}}
  end

  defp refill_until_marker(%__MODULE__{io: nil} = source, marker) do
    refill_until_marker(%{source | io: :eof}, marker)
  end

  defp refill_until_marker(
         %__MODULE__{io: io, buffer: buffer, read_ahead: read_ahead} = source,
         marker
       ) do
    case IO.binread(io, read_ahead) do
      data when is_binary(data) and byte_size(data) > 0 ->
        consume_until(%{source | buffer: buffer <> data}, marker)

      _ ->
        refill_until_marker(%{source | io: :eof}, marker)
    end
  end

  defp refill_until_required_marker(%__MODULE__{io: :eof}, _marker), do: {:error, :unexpected_end}

  defp refill_until_required_marker(%__MODULE__{io: nil} = source, marker) do
    refill_until_required_marker(%{source | io: :eof}, marker)
  end

  defp refill_until_required_marker(
         %__MODULE__{io: io, buffer: buffer, read_ahead: read_ahead} = source,
         marker
       ) do
    case IO.binread(io, read_ahead) do
      data when is_binary(data) and byte_size(data) > 0 ->
        consume_until_required(%{source | buffer: buffer <> data}, marker)

      _ ->
        refill_until_required_marker(%{source | io: :eof}, marker)
    end
  end

  defp normalize_read_ahead(read_ahead) when is_integer(read_ahead) and read_ahead > 0,
    do: read_ahead

  defp normalize_read_ahead(_read_ahead), do: @read_ahead_size
end
