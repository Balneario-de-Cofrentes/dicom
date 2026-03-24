defmodule Mix.Tasks.Dicom.GenContextGroups do
  @compile {:no_warn_undefined, :json}
  @moduledoc """
  Generates the context group registry ETF from `priv/context_groups.json`.

  Reads the scraped PS3.16 context group data, resolves include chains,
  and writes the registry as a pre-compiled ETF binary that
  `Dicom.SR.ContextGroup.Registry` loads at compile time.

  ## Usage

      mix dicom.gen_context_groups                          # uses priv/context_groups.json
      mix dicom.gen_context_groups path/to/cg.json          # custom path
  """
  @shortdoc "Generate SR context group registry ETF from PS3.16 JSON"

  use Mix.Task

  @etf_path "priv/context_groups_registry.etf"

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

    etf = :erlang.term_to_binary(registry, [:compressed])
    File.write!(@etf_path, etf)

    Mix.shell().info("Written #{byte_size(etf)} bytes to #{@etf_path}")
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
end
