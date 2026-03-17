defmodule Dicom.DeIdentification.Profile do
  @moduledoc """
  De-identification profile options (PS3.15 Table E.1-1 option columns).

  The 10 boolean options correspond to the DICOM standard's option
  columns that modify the Basic Application Level Confidentiality Profile.
  """

  @type t :: %__MODULE__{
          retain_uids: boolean(),
          retain_device_identity: boolean(),
          retain_patient_characteristics: boolean(),
          retain_institution_identity: boolean(),
          retain_long_full_dates: boolean(),
          retain_long_modified_dates: boolean(),
          clean_descriptions: boolean(),
          clean_structured_content: boolean(),
          clean_graphics: boolean(),
          retain_safe_private: boolean()
        }

  defstruct retain_uids: false,
            retain_device_identity: false,
            retain_patient_characteristics: false,
            retain_institution_identity: false,
            retain_long_full_dates: false,
            retain_long_modified_dates: false,
            clean_descriptions: false,
            clean_structured_content: false,
            clean_graphics: false,
            retain_safe_private: false
end
