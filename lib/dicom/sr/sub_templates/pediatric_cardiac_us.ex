defmodule Dicom.SR.SubTemplates.PediatricCardiacUS do
  @moduledoc """
  Sub-templates for Pediatric, Fetal and Congenital Cardiac Ultrasound
  reports (TID 5221-5225).

  Covers:
  - TID 5221 Patient Characteristics
  - TID 5222 Cardiac Measurement Section
  - TID 5223 Summary
  - TID 5224 Findings Section
  - TID 5225 Impressions Section
  """

  alias Dicom.SR.{Code, Codes, ContentItem, MeasurementGroup}

  @doc """
  TID 5221 -- Patient Characteristics.

  Returns a CONTAINER with patient characteristics as finding/text children.

  Options:
  - `:characteristics` (required) -- list of String.t() or Code.t()
  """
  @spec patient_characteristics(keyword()) :: ContentItem.t()
  def patient_characteristics(opts) when is_list(opts) do
    characteristics = Keyword.fetch!(opts, :characteristics)

    children =
      Enum.map(characteristics, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.patient_characteristics(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5222 -- Cardiac Measurement Section.

  Returns a list of MeasurementGroup content items for cardiac sections.
  Each section map must have `:name` (Code.t()), `:tracking_uid` (String.t()),
  and optionally `:measurements` (list of Measurement.t()) and
  `:findings` (list of String.t() or Code.t()).
  """
  @spec cardiac_measurement_sections([map()]) :: [ContentItem.t()]
  def cardiac_measurement_sections(sections) when is_list(sections) do
    Enum.map(sections, fn section ->
      measurements = Map.get(section, :measurements, [])
      findings = Map.get(section, :findings, [])

      qualitative_evals =
        Enum.map(findings, fn
          %Code{} = code ->
            ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

          text when is_binary(text) ->
            ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
        end)

      MeasurementGroup.new(
        Map.fetch!(section, :name),
        Map.fetch!(section, :tracking_uid),
        activity_session: Map.fetch!(section, :name),
        measurements: measurements,
        qualitative_evaluations: qualitative_evals
      )
      |> MeasurementGroup.to_content_item()
    end)
  end

  @doc """
  TID 5223 -- Summary.

  Returns a CONTAINER with summary findings/conclusions.

  Options:
  - `:values` (required) -- list of String.t() or Code.t()
  """
  @spec summary(keyword()) :: ContentItem.t()
  def summary(opts) when is_list(opts) do
    values = Keyword.fetch!(opts, :values)

    children =
      Enum.map(values, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5224 -- Findings Section.

  Returns a list of TEXT or CODE content items for pediatric cardiac findings.
  """
  @spec findings([String.t() | Code.t()]) :: [ContentItem.t()]
  def findings(values) when is_list(values) do
    map_text_or_code(values, Codes.finding())
  end

  @doc """
  TID 5225 -- Impressions Section.

  Returns a list of TEXT or CODE content items for pediatric cardiac impressions.
  """
  @spec impressions([String.t() | Code.t()]) :: [ContentItem.t()]
  def impressions(values) when is_list(values) do
    map_text_or_code(values, Codes.impression())
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
