defmodule Dicom.SR.Templates.ECGReport do
  @moduledoc """
  Builder for a practical TID 3700 ECG Report document.

  The current builder covers the normative root title, procedure modifier,
  observer context, global measurements, lead measurement groups, generic
  findings, and summary impressions.
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
      |> add_optional(map_text_or_code_items(Keyword.get(opts, :reasons, []), "CONTAINS"))
      |> add_optional(optional_global_measurements(Keyword.get(opts, :global_measurements, [])))
      |> add_optional(optional_lead_measurements(Keyword.get(opts, :lead_measurements, [])))
      |> add_optional(map_findings(Keyword.get(opts, :findings, [])))
      |> add_optional(map_impressions(Keyword.get(opts, :summary, [])))

    root = ContentItem.container(Codes.ecg_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "3700",
        series_description: Keyword.get(opts, :series_description, "ECG Report")
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_global_measurements([]), do: nil

  defp optional_global_measurements(measurements) do
    ContentItem.container(Codes.ecg_global_measurements(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end

  defp optional_lead_measurements([]), do: nil

  defp optional_lead_measurements(lead_groups) do
    ContentItem.container(Codes.ecg_lead_measurements(),
      relationship_type: "CONTAINS",
      children:
        Enum.map(lead_groups, fn lead_group ->
          lead = Map.fetch!(lead_group, :lead)
          measurements = Map.get(lead_group, :measurements, [])

          MeasurementGroup.new("lead:#{lead}", Dicom.UID.generate(),
            activity_session: lead,
            measurements: measurements
          )
          |> MeasurementGroup.to_content_item()
        end)
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

  defp map_impressions(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
    end)
  end

  defp map_text_or_code_items(values, relationship_type) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: relationship_type)

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: relationship_type)
    end)
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
