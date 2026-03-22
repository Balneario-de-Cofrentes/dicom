defmodule Dicom.SR.SubTemplates.WaveformAnnotations do
  @moduledoc """
  TID 3751-3757 Waveform Annotation Sub-Templates.

  Implements the waveform annotation sub-template hierarchy:

  - TID 3751 -- Waveform Pattern or Event
  - TID 3752 -- Waveform Measurement
  - TID 3753 -- Annotation Note
  - TID 3754 -- Waveform Library Entry
  - TID 3755 -- Waveform Library Descriptors
  - TID 3756 -- Waveform Multiplex Group Descriptors
  - TID 3757 -- Waveform Channel Descriptors

  These sub-templates are referenced by TID 3750 Waveform Annotation
  for annotating waveform data in SR documents.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 3751: Waveform Pattern or Event -----------------------------------

  @doc """
  Builds TID 3751 Waveform Pattern or Event content items.

  ## Options

    * `:pattern` -- pattern or event Code (e.g., arrhythmia type)
    * `:temporal_location` -- temporal location description (TEXT)
    * `:morphology` -- waveform morphology Code
    * `:description` -- pattern description (TEXT)

  """
  @spec waveform_pattern(keyword()) :: [ContentItem.t()]
  def waveform_pattern(opts \\ []) do
    children =
      []
      |> add_text_child(Codes.comment(), opts[:temporal_location])
      |> add_code_child(Codes.waveform_morphology(), opts[:morphology])
      |> add_text_child(Codes.procedure_description(), opts[:description])

    concept = opts[:pattern] || Codes.waveform_annotation()

    [
      ContentItem.container(concept,
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3752: Waveform Measurement ----------------------------------------

  @doc """
  Builds TID 3752 Waveform Measurement content items.

  ## Options

    * `:concept` -- (required) measurement concept Code
    * `:value` -- (required) numeric value
    * `:units` -- (required) measurement units Code
    * `:lead` -- measurement lead Code
    * `:temporal_location` -- temporal location (TEXT)
    * `:method` -- measurement method Code

  """
  @spec waveform_measurement(keyword()) :: [ContentItem.t()]
  def waveform_measurement(opts) when is_list(opts) do
    concept = Keyword.fetch!(opts, :concept)
    value = Keyword.fetch!(opts, :value)
    units = Keyword.fetch!(opts, :units)

    children =
      []
      |> add_code_child(Codes.finding_site(), opts[:lead])
      |> add_text_child(Codes.comment(), opts[:temporal_location])
      |> add_code_child(Codes.measurement_method(), opts[:method])

    [
      ContentItem.num(concept, value, units,
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3753: Annotation Note --------------------------------------------

  @doc """
  Builds TID 3753 Annotation Note content items.

  ## Options

    * `:note` -- (required) annotation text
    * `:temporal_location` -- temporal location (TEXT)

  """
  @spec annotation_note(keyword()) :: [ContentItem.t()]
  def annotation_note(opts) when is_list(opts) do
    note = Keyword.fetch!(opts, :note)

    children =
      []
      |> add_text_child(Codes.comment(), opts[:temporal_location])

    [
      ContentItem.text(Codes.waveform_annotation(), note,
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3754: Waveform Library Entry --------------------------------------

  @doc """
  Builds TID 3754 Waveform Library Entry content items.

  A container for a single waveform library entry with descriptors.

  ## Options

    * `:description` -- entry description (TEXT)
    * `:descriptors` -- library descriptors (keyword, see `library_descriptors/1`)
    * `:multiplex` -- multiplex group descriptors (keyword, see `multiplex_descriptors/1`)
    * `:channel` -- channel descriptors (keyword, see `channel_descriptors/1`)

  """
  @spec library_entry(keyword()) :: [ContentItem.t()]
  def library_entry(opts \\ []) do
    children =
      []
      |> add_text_child(Codes.procedure_description(), opts[:description])
      |> add_items(descriptor_items(opts[:descriptors]))
      |> add_items(multiplex_items(opts[:multiplex]))
      |> add_items(channel_items(opts[:channel]))

    [
      ContentItem.container(Codes.waveform_reference(),
        relationship_type: "CONTAINS",
        children: children
      )
    ]
  end

  # -- TID 3755: Waveform Library Descriptors --------------------------------

  @doc """
  Builds TID 3755 Waveform Library Descriptors content items.

  ## Options

    * `:modality` -- modality Code
    * `:waveform_type` -- waveform type Code
    * `:sample_rate` -- sample rate (number, with `:sample_rate_units`)
    * `:sample_rate_units` -- units for sample rate
    * `:duration` -- duration (number, with `:duration_units`)
    * `:duration_units` -- units for duration

  """
  @spec library_descriptors(keyword()) :: [ContentItem.t()]
  def library_descriptors(opts \\ []) do
    sample_rate_code = Code.new("122161", "DCM", "Sampling Frequency")
    duration_code = Code.new("122162", "DCM", "Waveform Duration")

    []
    |> add_code_child(Codes.modality(), opts[:modality])
    |> add_code_child(Codes.waveform_annotation(), opts[:waveform_type])
    |> add_num_child(sample_rate_code, opts[:sample_rate], opts[:sample_rate_units])
    |> add_num_child(duration_code, opts[:duration], opts[:duration_units])
  end

  # -- TID 3756: Waveform Multiplex Group Descriptors ------------------------

  @doc """
  Builds TID 3756 Waveform Multiplex Group Descriptors content items.

  ## Options

    * `:group_label` -- group label (TEXT)
    * `:number_of_channels` -- number of channels in group (number)

  """
  @spec multiplex_descriptors(keyword()) :: [ContentItem.t()]
  def multiplex_descriptors(opts \\ []) do
    group_label_code = Code.new("122163", "DCM", "Multiplex Group Label")
    channel_count_code = Code.new("122164", "DCM", "Number of Waveform Channels")

    []
    |> add_text_child(group_label_code, opts[:group_label])
    |> add_num_child(channel_count_code, opts[:number_of_channels], nil)
  end

  # -- TID 3757: Waveform Channel Descriptors --------------------------------

  @doc """
  Builds TID 3757 Waveform Channel Descriptors content items.

  ## Options

    * `:channel_label` -- channel label (TEXT)
    * `:channel_source` -- channel source Code (e.g., lead identification)
    * `:sensitivity` -- channel sensitivity (number, with `:sensitivity_units`)
    * `:sensitivity_units` -- units for sensitivity

  """
  @spec channel_descriptors(keyword()) :: [ContentItem.t()]
  def channel_descriptors(opts \\ []) do
    label_code = Code.new("122165", "DCM", "Channel Label")
    source_code = Code.new("122166", "DCM", "Channel Source")
    sensitivity_code = Code.new("122167", "DCM", "Channel Sensitivity")

    []
    |> add_text_child(label_code, opts[:channel_label])
    |> add_code_child(source_code, opts[:channel_source])
    |> add_num_child(sensitivity_code, opts[:sensitivity], opts[:sensitivity_units])
  end

  # -- Private helpers -------------------------------------------------------

  defp add_items(items, []), do: items
  defp add_items(items, more), do: items ++ more

  defp descriptor_items(nil), do: []
  defp descriptor_items(opts), do: library_descriptors(opts)

  defp multiplex_items(nil), do: []
  defp multiplex_items(opts), do: multiplex_descriptors(opts)

  defp channel_items(nil), do: []
  defp channel_items(opts), do: channel_descriptors(opts)

  defp add_code_child(children, _concept, nil), do: children

  defp add_code_child(children, concept, %Code{} = code) do
    children ++ [ContentItem.code(concept, code, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_text_child(children, _concept, nil), do: children

  defp add_text_child(children, concept, text) when is_binary(text) do
    children ++ [ContentItem.text(concept, text, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, _concept, nil, _units), do: children

  defp add_num_child(children, concept, value, nil) when is_number(value) do
    no_units = Code.new("1", "UCUM", "no units")
    children ++ [ContentItem.num(concept, value, no_units, relationship_type: "HAS CONCEPT MOD")]
  end

  defp add_num_child(children, concept, value, %Code{} = units) when is_number(value) do
    children ++ [ContentItem.num(concept, value, units, relationship_type: "HAS CONCEPT MOD")]
  end
end
