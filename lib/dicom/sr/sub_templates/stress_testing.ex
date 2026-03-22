defmodule Dicom.SR.SubTemplates.StressTesting do
  @moduledoc """
  Sub-templates for Stress Testing reports (TID 3301-3320).

  Covers:
  - TID 3301 Procedure Description
  - TID 3303 Phase Data
  - TID 3304 Measurement Group
  - TID 3307 NM/PET Perfusion
  - TID 3309 Stress Echo
  - TID 3311 Test Summary
  - TID 3312 Physiological Summary
  - TID 3313 Stress ECG Summary
  - TID 3317 Imaging Summary
  - TID 3318 Comparison to Prior
  - TID 3320 Conclusions and Recommendations
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Measurement}

  @doc """
  TID 3301 -- Procedure Description.

  Returns a CONTAINER with protocol, stress mode, and optional text description.

  Options:
  - `:protocol` (required) -- Code.t() for the stress protocol used
  - `:stress_mode` (required) -- Code.t() for mode (exercise, pharmacological)
  - `:description` (optional) -- free-text procedure description
  """
  @spec procedure_description(keyword()) :: ContentItem.t()
  def procedure_description(opts) when is_list(opts) do
    protocol = Keyword.fetch!(opts, :protocol)
    stress_mode = Keyword.fetch!(opts, :stress_mode)

    children =
      [
        ContentItem.code(Codes.stress_protocol(), protocol, relationship_type: "CONTAINS"),
        ContentItem.code(Codes.stress_mode(), stress_mode, relationship_type: "CONTAINS")
      ]
      |> maybe_add_text(Codes.procedure_description(), opts[:description])

    ContentItem.container(Codes.procedure_description(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3303 -- Phase Data.

  Returns a CONTAINER with phase identification and optional measurements/findings.

  Options:
  - `:phase` (required) -- Code.t() identifying the phase (rest, peak, recovery)
  - `:measurements` (optional) -- list of Measurement.t()
  - `:findings` (optional) -- list of String.t() or Code.t()
  """
  @spec phase_data(keyword()) :: ContentItem.t()
  def phase_data(opts) when is_list(opts) do
    phase = Keyword.fetch!(opts, :phase)

    children =
      [ContentItem.code(Codes.phase_of_exercise(), phase, relationship_type: "HAS CONCEPT MOD")]
      |> append_measurements(Keyword.get(opts, :measurements, []))
      |> append_findings(Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.measurement_group(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3304 -- Measurement Group.

  Returns a list of NUM content items for a set of stress-related measurements.
  """
  @spec measurement_group([Measurement.t()]) :: [ContentItem.t()]
  def measurement_group(measurements) when is_list(measurements) do
    Enum.map(measurements, &Measurement.to_content_item/1)
  end

  @doc """
  TID 3307 -- NM/PET Perfusion Finding.

  Returns a CONTAINER with perfusion findings for nuclear/PET stress imaging.

  Options:
  - `:findings` (required) -- list of String.t() or Code.t() perfusion findings
  - `:phase` (optional) -- Code.t() identifying the phase
  """
  @spec perfusion_finding(keyword()) :: ContentItem.t()
  def perfusion_finding(opts) when is_list(opts) do
    findings = Keyword.fetch!(opts, :findings)

    children =
      maybe_add_phase([], opts[:phase])
      |> append_coded_or_text(Codes.perfusion_finding(), findings)

    ContentItem.container(Codes.perfusion_finding(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3309 -- Stress Echo findings.

  Returns a CONTAINER with wall motion and optional qualitative findings.

  Options:
  - `:phase` (required) -- Code.t() identifying the phase
  - `:wall_motion_findings` (optional) -- list of String.t() or Code.t()
  - `:measurements` (optional) -- list of Measurement.t()
  """
  @spec stress_echo(keyword()) :: ContentItem.t()
  def stress_echo(opts) when is_list(opts) do
    phase = Keyword.fetch!(opts, :phase)

    children =
      [ContentItem.code(Codes.phase_of_exercise(), phase, relationship_type: "HAS CONCEPT MOD")]
      |> append_coded_or_text(
        Codes.wall_motion_abnormality(),
        Keyword.get(opts, :wall_motion_findings, [])
      )
      |> append_measurements(Keyword.get(opts, :measurements, []))

    ContentItem.container(Codes.echo_section(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3311 -- Test Summary.

  Returns a CODE content item with the overall test result.

  Options:
  - `:result` (required) -- Code.t() (positive, negative, equivocal)
  """
  @spec test_summary(Code.t()) :: ContentItem.t()
  def test_summary(%Code{} = result) do
    ContentItem.code(Codes.test_result(), result, relationship_type: "CONTAINS")
  end

  @doc """
  TID 3312 -- Physiological Summary.

  Returns a CONTAINER with key physiological measurements at rest and peak.

  Options:
  - `:measurements` (required) -- list of Measurement.t()
  - `:findings` (optional) -- list of String.t() or Code.t()
  """
  @spec physiological_summary(keyword()) :: ContentItem.t()
  def physiological_summary(opts) when is_list(opts) do
    measurements = Keyword.fetch!(opts, :measurements)

    children =
      []
      |> append_measurements(measurements)
      |> append_findings(Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.physiological_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3313 -- Stress ECG Summary.

  Returns a CONTAINER with ECG-specific findings from the stress test.

  Options:
  - `:st_findings` (optional) -- list of String.t() or Code.t() ST segment findings
  - `:findings` (optional) -- list of String.t() or Code.t() general ECG findings
  """
  @spec ecg_summary(keyword()) :: ContentItem.t()
  def ecg_summary(opts) when is_list(opts) do
    children =
      []
      |> append_coded_or_text(Codes.st_segment_finding(), Keyword.get(opts, :st_findings, []))
      |> append_findings(Keyword.get(opts, :findings, []))

    ContentItem.container(Codes.ecg_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3317 -- Imaging Summary.

  Returns a CONTAINER with imaging findings summary.

  Options:
  - `:findings` (required) -- list of String.t() or Code.t()
  """
  @spec imaging_summary(keyword()) :: ContentItem.t()
  def imaging_summary(opts) when is_list(opts) do
    findings = Keyword.fetch!(opts, :findings)

    children = append_findings([], findings)

    ContentItem.container(Codes.imaging_summary(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 3318 -- Comparison to Prior Study.

  Returns a TEXT content item with the comparison description.
  """
  @spec comparison_to_prior(String.t()) :: ContentItem.t()
  def comparison_to_prior(text) when is_binary(text) do
    ContentItem.text(Codes.comparison_to_prior(), text, relationship_type: "CONTAINS")
  end

  @doc """
  TID 3320 -- Conclusions and Recommendations.

  Returns a list of content items with conclusions and recommendations.

  Options:
  - `:conclusions` (optional) -- list of String.t() or Code.t()
  - `:recommendations` (optional) -- list of String.t() or Code.t()
  """
  @spec conclusions_and_recommendations(keyword()) :: [ContentItem.t()]
  def conclusions_and_recommendations(opts) when is_list(opts) do
    conclusion_items =
      opts
      |> Keyword.get(:conclusions, [])
      |> Enum.map(fn
        %Code{} = code ->
          ContentItem.code(Codes.impression(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.impression(), text, relationship_type: "CONTAINS")
      end)

    recommendation_items =
      opts
      |> Keyword.get(:recommendations, [])
      |> Enum.map(fn
        %Code{} = code ->
          ContentItem.code(Codes.recommendation(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.recommendation(), text, relationship_type: "CONTAINS")
      end)

    conclusion_items ++ recommendation_items
  end

  # -- Private Helpers --

  defp maybe_add_phase(items, nil), do: items

  defp maybe_add_phase(items, %Code{} = phase) do
    items ++
      [ContentItem.code(Codes.phase_of_exercise(), phase, relationship_type: "HAS CONCEPT MOD")]
  end

  defp maybe_add_text(items, _concept, nil), do: items

  defp maybe_add_text(items, concept, text) when is_binary(text) do
    items ++ [ContentItem.text(concept, text, relationship_type: "CONTAINS")]
  end

  defp append_measurements(items, measurements) do
    items ++ Enum.map(measurements, &Measurement.to_content_item/1)
  end

  defp append_findings(items, findings) do
    items ++
      Enum.map(findings, fn
        %Code{} = code ->
          ContentItem.code(Codes.finding(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.finding(), text, relationship_type: "CONTAINS")
      end)
  end

  defp append_coded_or_text(items, concept, values) do
    items ++
      Enum.map(values, fn
        %Code{} = code ->
          ContentItem.code(concept, code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(concept, text, relationship_type: "CONTAINS")
      end)
  end
end
