defmodule Dicom.SR.SubTemplates.MacularGrid do
  @moduledoc """
  Sub-templates for Macular Grid Thickness and Volume reports (TID 2100).

  Provides reusable building blocks for macular grid sector measurements,
  quality assessment, central subfield thickness, and total macular volume.

  The 9 ETDRS grid sectors are:
  - Center
  - Inner superior, inner nasal, inner inferior, inner temporal
  - Outer superior, outer nasal, outer inferior, outer temporal
  """

  alias Dicom.SR.{Codes, ContentItem}

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

  @doc """
  Builds a CONTAINER for a single macular grid sector.

  Each sector container includes a finding site modifier identifying the
  ETDRS grid location, plus optional retinal thickness and retinal volume
  NUM items.

  Options:
  - `:sector` (required) -- atom identifying the grid sector (see `@sector_map`)
  - `:thickness` (optional) -- number, retinal thickness in micrometers
  - `:volume` (optional) -- number, retinal volume in cubic millimeters
  """
  @spec grid_sector(keyword()) :: ContentItem.t()
  def grid_sector(opts) when is_list(opts) do
    sector = Keyword.fetch!(opts, :sector)
    location_code = sector_code(sector)

    children =
      [
        ContentItem.code(Codes.finding_site(), location_code,
          relationship_type: "HAS CONCEPT MOD"
        )
      ]
      |> maybe_add_num(opts[:thickness], Codes.retinal_thickness(), Codes.micrometer())
      |> maybe_add_num(opts[:volume], Codes.retinal_volume(), Codes.cubic_millimeter())

    ContentItem.container(Codes.macular_grid_measurement(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  Builds a NUM content item for scan quality assessment.

  Options:
  - `:rating` (required) -- number, quality rating value
  """
  @spec quality_assessment(keyword()) :: ContentItem.t()
  def quality_assessment(opts) when is_list(opts) do
    rating = Keyword.fetch!(opts, :rating)

    ContentItem.num(
      Codes.quality_assessment(),
      rating,
      Codes.signal_quality(),
      relationship_type: "CONTAINS"
    )
  end

  @doc """
  Builds a NUM content item for central subfield thickness (CST).

  Options:
  - `:value` (required) -- number, thickness in micrometers
  """
  @spec central_subfield_thickness(keyword()) :: ContentItem.t()
  def central_subfield_thickness(opts) when is_list(opts) do
    value = Keyword.fetch!(opts, :value)

    ContentItem.num(
      Codes.central_subfield_thickness(),
      value,
      Codes.micrometer(),
      relationship_type: "CONTAINS"
    )
  end

  @doc """
  Builds a NUM content item for total macular volume.

  Options:
  - `:value` (required) -- number, volume in cubic millimeters
  """
  @spec total_volume(keyword()) :: ContentItem.t()
  def total_volume(opts) when is_list(opts) do
    value = Keyword.fetch!(opts, :value)

    ContentItem.num(
      Codes.total_volume(),
      value,
      Codes.cubic_millimeter(),
      relationship_type: "CONTAINS"
    )
  end

  # -- Private Helpers --

  defp maybe_add_num(items, nil, _concept, _units), do: items

  defp maybe_add_num(items, value, concept, units) when is_number(value) do
    items ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
  end

  defp sector_code(sector) when is_atom(sector) do
    case Map.fetch(@sector_map, sector) do
      {:ok, fun_name} -> apply(Codes, fun_name, [])
      :error -> raise ArgumentError, "unknown grid sector: #{inspect(sector)}"
    end
  end
end
