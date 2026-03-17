defmodule Dicom.DataSet do
  @moduledoc """
  An ordered collection of DICOM Data Elements.

  A Data Set represents the core content of a DICOM object — all the
  attributes describing a patient, study, series, or instance. Elements
  are stored ordered by tag for conformant serialization.

  ## Usage

      data_set = Dicom.DataSet.new()
      data_set = Dicom.DataSet.put(data_set, {0x0010, 0x0010}, :PN, "DOE^JOHN")
      "DOE^JOHN" = Dicom.DataSet.get(data_set, {0x0010, 0x0010})

  Reference: DICOM PS3.5 Section 7.
  """

  @behaviour Access

  @type t :: %__MODULE__{
          elements: %{Dicom.DataElement.tag() => Dicom.DataElement.t()},
          file_meta: %{Dicom.DataElement.tag() => Dicom.DataElement.t()}
        }

  defstruct elements: %{}, file_meta: %{}

  @doc """
  Creates a new empty data set.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Returns true if the tag is present in the data set.
  """
  @spec has_tag?(t(), Dicom.DataElement.tag()) :: boolean()
  def has_tag?(%__MODULE__{} = ds, tag), do: get_element(ds, tag) != nil

  @doc """
  Gets the value of a data element by tag.

  Returns `nil` if the tag is not present.
  """
  @spec get(t(), Dicom.DataElement.tag()) :: term() | nil
  def get(%__MODULE__{} = ds, tag) do
    case get_element(ds, tag) do
      %Dicom.DataElement{value: value} -> value
      nil -> nil
    end
  end

  @doc """
  Gets the value of a data element by tag, returning `default` if absent.
  """
  @spec get(t(), Dicom.DataElement.tag(), term()) :: term()
  def get(%__MODULE__{} = ds, tag, default) do
    case get_element(ds, tag) do
      %Dicom.DataElement{value: value} -> value
      nil -> default
    end
  end

  @doc """
  Fetches the value of a data element by tag.

  Returns `{:ok, value}` or `:error`. Implements `Access.fetch/2`.
  """
  @impl Access
  @spec fetch(t(), Dicom.DataElement.tag()) :: {:ok, term()} | :error
  def fetch(%__MODULE__{} = ds, tag) do
    case get_element(ds, tag) do
      %Dicom.DataElement{value: value} -> {:ok, value}
      nil -> :error
    end
  end

  @doc """
  Gets and updates a value in the data set. Implements `Access.get_and_update/3`.

  The function receives the current value (or nil) and must return
  `{current_value, new_value}` or `:pop`.
  """
  @impl Access
  def get_and_update(%__MODULE__{} = ds, tag, fun) do
    current = get(ds, tag)

    case fun.(current) do
      {get_value, new_value} ->
        vr = resolve_vr(ds, tag)
        {get_value, put(ds, tag, vr, new_value)}

      :pop ->
        {current, delete(ds, tag)}
    end
  end

  @doc """
  Pops a value from the data set. Implements `Access.pop/2`.
  """
  @impl Access
  def pop(%__MODULE__{} = ds, tag) do
    case get_element(ds, tag) do
      %Dicom.DataElement{value: value} -> {value, delete(ds, tag)}
      nil -> {nil, ds}
    end
  end

  @doc """
  Gets the raw DataElement struct by tag.

  Returns `nil` if the tag is not present.
  """
  @spec get_element(t(), Dicom.DataElement.tag()) :: Dicom.DataElement.t() | nil
  def get_element(%__MODULE__{elements: elements, file_meta: file_meta}, {group, _element} = tag) do
    source = if group == 0x0002, do: file_meta, else: elements
    Map.get(source, tag)
  end

  @doc """
  Puts a data element into the data set.
  """
  @spec put(t(), Dicom.DataElement.tag(), Dicom.VR.t(), term()) :: t()
  def put(%__MODULE__{} = ds, {group, _element} = tag, vr, value) do
    element = Dicom.DataElement.new(tag, vr, value)

    if group == 0x0002 do
      %{ds | file_meta: Map.put(ds.file_meta, tag, element)}
    else
      %{ds | elements: Map.put(ds.elements, tag, element)}
    end
  end

  @doc """
  Deletes a data element from the data set by tag.
  """
  @spec delete(t(), Dicom.DataElement.tag()) :: t()
  def delete(%__MODULE__{} = ds, {group, _element} = tag) do
    if group == 0x0002 do
      %{ds | file_meta: Map.delete(ds.file_meta, tag)}
    else
      %{ds | elements: Map.delete(ds.elements, tag)}
    end
  end

  @doc """
  Returns all tags present in the data set.
  """
  @spec tags(t()) :: [Dicom.DataElement.tag()]
  def tags(%__MODULE__{elements: elements, file_meta: file_meta}) do
    (Map.keys(file_meta) ++ Map.keys(elements))
    |> Enum.sort()
  end

  @doc """
  Converts the data set to a plain map of `tag => value`.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{elements: elements, file_meta: file_meta}) do
    Map.merge(file_meta, elements)
    |> Map.new(fn {tag, %Dicom.DataElement{value: value}} -> {tag, value} end)
  end

  @doc """
  Returns the number of elements in the data set (including file meta).
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{elements: elements, file_meta: file_meta}) do
    map_size(elements) + map_size(file_meta)
  end

  @doc """
  Merges two data sets. Elements in `other` take precedence.
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = base, %__MODULE__{} = other) do
    %__MODULE__{
      elements: Map.merge(base.elements, other.elements),
      file_meta: Map.merge(base.file_meta, other.file_meta)
    }
  end

  @doc """
  Builds a data set from a list of `{tag, vr, value}` tuples.

  ## Examples

      iex> ds = Dicom.DataSet.from_list([{{0x0010, 0x0010}, :PN, "DOE^JOHN"}])
      iex> Dicom.DataSet.get(ds, {0x0010, 0x0010})
      "DOE^JOHN"
  """
  @spec from_list([{Dicom.DataElement.tag(), Dicom.VR.t(), term()}]) :: t()
  def from_list(entries) when is_list(entries) do
    Enum.reduce(entries, new(), fn {tag, vr, value}, ds ->
      put(ds, tag, vr, value)
    end)
  end

  @doc """
  Gets a VR-decoded value for a tag using `Dicom.Value.decode/2`.

  Returns `nil` if the tag is absent.
  """
  @spec decoded_value(t(), Dicom.DataElement.tag()) :: term() | nil
  def decoded_value(%__MODULE__{} = ds, tag) do
    case get_element(ds, tag) do
      %Dicom.DataElement{vr: vr, value: value} when is_binary(value) ->
        Dicom.Value.decode(value, vr)

      %Dicom.DataElement{value: value} ->
        value

      nil ->
        nil
    end
  end

  # Resolves VR for a tag: from existing element, dictionary, or fallback to :UN.
  defp resolve_vr(%__MODULE__{} = ds, tag) do
    case get_element(ds, tag) do
      %Dicom.DataElement{vr: vr} ->
        vr

      nil ->
        case Dicom.Dictionary.Registry.lookup(tag) do
          {:ok, _name, vr, _vm} -> vr
          :error -> :UN
        end
    end
  end
end

defimpl Inspect, for: Dicom.DataSet do
  import Inspect.Algebra

  def inspect(ds, _opts) do
    count = Dicom.DataSet.size(ds)
    parts = ["#{count} elements"]

    parts =
      case Dicom.DataSet.get(ds, {0x0010, 0x0010}) do
        nil -> parts
        patient -> parts ++ ["patient=#{inspect_short(patient)}"]
      end

    parts =
      case Dicom.DataSet.get(ds, {0x0008, 0x0060}) do
        nil -> parts
        modality -> parts ++ ["modality=#{modality}"]
      end

    concat(["#Dicom.DataSet<", Enum.join(parts, ", "), ">"])
  end

  defp inspect_short(value) when is_binary(value), do: "\"#{value}\""
  defp inspect_short(value), do: Kernel.inspect(value)
end

defimpl Enumerable, for: Dicom.DataSet do
  def count(%Dicom.DataSet{} = ds) do
    {:ok, Dicom.DataSet.size(ds)}
  end

  def member?(%Dicom.DataSet{} = ds, %Dicom.DataElement{tag: tag} = element) do
    {:ok, Dicom.DataSet.get_element(ds, tag) == element}
  end

  def member?(%Dicom.DataSet{}, _), do: {:ok, false}

  def reduce(%Dicom.DataSet{} = ds, acc, fun) do
    sorted_elements =
      (Map.values(ds.file_meta) ++ Map.values(ds.elements))
      |> Enum.sort_by(& &1.tag)

    Enumerable.List.reduce(sorted_elements, acc, fun)
  end

  def slice(%Dicom.DataSet{} = ds) do
    size = Dicom.DataSet.size(ds)

    sorted =
      (Map.values(ds.file_meta) ++ Map.values(ds.elements))
      |> Enum.sort_by(& &1.tag)

    {:ok, size,
     fn start, amount, step ->
       sorted
       |> Enum.drop(start)
       |> Enum.take(amount_with_step(amount, step))
       |> take_every(step)
     end}
  end

  defp amount_with_step(amount, 1), do: amount
  defp amount_with_step(amount, step), do: amount * step

  defp take_every(list, 1), do: list
  defp take_every(list, step), do: Enum.take_every(list, step)
end
