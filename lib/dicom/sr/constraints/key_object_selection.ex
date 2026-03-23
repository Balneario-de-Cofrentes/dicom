defmodule Dicom.SR.Constraints.KeyObjectSelection do
  @moduledoc """
  Content constraints for TID 2010 — Key Object Selection.

  Defines the expected structure of a Key Object Selection root container
  per PS3.16 TID 2010. Structure:

    - Language of Content (HAS CONCEPT MOD, optional)
    - Observer Type (HAS OBS CONTEXT, mandatory)
    - Person Observer Name (HAS OBS CONTEXT, mandatory)
    - Key Object Description (CONTAINS, optional TEXT)
    - Image references (CONTAINS, mandatory 1-n IMAGE)
  """

  alias Dicom.SR.{Codes, ContentConstraint}

  @doc """
  Returns the list of child constraints for a TID 2010 root container.
  """
  @spec constraints() :: [ContentConstraint.t()]
  def constraints do
    [
      %ContentConstraint{
        concept_name: Codes.language_of_content_item_and_descendants(),
        value_type: :code,
        relationship_type: "HAS CONCEPT MOD",
        requirement: :optional,
        vm: :zero_or_one
      },
      %ContentConstraint{
        concept_name: Codes.observer_type(),
        value_type: :code,
        relationship_type: "HAS OBS CONTEXT",
        requirement: :mandatory,
        vm: :one_or_more
      },
      %ContentConstraint{
        concept_name: Codes.person_observer_name(),
        value_type: :pname,
        relationship_type: "HAS OBS CONTEXT",
        requirement: :mandatory,
        vm: :one_or_more
      },
      %ContentConstraint{
        concept_name: Codes.key_object_description(),
        value_type: :text,
        relationship_type: "CONTAINS",
        requirement: :optional,
        vm: :zero_or_one
      },
      %ContentConstraint{
        concept_name: Codes.source(),
        value_type: :image,
        relationship_type: "CONTAINS",
        requirement: :mandatory,
        vm: :one_or_more
      }
    ]
  end

  @doc """
  Returns the expected root concept name code for TID 2010.
  """
  @spec root_concept() :: Dicom.SR.Code.t()
  def root_concept, do: Codes.key_object_selection()
end
