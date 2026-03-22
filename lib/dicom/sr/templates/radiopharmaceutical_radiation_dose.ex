defmodule Dicom.SR.Templates.RadiopharmaceuticalRadiationDose do
  @moduledoc """
  Builder for a practical TID 10021 Radiopharmaceutical Radiation Dose Report.

  Nuclear medicine dose tracking. The root container holds observer context,
  procedure-reported modifiers, radiopharmaceutical administration events
  (TID 10022), and per-organ dose estimates (TID 10023).

  Structure:

      CONTAINER: Radiopharmaceutical Radiation Dose Report
        +-- HAS CONCEPT MOD: Language
        +-- HAS OBS CONTEXT: Observer (person and/or device)
        +-- HAS CONCEPT MOD: Procedure Reported
        +-- CONTAINS: Radiopharmaceutical Administration Event (1-n)
        |     +-- CONTAINS: Radiopharmaceutical (CODE)
        |     +-- CONTAINS: Radionuclide (CODE)
        |     +-- CONTAINS: Administered Activity (NUM, MBq)
        |     +-- CONTAINS: Route of Administration (CODE)
        |     +-- CONTAINS: DateTime Started (DATETIME)
        +-- CONTAINS: Organ Dose Information (0-n)
              +-- CONTAINS: Finding Site / target organ (CODE)
              +-- CONTAINS: Organ Dose (NUM, mSv)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    procedure_reported = Keyword.get(opts, :procedure_reported)
    administration_events = Keyword.get(opts, :administration_events, [])
    organ_doses = Keyword.get(opts, :organ_doses, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(procedure_reported))
      |> add_optional(Enum.map(administration_events, &administration_event_item/1))
      |> add_optional(Enum.map(organ_doses, &organ_dose_item/1))

    root =
      ContentItem.container(Codes.radiopharmaceutical_dose_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "10021",
        series_description:
          Keyword.get(opts, :series_description, "Radiopharmaceutical Radiation Dose Report")
      )
    )
  end

  defp administration_event_item(event) do
    children =
      []
      |> add_optional(
        optional_code_item(Map.get(event, :radiopharmaceutical), Codes.radiopharmaceutical())
      )
      |> add_optional(optional_code_item(Map.get(event, :radionuclide), Codes.radionuclide()))
      |> add_optional(
        optional_num_item(event, :administered_activity, Codes.administered_activity())
      )
      |> add_optional(
        optional_code_item(
          Map.get(event, :route_of_administration),
          Codes.route_of_administration()
        )
      )
      |> add_optional(
        optional_datetime_item(
          Map.get(event, :administration_datetime),
          Codes.administration_datetime()
        )
      )

    ContentItem.container(Codes.radiopharmaceutical_administration_event(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp organ_dose_item(organ_dose) do
    children =
      []
      |> add_optional(
        optional_code_item(Map.get(organ_dose, :target_organ), Codes.target_organ())
      )
      |> add_optional(optional_num_item(organ_dose, :dose, Codes.organ_dose()))

    ContentItem.container(Codes.organ_dose_estimate(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_code_item(nil, _concept_name), do: nil

  defp optional_code_item(%Code{} = value, concept_name) do
    ContentItem.code(concept_name, value, relationship_type: "CONTAINS")
  end

  defp optional_num_item(map, key, concept_name) do
    case Map.get(map, key) do
      nil ->
        nil

      %{value: value, units: units} ->
        ContentItem.num(concept_name, value, units, relationship_type: "CONTAINS")
    end
  end

  defp optional_datetime_item(nil, _concept_name), do: nil

  defp optional_datetime_item(datetime, concept_name) do
    ContentItem.datetime(concept_name, datetime, relationship_type: "CONTAINS")
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
