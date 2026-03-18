defmodule Dicom.P10.Stream do
  @moduledoc """
  Streaming DICOM P10 parser.

  Provides lazy, event-based parsing of DICOM P10 data as Elixir streams.
  This enables processing DICOM files without loading the entire content
  into memory, and composing with standard `Stream` and `Enum` functions.

  ## Binary Streaming

      events = Dicom.P10.Stream.parse(binary)
      Enum.each(events, fn
        {:element, elem} -> IO.inspect(elem.tag)
        _ -> :ok
      end)

  ## File Streaming

      events = Dicom.P10.Stream.parse_file("/path/to/image.dcm")
      Enum.each(events, fn event -> process(event) end)

  ## Materialization

      {:ok, data_set} = Dicom.P10.Stream.to_data_set(events)

  Reference: DICOM PS3.5, PS3.10.

  ## Stability

  This module is **stable**. Its public API is covered by normal compatibility
  expectations.
  """

  alias Dicom.P10.Stream.{Parser, Source}
  alias Dicom.{DataElement, DataSet}

  @doc """
  Parses a DICOM P10 binary into a lazy stream of events.

  Uses `Stream.unfold/2` to emit events one at a time.

  ## Examples

      events = Dicom.P10.Stream.parse(binary)
      tags = events
             |> Stream.filter(&match?({:element, _}, &1))
             |> Enum.map(fn {:element, elem} -> elem.tag end)
  """
  @spec parse(binary()) :: Enumerable.t()
  def parse(binary) when is_binary(binary) do
    source = Source.from_binary(binary)
    state = Parser.new(source)

    Stream.unfold(state, fn state ->
      case Parser.next(state) do
        nil -> nil
        {event, new_state} -> {event, new_state}
      end
    end)
  end

  @doc """
  Parses a DICOM P10 file into a lazy stream of events.

  Opens the file with `:raw, :binary, :read` mode and uses
  `Stream.resource/3` for proper resource management (the file
  handle is closed when the stream is consumed or halted).

  ## Options

  - `:read_ahead` -- read-ahead buffer size in bytes (default: 65536)

  ## Examples

      events = Dicom.P10.Stream.parse_file("/path/to/image.dcm")
      {:ok, data_set} = Dicom.P10.Stream.to_data_set(events)
  """
  @spec parse_file(Path.t(), keyword()) :: Enumerable.t()
  def parse_file(path, opts \\ []) do
    Stream.resource(
      fn ->
        case File.open(path, [:raw, :binary, :read]) do
          {:ok, io} ->
            source = Source.from_io(io, opts)
            {:ok, Parser.new(source), io}

          {:error, reason} ->
            {:error, reason, nil}
        end
      end,
      fn
        {:error, reason, _io} ->
          {[{:error, reason}], {:done, nil}}

        {:done, _io} ->
          {:halt, {:done, nil}}

        {:ok, state, io} ->
          case Parser.next(state) do
            nil ->
              {:halt, {:done, io}}

            {:end, _state} ->
              {[:end], {:done, io}}

            {{:error, _} = error, _state} ->
              {[error], {:done, io}}

            {event, new_state} ->
              {[event], {:ok, new_state, io}}
          end
      end,
      fn
        {:done, nil} -> :ok
        {:done, io} when not is_nil(io) -> File.close(io)
        {:ok, _state, io} when not is_nil(io) -> File.close(io)
        {:error, _reason, nil} -> :ok
        _ -> :ok
      end
    )
  end

  @doc """
  Materializes a stream of events into a `Dicom.DataSet`.

  Collects all events from the stream and reconstructs the data set,
  including file meta information, data elements, sequences, and
  encapsulated pixel data.

  ## Examples

      events = Dicom.P10.Stream.parse(binary)
      {:ok, data_set} = Dicom.P10.Stream.to_data_set(events)
  """
  @spec to_data_set(Enumerable.t()) :: {:ok, DataSet.t()} | {:error, term()}
  def to_data_set(events) do
    result =
      Enum.reduce_while(events, {:file_meta, %{}, [], []}, fn event, acc ->
        case handle_event(event, acc) do
          {:ok, new_acc} -> {:cont, new_acc}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      {:error, _} = error ->
        error

      {_phase, file_meta, elements, []} ->
        {:ok, %DataSet{file_meta: file_meta, elements: Map.new(elements)}}
    end
  end

  # Event accumulator: {phase, file_meta_map, elements_list, stack}
  # Stack entries: {:sequence, tag, items_acc} | {:item, elements_acc}
  #              | {:pixel_data, tag, vr, fragments_acc}

  defp handle_event(:file_meta_start, acc), do: {:ok, acc}

  defp handle_event({:file_meta_end, _ts_uid}, {_phase, file_meta, elements, stack}) do
    {:ok, {:data_set, file_meta, elements, stack}}
  end

  defp handle_event({:element, element}, {:file_meta, file_meta, elements, stack}) do
    {:ok, {:file_meta, Map.put(file_meta, element.tag, element), elements, stack}}
  end

  defp handle_event({:element, element}, {:data_set, file_meta, elements, []}) do
    {:ok, {:data_set, file_meta, [{element.tag, element} | elements], []}}
  end

  defp handle_event({:element, element}, {:data_set, file_meta, elements, stack}) do
    {:ok, {:data_set, file_meta, elements, push_element_to_stack(element, stack)}}
  end

  defp handle_event({:sequence_start, tag, _length}, {:data_set, file_meta, elements, stack}) do
    {:ok, {:data_set, file_meta, elements, [{:sequence, tag, []} | stack]}}
  end

  defp handle_event(
         :sequence_end,
         {:data_set, file_meta, elements, [{:sequence, tag, items} | rest]}
       ) do
    sq_element = DataElement.new(tag, :SQ, Enum.reverse(items))

    case rest do
      [] ->
        {:ok, {:data_set, file_meta, [{tag, sq_element} | elements], []}}

      _ ->
        {:ok, {:data_set, file_meta, elements, push_element_to_stack(sq_element, rest)}}
    end
  end

  defp handle_event({:item_start, _length}, {:data_set, file_meta, elements, stack}) do
    {:ok, {:data_set, file_meta, elements, [{:item, %{}} | stack]}}
  end

  defp handle_event(
         :item_end,
         {:data_set, file_meta, elements,
          [{:item, item_elements} | [{:sequence, tag, items} | rest]]}
       ) do
    {:ok, {:data_set, file_meta, elements, [{:sequence, tag, [item_elements | items]} | rest]}}
  end

  defp handle_event({:pixel_data_start, tag, vr}, {:data_set, file_meta, elements, stack}) do
    {:ok, {:data_set, file_meta, elements, [{:pixel_data, tag, vr, []} | stack]}}
  end

  defp handle_event(
         {:pixel_data_fragment, _index, fragment},
         {:data_set, file_meta, elements, [{:pixel_data, tag, vr, fragments} | rest]}
       ) do
    {:ok,
     {:data_set, file_meta, elements, [{:pixel_data, tag, vr, [fragment | fragments]} | rest]}}
  end

  defp handle_event(
         :pixel_data_end,
         {:data_set, file_meta, elements, [{:pixel_data, tag, vr, fragments} | rest]}
       ) do
    element = DataElement.new(tag, vr, {:encapsulated, Enum.reverse(fragments)})
    {:ok, {:data_set, file_meta, [{tag, element} | elements], rest}}
  end

  defp handle_event(:end, acc), do: {:ok, acc}

  defp handle_event({:error, reason}, _acc), do: {:error, reason}

  defp push_element_to_stack(element, [{:item, item_elements} | rest]) do
    [{:item, Map.put(item_elements, element.tag, element)} | rest]
  end

  defp push_element_to_stack(element, stack) do
    # Shouldn't happen in well-formed streams, but handle gracefully
    [{:item, %{element.tag => element}} | stack]
  end
end
