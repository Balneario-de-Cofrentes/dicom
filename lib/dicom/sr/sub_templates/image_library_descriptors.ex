defmodule Dicom.SR.SubTemplates.ImageLibraryDescriptors do
  @moduledoc """
  TID 1600-1608 Image Library Entry Descriptor Sub-Templates.

  Implements the image library descriptor sub-template hierarchy:

  - TID 1602 — Image Library Entry Descriptors (common)
  - TID 1603 — Image Library Entry Descriptors for Projection Radiography
  - TID 1604 — Image Library Entry Descriptors for Cross-Sectional Modalities
  - TID 1605 — Image Library Entry Descriptors for CT
  - TID 1606 — Image Library Entry Descriptors for MR
  - TID 1607 — Image Library Entry Descriptors for PET
  - TID 1608 — Image Library Entry Descriptors for Prostate Multiparametric MR

  These sub-templates provide modality-specific descriptor content items
  for image library entries in SR documents such as TID 1500
  Measurement Report.
  """

  alias Dicom.SR.{Code, Codes, ContentItem}

  # -- TID 1602: Image Library Entry Descriptors (common) -------------------

  @doc """
  Builds TID 1602 common Image Library Entry Descriptors.

  These descriptors are shared across all modalities.

  ## Options

    * `:modality` — modality Code (CID 29)
    * `:frame_of_reference_uid` — frame of reference UID
    * `:pixel_spacing` — pixel data rows spacing (number, with `:spacing_units`)
    * `:spacing_units` — units for pixel spacing Code
    * `:slice_thickness` — slice thickness (number, with `:thickness_units`)
    * `:thickness_units` — units for slice thickness Code
    * `:image_laterality` — image laterality Code
    * `:patient_orientation_row` — patient orientation row Code
    * `:patient_orientation_column` — patient orientation column Code
    * `:horizontal_pixel_spacing` — horizontal pixel spacing (number)
    * `:vertical_pixel_spacing` — vertical pixel spacing (number)

  """
  @spec common_descriptors(keyword()) :: [ContentItem.t()]
  def common_descriptors(opts) when is_list(opts) do
    []
    |> add_code(Codes.modality(), opts[:modality])
    |> add_uidref(Codes.frame_of_reference_uid(), opts[:frame_of_reference_uid])
    |> add_num(Codes.pixel_data_rows(), opts[:pixel_spacing], opts[:spacing_units])
    |> add_num(Codes.slice_thickness(), opts[:slice_thickness], opts[:thickness_units])
    |> add_code(Codes.image_laterality(), opts[:image_laterality])
    |> add_code(Codes.patient_orientation_row(), opts[:patient_orientation_row])
    |> add_code(Codes.patient_orientation_column(), opts[:patient_orientation_column])
  end

  # -- TID 1603: Projection Radiography Descriptors -------------------------

  @doc """
  Builds TID 1603 Image Library Entry Descriptors for Projection Radiography.

  Includes TID 1602 common descriptors plus radiography-specific fields.

  ## Options

  All options from `common_descriptors/1`, plus:

    * `:positioner_primary_angle` — positioner primary angle (number, degrees)
    * `:positioner_secondary_angle` — positioner secondary angle (number, degrees)
    * `:view_code` — radiographic view Code

  """
  @spec projection_radiography_descriptors(keyword()) :: [ContentItem.t()]
  def projection_radiography_descriptors(opts) when is_list(opts) do
    degrees = Codes.degrees()

    common_descriptors(opts)
    |> add_num(Codes.positioner_primary_angle(), opts[:positioner_primary_angle], degrees)
    |> add_num(Codes.positioner_secondary_angle(), opts[:positioner_secondary_angle], degrees)
    |> add_code(Codes.radiographic_view(), opts[:view_code])
  end

  # -- TID 1604: Cross-Sectional Modality Descriptors -----------------------

  @doc """
  Builds TID 1604 Image Library Entry Descriptors for Cross-Sectional Modalities.

  Includes TID 1602 common descriptors plus cross-sectional fields.

  ## Options

  All options from `common_descriptors/1`, plus:

    * `:image_position_patient` — image position patient coordinates (TEXT)
    * `:image_orientation_patient` — image orientation patient (TEXT)
    * `:pixel_spacing_value` — pixel spacing value (number, with `:pixel_spacing_units`)
    * `:pixel_spacing_units` — units for pixel spacing
    * `:spacing_between_slices` — spacing between slices (number)
    * `:spacing_units` — units for spacing

  """
  @spec cross_sectional_descriptors(keyword()) :: [ContentItem.t()]
  def cross_sectional_descriptors(opts) when is_list(opts) do
    common_descriptors(opts)
    |> add_text(Codes.image_position_patient(), opts[:image_position_patient])
    |> add_text(Codes.image_orientation_patient(), opts[:image_orientation_patient])
    |> add_num(Codes.pixel_spacing(), opts[:pixel_spacing_value], opts[:pixel_spacing_units])
    |> add_num(
      Codes.spacing_between_slices(),
      opts[:spacing_between_slices],
      opts[:spacing_units]
    )
  end

  # -- TID 1605: CT Descriptors ---------------------------------------------

  @doc """
  Builds TID 1605 Image Library Entry Descriptors for CT.

  Includes TID 1604 cross-sectional descriptors plus CT-specific fields.

  ## Options

  All options from `cross_sectional_descriptors/1`, plus:

    * `:kvp` — peak kilovoltage (number)
    * `:tube_current` — tube current in mA (number)
    * `:exposure_time` — exposure time in ms (number)
    * `:ctdi_vol` — CTDIvol (number, with `:ctdi_units`)
    * `:ctdi_units` — units for CTDIvol Code
    * `:reconstruction_algorithm` — reconstruction algorithm Code
    * `:convolution_kernel` — convolution kernel (TEXT)
    * `:spiral_pitch_factor` — spiral pitch factor (number)

  """
  @spec ct_descriptors(keyword()) :: [ContentItem.t()]
  def ct_descriptors(opts) when is_list(opts) do
    kv = Codes.kv()
    ma = Codes.milliampere()
    ms = Codes.millisecond()

    cross_sectional_descriptors(opts)
    |> add_num(Codes.kvp(), opts[:kvp], kv)
    |> add_num(Codes.tube_current(), opts[:tube_current], ma)
    |> add_num(Codes.exposure_time(), opts[:exposure_time], ms)
    |> add_num(Codes.ctdi_vol(), opts[:ctdi_vol], opts[:ctdi_units])
    |> add_code(Codes.reconstruction_algorithm(), opts[:reconstruction_algorithm])
    |> add_text(Codes.convolution_kernel(), opts[:convolution_kernel])
    |> add_num(Codes.spiral_pitch_factor(), opts[:spiral_pitch_factor], nil)
  end

  # -- TID 1606: MR Descriptors ---------------------------------------------

  @doc """
  Builds TID 1606 Image Library Entry Descriptors for MR.

  Includes TID 1604 cross-sectional descriptors plus MR-specific fields.

  ## Options

  All options from `cross_sectional_descriptors/1`, plus:

    * `:echo_time` — echo time in ms (number)
    * `:repetition_time` — repetition time in ms (number)
    * `:flip_angle` — flip angle in degrees (number)
    * `:inversion_time` — inversion time in ms (number)
    * `:pulse_sequence_name` — pulse sequence name (TEXT)
    * `:mr_acquisition_type` — MR acquisition type Code (e.g., 2D, 3D)

  """
  @spec mr_descriptors(keyword()) :: [ContentItem.t()]
  def mr_descriptors(opts) when is_list(opts) do
    ms = Codes.millisecond()
    deg = Codes.degrees()

    cross_sectional_descriptors(opts)
    |> add_num(Codes.echo_time(), opts[:echo_time], ms)
    |> add_num(Codes.repetition_time(), opts[:repetition_time], ms)
    |> add_num(Codes.flip_angle(), opts[:flip_angle], deg)
    |> add_num(Codes.inversion_time(), opts[:inversion_time], ms)
    |> add_text(Codes.pulse_sequence_name(), opts[:pulse_sequence_name])
    |> add_code(Codes.mr_acquisition_type(), opts[:mr_acquisition_type])
  end

  # -- TID 1607: PET Descriptors --------------------------------------------

  @doc """
  Builds TID 1607 Image Library Entry Descriptors for PET.

  Includes TID 1604 cross-sectional descriptors plus PET-specific fields.

  ## Options

  All options from `cross_sectional_descriptors/1`, plus:

    * `:radiopharmaceutical` — radiopharmaceutical Code
    * `:radionuclide` — radionuclide Code
    * `:radiopharmaceutical_volume` — volume (number, with `:volume_units`)
    * `:volume_units` — units for radiopharmaceutical volume
    * `:administered_activity` — administered activity (number, with `:activity_units`)
    * `:activity_units` — units for administered activity
    * `:radiopharmaceutical_start_datetime` — start datetime (TEXT)

  """
  @spec pet_descriptors(keyword()) :: [ContentItem.t()]
  def pet_descriptors(opts) when is_list(opts) do
    cross_sectional_descriptors(opts)
    |> add_code(Codes.radiopharmaceutical(), opts[:radiopharmaceutical])
    |> add_code(Codes.radionuclide(), opts[:radionuclide])
    |> add_num(
      Codes.radiopharmaceutical_volume(),
      opts[:radiopharmaceutical_volume],
      opts[:volume_units]
    )
    |> add_num(
      Codes.administered_activity(),
      opts[:administered_activity],
      opts[:activity_units]
    )
    |> add_text(
      Codes.radiopharmaceutical_start_datetime(),
      opts[:radiopharmaceutical_start_datetime]
    )
  end

  # -- TID 1608: Prostate Multiparametric MR Descriptors --------------------

  @doc """
  Builds TID 1608 Image Library Entry Descriptors for Prostate Multiparametric MR.

  Includes TID 1606 MR descriptors plus prostate-specific fields.

  ## Options

  All options from `mr_descriptors/1`, plus:

    * `:diffusion_b_value` — diffusion b-value (number, with `:b_value_units`)
    * `:b_value_units` — units for b-value Code
    * `:adc_map` — whether image is an ADC map (boolean Code)
    * `:dynamic_contrast_enhanced` — DCE parameter (TEXT)

  """
  @spec prostate_mr_descriptors(keyword()) :: [ContentItem.t()]
  def prostate_mr_descriptors(opts) when is_list(opts) do
    mr_descriptors(opts)
    |> add_num(Codes.diffusion_b_value(), opts[:diffusion_b_value], opts[:b_value_units])
    |> add_code(Codes.adc_map_indicator(), opts[:adc_map])
    |> add_text(Codes.dynamic_contrast_enhanced(), opts[:dynamic_contrast_enhanced])
  end

  # -- Private helpers -------------------------------------------------------

  defp add_code(items, _concept, nil), do: items

  defp add_code(items, concept, %Code{} = code) do
    items ++ [ContentItem.code(concept, code, relationship_type: "HAS ACQ CONTEXT")]
  end

  defp add_text(items, _concept, nil), do: items

  defp add_text(items, concept, text) when is_binary(text) do
    items ++ [ContentItem.text(concept, text, relationship_type: "HAS ACQ CONTEXT")]
  end

  defp add_uidref(items, _concept, nil), do: items

  defp add_uidref(items, concept, uid) when is_binary(uid) do
    items ++ [ContentItem.uidref(concept, uid, relationship_type: "HAS ACQ CONTEXT")]
  end

  defp add_num(items, _concept, nil, _units), do: items

  defp add_num(items, concept, value, nil) when is_number(value) do
    no_units = Code.new("1", "UCUM", "no units")
    items ++ [ContentItem.num(concept, value, no_units, relationship_type: "HAS ACQ CONTEXT")]
  end

  defp add_num(items, concept, value, %Code{} = units) when is_number(value) do
    items ++ [ContentItem.num(concept, value, units, relationship_type: "HAS ACQ CONTEXT")]
  end
end
