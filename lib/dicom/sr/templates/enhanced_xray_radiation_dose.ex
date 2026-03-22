defmodule Dicom.SR.Templates.EnhancedXrayRadiationDose do
  @moduledoc """
  Builder for a practical TID 10040 Enhanced X-Ray Radiation Dose Report.

  Enhanced dose reporting for CBCT, tomosynthesis, and advanced X-ray
  modalities. The root container holds observer context, procedure-reported
  modifiers, accumulated dose data (TID 10041), irradiation event summaries
  (TID 10042), and irradiation details (TID 10043).

  Structure:

      CONTAINER: X-Ray Radiation Dose Report
        +-- HAS CONCEPT MOD: Language
        +-- HAS OBS CONTEXT: Observer (person and/or device)
        +-- HAS CONCEPT MOD: Procedure Reported
        +-- CONTAINS: Accumulated Dose Data (0-1)
        |     +-- CONTAINS: measurements (NUM, mGy)
        +-- CONTAINS: Irradiation Event (0-n)
        |     +-- CONTAINS: measurements and details
        +-- CONTAINS: Irradiation Event Data (0-n)
              +-- CONTAINS: detailed event measurements
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    procedure_reported = Keyword.get(opts, :procedure_reported)
    accumulated_dose = Keyword.get(opts, :accumulated_dose)
    irradiation_events = Keyword.get(opts, :irradiation_events, [])
    irradiation_details = Keyword.get(opts, :irradiation_details, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional(optional_accumulated_dose(accumulated_dose))
      |> add_optional(Enum.map(irradiation_events, &irradiation_event_item/1))
      |> add_optional(Enum.map(irradiation_details, &irradiation_details_item/1))

    root = ContentItem.container(Codes.enhanced_xray_dose_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "10040",
        series_description:
          Keyword.get(opts, :series_description, "Enhanced X-Ray Radiation Dose Report")
      )
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_accumulated_dose(nil), do: nil

  defp optional_accumulated_dose(%{measurements: measurements}) do
    ContentItem.container(Codes.accumulated_dose(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end

  defp irradiation_event_item(event) do
    measurements = Map.get(event, :measurements, [])

    ContentItem.container(Codes.irradiation_event_summary(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end

  defp irradiation_details_item(details) do
    measurements = Map.get(details, :measurements, [])

    ContentItem.container(Codes.irradiation_details(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurements, &Measurement.to_content_item/1)
    )
  end
end
