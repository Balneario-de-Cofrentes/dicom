defmodule Dicom.SR.Reference do
  @moduledoc """
  Reference to a DICOM composite or image object for SR content items.
  """

  alias Dicom.SR.Code
  alias Dicom.UID

  @enforce_keys [:sop_class_uid, :sop_instance_uid]
  defstruct [
    :sop_class_uid,
    :sop_instance_uid,
    purpose: nil,
    frame_numbers: [],
    segment_numbers: []
  ]

  @type t :: %__MODULE__{
          sop_class_uid: String.t(),
          sop_instance_uid: String.t(),
          purpose: Code.t() | nil,
          frame_numbers: [pos_integer()],
          segment_numbers: [pos_integer()]
        }

  @spec new(String.t(), String.t(), keyword()) :: t()
  def new(sop_class_uid, sop_instance_uid, opts \\ [])
      when is_binary(sop_class_uid) and is_binary(sop_instance_uid) do
    ensure_uid!(sop_class_uid, :sop_class_uid)
    ensure_uid!(sop_instance_uid, :sop_instance_uid)

    %__MODULE__{
      sop_class_uid: sop_class_uid,
      sop_instance_uid: sop_instance_uid,
      purpose: Keyword.get(opts, :purpose),
      frame_numbers:
        normalize_positive_list(Keyword.get(opts, :frame_numbers, []), :frame_numbers),
      segment_numbers:
        normalize_positive_list(Keyword.get(opts, :segment_numbers, []), :segment_numbers)
    }
  end

  defp ensure_uid!(uid, field) do
    if UID.valid?(uid) do
      :ok
    else
      raise ArgumentError, "expected #{field} to be a valid UID"
    end
  end

  defp normalize_positive_list(values, _field) when values == [], do: []

  defp normalize_positive_list(values, field) when is_list(values) do
    Enum.map(values, fn
      value when is_integer(value) and value > 0 -> value
      _other -> raise ArgumentError, "expected #{field} to contain only positive integers"
    end)
  end

  defp normalize_positive_list(_values, field) do
    raise ArgumentError, "expected #{field} to be a list of positive integers"
  end
end
