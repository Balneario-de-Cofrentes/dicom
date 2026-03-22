defmodule Dicom.SR.SubTemplates.Language do
  @moduledoc """
  TID 1200-1211 Language Sub-Templates.

  Implements the language designation sub-template hierarchy:

  - TID 1200 — Language Designation
  - TID 1201 — Language of Value
  - TID 1202 — Language of Name and Value
  - TID 1204 — Language of Content Item and Descendants
  - TID 1210 — Equivalent Meaning(s) of Concept Name
  - TID 1211 — Equivalent Meaning(s) of Value

  These sub-templates allow specifying the human language used in SR
  content items and providing equivalent meanings in alternate languages.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 1200: Language Designation -----------------------------------------

  @doc """
  Builds TID 1200 Language Designation content items.

  Returns a CODE content item for the language, optionally with a country
  of language child item.

  ## Options

    * `:language` — (required) language Code (e.g., CID 5000)
    * `:country` — country of language Code (e.g., CID 5001)

  """
  @spec language_designation(keyword()) :: [ContentItem.t()]
  def language_designation(opts) when is_list(opts) do
    language = Keyword.fetch!(opts, :language)
    country = opts[:country]

    children = country_children(country)

    [
      ContentItem.code(Codes.language(), language,
        relationship_type: "HAS CONCEPT MOD",
        children: children
      )
    ]
  end

  # -- TID 1201: Language of Value -------------------------------------------

  @doc """
  Builds TID 1201 Language of Value content items.

  Wraps TID 1200 with the concept name "Language of Value" for tagging
  the language of a content item's value.

  ## Options

    * `:language` — (required) language Code
    * `:country` — country of language Code

  """
  @spec language_of_value(keyword()) :: [ContentItem.t()]
  def language_of_value(opts) when is_list(opts) do
    language = Keyword.fetch!(opts, :language)
    country = opts[:country]

    children = country_children(country)

    [
      ContentItem.code(Codes.language_of_value(), language,
        relationship_type: "HAS CONCEPT MOD",
        children: children
      )
    ]
  end

  # -- TID 1202: Language of Name and Value ----------------------------------

  @doc """
  Builds TID 1202 Language of Name and Value content items.

  Combines TID 1200 (concept name language) and TID 1201 (value language)
  when name and value may be in different languages.

  ## Options

    * `:name_language` — (required) language of concept name Code
    * `:name_country` — country for concept name language
    * `:value_language` — (required) language of value Code
    * `:value_country` — country for value language

  """
  @spec language_of_name_and_value(keyword()) :: [ContentItem.t()]
  def language_of_name_and_value(opts) when is_list(opts) do
    name_lang = Keyword.fetch!(opts, :name_language)
    value_lang = Keyword.fetch!(opts, :value_language)

    name_children = country_children(opts[:name_country])
    value_children = country_children(opts[:value_country])

    [
      ContentItem.code(Codes.language(), name_lang,
        relationship_type: "HAS CONCEPT MOD",
        children: name_children
      ),
      ContentItem.code(Codes.language_of_value(), value_lang,
        relationship_type: "HAS CONCEPT MOD",
        children: value_children
      )
    ]
  end

  # -- TID 1204: Language of Content Item and Descendants --------------------

  @doc """
  Builds TID 1204 Language of Content Item and Descendants content items.

  Returns a CODE content item using (121049, DCM, "Language of Content Item
  and Descendants") with an optional Country of Language child. This is the
  same concept used by `Dicom.SR.Observer.language/1` but with full
  template compliance including country support.

  ## Options

    * `:language` — (required) language Code
    * `:country` — country of language Code

  """
  @spec language_of_content_item_and_descendants(keyword()) :: [ContentItem.t()]
  def language_of_content_item_and_descendants(opts) when is_list(opts) do
    language = Keyword.fetch!(opts, :language)
    country = opts[:country]

    children = country_children(country)

    [
      ContentItem.code(
        Codes.language_of_content_item_and_descendants(),
        language,
        relationship_type: "HAS CONCEPT MOD",
        children: children
      )
    ]
  end

  # -- TID 1210: Equivalent Meaning(s) of Concept Name ----------------------

  @doc """
  Builds TID 1210 Equivalent Meaning(s) of Concept Name content items.

  Provides one or more equivalent meanings for the concept name of a
  content item, each tagged with its language via TID 1200.

  ## Parameters

    * `meanings` — list of `{text, language_opts}` tuples where
      `language_opts` is a keyword list with `:language` and optional `:country`

  """
  @spec equivalent_meanings_of_concept_name([{String.t(), keyword()}]) :: [ContentItem.t()]
  def equivalent_meanings_of_concept_name(meanings) when is_list(meanings) do
    Enum.flat_map(meanings, fn {text, lang_opts} ->
      lang_children = language_designation(lang_opts)

      [
        ContentItem.text(Codes.equivalent_meaning_of_concept_name(), text,
          relationship_type: "HAS CONCEPT MOD",
          children: lang_children
        )
      ]
    end)
  end

  # -- TID 1211: Equivalent Meaning(s) of Value -----------------------------

  @doc """
  Builds TID 1211 Equivalent Meaning(s) of Value content items.

  Provides one or more equivalent meanings for the value of a content item,
  each tagged with its language via TID 1200.

  ## Parameters

    * `meanings` — list of `{text, language_opts}` tuples where
      `language_opts` is a keyword list with `:language` and optional `:country`

  """
  @spec equivalent_meanings_of_value([{String.t(), keyword()}]) :: [ContentItem.t()]
  def equivalent_meanings_of_value(meanings) when is_list(meanings) do
    Enum.flat_map(meanings, fn {text, lang_opts} ->
      lang_children = language_designation(lang_opts)

      [
        ContentItem.text(Codes.equivalent_meaning_of_value(), text,
          relationship_type: "HAS CONCEPT MOD",
          children: lang_children
        )
      ]
    end)
  end

  # -- Private helpers -------------------------------------------------------

  defp country_children(nil), do: []

  defp country_children(%Code{} = country) do
    [
      ContentItem.code(Codes.country_of_language(), country, relationship_type: "HAS CONCEPT MOD")
    ]
  end
end
