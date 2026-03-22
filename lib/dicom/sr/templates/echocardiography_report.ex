defmodule Dicom.SR.Templates.EchocardiographyReport do
  @moduledoc """
  Builder for a practical TID 5200 Echocardiography Procedure Report document.

  The current builder covers the root document structure, observer context,
  procedure modifier, patient characteristics (height, weight, BSA, blood
  pressure), echo measurement sections, wall motion analysis, and
  narrative summary/findings/impressions/recommendations.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, MeasurementGroup, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    procedure_reported = Keyword.get(opts, :procedure_reported)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional(
        optional_patient_characteristics(Keyword.get(opts, :patient_characteristics))
      )
      |> add_optional(Enum.map(Keyword.get(opts, :echo_sections, []), &echo_section/1))
      |> add_optional(optional_wall_motion(Keyword.get(opts, :wall_motion)))
      |> add_optional(optional_text_item(Codes.summary(), Keyword.get(opts, :summary)))
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :impressions, [])))
      |> add_optional(map_recommendations(Keyword.get(opts, :recommendations, [])))

    root = ContentItem.container(Codes.echocardiography_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "5200",
        series_description:
          Keyword.get(opts, :series_description, "Echocardiography Procedure Report")
      )
    )
  end

  # -- Procedure --

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  # -- Patient Characteristics (TID 5201) --

  defp optional_patient_characteristics(nil), do: nil
  defp optional_patient_characteristics(chars) when map_size(chars) == 0, do: nil

  defp optional_patient_characteristics(chars) when is_map(chars) do
    children =
      []
      |> add_num(Codes.body_height(), chars[:height], cm_unit())
      |> add_num(Codes.body_weight(), chars[:weight], kg_unit())
      |> add_num(Codes.body_surface_area(), chars[:bsa], m2_unit())
      |> add_num(Codes.systolic_blood_pressure(), chars[:bp_systolic], mmhg_unit())
      |> add_num(Codes.diastolic_blood_pressure(), chars[:bp_diastolic], mmhg_unit())

    case children do
      [] ->
        nil

      _ ->
        ContentItem.container(Codes.patient_characteristics(),
          relationship_type: "HAS OBS CONTEXT",
          children: children
        )
    end
  end

  # -- Echo Sections (TID 5202/5203) --

  defp echo_section(section) do
    name = Map.fetch!(section, :name)
    measurements = Map.get(section, :measurements, [])
    qualitative_evaluations = Map.get(section, :qualitative_evaluations, [])

    MeasurementGroup.new(
      section_tracking_id(name),
      Dicom.UID.generate(),
      finding_sites: [name],
      measurements: measurements,
      qualitative_evaluations: map_qualitative_evaluations(qualitative_evaluations)
    )
    |> MeasurementGroup.to_content_item()
  end

  defp section_tracking_id(%Code{meaning: meaning}), do: meaning

  defp map_qualitative_evaluations(evaluations) do
    Enum.map(evaluations, fn
      %ContentItem{} = item ->
        item

      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- Wall Motion Analysis (TID 5204) --

  defp optional_wall_motion(nil), do: nil

  defp optional_wall_motion(wall_motion) when is_map(wall_motion) do
    segments = Map.get(wall_motion, :segments, [])
    wmsi = Map.get(wall_motion, :wmsi)

    segment_children =
      Enum.map(segments, fn segment ->
        ContentItem.code(
          Codes.wall_motion_segment(),
          segment,
          relationship_type: "CONTAINS"
        )
      end)

    wmsi_children =
      case wmsi do
        nil ->
          []

        value ->
          [
            Measurement.new(Codes.wall_motion_score_index(), value, no_unit())
            |> Measurement.to_content_item()
          ]
      end

    ContentItem.container(Codes.wall_motion_analysis(),
      relationship_type: "CONTAINS",
      children: segment_children ++ wmsi_children
    )
  end

  # -- Narrative sections --

  defp optional_text_item(_concept, nil), do: nil

  defp optional_text_item(concept, text) when is_binary(text) do
    ContentItem.text(concept, text, relationship_type: "CONTAINS")
  end

  defp map_findings(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  defp map_impressions(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
    end)
  end

  defp map_recommendations(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.recommendation(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.recommendation(), text, relationship_type: "CONTAINS")
    end)
  end

  # -- Observer --

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  # -- Units --

  defp cm_unit, do: Code.new("cm", "UCUM", "centimeter")
  defp kg_unit, do: Code.new("kg", "UCUM", "kilogram")
  defp m2_unit, do: Code.new("m2", "UCUM", "square meter")
  defp mmhg_unit, do: Code.new("mm[Hg]", "UCUM", "millimeter of mercury")
  defp no_unit, do: Code.new("1", "UCUM", "no units")

  # -- Helpers --

  defp add_num(items, _concept, nil, _units), do: items

  defp add_num(items, concept, value, units) do
    items ++
      [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
