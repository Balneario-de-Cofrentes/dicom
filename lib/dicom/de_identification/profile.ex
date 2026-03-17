defmodule Dicom.DeIdentification.Profile do
  @moduledoc """
  De-identification profile options (PS3.15 Table E.1-1 option columns).

  The 10 standard boolean options mirror the PS3.15 profile flags and are
  applied to the supported tag set in `Dicom.DeIdentification`.

  `retain_private_tags` is a library-specific switch that retains all private
  tags. `retain_safe_private` is kept as a compatibility alias for the same
  behavior, but it does not implement the PS3.15 Retain Safe Private Option.

  When overlapping options target the same tag, `Dicom.DeIdentification`
  applies the more conservative override. For temporal tags, that means
  `retain_long_full_dates` takes precedence over `retain_long_modified_dates`.
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
          retain_private_tags: boolean(),
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
            retain_private_tags: false,
            retain_safe_private: false
end
