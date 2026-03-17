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
end
