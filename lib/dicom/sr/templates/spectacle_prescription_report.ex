defmodule Dicom.SR.Templates.SpectaclePrescriptionReport do
  @moduledoc """
  Builder for a practical TID 2020 Spectacle Prescription Report document.

  This builder covers the root document structure, observer context, and
  per-eye prescription details including sphere, cylinder, axis, add power,
  prism, and interpupillary distance.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    prescriptions = Keyword.get(opts, :prescriptions, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(Enum.map(prescriptions, &prescription_container/1))

    root =
      ContentItem.container(Codes.spectacle_prescription_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "2020",
        series_description:
          Keyword.get(opts, :series_description, "Spectacle Prescription Report")
      )
    )
  end

  defp prescription_container(eye_opts) do
    laterality_code =
      case Map.fetch!(eye_opts, :eye) do
        :right -> Codes.right_eye()
        :left -> Codes.left_eye()
      end

    children =
      [
        ContentItem.code(Codes.laterality(), laterality_code,
          relationship_type: "HAS CONCEPT MOD"
        )
      ]
      |> add_optional(optional_num(:sphere, eye_opts, Codes.sphere_power(), Codes.diopter()))
      |> add_optional(optional_num(:cylinder, eye_opts, Codes.cylinder_power(), Codes.diopter()))
      |> add_optional(optional_num(:axis, eye_opts, Codes.cylinder_axis(), Codes.degree()))
      |> add_optional(optional_num(:add_power, eye_opts, Codes.add_power(), Codes.diopter()))
      |> add_optional(
        optional_num(:prism_power, eye_opts, Codes.prism_power(), Codes.prism_diopter())
      )
      |> add_optional(optional_prism_base(eye_opts))
      |> add_optional(
        optional_num(
          :interpupillary_distance,
          eye_opts,
          Codes.interpupillary_distance(),
          Codes.millimeter()
        )
      )

    ContentItem.container(Codes.prescription_for_eye(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_num(key, eye_opts, concept, units) do
    case Map.get(eye_opts, key) do
      nil -> nil
      value -> ContentItem.num(concept, value, units, relationship_type: "CONTAINS")
    end
  end

  defp optional_prism_base(eye_opts) do
    case Map.get(eye_opts, :prism_base) do
      nil ->
        nil

      base when is_binary(base) ->
        ContentItem.text(Codes.prism_base(), base, relationship_type: "CONTAINS")
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
