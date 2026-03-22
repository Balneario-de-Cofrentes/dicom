defmodule Dicom.SR.Templates.HemodynamicsReport do
  @moduledoc """
  Builder for a practical TID 3500 Hemodynamics Report document.

  Hemodynamics Reports document cardiac catheterization hemodynamic
  measurements including pressures, gradients, cardiac output, blood
  velocity, and derived calculations.

  The builder covers the normative root title, language modifier,
  observer context, procedure modifier, clinical context (patient state
  and medications), repeating hemodynamic measurement groups, derived
  measurements, findings, conclusions, and summary.
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
      |> add_optional(optional_clinical_context(Keyword.get(opts, :clinical_context)))
      |> add_optional(optional_measurement_groups(Keyword.get(opts, :measurement_groups, [])))
      |> add_optional(optional_derived_measurements(Keyword.get(opts, :derived_measurements, [])))
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_conclusions(Keyword.get(opts, :conclusions, [])))
      |> add_optional(optional_summary(Keyword.get(opts, :summary)))

    root = ContentItem.container(Codes.hemodynamic_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3500",
        series_description: Keyword.get(opts, :series_description, "Hemodynamics Report")
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_clinical_context(nil), do: nil
  defp optional_clinical_context([]), do: nil

  defp optional_clinical_context(context) when is_list(context) do
    children =
      []
      |> add_optional(optional_patient_state(Keyword.get(context, :patient_state)))
      |> add_optional(Enum.map(Keyword.get(context, :medications, []), &medication_item/1))

    case children do
      [] -> nil
      items -> items
    end
  end

  defp optional_patient_state(nil), do: nil

  defp optional_patient_state(state) when is_binary(state) do
    ContentItem.text(Codes.patient_state(), state, relationship_type: "HAS OBS CONTEXT")
  end

  defp optional_patient_state(%Code{} = state) do
    ContentItem.code(Codes.patient_state(), state, relationship_type: "HAS OBS CONTEXT")
  end

  defp medication_item(medication) when is_binary(medication) do
    ContentItem.text(Codes.medication_administered(), medication,
      relationship_type: "HAS OBS CONTEXT"
    )
  end

  defp medication_item(%Code{} = medication) do
    ContentItem.code(Codes.medication_administered(), medication,
      relationship_type: "HAS OBS CONTEXT"
    )
  end

  defp optional_measurement_groups([]), do: nil

  defp optional_measurement_groups(groups) do
    ContentItem.container(Codes.hemodynamic_measurements(),
      relationship_type: "CONTAINS",
      children: Enum.map(groups, &measurement_group_item/1)
    )
  end

  defp measurement_group_item(%MeasurementGroup{} = group) do
    MeasurementGroup.to_content_item(group)
  end

  defp measurement_group_item(%{} = group) do
    name = Map.fetch!(group, :name)
    measurements = Map.get(group, :measurements, [])

    MeasurementGroup.new(name, Dicom.UID.generate(),
      activity_session: name,
      measurements: measurements,
      qualitative_evaluations: map_findings(Map.get(group, :findings, []))
    )
    |> MeasurementGroup.to_content_item()
  end

  defp optional_derived_measurements([]), do: nil

  defp optional_derived_measurements(measurements) do
    ContentItem.container(Codes.derived_hemodynamic_measurements(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end

  defp map_findings(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  defp map_conclusions(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.conclusion(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.conclusion(), text, relationship_type: "CONTAINS")
    end)
  end

  defp optional_summary(nil), do: nil

  defp optional_summary(summary) when is_binary(summary) do
    ContentItem.text(Codes.impression(), summary, relationship_type: "CONTAINS")
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
