defmodule Dicom.SR.Constraints.MeasurementReport do
  @moduledoc """
  Content constraints for TID 1500 — Measurement Report.

  Defines the expected structure of a Measurement Report root container
  per PS3.16 TID 1500. Covers the most commonly validated slots:

    - Language of Content (HAS CONCEPT MOD, optional)
    - Observer Type / Person Observer Name (HAS OBS CONTEXT, mandatory)
    - Procedure Reported (HAS CONCEPT MOD, mandatory 1-n)
    - Image Library (CONTAINS, optional)
    - Imaging Measurements (CONTAINS, mandatory)
  """

  alias Dicom.SR.{Codes, ContentConstraint}

  @doc """
  Returns the list of child constraints for a TID 1500 root container.
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
        concept_name: Codes.procedure_reported(),
        value_type: :code,
        relationship_type: "HAS CONCEPT MOD",
        requirement: :mandatory,
        vm: :one_or_more
      },
      %ContentConstraint{
        concept_name: Codes.image_library(),
        value_type: :container,
        relationship_type: "CONTAINS",
        requirement: :optional,
        vm: :zero_or_one
      },
      %ContentConstraint{
        concept_name: Codes.imaging_measurements(),
        value_type: :container,
        relationship_type: "CONTAINS",
        requirement: :mandatory,
        vm: :one,
        children: [
          %ContentConstraint{
            concept_name: Codes.measurement_group(),
            value_type: :container,
            relationship_type: "CONTAINS",
            requirement: :optional,
            vm: :zero_or_more
          }
        ]
      }
    ]
  end

  @doc """
  Returns the expected root concept name code for TID 1500.
  """
  @spec root_concept() :: Dicom.SR.Code.t()
  def root_concept, do: Codes.imaging_measurement_report()
end
