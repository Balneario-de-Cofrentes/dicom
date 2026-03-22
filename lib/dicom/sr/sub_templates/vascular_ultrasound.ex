defmodule Dicom.SR.SubTemplates.VascularUltrasound do
  @moduledoc """
  Sub-templates for Vascular Ultrasound reports (TID 5101-5105).

  Covers:
  - TID 5101 Patient Characteristics
  - TID 5102 Procedure Summary
  - TID 5103 Vascular Section
  - TID 5104 Measurement Group
  - TID 5105 Graft Section
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}

  @doc """
  TID 5101 -- Patient Characteristics.

  Returns a CONTAINER with patient-level measurements relevant to vascular
  assessment (weight, height, BSA, etc.).

  Options:
  - `:measurements` (required) -- list of Measurement.t()
  """
  @spec patient_characteristics(keyword()) :: ContentItem.t()
  def patient_characteristics(opts) when is_list(opts) do
    measurements = Keyword.fetch!(opts, :measurements)

    children = Enum.map(measurements, &Measurement.to_content_item/1)

    ContentItem.container(Codes.vascular_patient_characteristics(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5102 -- Procedure Summary.

  Returns a CONTAINER with procedure description and optional findings.

  Options:
  - `:description` (required) -- String.t() procedure description
  - `:findings` (optional) -- list of String.t() or Code.t()
  - `:impressions` (optional) -- list of String.t() or Code.t()
  """
  @spec procedure_summary(keyword()) :: ContentItem.t()
  def procedure_summary(opts) when is_list(opts) do
    description = Keyword.fetch!(opts, :description)

    children =
      [
        ContentItem.text(Codes.procedure_description(), description,
          relationship_type: "CONTAINS"
        )
      ]
      |> append_findings(Keyword.get(opts, :findings, []))
      |> append_impressions(Keyword.get(opts, :impressions, []))

    ContentItem.container(Codes.vascular_procedure_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5103 -- Vascular Section.

  Returns a CONTAINER grouping measurements for a specific vessel.

  Options:
  - `:vessel` (required) -- Code.t() identifying the vessel
  - `:laterality` (optional) -- Code.t() (left/right)
  - `:measurement_groups` (optional) -- list of ContentItem.t() from `measurement_group/1`
  - `:findings` (optional) -- list of String.t() or Code.t()
  """
  @spec vascular_section(keyword()) :: ContentItem.t()
  def vascular_section(opts) when is_list(opts) do
    vessel = Keyword.fetch!(opts, :vessel)

    children =
      [ContentItem.code(Codes.finding_site(), vessel, relationship_type: "HAS CONCEPT MOD")]
      |> maybe_add_laterality(opts[:laterality])
      |> append_items(Keyword.get(opts, :measurement_groups, []))
      |> append_findings(Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.vascular_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5104 -- Measurement Group.

  Returns a CONTAINER with vascular Doppler and morphometric measurements.

  Options:
  - `:tracking_id` (required) -- String.t() site identifier
  - `:measurements` (required) -- list of Measurement.t()
  """
  @spec measurement_group(keyword()) :: ContentItem.t()
  def measurement_group(opts) when is_list(opts) do
    tracking_id = Keyword.fetch!(opts, :tracking_id)
    measurements = Keyword.fetch!(opts, :measurements)

    children =
      [
        ContentItem.text(Codes.tracking_identifier(), tracking_id,
          relationship_type: "HAS OBS CONTEXT"
        )
      ]
      |> append_measurements(measurements)

    ContentItem.container(Codes.vascular_measurement_group(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 5105 -- Graft Section.

  Returns a CONTAINER describing a vascular graft with type, origin/destination,
  patency, and optional measurements.

  Options:
  - `:graft_type` (required) -- Code.t() (synthetic, vein)
  - `:origin` (required) -- String.t() graft origin site
  - `:destination` (required) -- String.t() graft destination site
  - `:patency` (required) -- Code.t() (patent, occluded)
  - `:measurements` (optional) -- list of Measurement.t()
  - `:findings` (optional) -- list of String.t() or Code.t()
  """
  @spec graft_section(keyword()) :: ContentItem.t()
  def graft_section(opts) when is_list(opts) do
    graft_type = Keyword.fetch!(opts, :graft_type)
    origin = Keyword.fetch!(opts, :origin)
    destination = Keyword.fetch!(opts, :destination)
    patency = Keyword.fetch!(opts, :patency)

    children =
      [
        ContentItem.code(Codes.graft_type(), graft_type, relationship_type: "CONTAINS"),
        ContentItem.text(Codes.graft_origin(), origin, relationship_type: "CONTAINS"),
        ContentItem.text(Codes.graft_destination(), destination, relationship_type: "CONTAINS"),
        ContentItem.code(Codes.graft_patency(), patency, relationship_type: "CONTAINS")
      ]
      |> append_measurements(Keyword.get(opts, :measurements, []))
      |> append_findings(Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.graft_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  # -- Private Helpers --

  defp maybe_add_laterality(items, nil), do: items

  defp maybe_add_laterality(items, %Code{} = laterality) do
    items ++
      [
        ContentItem.code(Codes.finding_site(), laterality, relationship_type: "HAS CONCEPT MOD")
      ]
  end

  defp append_items(items, more), do: items ++ more

  defp append_findings(items, findings) do
    items ++
      Enum.map(findings, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)
  end

  defp append_impressions(items, impressions) do
    items ++
      Enum.map(impressions, fn
        %Code{} = code ->
          ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
      end)
  end

  defp append_measurements(items, measurement_list) do
    items ++ Enum.map(measurement_list, &Measurement.to_content_item/1)
  end
end
