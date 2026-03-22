defmodule Dicom.SR.Templates.WaveformAnnotation do
  @moduledoc """
  Builder for a practical TID 3750 Waveform Annotation document.

  Waveform Annotations are SR documents for annotating waveform data
  (ECG, EEG, hemodynamic, etc.) with temporal coordinate references.
  The document references a waveform SOP instance and can contain
  pattern/event annotations, numeric measurements, and text notes,
  each associated with temporal coordinates within the waveform.

  Structure:

      CONTAINER: Waveform Annotation (root)
        +-- HAS CONCEPT MOD: Language (TID 1204, defaults to en-US)
        +-- HAS OBS CONTEXT: Observer (TID 1002, person and/or device)
        +-- CONTAINS: COMPOSITE reference to waveform SOP instance
        +-- CONTAINS: Annotation items (repeating, any of):
            +-- CODE: pattern/event with TCOORD temporal coordinates
            +-- NUM: measurement with TCOORD temporal coordinates
            +-- TEXT: annotation note with optional TCOORD coordinates
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, Observer, Reference, Tcoord}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    waveform_reference = Keyword.fetch!(opts, :waveform_reference)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional([waveform_composite_item(waveform_reference)])
      |> add_optional(build_patterns(Keyword.get(opts, :patterns, [])))
      |> add_optional(build_measurements(Keyword.get(opts, :measurements, [])))
      |> add_optional(build_notes(Keyword.get(opts, :notes, [])))
      |> add_optional(build_annotations(Keyword.get(opts, :annotations, [])))

    root = ContentItem.container(Codes.waveform_annotation(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3750",
        series_description: Keyword.get(opts, :series_description, "Waveform Annotation")
      )
    )
  end

  defp waveform_composite_item(%Reference{} = reference) do
    ContentItem.composite(Codes.waveform_reference(), reference, relationship_type: "CONTAINS")
  end

  defp build_patterns(patterns) do
    Enum.map(patterns, fn pattern ->
      code = Map.fetch!(pattern, :code)
      tcoord = Map.fetch!(pattern, :tcoord)

      ContentItem.code(Codes.finding(), code,
        relationship_type: "CONTAINS",
        children: [tcoord_item(tcoord)]
      )
    end)
  end

  defp build_measurements(measurements) do
    Enum.map(measurements, fn measurement_spec ->
      tcoord = Map.get(measurement_spec, :tcoord)

      measurement = %Measurement{
        name: Map.fetch!(measurement_spec, :name),
        value: Map.fetch!(measurement_spec, :value),
        units: Map.fetch!(measurement_spec, :units)
      }

      item = Measurement.to_content_item(measurement)

      if tcoord do
        %{item | children: item.children ++ [tcoord_item(tcoord)]}
      else
        item
      end
    end)
  end

  defp build_notes(notes) do
    Enum.map(notes, fn note ->
      text = Map.fetch!(note, :text)
      tcoord = Map.get(note, :tcoord)

      children = if tcoord, do: [tcoord_item(tcoord)], else: []

      ContentItem.text(Codes.comment(), text,
        relationship_type: "CONTAINS",
        children: children
      )
    end)
  end

  defp build_annotations(annotations) do
    Enum.flat_map(annotations, fn
      %{type: :pattern} = annotation ->
        build_patterns([annotation])

      %{type: :measurement} = annotation ->
        build_measurements([annotation])

      %{type: :note} = annotation ->
        build_notes([annotation])
    end)
  end

  defp tcoord_item(%Tcoord{} = tcoord) do
    ContentItem.tcoord(Codes.finding(), tcoord, relationship_type: "INFERRED FROM")
  end

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
