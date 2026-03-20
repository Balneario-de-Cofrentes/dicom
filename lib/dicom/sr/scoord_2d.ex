defmodule Dicom.SR.Scoord2D do
  @moduledoc """
  Two-dimensional spatial coordinate reference for SR content items.
  """

  alias Dicom.SR.Reference

  @graphic_types ~w(POINT MULTIPOINT POLYLINE CIRCLE ELLIPSE)

  @enforce_keys [:reference, :graphic_type, :graphic_data]
  defstruct [:reference, :graphic_type, :graphic_data]

  @type t :: %__MODULE__{
          reference: Reference.t(),
          graphic_type: String.t(),
          graphic_data: [number()]
        }

  @spec new(Reference.t(), String.t(), [number()]) :: t()
  def new(%Reference{} = reference, graphic_type, graphic_data)
      when is_binary(graphic_type) and is_list(graphic_data) do
    normalized_type = String.upcase(graphic_type)

    unless normalized_type in @graphic_types do
      raise ArgumentError, "unsupported SCOORD graphic_type #{inspect(graphic_type)}"
    end

    unless Enum.all?(graphic_data, &is_number/1) do
      raise ArgumentError, "expected graphic_data to contain only numbers"
    end

    validate_graphic_data!(normalized_type, graphic_data)

    %__MODULE__{
      reference: reference,
      graphic_type: normalized_type,
      graphic_data: graphic_data
    }
  end

  defp validate_graphic_data!("POINT", [_x, _y]), do: :ok

  defp validate_graphic_data!("MULTIPOINT", data)
       when rem(length(data), 2) == 0 and length(data) >= 2,
       do: :ok

  defp validate_graphic_data!("POLYLINE", data)
       when rem(length(data), 2) == 0 and length(data) >= 4,
       do: :ok

  defp validate_graphic_data!("CIRCLE", [_x1, _y1, _x2, _y2]), do: :ok
  defp validate_graphic_data!("ELLIPSE", data) when length(data) == 8, do: :ok

  defp validate_graphic_data!(graphic_type, graphic_data) do
    raise ArgumentError,
          "invalid graphic_data #{inspect(graphic_data)} for SCOORD graphic_type #{graphic_type}"
  end
end
