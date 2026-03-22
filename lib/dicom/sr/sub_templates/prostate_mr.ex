defmodule Dicom.SR.SubTemplates.ProstateMR do
  @moduledoc """
  Sub-templates for Prostate Multiparametric MR reports (TID 4301-4305).

  Covers:
  - TID 4301 Patient History (PSA, prior biopsies, family history)
  - TID 4302 Prostate Imaging Findings (volume, PSA density, assessment, findings)
  - TID 4303 Overall PI-RADS Assessment
  - TID 4304 Localized Finding (location, size, T2W/DWI/DCE scores, PI-RADS, Likert)
  - TID 4305 Extra-prostatic Finding
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}

  # -- TID 4301 Patient History --

  @doc """
  TID 4301 -- Patient History.

  Returns a CONTAINER with clinical history relevant to prostate MR interpretation:
  PSA level, prior biopsy information, and family history.

  Options:
  - `:psa` (optional) -- Measurement.t() for PSA level (units: ng/mL)
  - `:prior_biopsies` (optional) -- String.t() describing prior biopsy results
  - `:family_history` (optional) -- String.t() describing family history of prostate cancer

  Returns `nil` when all options are absent or nil.
  """
  @spec patient_history(keyword()) :: ContentItem.t() | nil
  def patient_history(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_measurement(opts[:psa], Codes.psa_level())
      |> maybe_add_text(opts[:prior_biopsies], Codes.prior_biopsy())
      |> maybe_add_text(opts[:family_history], Codes.family_history())

    if children == [] do
      nil
    else
      ContentItem.container(Codes.patient_history(),
        relationship_type: "HAS OBS CONTEXT",
        children: children
      )
    end
  end

  # -- TID 4302 Prostate Imaging Findings --

  @doc """
  TID 4302 -- Prostate Imaging Findings.

  Returns a CONTAINER grouping prostate-level measurements and subordinate findings.

  Options:
  - `:prostate_volume` (optional) -- Measurement.t() for gland volume
  - `:psa_density` (optional) -- Measurement.t() for PSA density
  - `:overall_assessment` (optional) -- Code.t() for overall PI-RADS (delegates to TID 4303)
  - `:localized_findings` (optional) -- list of keyword opts for `localized_finding/1` (TID 4304)
  - `:extraprostatic_findings` (optional) -- list of Code.t() or String.t() for TID 4305

  Returns `nil` when all options are absent or nil.
  """
  @spec imaging_findings(keyword()) :: ContentItem.t() | nil
  def imaging_findings(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_measurement(opts[:prostate_volume], Codes.prostate_volume())
      |> maybe_add_measurement(opts[:psa_density], Codes.psa_density())
      |> maybe_add_item(build_overall_assessment(opts[:overall_assessment]))
      |> append_items(
        Keyword.get(opts, :localized_findings, [])
        |> Enum.map(&localized_finding/1)
      )
      |> append_items(
        Keyword.get(opts, :extraprostatic_findings, [])
        |> Enum.map(&extraprostatic_finding/1)
      )

    if children == [] do
      nil
    else
      ContentItem.container(Codes.prostate_imaging_findings(),
        relationship_type: "CONTAINS",
        children: children
      )
    end
  end

  # -- TID 4303 Overall PI-RADS Assessment --

  @doc """
  TID 4303 -- Overall PI-RADS Assessment.

  Returns a CONTAINER wrapping the PI-RADS assessment code.

  Accepts:
  - `assessment` -- Code.t() (e.g. `Codes.pirads_category_3()`) or integer 1-5
  """
  @spec overall_assessment(Code.t() | 1..5) :: ContentItem.t()
  def overall_assessment(%Code{} = assessment) do
    ContentItem.container(Codes.overall_assessment(),
      relationship_type: "CONTAINS",
      children: [
        ContentItem.code(Codes.pirads_assessment(), assessment, relationship_type: "CONTAINS")
      ]
    )
  end

  def overall_assessment(n) when is_integer(n) and n >= 1 and n <= 5 do
    overall_assessment(pirads_category_code(n))
  end

  # -- TID 4304 Localized Finding --

  @doc """
  TID 4304 -- Localized Finding.

  Returns a CONTAINER describing a single lesion with location, size,
  MR sequence scores, PI-RADS category, and optional Likert score.

  Options:
  - `:location` (optional) -- Code.t() identifying the prostate sector/zone
  - `:size` (optional) -- number (mm) or Measurement.t() for lesion size
  - `:t2w_score` (optional) -- integer T2-weighted signal score
  - `:dwi_score` (optional) -- integer DWI signal score
  - `:dce_score` (optional) -- integer DCE curve type score
  - `:pirads_category` (optional) -- Code.t() or integer 1-5
  - `:likert_score` (optional) -- integer Likert score
  """
  @spec localized_finding(keyword()) :: ContentItem.t()
  def localized_finding(opts) when is_list(opts) do
    children =
      []
      |> maybe_add_location(opts[:location])
      |> maybe_add_lesion_size(opts[:size])
      |> maybe_add_score(opts[:t2w_score], Codes.t2w_signal_score())
      |> maybe_add_score(opts[:dwi_score], Codes.dwi_signal_score())
      |> maybe_add_score(opts[:dce_score], Codes.dce_curve_type())
      |> maybe_add_pirads_category(opts[:pirads_category])
      |> maybe_add_score(opts[:likert_score], Codes.likert_score())

    ContentItem.container(Codes.localized_finding(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- TID 4305 Extra-prostatic Finding --

  @doc """
  TID 4305 -- Extra-prostatic Finding.

  Returns a CODE or TEXT content item for findings outside the prostate gland
  (e.g. seminal vesicle invasion, lymphadenopathy, bone lesions).

  Accepts a Code.t() or a String.t().
  """
  @spec extraprostatic_finding(Code.t() | String.t()) :: ContentItem.t()
  def extraprostatic_finding(%Code{} = code) do
    ContentItem.code(Codes.extraprostatic_finding(), code, relationship_type: "CONTAINS")
  end

  def extraprostatic_finding(text) when is_binary(text) do
    ContentItem.text(Codes.extraprostatic_finding(), text, relationship_type: "CONTAINS")
  end

  # -- Private Helpers --

  defp maybe_add_measurement(items, nil, _concept), do: items

  defp maybe_add_measurement(items, %Measurement{} = m, _concept) do
    items ++ [Measurement.to_content_item(m)]
  end

  defp maybe_add_text(items, nil, _concept), do: items

  defp maybe_add_text(items, text, concept) when is_binary(text) do
    items ++ [ContentItem.text(concept, text, relationship_type: "CONTAINS")]
  end

  defp maybe_add_item(items, nil), do: items
  defp maybe_add_item(items, item), do: items ++ [item]

  defp append_items(items, more), do: items ++ more

  defp build_overall_assessment(nil), do: nil
  defp build_overall_assessment(assessment), do: overall_assessment(assessment)

  defp maybe_add_location(items, nil), do: items

  defp maybe_add_location(items, %Code{} = location) do
    items ++
      [ContentItem.code(Codes.finding_site(), location, relationship_type: "HAS CONCEPT MOD")]
  end

  defp maybe_add_lesion_size(items, nil), do: items

  defp maybe_add_lesion_size(items, %Measurement{} = m) do
    items ++ [Measurement.to_content_item(m)]
  end

  defp maybe_add_lesion_size(items, value) when is_number(value) do
    items ++
      [ContentItem.num(Codes.lesion_size(), value, Codes.mm(), relationship_type: "CONTAINS")]
  end

  defp maybe_add_score(items, nil, _concept), do: items

  defp maybe_add_score(items, value, concept) when is_integer(value) do
    items ++
      [ContentItem.num(concept, value, Codes.score_unit(), relationship_type: "CONTAINS")]
  end

  defp maybe_add_pirads_category(items, nil), do: items

  defp maybe_add_pirads_category(items, %Code{} = category) do
    items ++
      [ContentItem.code(Codes.pirads_assessment(), category, relationship_type: "CONTAINS")]
  end

  defp maybe_add_pirads_category(items, n) when is_integer(n) and n >= 1 and n <= 5 do
    maybe_add_pirads_category(items, pirads_category_code(n))
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
end
