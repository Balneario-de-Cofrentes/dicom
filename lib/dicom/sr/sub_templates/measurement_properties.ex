defmodule Dicom.SR.SubTemplates.MeasurementProperties do
  @moduledoc """
  TID 300-315 and TID 1501-1502 Measurement Properties Sub-Templates.

  Implements the measurement properties sub-template hierarchy:

  - TID 300  — Measurement
  - TID 301  — Measurement Content
  - TID 310  — Measurement Properties
  - TID 311  — Measurement Statistical Properties
  - TID 312  — Normal Range Properties
  - TID 314  — Ratio
  - TID 315  — Equation or Table
  - TID 1501 — Measurement and Qualitative Evaluation Group
  - TID 1502 — Time Point Context

  These sub-templates provide measurement property modifiers, statistical
  annotations, normal range specifications, and time-point context for
  SR measurement content items.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 300: Measurement --------------------------------------------------

  @doc """
  Builds TID 300 Measurement content items.

  A top-level measurement with concept name, value, units, and optional
  measurement properties (TID 310).

  ## Options

    * `:concept` — (required) measurement concept Code
    * `:value` — (required) numeric value
    * `:units` — (required) units Code
    * `:properties` — measurement properties (keyword, see `measurement_properties/1`)
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec measurement(keyword()) :: [ContentItem.t()]
  def measurement(opts) when is_list(opts) do
    concept = Keyword.fetch!(opts, :concept)
    value = Keyword.fetch!(opts, :value)
    units = Keyword.fetch!(opts, :units)
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    children = properties_children(opts[:properties])

    [
      ContentItem.num(concept, value, units,
        relationship_type: rel,
        children: children
      )
    ]
  end

  # -- TID 301: Measurement Content ------------------------------------------

  @doc """
  Builds TID 301 Measurement Content as a CONTAINER with child measurements.

  ## Options

    * `:concept` — (required) container concept Code
    * `:measurements` — list of measurement keyword options (each passed
      to `measurement/1`)
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec measurement_content(keyword()) :: [ContentItem.t()]
  def measurement_content(opts) when is_list(opts) do
    concept = Keyword.fetch!(opts, :concept)
    measurements = Keyword.get(opts, :measurements, [])
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    children = Enum.flat_map(measurements, &measurement/1)

    [
      ContentItem.container(concept,
        relationship_type: rel,
        children: children
      )
    ]
  end

  # -- TID 310: Measurement Properties --------------------------------------

  @doc """
  Builds TID 310 Measurement Properties content items.

  Returns modifier content items that annotate a measurement with
  statistical properties, normal ranges, and population descriptions.

  ## Options

    * `:statistical` — statistical properties (keyword, see `statistical_properties/1`)
    * `:normal_range` — normal range properties (keyword, see `normal_range_properties/1`)
    * `:selection_status` — measurement selection status Code
    * `:population_description` — description of measurement population (TEXT)
    * `:authority` — measurement authority (TEXT)

  """
  @spec measurement_properties(keyword()) :: [ContentItem.t()]
  def measurement_properties(opts) when is_list(opts) do
    []
    |> add_items(statistical_items(opts[:statistical]))
    |> add_items(normal_range_items(opts[:normal_range]))
    |> add_code_child(Codes.selection_status(), opts[:selection_status])
    |> add_text_child(Codes.population_description(), opts[:population_description])
    |> add_text_child(Codes.measurement_authority(), opts[:authority])
  end

  # -- TID 311: Measurement Statistical Properties --------------------------

  @doc """
  Builds TID 311 Measurement Statistical Properties content items.

  ## Options

    * `:description` — statistical description Code (e.g., Mean, Median)
    * `:value_for_n` — value for N (number of observations)
    * `:units_for_n` — units for N (typically "1" = no units)

  """
  @spec statistical_properties(keyword()) :: [ContentItem.t()]
  def statistical_properties(opts) when is_list(opts) do
    []
    |> add_code_child(Codes.statistical_description(), opts[:description])
    |> add_num_child(Codes.value_for_n(), opts[:value_for_n], opts[:units_for_n])
  end

  # -- TID 312: Normal Range Properties -------------------------------------

  @doc """
  Builds TID 312 Normal Range Properties content items.

  ## Options

    * `:upper` — upper normal value (number, with `:upper_units`)
    * `:upper_units` — units for upper value
    * `:lower` — lower normal value (number, with `:lower_units`)
    * `:lower_units` — units for lower value
    * `:description` — normal range description (TEXT)

  """
  @spec normal_range_properties(keyword()) :: [ContentItem.t()]
  def normal_range_properties(opts) when is_list(opts) do
    []
    |> add_num_child(Codes.normal_range_upper(), opts[:upper], opts[:upper_units])
    |> add_num_child(Codes.normal_range_lower(), opts[:lower], opts[:lower_units])
    |> add_text_child(Codes.normal_range_description(), opts[:description])
  end

  # -- TID 314: Ratio -------------------------------------------------------

  @doc """
  Builds TID 314 Ratio content items.

  Represents a ratio between two NUM values (numerator / denominator).

  ## Options

    * `:concept` — (required) ratio concept Code
    * `:numerator` — (required) numerator value (number)
    * `:numerator_units` — (required) numerator units Code
    * `:denominator` — (required) denominator value (number)
    * `:denominator_units` — (required) denominator units Code
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec ratio(keyword()) :: [ContentItem.t()]
  def ratio(opts) when is_list(opts) do
    concept = Keyword.fetch!(opts, :concept)
    num_val = Keyword.fetch!(opts, :numerator)
    num_units = Keyword.fetch!(opts, :numerator_units)
    den_val = Keyword.fetch!(opts, :denominator)
    den_units = Keyword.fetch!(opts, :denominator_units)
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")

    children = [
      ContentItem.num(Codes.numerator(), num_val, num_units, relationship_type: "HAS PROPERTIES"),
      ContentItem.num(Codes.denominator(), den_val, den_units,
        relationship_type: "HAS PROPERTIES"
      )
    ]

    [
      ContentItem.container(concept,
        relationship_type: rel,
        children: children
      )
    ]
  end

  # -- TID 315: Equation or Table -------------------------------------------

  @doc """
  Builds TID 315 Equation or Table content items.

  ## Options

    * `:equation` — equation text (TEXT)
    * `:table` — table reference or description (TEXT)
    * `:algorithm_name` — algorithm name (TEXT)
    * `:algorithm_version` — algorithm version (TEXT)

  """
  @spec equation_or_table(keyword()) :: [ContentItem.t()]
  def equation_or_table(opts) when is_list(opts) do
    []
    |> add_text_child(Codes.equation_or_table(), opts[:equation])
    |> add_text_child(Codes.table(), opts[:table])
    |> add_text_child(Codes.algorithm_name(), opts[:algorithm_name])
    |> add_text_child(Codes.algorithm_version(), opts[:algorithm_version])
  end

  # -- TID 1501: Measurement and Qualitative Evaluation Group ---------------

  @doc """
  Builds TID 1501 Measurement and Qualitative Evaluation Group.

  A container grouping measurements, qualitative evaluations, tracking
  identifiers, and finding context for a measured entity.

  ## Options

    * `:tracking_identifier` — tracking identifier (TEXT)
    * `:tracking_uid` — tracking unique identifier (UID)
    * `:finding` — finding Code
    * `:finding_site` — finding site Code
    * `:measurements` — list of measurement keyword options
    * `:evaluations` — list of `{concept, value}` Code tuples
    * `:time_point` — time point context (keyword, see `time_point_context/1`)
    * `:relationship_type` — relationship type (default: "CONTAINS")

  """
  @spec measurement_group(keyword()) :: [ContentItem.t()]
  def measurement_group(opts) when is_list(opts) do
    rel = Keyword.get(opts, :relationship_type, "CONTAINS")
    measurements = Keyword.get(opts, :measurements, [])
    evaluations = Keyword.get(opts, :evaluations, [])

    children =
      []
      |> add_text_child(Codes.tracking_identifier(), opts[:tracking_identifier])
      |> add_uidref_child(Codes.tracking_unique_identifier(), opts[:tracking_uid])
      |> add_code_child(Codes.finding(), opts[:finding])
      |> add_code_child(Codes.finding_site(), opts[:finding_site])
      |> add_items(time_point_items(opts[:time_point]))
      |> add_items(build_measurements(measurements))
      |> add_items(build_evaluations(evaluations))

    [
      ContentItem.container(Codes.measurement_group(),
        relationship_type: rel,
        children: children
      )
    ]
  end

  # -- TID 1502: Time Point Context -----------------------------------------

  @doc """
  Builds TID 1502 Time Point Context content items.

  ## Options

    * `:time_point` — time point identifier (TEXT)
    * `:time_point_type` — time point type Code (e.g., Baseline, Follow-up)
    * `:time_point_order` — ordinal position (number, with optional `:order_units`)
    * `:order_units` — units for time point order
    * `:subject_time_point_identifier` — subject-specific time point ID (TEXT)
    * `:protocol_time_point_identifier` — protocol-specific time point ID (TEXT)
    * `:temporal_offset_from_event` — temporal offset (number, with `:offset_units`)
    * `:offset_units` — units for temporal offset
    * `:event` — reference event Code

  """
  @spec time_point_context(keyword()) :: [ContentItem.t()]
  def time_point_context(opts) when is_list(opts) do
    []
    |> add_text_child(Codes.time_point(), opts[:time_point])
    |> add_code_child(Codes.time_point_type(), opts[:time_point_type])
    |> add_num_child(Codes.time_point_order(), opts[:time_point_order], opts[:order_units])
    |> add_text_child(
      Codes.subject_time_point_identifier(),
      opts[:subject_time_point_identifier]
    )
    |> add_text_child(
      Codes.protocol_time_point_identifier(),
      opts[:protocol_time_point_identifier]
    )
    |> add_num_child(
      Codes.temporal_offset_from_event(),
      opts[:temporal_offset_from_event],
      opts[:offset_units]
    )
    |> add_code_child(Codes.temporal_event(), opts[:event])
  end

  # -- Private helpers -------------------------------------------------------

  defp properties_children(nil), do: []
  defp properties_children(opts), do: measurement_properties(opts)

  defp statistical_items(nil), do: []
  defp statistical_items(opts), do: statistical_properties(opts)

  defp normal_range_items(nil), do: []
  defp normal_range_items(opts), do: normal_range_properties(opts)

  defp time_point_items(nil), do: []
  defp time_point_items(opts), do: time_point_context(opts)

  defp build_measurements(measurements) do
    Enum.flat_map(measurements, &measurement/1)
  end

  defp build_evaluations(evaluations) do
    Enum.map(evaluations, fn {concept, value} ->
      ContentItem.code(concept, value, relationship_type: "CONTAINS")
    end)
  end

  defp add_items(items, []), do: items
  defp add_items(items, more), do: items ++ more

  defp add_code_child(children, _concept, nil), do: children

  defp add_code_child(children, concept, %Code{} = code) do
    children ++ [ContentItem.code(concept, code, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_text_child(children, _concept, nil), do: children

  defp add_text_child(children, concept, text) when is_binary(text) do
    children ++ [ContentItem.text(concept, text, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_uidref_child(children, _concept, nil), do: children

  defp add_uidref_child(children, concept, uid) when is_binary(uid) do
    children ++ [ContentItem.uidref(concept, uid, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, _concept, nil, _units), do: children

  defp add_num_child(children, concept, value, nil) when is_number(value) do
    no_units = Code.new("1", "UCUM", "no units")
    children ++ [ContentItem.num(concept, value, no_units, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, concept, value, %Code{} = units) when is_number(value) do
    children ++ [ContentItem.num(concept, value, units, relationship_type: "HAS CONCEPT MOD")]
  end
end
