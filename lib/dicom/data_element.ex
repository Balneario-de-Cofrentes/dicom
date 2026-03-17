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
