defmodule Dicom.SR.Templates.CTRadiationDose do
  @moduledoc """
  Builder for a practical TID 10011 CT Radiation Dose Report.

  This builder covers the root document structure, observation context,
  procedure-reported modifier, CT accumulated dose data (TID 10012),
  and CT irradiation event data (TID 10013).

  Reference: DICOM PS3.16 TID 10011.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    accumulated_dose = Keyword.fetch!(opts, :accumulated_dose)
    procedure_reported = Keyword.get(opts, :procedure_reported)
    irradiation_events = Keyword.get(opts, :irradiation_events, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional([ct_accumulated_dose_item(accumulated_dose)])
      |> add_optional(Enum.map(irradiation_events, &ct_irradiation_event_item/1))

    root = ContentItem.container(Codes.ct_radiation_dose_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "10011",
        series_description: Keyword.get(opts, :series_description, "CT Radiation Dose Report"),
        sop_class_uid:
          Keyword.get(opts, :sop_class_uid, Dicom.UID.xray_radiation_dose_sr_storage())
      )
    )
  end

  # TID 10012: CT Accumulated Dose Data
  defp ct_accumulated_dose_item(dose) when is_map(dose) do
    children =
      []
      |> add_dose_num(
        :total_dlp,
        Codes.ct_dose_length_product_total(),
        Codes.mgy_cm(),
        dose
      )

    ContentItem.container(Codes.ct_accumulated_dose_data(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # TID 10013: CT Irradiation Event Data
  defp ct_irradiation_event_item(event) when is_map(event) do
    children =
      []
      |> add_event_uid(event)
      |> add_acquisition_type(event)
      |> add_dose_num(:ctdi_vol, Codes.ctdi_vol(), Codes.mgy(), event)
      |> add_dose_num(:dlp, Codes.dlp(), Codes.mgy_cm(), event)
      |> add_dose_num(:scanning_length, Codes.scanning_length(), Codes.millimeter(), event)
      |> add_dose_num(:mean_ctdi_vol, Codes.mean_ctdi_vol(), Codes.mgy(), event)
      |> add_phantom_type(event)

    ContentItem.container(Codes.ct_irradiation_event_data(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp add_event_uid(children, event) do
    case Map.get(event, :irradiation_event_uid) do
      nil ->
        children

      uid ->
        children ++
          [ContentItem.uidref(Codes.irradiation_event_uid(), uid, relationship_type: "CONTAINS")]
    end
  end

  defp add_acquisition_type(children, event) do
    case Map.get(event, :ct_acquisition_type) do
      nil ->
        children

      %Code{} = code ->
        children ++
          [ContentItem.code(Codes.ct_acquisition_type(), code, relationship_type: "CONTAINS")]
    end
  end

  defp add_phantom_type(children, event) do
    case Map.get(event, :phantom_type) do
      nil ->
        children

      %Code{} = code ->
        children ++ [ContentItem.code(Codes.phantom_type(), code, relationship_type: "CONTAINS")]
    end
  end

  defp add_dose_num(children, key, concept, units, data) do
    case Map.get(data, key) do
      nil -> children
      value -> children ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
    end
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end
end
