defmodule Dicom.SR.Templates.ProstateMRReport do
  @moduledoc """
  Builder for a practical TID 4300 Prostate Multiparametric MR Imaging Report.

  This builder covers the root document structure, observation context,
  patient history (PSA, prior biopsies, family history), prostate imaging
  findings (volume, PSA density, overall PI-RADS assessment), localized
  findings with sector locations and sequence scores, extra-prostatic
  findings, and final impressions/recommendations.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_procedure_item(Keyword.get(opts, :procedure_reported)))
      |> add_optional(optional_patient_history(Keyword.get(opts, :patient_history)))
      |> add_optional(optional_imaging_findings(opts))
      |> add_optional(map_text_or_code(Keyword.get(opts, :findings, []), Codes.finding()))
      |> add_optional(map_text_or_code(Keyword.get(opts, :impressions, []), Codes.impression()))
      |> add_optional(
        map_text_or_code(Keyword.get(opts, :recommendations, []), Codes.recommendation())
      )

    root = ContentItem.container(Codes.prostate_mr_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "4300",
        series_description:
          Keyword.get(opts, :series_description, "Prostate Multiparametric MR Imaging Report")
      )
    )
  end

  # -- Patient History (TID 4301) --

  defp optional_patient_history(nil), do: nil

  defp optional_patient_history(history) when is_map(history) do
    children =
      []
      |> add_optional(optional_measurement(Map.get(history, :psa), Codes.psa_level()))
      |> add_optional(
        optional_history_text(Map.get(history, :prior_biopsies), Codes.prior_biopsy())
      )
      |> add_optional(
        optional_history_text(Map.get(history, :family_history), Codes.family_history())
      )

    if children == [] do
      nil
    else
      ContentItem.container(Codes.patient_history(),
        relationship_type: "HAS OBS CONTEXT",
        children: children
      )
    end
  end

  defp optional_history_text(nil, _concept), do: nil

  defp optional_history_text(text, concept) when is_binary(text) do
    ContentItem.text(concept, text, relationship_type: "CONTAINS")
  end

  # -- Prostate Imaging Findings (TID 4302) --

  defp optional_imaging_findings(opts) do
    prostate_volume = Keyword.get(opts, :prostate_volume)
    psa_density = Keyword.get(opts, :psa_density)
    overall_assessment = Keyword.get(opts, :overall_assessment)
    localized_findings = Keyword.get(opts, :localized_findings, [])
    extraprostatic_findings = Keyword.get(opts, :extraprostatic_findings, [])

    children =
      []
      |> add_optional(optional_measurement(prostate_volume, Codes.prostate_volume()))
      |> add_optional(optional_measurement(psa_density, Codes.psa_density()))
      |> add_optional(optional_overall_assessment(overall_assessment))
      |> add_optional(Enum.map(localized_findings, &localized_finding_item/1))
      |> add_optional(Enum.map(extraprostatic_findings, &extraprostatic_finding_item/1))

    if children == [] do
      nil
    else
      ContentItem.container(Codes.prostate_imaging_findings(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  # -- Overall Assessment (TID 4303) --

  defp optional_overall_assessment(nil), do: nil

  defp optional_overall_assessment(%Code{} = assessment) do
    ContentItem.container(Codes.overall_assessment(),
      relationship_type: "CONTAINS",
      children: [
        ContentItem.code(Codes.pirads_assessment(), assessment, relationship_type: "CONTAINS")
      ]
    )
  end

  # -- Localized Finding (TID 4304) --

  defp localized_finding_item(finding) when is_map(finding) do
    children =
      []
      |> add_optional(optional_location(Map.get(finding, :location)))
      |> add_optional(optional_lesion_size(Map.get(finding, :size)))
      |> add_optional(optional_score(Map.get(finding, :t2w_score), Codes.t2w_signal_score()))
      |> add_optional(optional_score(Map.get(finding, :dwi_score), Codes.dwi_signal_score()))
      |> add_optional(optional_score(Map.get(finding, :dce_score), Codes.dce_curve_type()))
      |> add_optional(optional_pirads_category(Map.get(finding, :pirads_category)))
      |> add_optional(optional_score(Map.get(finding, :likert_score), Codes.likert_score()))

    ContentItem.container(Codes.localized_finding(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_location(nil), do: nil

  defp optional_location(%Code{} = location) do
    ContentItem.code(Codes.finding_site(), location, relationship_type: "HAS CONCEPT MOD")
  end

  defp optional_lesion_size(nil), do: nil

  defp optional_lesion_size(%Measurement{} = measurement) do
    Measurement.to_content_item(measurement)
  end

  defp optional_lesion_size(value) when is_number(value) do
    ContentItem.num(Codes.lesion_size(), value, Code.new("mm", "UCUM", "millimeters"),
      relationship_type: "CONTAINS"
    )
  end

  defp optional_score(nil, _concept), do: nil

  defp optional_score(value, concept) when is_integer(value) do
    ContentItem.num(concept, value, Code.new("{score}", "UCUM", "score"),
      relationship_type: "CONTAINS"
    )
  end

  defp optional_pirads_category(nil), do: nil

  defp optional_pirads_category(%Code{} = category) do
    ContentItem.code(Codes.pirads_assessment(), category, relationship_type: "CONTAINS")
  end

  defp optional_pirads_category(n) when is_integer(n) and n >= 1 and n <= 5 do
    category = pirads_category_code(n)
    ContentItem.code(Codes.pirads_assessment(), category, relationship_type: "CONTAINS")
  end

  # -- Extra-prostatic Findings (TID 4305) --

  defp extraprostatic_finding_item(%Code{} = code) do
    ContentItem.code(Codes.extraprostatic_finding(), code, relationship_type: "CONTAINS")
  end

  defp extraprostatic_finding_item(text) when is_binary(text) do
    ContentItem.text(Codes.extraprostatic_finding(), text, relationship_type: "CONTAINS")
  end

  # -- Shared helpers --

  defp optional_measurement(nil, _concept), do: nil

  defp optional_measurement(%Measurement{} = m, _concept) do
    Measurement.to_content_item(m)
  end

  defp optional_procedure_item(nil), do: nil

  defp optional_procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
  end

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  defp map_text_or_code(values, concept) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(concept, code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(concept, text, relationship_type: "CONTAINS")
    end)
  end

  @pirads_categories %{
    1 => :pirads_category_1,
    2 => :pirads_category_2,
    3 => :pirads_category_3,
    4 => :pirads_category_4,
    5 => :pirads_category_5
  }

  defp pirads_category_code(n) when is_integer(n) and n >= 1 and n <= 5 do
    apply(Codes, @pirads_categories[n], [])
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
