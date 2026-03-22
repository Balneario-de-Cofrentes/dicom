defmodule Dicom.SR.SubTemplates.ImplantationPlan do
  @moduledoc """
  Sub-templates for Implantation Plan documents (TID 7001-7005).

  Covers:
  - TID 7001 Implant Template Item
  - TID 7002 Planning Measurement
  - TID 7003 Implantation Site
  - TID 7004 Findings, Impressions, Recommendations
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Reference}

  @doc """
  TID 7001 -- Implant Template Item.

  Returns a COMPOSITE or TEXT content item describing an implant template.
  Accepts either a Reference (COMPOSITE) or a text description (TEXT).
  """
  @spec implant_template(Reference.t() | String.t()) :: ContentItem.t()
  def implant_template(%Reference{} = reference) do
    ContentItem.composite(Codes.implant_template(), reference, relationship_type: "CONTAINS")
  end

  def implant_template(description) when is_binary(description) do
    ContentItem.text(Codes.implant_template(), description, relationship_type: "CONTAINS")
  end

  @doc """
  TID 7002 -- Planning Measurement.

  Returns a NUM content item for a single planning measurement.

  Options:
  - `:concept` (required) -- Code.t() identifying the measurement
  - `:value` (required) -- number()
  - `:units` (required) -- Code.t() measurement units
  - `:qualifier` (optional) -- Code.t() qualifier
  """
  @spec planning_measurement(keyword()) :: ContentItem.t()
  def planning_measurement(opts) when is_list(opts) do
    concept = Keyword.fetch!(opts, :concept)
    value = Keyword.fetch!(opts, :value)
    units = Keyword.fetch!(opts, :units)

    ContentItem.num(concept, value, units,
      relationship_type: "CONTAINS",
      qualifier: opts[:qualifier]
    )
  end

  @doc """
  TID 7003 -- Implantation Site.

  Returns a CODE content item identifying the implantation site.
  """
  @spec implantation_site(Code.t()) :: ContentItem.t()
  def implantation_site(%Code{} = site) do
    ContentItem.code(Codes.implantation_site(), site, relationship_type: "CONTAINS")
  end

  @doc """
  TID 7004 -- Findings.

  Returns a list of TEXT or CODE content items for findings.
  """
  @spec findings([String.t() | Code.t()]) :: [ContentItem.t()]
  def findings(values) when is_list(values) do
    map_text_or_code(values, Codes.finding())
  end

  @doc """
  TID 7004 -- Impressions.

  Returns a list of TEXT or CODE content items for impressions.
  """
  @spec impressions([String.t() | Code.t()]) :: [ContentItem.t()]
  def impressions(values) when is_list(values) do
    map_text_or_code(values, Codes.impression())
  end

  @doc """
  TID 7004 -- Recommendations.

  Returns a list of TEXT or CODE content items for recommendations.
  """
  @spec recommendations([String.t() | Code.t()]) :: [ContentItem.t()]
  def recommendations(values) when is_list(values) do
    map_text_or_code(values, Codes.recommendation())
  end

  # -- Private Helpers --

  defp map_text_or_code(values, concept) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(concept, code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(concept, text, relationship_type: "CONTAINS")
    end)
  end
end
