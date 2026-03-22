defmodule Dicom.SR.SubTemplates.BreastImaging do
  @moduledoc """
  Sub-templates for Breast Imaging reports (TID 4200-4206).

  Covers:
  - TID 4205 Breast Composition
  - TID 4202 Report Narrative
  - TID 4203 BI-RADS Assessment
  - TID 4206 Finding Item
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  @doc """
  TID 4205 -- Breast Composition.

  Returns a CODE content item for breast tissue density category.
  Typical values: `Codes.almost_entirely_fat/0`, `Codes.scattered_fibroglandular/0`,
  `Codes.heterogeneously_dense/0`, `Codes.extremely_dense/0`.
  """
  @spec breast_composition(Code.t()) :: ContentItem.t()
  def breast_composition(%Code{} = density) do
    ContentItem.code(Codes.breast_composition(), density, relationship_type: "CONTAINS")
  end

  @doc """
  TID 4202 -- Report Narrative.

  Returns a TEXT content item for the narrative summary of the breast imaging report.
  """
  @spec report_narrative(String.t()) :: ContentItem.t()
  def report_narrative(text) when is_binary(text) do
    ContentItem.text(Codes.narrative_summary(), text, relationship_type: "CONTAINS")
  end

  @doc """
  TID 4203 -- BI-RADS Assessment.

  Returns a CODE content item for the overall BI-RADS assessment category.
  Typical values: `Codes.birads_category_0/0` through `Codes.birads_category_6/0`.
  """
  @spec birads_assessment(Code.t()) :: ContentItem.t()
  def birads_assessment(%Code{} = category) do
    ContentItem.code(Codes.overall_assessment(), category, relationship_type: "CONTAINS")
  end

  @doc """
  TID 4206 -- Finding Item.

  Returns a CODE or TEXT content item for a breast imaging finding.
  Accepts either a `Code.t()` for coded findings or a `String.t()` for free-text findings.
  """
  @spec finding_item(Code.t() | String.t()) :: ContentItem.t()
  def finding_item(%Code{} = code) do
    ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")
  end

  def finding_item(text) when is_binary(text) do
    ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
  end
end
