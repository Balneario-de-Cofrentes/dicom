defmodule Dicom.SR.Templates.PreclinicalAcquisitionContext do
  @moduledoc """
  Builder for a practical TID 8101 Preclinical Small Animal Acquisition
  Context document.

  The current builder covers the root title, observer context, biosafety
  conditions (TID 8110), animal housing (TID 8121), anesthesia (TID 8130),
  and physiological monitoring (TID 8170) sections.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Document, Measurement, Observer}

  import Dicom.SR.Templates.Helpers

  @spec new(keyword()) :: {:ok, Document.t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    observer_name = Keyword.fetch!(opts, :observer_name)

    language =
      Keyword.get(opts, :language, Code.new("en-US", "RFC5646", "English (United States)"))

    root_children =
      []
      |> add_optional([Observer.language(language)])
      |> add_optional(observer_items(opts, observer_name))
      |> add_optional(optional_biosafety(Keyword.get(opts, :biosafety, [])))
      |> add_optional(optional_animal_housing(Keyword.get(opts, :animal_housing, [])))
      |> add_optional(optional_anesthesia(Keyword.get(opts, :anesthesia, [])))
      |> add_optional(
        optional_physiological_monitoring(Keyword.get(opts, :physiological_monitoring, []))
      )

    root =
      ContentItem.container(Codes.preclinical_acquisition_context(), children: root_children)

    Document.new(
      root,
      Keyword.merge(opts,
        template_identifier: "8101",
        series_description:
          Keyword.get(
            opts,
            :series_description,
            "Preclinical Small Animal Acquisition Context"
          )
      )
    )
  end

  defp optional_biosafety([]), do: nil

  defp optional_biosafety(items) do
    children =
      Enum.map(items, fn
        %Code{} = code ->
          ContentItem.code(Codes.biosafety_level(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.biosafety_level(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.biosafety_conditions(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_animal_housing([]), do: nil

  defp optional_animal_housing(items) do
    children =
      Enum.map(items, fn
        %Code{} = code ->
          ContentItem.code(Codes.housing_type(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.housing_type(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.animal_housing(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_anesthesia([]), do: nil

  defp optional_anesthesia(items) do
    children =
      Enum.map(items, fn
        %Measurement{} = m ->
          Measurement.to_content_item(m)

        %Code{} = code ->
          ContentItem.code(Codes.anesthesia_agent(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.anesthesia_agent(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.anesthesia(),
      relationship_type: "CONTAINS",
      children: children
    )
  end

  defp optional_physiological_monitoring([]), do: nil

  defp optional_physiological_monitoring(items) do
    children =
      Enum.map(items, fn
        %Measurement{} = m ->
          Measurement.to_content_item(m)

        %Code{} = code ->
          ContentItem.code(Codes.monitoring_parameter(), code, relationship_type: "CONTAINS")

        text when is_binary(text) ->
          ContentItem.text(Codes.monitoring_parameter(), text, relationship_type: "CONTAINS")
      end)

    ContentItem.container(Codes.physiological_monitoring(),
      relationship_type: "CONTAINS",
      children: children
    )
  end
end
