defmodule Dicom.SR.Tcoord do
  @moduledoc """
  Temporal coordinate reference for SR content items.

  Defines a temporal region in a waveform or time series by specifying
  a range type and one of: sample positions, time offsets, or datetime values.
  """

  @temporal_range_types ~w(POINT MULTIPOINT SEGMENT MULTISEGMENT BEGIN END)

  @enforce_keys [:temporal_range_type]
  defstruct [
    :temporal_range_type,
    sample_positions: [],
    time_offsets: [],
    datetime_values: []
  ]

  @type t :: %__MODULE__{
          temporal_range_type: String.t(),
          sample_positions: [pos_integer()],
          time_offsets: [number()],
          datetime_values: [String.t()]
        }

  @spec new(String.t(), keyword()) :: t()
  def new(temporal_range_type, opts \\ [])
      when is_binary(temporal_range_type) do
    normalized_type = String.upcase(temporal_range_type)

    unless normalized_type in @temporal_range_types do
      raise ArgumentError,
            "unsupported temporal_range_type #{inspect(temporal_range_type)}, " <>
              "expected one of: #{Enum.join(@temporal_range_types, ", ")}"
    end

    sample_positions = Keyword.get(opts, :sample_positions, [])
    time_offsets = Keyword.get(opts, :time_offsets, [])
    datetime_values = Keyword.get(opts, :datetime_values, [])

    validate_exactly_one_reference!(sample_positions, time_offsets, datetime_values)

    %__MODULE__{
      temporal_range_type: normalized_type,
      sample_positions: sample_positions,
      time_offsets: time_offsets,
      datetime_values: datetime_values
    }
  end

  defp validate_exactly_one_reference!(sample_positions, time_offsets, datetime_values) do
    non_empty_count =
      [sample_positions != [], time_offsets != [], datetime_values != []]
      |> Enum.count(& &1)

    unless non_empty_count == 1 do
      raise ArgumentError,
            "exactly one of :sample_positions, :time_offsets, or :datetime_values must be provided"
    end
  end
end
