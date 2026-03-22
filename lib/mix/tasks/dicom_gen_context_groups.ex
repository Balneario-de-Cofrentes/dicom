defmodule Mix.Tasks.Dicom.GenContextGroups do
  @compile {:no_warn_undefined, :json}
  @moduledoc """
  Generates `Dicom.SR.ContextGroup.Registry` from `priv/context_groups.json`.

  Reads the scraped PS3.16 context group data and generates a compile-time
  registry module with include-chain resolution.

  ## Usage

      mix dicom.gen_context_groups                          # uses priv/context_groups.json
      mix dicom.gen_context_groups path/to/cg.json          # custom path
  """
  @shortdoc "Generate SR context group registry from PS3.16 JSON"

  use Mix.Task

  @output_path "lib/dicom/sr/context_group/registry.ex"

  @impl Mix.Task
  def run(args) do
    input = List.first(args) || "priv/context_groups.json"

    unless File.exists?(input) do
      Mix.raise("Input file not found: #{input}.")
    end

    Mix.shell().info("Reading #{input}...")
    json = File.read!(input)
    entries = :json.decode(json)

    Mix.shell().info("Processing #{length(entries)} context groups...")

    by_cid = Map.new(entries, fn e -> {e["cid"], e} end)
    registry = build_registry(entries, by_cid)

    extensible_count = Enum.count(registry, fn {_cid, entry} -> entry.extensible end)

    total_codes =
      Enum.reduce(registry, 0, fn {_cid, entry}, acc -> acc + MapSet.size(entry.codes) end)

    Mix.shell().info(
      "CIDs: #{map_size(registry)}, " <>
        "Extensible: #{extensible_count}, " <>
        "Total codes (after resolution): #{total_codes}"
    )

    source = generate_source(registry)

    File.mkdir_p!(Path.dirname(@output_path))
    File.write!(@output_path, source)

    Mix.shell().info("Written to #{@output_path}")
    Mix.shell().info("Run `mix format #{@output_path}` to format.")
  end

  # ── Build resolved registry ──────────────────────────────

  defp build_registry(entries, by_cid) do
    Map.new(entries, fn entry ->
      cid = entry["cid"]
      codes = resolve_codes(cid, by_cid, MapSet.new())

      {cid,
       %{
         name: entry["name"],
         extensible: entry["extensible"],
         codes: codes
       }}
    end)
  end

  defp resolve_codes(cid, by_cid, seen) do
    if MapSet.member?(seen, cid) do
      MapSet.new()
    else
      seen = MapSet.put(seen, cid)

      case Map.get(by_cid, cid) do
        nil ->
          MapSet.new()

        entry ->
          own_codes =
            entry
            |> Map.get("codes", [])
            |> Enum.map(fn c -> {c["scheme"], c["value"]} end)
            |> MapSet.new()

          included_codes =
            entry
            |> Map.get("includes", [])
            |> Enum.reduce(MapSet.new(), fn inc_cid, acc ->
              MapSet.union(acc, resolve_codes(inc_cid, by_cid, seen))
            end)

          MapSet.union(own_codes, included_codes)
      end
    end
  end

  # ── Source code generation ──────────────────────────────

  defp generate_source(registry) do
    """
    defmodule Dicom.SR.ContextGroup.Registry do
      @moduledoc \"\"\"
      Generated CID registry for DICOM SR context groups.

      Contains #{map_size(registry)} context groups with include-chain resolved codes.
      Generated via `mix dicom.gen_context_groups` from PS3.16 data.
      \"\"\"

      @registry %{
    #{generate_registry_entries(registry)}  }

      @doc "Looks up a context group by CID number."
      @spec lookup(non_neg_integer()) :: {:ok, map()} | :error
      def lookup(cid) do
        case Map.get(@registry, cid) do
          nil -> :error
          entry -> {:ok, entry}
        end
      end

      @doc "Checks whether a code is a member of the given CID."
      @spec member?(non_neg_integer(), String.t(), String.t()) :: boolean() | :unknown_cid
      def member?(cid, scheme, value) do
        case Map.get(@registry, cid) do
          nil -> :unknown_cid
          entry -> MapSet.member?(entry.codes, {scheme, value})
        end
      end

      @doc "Returns whether the given CID is extensible."
      @spec extensible?(non_neg_integer()) :: boolean() | :unknown_cid
      def extensible?(cid) do
        case Map.get(@registry, cid) do
          nil -> :unknown_cid
          entry -> entry.extensible
        end
      end

      @doc "Returns the number of context groups in the registry."
      @spec size() :: non_neg_integer()
      def size, do: map_size(@registry)
    end
    """
  end

  defp generate_registry_entries(registry) do
    registry
    |> Enum.sort_by(fn {cid, _} -> cid end)
    |> Enum.map(fn {cid, entry} ->
      codes_list =
        entry.codes
        |> MapSet.to_list()
        |> Enum.sort()
        |> Enum.map(fn {scheme, value} -> "{#{inspect(scheme)}, #{inspect(value)}}" end)
        |> Enum.join(", ")

      "    #{cid} => %{name: #{inspect(entry.name)}, extensible: #{entry.extensible}, codes: MapSet.new([#{codes_list}])}"
    end)
    |> Enum.join(",\n")
    |> Kernel.<>("\n")
  end
end
