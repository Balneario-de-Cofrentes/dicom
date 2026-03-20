defmodule Dicom.SR.Scoord3D do
  @moduledoc """
  Three-dimensional spatial coordinate reference for SR content items.

  Unlike `Scoord2D`, which references an image via a SOP reference,
  `Scoord3D` coordinates are in the patient coordinate system (mm)
  and reference a Frame of Reference UID instead.

  Reference: DICOM PS3.3 Section C.18.9 (3D Spatial Coordinates Macro).
  """

  @graphic_types ~w(POINT MULTIPOINT POLYLINE POLYGON ELLIPSE ELLIPSOID)

  @enforce_keys [:graphic_type, :graphic_data, :frame_of_reference_uid]
  defstruct [:graphic_type, :graphic_data, :frame_of_reference_uid]

  @type t :: %__MODULE__{
          graphic_type: String.t(),
          graphic_data: [number()],
          frame_of_reference_uid: String.t()
        }

  @doc """
  Creates a new 3D spatial coordinate with validation.

  ## Parameters

    * `graphic_type` — one of POINT, MULTIPOINT, POLYLINE, POLYGON, ELLIPSE, ELLIPSOID
    * `graphic_data` — list of coordinate triples (x, y, z) in mm
    * `frame_of_reference_uid` — Referenced Frame of Reference UID (3006,0024)

  ## Validation rules

    * POINT: exactly 3 values (one triple)
    * MULTIPOINT: divisible by 3, minimum 3
    * POLYLINE: divisible by 3, minimum 6
    * POLYGON: divisible by 3, minimum 9
    * ELLIPSE: exactly 12 values (4 points)
    * ELLIPSOID: exactly 18 values (6 points)
  """
  @spec new(String.t(), [number()], String.t()) :: t()
  def new(graphic_type, graphic_data, frame_of_reference_uid)
      when is_binary(graphic_type) and is_list(graphic_data) and
             is_binary(frame_of_reference_uid) do
    normalized_type = String.upcase(graphic_type)

    unless normalized_type in @graphic_types do
      raise ArgumentError, "unsupported SCOORD3D graphic_type #{inspect(graphic_type)}"
    end

    unless Enum.all?(graphic_data, &is_number/1) do
      raise ArgumentError, "expected graphic_data to contain only numbers"
    end

    validate_graphic_data!(normalized_type, graphic_data)

    %__MODULE__{
      graphic_type: normalized_type,
      graphic_data: graphic_data,
      frame_of_reference_uid: frame_of_reference_uid
    }
  end

  defp validate_graphic_data!("POINT", [_x, _y, _z]), do: :ok

  defp validate_graphic_data!("MULTIPOINT", data)
       when rem(length(data), 3) == 0 and length(data) >= 3,
       do: :ok

  defp validate_graphic_data!("POLYLINE", data)
       when rem(length(data), 3) == 0 and length(data) >= 6,
       do: :ok

  defp validate_graphic_data!("POLYGON", data)
       when rem(length(data), 3) == 0 and length(data) >= 9,
       do: :ok

  defp validate_graphic_data!("ELLIPSE", data) when length(data) == 12, do: :ok
  defp validate_graphic_data!("ELLIPSOID", data) when length(data) == 18, do: :ok

  defp validate_graphic_data!(graphic_type, graphic_data) do
    raise ArgumentError,
          "invalid graphic_data #{inspect(graphic_data)} for SCOORD3D graphic_type #{graphic_type}"
  end
end
