defmodule Dicom.SR.Templates.MeasurementReport do
  @moduledoc """
  Builder for a practical TID 1500 Measurement Report root document.

  This builder covers the root document structure, observation context,
  procedure-reported modifiers, and imaging measurement groups. It does not
  attempt to implement every included sub-template of TID 1500.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, MeasurementGroup, Observer}

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)
    procedure_reported = Keyword.get(opts, :procedure_reported, [])
    measurement_groups = Keyword.get(opts, :measurement_groups, [])
    image_library = Keyword.get(opts, :image_library, [])

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(Enum.map(List.wrap(procedure_reported), &procedure_item/1))
      |> add_optional(optional_image_library(image_library))
      |> add_optional([imaging_measurements_item(measurement_groups)])

    root = ContentItem.container(Codes.imaging_measurement_report(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "1500",
        series_description: Keyword.get(opts, :series_description, "Measurement Report")
      )
    )
  end

  defp imaging_measurements_item(measurement_groups) do
    ContentItem.container(Codes.imaging_measurements(),
      relationship_type: "CONTAINS",
      children: Enum.map(measurement_groups, &MeasurementGroup.to_content_item/1)
    )
  end

  defp optional_image_library([]), do: nil

  defp optional_image_library(references) do
    ContentItem.container(Codes.image_library(),
      relationship_type: "CONTAINS",
      children:
        Enum.map(references, fn reference ->
          ContentItem.image(Codes.source(), reference, relationship_type: "CONTAINS")
        end)
    )
  end

  defp procedure_item(%Code{} = code) do
    ContentItem.code(Codes.procedure_reported(), code, relationship_type: "HAS CONCEPT MOD")
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
