defmodule Mix.Tasks.Dicom.GenDictionary do
  @moduledoc """
  Generates `Dicom.Dictionary.Registry` from innolitics/dicom-standard JSON.

  Downloads or reads `priv/attributes.json` and generates the full DICOM PS3.6
  data dictionary as a compile-time Elixir module.

  ## Usage

      mix dicom.gen_dictionary                      # uses priv/attributes.json
      mix dicom.gen_dictionary path/to/attrs.json   # custom path
  """
  @shortdoc "Generate DICOM tag dictionary from PS3.6 JSON"

  use Mix.Task

  @output_path "lib/dicom/dictionary/registry.ex"

  @impl Mix.Task
  def run(args) do
    input = List.first(args) || "priv/attributes.json"

    unless File.exists?(input) do
      Mix.raise("Input file not found: #{input}. Download from innolitics/dicom-standard.")
    end

    Mix.shell().info("Reading #{input}...")
    json = File.read!(input)
    entries = :json.decode(json)

    Mix.shell().info("Processing #{length(entries)} entries...")

    {standard, repeating} = partition_entries(entries)
    {curve_tags, overlay_tags, waveform_tags, _other_repeating} = group_repeating(repeating)

    standard_map = build_standard_map(standard)
    retired_set = build_retired_set(standard)
    keyword_index = build_keyword_index(standard_map)

    Mix.shell().info(
      "Standard: #{map_size(standard_map)}, " <>
        "Curve: #{map_size(curve_tags)}, " <>
        "Overlay: #{map_size(overlay_tags)}, " <>
        "Waveform: #{map_size(waveform_tags)}, " <>
        "Retired: #{MapSet.size(retired_set)}"
    )

    source =
      generate_source(
        standard_map,
        retired_set,
        keyword_index,
        curve_tags,
        overlay_tags,
        waveform_tags
      )

    File.write!(@output_path, source)

    Mix.shell().info("Written to #{@output_path}")
    Mix.shell().info("Run `mix format #{@output_path}` to format.")
  end

  # ── Partition standard vs repeating group entries ────────────

  defp partition_entries(entries) do
    Enum.split_with(entries, fn entry ->
      tag = entry["tag"]
      not String.contains?(String.downcase(tag), "x")
    end)
  end

  # ── Group repeating entries by pattern ───────────────────────

  defp group_repeating(repeating) do
    {curve, rest} = Enum.split_with(repeating, fn e -> String.starts_with?(e["tag"], "(50XX") end)
    {overlay, rest} = Enum.split_with(rest, fn e -> String.starts_with?(e["tag"], "(60XX") end)
    {waveform, other} = Enum.split_with(rest, fn e -> String.starts_with?(e["tag"], "(7FXX") end)

    {
      build_repeating_map(curve),
      build_repeating_map(overlay),
      build_repeating_map(waveform),
      other
    }
  end

  defp build_repeating_map(entries) do
    Map.new(entries, fn entry ->
      element = parse_element_from_tag(entry["tag"])
      vr = normalize_vr(entry["valueRepresentation"])
      vm = entry["valueMultiplicity"]
      keyword = entry["keyword"]
      {element, {keyword, vr, vm}}
    end)
  end

  defp parse_element_from_tag(tag) do
    # "(50XX,3000)" -> 0x3000
    [_group, element_hex] =
      tag
      |> String.replace(~r/[()]/, "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    String.to_integer(element_hex, 16)
  end

  # ── Build standard (non-repeating) map ──────────────────────

  defp build_standard_map(entries) do
    entries
    |> Enum.reject(fn e -> e["valueRepresentation"] in ["", "See Note 2"] end)
    |> Map.new(fn entry ->
      tag = parse_tag(entry["tag"])
      vr = normalize_vr(entry["valueRepresentation"])
      vm = entry["valueMultiplicity"]
      keyword = entry["keyword"]
      {tag, {keyword, vr, vm}}
    end)
  end

  defp parse_tag(tag_str) do
    [group_hex, element_hex] =
      tag_str
      |> String.replace(~r/[()]/, "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    {String.to_integer(group_hex, 16), String.to_integer(element_hex, 16)}
  end

  defp normalize_vr("OB or OW"), do: :OW
  defp normalize_vr("US or SS"), do: :US
  defp normalize_vr("US or OW"), do: :US
  defp normalize_vr("US or SS or OW"), do: :US
  defp normalize_vr(vr), do: String.to_atom(vr)

  # ── Retired set ─────────────────────────────────────────────

  defp build_retired_set(entries) do
    entries
    |> Enum.filter(fn e -> e["retired"] == "Y" end)
    |> Enum.reject(fn e -> e["valueRepresentation"] in ["", "See Note 2"] end)
    |> Enum.map(fn e -> parse_tag(e["tag"]) end)
    |> MapSet.new()
  end

  # ── Keyword index ───────────────────────────────────────────

  defp build_keyword_index(standard_map) do
    standard_map
    |> Enum.reject(fn {_tag, {keyword, _vr, _vm}} -> keyword == "" end)
    |> Map.new(fn {tag, {keyword, vr, vm}} ->
      {keyword, {tag, vr, vm}}
    end)
  end

  # ── Source code generation ──────────────────────────────────

  defp generate_source(
         standard_map,
         retired_set,
         keyword_index,
         curve_tags,
         overlay_tags,
         waveform_tags
       ) do
    """
    defmodule Dicom.Dictionary.Registry do
      @moduledoc \"\"\"
      DICOM Data Dictionary tag registry.

      Maps `{group, element}` tags to their name, VR, and VM (Value Multiplicity).
      Generated from the DICOM PS3.6 standard data dictionary via `mix dicom.gen_dictionary`.

      Contains #{map_size(standard_map)} entries covering the full standard data dictionary.
      Repeating group tags (50XX curve, 60XX overlay, 7FXX waveform) are handled via pattern matching.

      Reference: DICOM PS3.6.
      \"\"\"

      @type entry :: {String.t(), Dicom.VR.t(), String.t()}

      # Compile-time map for O(1) lookup.
      @registry %{
    #{generate_registry_entries(standard_map)}  }

      # Retired tags MapSet
      @retired_tags MapSet.new(#{inspect(MapSet.to_list(retired_set) |> Enum.sort(), limit: :infinity)})

      # Keyword → {tag, vr, vm} index for reverse lookup
      @keyword_index %{
    #{generate_keyword_entries(keyword_index)}  }

      # Repeating group patterns
      # Curve data (50XX) — groups 5000-501E (even)
      @curve_tags %{
    #{generate_repeating_entries(curve_tags)}  }

      # Overlay data (60XX) — groups 6000-601E (even)
      @overlay_tags %{
    #{generate_repeating_entries(overlay_tags)}  }

      # Waveform/variable pixel data (7FXX) — groups 7F00-7F1E (even)
      @waveform_tags %{
    #{generate_repeating_entries(waveform_tags)}  }

      @doc \"\"\"
      Looks up a tag in the dictionary.

      Returns `{:ok, name, vr, vm}` or `:error` if not found.
      \"\"\"
      @spec lookup(Dicom.Tag.t()) :: {:ok, String.t(), Dicom.VR.t(), String.t()} | :error
      def lookup(tag) do
        case Map.get(@registry, tag) do
          {name, vr, vm} -> {:ok, name, vr, vm}
          nil -> lookup_repeating(tag)
        end
      end

      @doc \"\"\"
      Finds a tag by its DICOM keyword (e.g., "PatientName").

      Returns `{:ok, tag, vr, vm}` or `:error`.
      \"\"\"
      @spec find_by_keyword(String.t()) :: {:ok, Dicom.Tag.t(), Dicom.VR.t(), String.t()} | :error
      def find_by_keyword(keyword) when is_binary(keyword) do
        case Map.get(@keyword_index, keyword) do
          {tag, vr, vm} -> {:ok, tag, vr, vm}
          nil -> :error
        end
      end

      @doc \"\"\"
      Returns true if the tag is marked as retired in the DICOM standard.
      \"\"\"
      @spec retired?(Dicom.Tag.t()) :: boolean()
      def retired?(tag), do: MapSet.member?(@retired_tags, tag)

      @doc \"\"\"
      Returns the number of entries in the registry (excluding repeating groups).
      \"\"\"
      @spec size() :: non_neg_integer()
      def size, do: map_size(@registry)

      # Curve repeating groups: groups 5000-501E (even numbers)
      defp lookup_repeating({group, element})
           when group >= 0x5000 and group <= 0x501E and rem(group, 2) == 0 do
        case Map.get(@curve_tags, element) do
          {name, vr, vm} -> {:ok, name, vr, vm}
          nil -> :error
        end
      end

      # Overlay repeating groups: groups 6000-601E (even numbers)
      defp lookup_repeating({group, element})
           when group >= 0x6000 and group <= 0x601E and rem(group, 2) == 0 do
        case Map.get(@overlay_tags, element) do
          {name, vr, vm} -> {:ok, name, vr, vm}
          nil -> :error
        end
      end

      # Waveform repeating groups: groups 7F00-7F1E (even numbers)
      defp lookup_repeating({group, element})
           when group >= 0x7F00 and group <= 0x7F1E and rem(group, 2) == 0 do
        case Map.get(@waveform_tags, element) do
          {name, vr, vm} -> {:ok, name, vr, vm}
          nil -> :error
        end
      end

      defp lookup_repeating(_), do: :error
    end
    """
  end

  defp generate_registry_entries(standard_map) do
    standard_map
    |> Enum.sort()
    |> Enum.map(fn {{group, element}, {keyword, vr, vm}} ->
      "    {#{hex(group)}, #{hex(element)}} => {#{inspect(keyword)}, :#{vr}, #{inspect(vm)}}"
    end)
    |> Enum.join(",\n")
    |> Kernel.<>("\n")
  end

  defp generate_keyword_entries(keyword_index) do
    keyword_index
    |> Enum.sort()
    |> Enum.map(fn {keyword, {{group, element}, vr, vm}} ->
      "    #{inspect(keyword)} => {{#{hex(group)}, #{hex(element)}}, :#{vr}, #{inspect(vm)}}"
    end)
    |> Enum.join(",\n")
    |> Kernel.<>("\n")
  end

  defp generate_repeating_entries(repeating_map) do
    repeating_map
    |> Enum.sort()
    |> Enum.map(fn {element, {keyword, vr, vm}} ->
      "    #{hex(element)} => {#{inspect(keyword)}, :#{vr}, #{inspect(vm)}}"
    end)
    |> Enum.join(",\n")
    |> Kernel.<>("\n")
  end

  defp hex(n), do: "0x" <> (n |> Integer.to_string(16) |> String.pad_leading(4, "0"))
end
