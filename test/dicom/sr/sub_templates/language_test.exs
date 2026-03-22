defmodule Dicom.SR.SubTemplates.LanguageTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.Language

  @english Code.new("en", "RFC5646", "English")
  @spanish Code.new("es", "RFC5646", "Spanish")
  @us Code.new("US", "ISO3166_1", "United States")
  @spain Code.new("ES", "ISO3166_1", "Spain")

  # -- TID 1200 Language Designation -----------------------------------------

  describe "language_designation/1" do
    test "builds language code item" do
      [item] = Language.language_designation(language: @english)
      assert item.value_type == :code
      assert item.concept_name == Codes.language()
      assert item.value == @english
      assert item.relationship_type == "HAS CONCEPT MOD"
      assert item.children == []
    end

    test "includes country child when provided" do
      [item] = Language.language_designation(language: @english, country: @us)
      assert item.value == @english
      assert length(item.children) == 1

      [country] = item.children
      assert country.value_type == :code
      assert country.concept_name == Codes.country_of_language()
      assert country.value == @us
      assert country.relationship_type == "HAS CONCEPT MOD"
    end

    test "raises when language is missing" do
      assert_raise KeyError, fn ->
        Language.language_designation([])
      end
    end
  end

  # -- TID 1201 Language of Value -------------------------------------------

  describe "language_of_value/1" do
    test "builds language of value item" do
      [item] = Language.language_of_value(language: @spanish)
      assert item.value_type == :code
      assert item.concept_name == Codes.language_of_value()
      assert item.value == @spanish
      assert item.relationship_type == "HAS CONCEPT MOD"
    end

    test "includes country child" do
      [item] = Language.language_of_value(language: @spanish, country: @spain)
      assert length(item.children) == 1
      [country] = item.children
      assert country.value == @spain
    end
  end

  # -- TID 1202 Language of Name and Value ----------------------------------

  describe "language_of_name_and_value/1" do
    test "builds separate name and value language items" do
      items =
        Language.language_of_name_and_value(
          name_language: @english,
          value_language: @spanish
        )

      assert length(items) == 2
      [name_item, value_item] = items

      assert name_item.concept_name == Codes.language()
      assert name_item.value == @english

      assert value_item.concept_name == Codes.language_of_value()
      assert value_item.value == @spanish
    end

    test "supports country for both name and value" do
      items =
        Language.language_of_name_and_value(
          name_language: @english,
          name_country: @us,
          value_language: @spanish,
          value_country: @spain
        )

      [name_item, value_item] = items
      assert length(name_item.children) == 1
      assert length(value_item.children) == 1

      [name_country] = name_item.children
      assert name_country.value == @us

      [value_country] = value_item.children
      assert value_country.value == @spain
    end

    test "raises without required languages" do
      assert_raise KeyError, fn ->
        Language.language_of_name_and_value(name_language: @english)
      end

      assert_raise KeyError, fn ->
        Language.language_of_name_and_value(value_language: @spanish)
      end
    end
  end

  # -- TID 1204 Language of Content Item and Descendants --------------------

  describe "language_of_content_item_and_descendants/1" do
    test "builds content item language code" do
      [item] = Language.language_of_content_item_and_descendants(language: @english)
      assert item.value_type == :code
      assert item.concept_name == Codes.language_of_content_item_and_descendants()
      assert item.value == @english
      assert item.relationship_type == "HAS CONCEPT MOD"
    end

    test "includes country child" do
      [item] =
        Language.language_of_content_item_and_descendants(
          language: @english,
          country: @us
        )

      assert length(item.children) == 1
      [country] = item.children
      assert country.concept_name == Codes.country_of_language()
    end

    test "matches existing Observer.language/1 concept" do
      observer_item = Dicom.SR.Observer.language(@english)

      [template_item] =
        Language.language_of_content_item_and_descendants(language: @english)

      assert template_item.concept_name == observer_item.concept_name
      assert template_item.value == observer_item.value
    end
  end

  # -- TID 1210 Equivalent Meaning(s) of Concept Name ----------------------

  describe "equivalent_meanings_of_concept_name/1" do
    test "builds single equivalent meaning" do
      [item] =
        Language.equivalent_meanings_of_concept_name([
          {"Hallazgo", [language: @spanish]}
        ])

      assert item.value_type == :text
      assert item.concept_name == Codes.equivalent_meaning_of_concept_name()
      assert item.value == "Hallazgo"
      assert item.relationship_type == "HAS CONCEPT MOD"
      assert length(item.children) == 1
    end

    test "builds multiple equivalent meanings" do
      items =
        Language.equivalent_meanings_of_concept_name([
          {"Hallazgo", [language: @spanish]},
          {"Finding", [language: @english, country: @us]}
        ])

      assert length(items) == 2

      [spanish_item, english_item] = items
      assert spanish_item.value == "Hallazgo"
      assert english_item.value == "Finding"

      # English item should have a language child with country grandchild
      [lang_child] = english_item.children
      assert lang_child.value_type == :code
      assert length(lang_child.children) == 1
    end

    test "returns empty list for empty input" do
      assert Language.equivalent_meanings_of_concept_name([]) == []
    end
  end

  # -- TID 1211 Equivalent Meaning(s) of Value ------------------------------

  describe "equivalent_meanings_of_value/1" do
    test "builds single equivalent meaning of value" do
      [item] =
        Language.equivalent_meanings_of_value([
          {"Positive", [language: @english]}
        ])

      assert item.value_type == :text
      assert item.concept_name == Codes.equivalent_meaning_of_value()
      assert item.value == "Positive"
      assert item.relationship_type == "HAS CONCEPT MOD"
    end

    test "builds multiple equivalent meanings with language tags" do
      items =
        Language.equivalent_meanings_of_value([
          {"Positivo", [language: @spanish, country: @spain]},
          {"Positive", [language: @english]}
        ])

      assert length(items) == 2
      [es_item, en_item] = items
      assert es_item.value == "Positivo"
      assert en_item.value == "Positive"
    end

    test "returns empty list for empty input" do
      assert Language.equivalent_meanings_of_value([]) == []
    end
  end
end
