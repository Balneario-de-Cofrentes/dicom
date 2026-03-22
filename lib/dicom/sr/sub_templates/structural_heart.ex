defmodule Dicom.SR.SubTemplates.StructuralHeart do
  @moduledoc """
  Sub-templates for Structural Heart reports (TID 5321-5325).

  Covers:
  - TID 5321 Annular Measurement Section
  - TID 5322 Device Measurement Section
  - TID 5323 Procedure Modifier
  - TID 5324 Findings Section
  - TID 5325 Impressions Section
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}

  @doc """
  TID 5321 -- Annular Measurement Section.

  Returns a CONTAINER grouping annular measurements for structural heart
  procedures (e.g. annulus diameter, area, perimeter).

  Options:
  - `:measurements` (required) -- list of Measurement.t()
  """
  @spec annular_measurement_section(keyword()) :: ContentItem.t()
  def annular_measurement_section(opts) when is_list(opts) do
    measurements = Keyword.fetch!(opts, :measurements)

    children = Enum.map(measurements, &Measurement.to_content_item/1)

    ContentItem.container(Codes.annular_measurements(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5322 -- Device Measurement Section.

  Returns a CONTAINER grouping device measurements for structural heart
  procedures (e.g. device size, deployment depth).

  Options:
  - `:measurements` (required) -- list of Measurement.t()
  """
  @spec device_measurement_section(keyword()) :: ContentItem.t()
  def device_measurement_section(opts) when is_list(opts) do
    measurements = Keyword.fetch!(opts, :measurements)

    children = Enum.map(measurements, &Measurement.to_content_item/1)

    ContentItem.container(Codes.device_measurements(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5323 -- Procedure Modifier.

  Returns a CODE content item identifying the structural heart procedure
  (TAVR, MitraClip, etc.).
  """
  @spec procedure_modifier(Code.t()) :: ContentItem.t()
  def procedure_modifier(%Code{} = procedure) do
    ContentItem.code(Codes.procedure_reported(), procedure, relationship_type: "HAS CONCEPT MOD")
  end

  @doc """
  TID 5324 -- Findings Section.

  Returns a list of TEXT or CODE content items for structural heart findings.
  """
  @spec findings([String.t() | Code.t()]) :: [ContentItem.t()]
  def findings(values) when is_list(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
    end)
  end

  @doc """
  TID 5325 -- Impressions Section.

  Returns a list of TEXT or CODE content items for structural heart impressions.
  """
  @spec impressions([String.t() | Code.t()]) :: [ContentItem.t()]
  def impressions(values) when is_list(values) do
    Enum.map(values, fn
      %Code{} = code ->
        ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

      text when is_binary(text) ->
        ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
    end)
  end
end
