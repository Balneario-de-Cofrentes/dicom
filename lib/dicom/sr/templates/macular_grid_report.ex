defmodule Dicom.SR.Templates.MacularGridReport do
  @moduledoc """
  Builder for a practical TID 2100 Macular Grid Thickness and Volume Report.

  This builder covers the root document structure, observer context, quality
  assessment, and per-sector macular grid measurements including retinal
  thickness, retinal volume, central subfield thickness, and total volume.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    grid_measurements = Keyword.get(opts, :grid_measurements, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_quality(opts))
      |> add_optional(Enum.map(grid_measurements, &grid_sector_container/1))
      |> add_optional(optional_summary_measurements(opts))

    root = ContentItem.container(Codes.macular_grid_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "2100",
        series_description:
          Keyword.get(
            opts,
            :series_description,
            "Macular Grid Thickness and Volume Report"
          )
      )
    )
  end

  defp grid_sector_container(sector_opts) do
    location_code = sector_code(Map.fetch!(sector_opts, :sector))

    children =
      [
        ContentItem.code(Codes.finding_site(), location_code,
          relationship_type: "HAS CONCEPT MOD"
        )
      ]
      |> add_optional(
        optional_num(:thickness, sector_opts, Codes.retinal_thickness(), Codes.micrometer())
      )
      |> add_optional(
        optional_num(:volume, sector_opts, Codes.retinal_volume(), Codes.cubic_millimeter())
      )

    ContentItem.container(Codes.macular_grid_measurement(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_summary_measurements(opts) do
    []
    |> add_optional(
      optional_num(
        :central_subfield_thickness,
        opts |> Enum.into(%{}),
        Codes.central_subfield_thickness(),
        Codes.micrometer()
      )
    )
    |> add_optional(
      optional_num(
        :total_volume,
        opts |> Enum.into(%{}),
        Codes.total_volume(),
        Codes.cubic_millimeter()
      )
    )
  end

  defp optional_quality(opts) do
    case Keyword.get(opts, :quality_rating) do
      nil ->
        nil

      rating when is_number(rating) ->
        ContentItem.num(
          Codes.quality_assessment(),
          rating,
          Codes.signal_quality(),
          relationship_type: "CONTAINS"
        )
    end
  end

  defp optional_num(key, sector_opts, concept, units) do
    case Map.get(sector_opts, key) do
      nil -> nil
      value -> ContentItem.num(concept, value, units, relationship_type: "CONTAINS")
    end
  end

  @sector_map %{
    center: :grid_center,
    inner_superior: :grid_inner_superior,
    inner_nasal: :grid_inner_nasal,
    inner_inferior: :grid_inner_inferior,
    inner_temporal: :grid_inner_temporal,
    outer_superior: :grid_outer_superior,
    outer_nasal: :grid_outer_nasal,
    outer_inferior: :grid_outer_inferior,
    outer_temporal: :grid_outer_temporal
  }

  defp sector_code(sector) when is_atom(sector) do
    case Map.fetch(@sector_map, sector) do
      {:ok, fun_name} -> apply(Codes, fun_name, [])
      :error -> raise ArgumentError, "unknown grid sector: #{inspect(sector)}"
    end
  end

  defp observer_items(opts, observer_name) do
    Observer.person(observer_name) ++
      case opts[:observer_device] do
        nil -> []
        device_opts -> Observer.device(device_opts)
      end
  end

  defp add_optional(items, more), do: items ++ Enum.reject(List.wrap(more), &is_nil/1)
end
