defmodule Dicom.SR.Templates.PatientRadiationDose do
  @moduledoc """
  Builder for a practical TID 10030 Patient Radiation Dose Report.

  Patient-level dose summary aggregating across procedures. The root container
  holds observer context and repeating radiation dose estimate sections
  (TID 10031), each containing the dose type, value, methodology (TID 10033),
  and estimation parameters (TID 10034).

  Structure:

      CONTAINER: Patient Radiation Dose Report
        +-- HAS CONCEPT MOD: Language
        +-- HAS OBS CONTEXT: Observer (person and/or device)
        +-- CONTAINS: Radiation Dose Estimate (1-n)
              +-- CONTAINS: Dose Estimate type (CODE: effective dose, organ dose)
              +-- CONTAINS: Dose value (NUM, mSv)
              +-- CONTAINS: Dose Estimation Methodology (TEXT or CODE)
              +-- CONTAINS: Dose Estimation Parameters (TEXT or CODE, 0-n)
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    dose_estimates = Keyword.get(opts, :dose_estimates, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(Enum.map(dose_estimates, &dose_estimate_item/1))

    root =
      ContentItem.container(Codes.patient_radiation_dose_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "10030",
        series_description:
          Keyword.get(opts, :series_description, "Patient Radiation Dose Report")
      )
    )
  end

  defp dose_estimate_item(estimate) do
    children =
      []
      |> add_optional(
        optional_code_item(Map.get(estimate, :dose_type), Codes.dose_estimate_type())
      )
      |> add_optional(optional_num_item(estimate, :dose_value, Codes.dose_estimate()))
      |> add_optional(optional_methodology(Map.get(estimate, :methodology)))
      |> add_optional(Enum.map(Map.get(estimate, :parameters, []), &parameter_item/1))

    ContentItem.container(Codes.radiation_dose_estimate(),
      relationship_type: "CONTAINS",
      children: children
    )
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

  defp optional_methodology(nil), do: nil

  defp optional_methodology(%Code{} = code) do
    ContentItem.code(Codes.dose_estimate_methodology(), code, relationship_type: "CONTAINS")
  end

  defp optional_methodology(text) when is_binary(text) do
    ContentItem.text(Codes.dose_estimate_methodology(), text, relationship_type: "CONTAINS")
  end

  defp parameter_item(%Code{} = code) do
    ContentItem.code(Codes.dose_estimation_parameters(), code, relationship_type: "CONTAINS")
  end

  defp parameter_item(text) when is_binary(text) do
    ContentItem.text(Codes.dose_estimation_parameters(), text, relationship_type: "CONTAINS")
  end
end
