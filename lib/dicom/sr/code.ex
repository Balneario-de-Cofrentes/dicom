defmodule Dicom.SR.Code do
  @moduledoc """
  A coded concept used in SR trees.
  """

  alias Dicom.{DataElement, Tag}

  @enforce_keys [:value, :scheme_designator, :meaning]
  defstruct [:value, :scheme_designator, :meaning, :scheme_version]

  @type t :: %__MODULE__{
          value: String.t(),
          scheme_designator: String.t(),
          meaning: String.t(),
          scheme_version: String.t() | nil
        }

  @spec new(String.t(), String.t(), String.t(), keyword()) :: t()
  def new(value, scheme_designator, meaning, opts \\ [])
      when is_binary(value) and is_binary(scheme_designator) and is_binary(meaning) do
    ensure_present!(value, :value)
    ensure_present!(scheme_designator, :scheme_designator)
    ensure_present!(meaning, :meaning)

    %__MODULE__{
      value: value,
      scheme_designator: scheme_designator,
      meaning: meaning,
      scheme_version: Keyword.get(opts, :scheme_version)
    }
  end

  @spec to_item(t()) :: map()
  def to_item(%__MODULE__{} = code) do
    base = %{
      Tag.code_value() => DataElement.new(Tag.code_value(), :SH, code.value),
      Tag.coding_scheme_designator() =>
        DataElement.new(Tag.coding_scheme_designator(), :SH, code.scheme_designator),
      Tag.code_meaning() => DataElement.new(Tag.code_meaning(), :LO, code.meaning)
    }

    if code.scheme_version do
      Map.put(
        base,
        Tag.coding_scheme_version(),
        DataElement.new(Tag.coding_scheme_version(), :SH, code.scheme_version)
      )
    else
      base
    end
  end

  defp ensure_present!(value, field) do
    if String.trim(value) == "" do
      raise ArgumentError, "expected #{field} to be a non-empty string"
    end
  end
end
