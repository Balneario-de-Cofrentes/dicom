defmodule Dicom.SR.SubTemplates.SpectaclePrescription do
  @moduledoc """
  Sub-templates for Spectacle Prescription reports (TID 2021-2023).

  Covers:
  - TID 2021 Eye Prescription Container
  - TID 2022 Lens Parameters
  - TID 2023 Prism Parameters
  """

  alias Dicom.SR.{Codes, ContentItem}

  @doc """
  TID 2021 -- Eye Prescription Container.

  Returns a CONTAINER with per-eye prescription details including
  sphere, cylinder, axis, add power, prism, and interpupillary distance.

  Options:
  - `:eye` (required) -- :right or :left
  - `:sphere` (optional) -- number() in diopters
  - `:cylinder` (optional) -- number() in diopters
  - `:axis` (optional) -- number() in degrees
  - `:add_power` (optional) -- number() in diopters
  - `:prism_power` (optional) -- number() in prism diopters
  - `:prism_base` (optional) -- String.t() base direction
  - `:interpupillary_distance` (optional) -- number() in mm
  """
  @spec eye_prescription(keyword()) :: ContentItem.t()
  def eye_prescription(opts) when is_list(opts) do
    laterality_code =
      case Keyword.fetch!(opts, :eye) do
        :right -> Codes.right_eye()
        :left -> Codes.left_eye()
      end

    children =
      [
        ContentItem.code(Codes.laterality(), laterality_code,
          relationship_type: "HAS CONCEPT MOD"
        )
      ]
      |> maybe_add_num(Codes.sphere_power(), opts[:sphere], Codes.diopter())
      |> maybe_add_num(Codes.cylinder_power(), opts[:cylinder], Codes.diopter())
      |> maybe_add_num(Codes.cylinder_axis(), opts[:axis], Codes.degree())
      |> maybe_add_num(Codes.add_power(), opts[:add_power], Codes.diopter())
      |> maybe_add_num(Codes.prism_power(), opts[:prism_power], Codes.prism_diopter())
      |> maybe_add_prism_base(opts[:prism_base])
      |> maybe_add_num(
        Codes.interpupillary_distance(),
        opts[:interpupillary_distance],
        Codes.millimeter()
      )

    ContentItem.container(Codes.prescription_for_eye(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  @doc """
  TID 2022 -- Lens Parameters.

  Returns a list of NUM content items for sphere, cylinder, and axis.
  """
  @spec lens_parameters(keyword()) :: [ContentItem.t()]
  def lens_parameters(opts) when is_list(opts) do
    []
    |> maybe_add_num(Codes.sphere_power(), opts[:sphere], Codes.diopter())
    |> maybe_add_num(Codes.cylinder_power(), opts[:cylinder], Codes.diopter())
    |> maybe_add_num(Codes.cylinder_axis(), opts[:axis], Codes.degree())
  end

  @doc """
  TID 2023 -- Prism Parameters.

  Returns a list of content items for prism power and base direction.
  """
  @spec prism_parameters(keyword()) :: [ContentItem.t()]
  def prism_parameters(opts) when is_list(opts) do
    []
    |> maybe_add_num(Codes.prism_power(), opts[:power], Codes.prism_diopter())
    |> maybe_add_prism_base(opts[:base])
  end

  # -- Private Helpers --

  defp maybe_add_num(items, _concept, nil, _units), do: items

  defp maybe_add_num(items, concept, value, units) do
    items ++ [ContentItem.num(concept, value, units, relationship_type: "CONTAINS")]
  end

  defp maybe_add_prism_base(items, nil), do: items

  defp maybe_add_prism_base(items, base) when is_binary(base) do
    items ++ [ContentItem.text(Codes.prism_base(), base, relationship_type: "CONTAINS")]
  end
end
