defmodule Dicom.DataElement do
  @moduledoc """
  A single DICOM Data Element.

  A data element is the fundamental unit of a DICOM data set, consisting of:
  - **Tag**: `{group, element}` pair identifying the attribute
  - **VR**: Value Representation (data type)
  - **Value**: The actual data (binary, string, integer, etc.)
  - **Length**: Byte length of the value field

  Reference: DICOM PS3.5 Section 7.1.
  """

  @type tag :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          tag: tag(),
          vr: Dicom.VR.t(),
          value: binary() | term(),
          length: non_neg_integer() | :undefined
        }

  defstruct [:tag, :vr, :value, length: 0]

  @doc """
  Creates a new data element.
  """
  @spec new(tag(), Dicom.VR.t(), term()) :: t()
  def new(tag, vr, value) when is_binary(value) do
    %__MODULE__{tag: tag, vr: vr, value: value, length: byte_size(value)}
  end

  def new(tag, vr, value) do
    %__MODULE__{tag: tag, vr: vr, value: value, length: 0}
  end
end

defimpl Inspect, for: Dicom.DataElement do
  import Inspect.Algebra

  def inspect(%Dicom.DataElement{tag: tag, vr: vr, value: value}, opts) do
    tag_str = Dicom.Tag.format(tag)
    vr_str = Atom.to_string(vr)
    value_str = format_value(value, vr, opts)
    concat(["#Dicom.DataElement<", tag_str, " ", vr_str, " ", value_str, ">"])
  end

  defp format_value({:encapsulated, fragments}, _vr, _opts) when is_list(fragments) do
    "#{length(fragments)} fragments"
  end

  defp format_value(items, :SQ, _opts) when is_list(items) do
    "#{length(items)} items"
  end

  defp format_value(binary, _vr, _opts) when is_binary(binary) and byte_size(binary) > 64 do
    truncated = binary_part(binary, 0, 64)

    if String.printable?(truncated) do
      "\"#{truncated}...\""
    else
      "<<#{byte_size(binary)} bytes>>"
    end
  end

  defp format_value(binary, _vr, opts) when is_binary(binary) do
    if String.printable?(binary) do
      Inspect.inspect(binary, opts)
    else
      "<<#{byte_size(binary)} bytes>>"
    end
  end

  defp format_value(other, _vr, opts) do
    Inspect.inspect(other, opts)
  end
end
