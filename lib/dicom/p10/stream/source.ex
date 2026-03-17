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
  - **File**: reads from a file handle with 64 KB read-ahead buffer
  """

  @read_ahead_size 65_536

  @type io_device :: pid() | {:file_descriptor, atom(), term()}

  @type t :: %__MODULE__{
          buffer: binary(),
          io: :eof | io_device() | nil,
          offset: non_neg_integer()
        }

  defstruct buffer: <<>>, io: nil, offset: 0

  @doc """
  Creates a source from an in-memory binary.
  """
  @spec from_binary(binary()) :: t()
  def from_binary(binary) when is_binary(binary) do
    %__MODULE__{buffer: binary, io: :eof, offset: 0}
  end

  @doc """
  Creates a source from an open file handle (opened in `:raw, :binary, :read` mode).
  """
  @spec from_io(io_device()) :: t()
  def from_io(io) do
    %__MODULE__{buffer: <<>>, io: io, offset: 0}
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

  def ensure(%__MODULE__{io: io, buffer: buffer} = source, n) do
    needed = max(n - byte_size(buffer), @read_ahead_size)

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
end
