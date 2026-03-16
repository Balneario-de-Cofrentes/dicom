defmodule Dicom.UID do
  @moduledoc """
  DICOM UID constants for SOP Classes and Transfer Syntaxes.

  Reference: DICOM PS3.4 (SOP Classes) and PS3.5 (Transfer Syntaxes).
  """

  # Transfer Syntaxes
  def implicit_vr_little_endian, do: "1.2.840.10008.1.2"
  def explicit_vr_little_endian, do: "1.2.840.10008.1.2.1"
  def explicit_vr_big_endian, do: "1.2.840.10008.1.2.2"
  def deflated_explicit_vr_little_endian, do: "1.2.840.10008.1.2.1.99"
  def jpeg_baseline, do: "1.2.840.10008.1.2.4.50"
  def jpeg_extended, do: "1.2.840.10008.1.2.4.51"
  def jpeg_lossless, do: "1.2.840.10008.1.2.4.70"
  def jpeg_lossless_first_order, do: "1.2.840.10008.1.2.4.57"
  def jpeg_ls_lossless, do: "1.2.840.10008.1.2.4.80"
  def jpeg_ls_lossy, do: "1.2.840.10008.1.2.4.81"
  def jpeg_2000_lossless, do: "1.2.840.10008.1.2.4.90"
  def jpeg_2000, do: "1.2.840.10008.1.2.4.91"
  def rle_lossless, do: "1.2.840.10008.1.2.5"

  # Verification
  def verification_sop_class, do: "1.2.840.10008.1.1"

  # Storage SOP Classes
  def ct_image_storage, do: "1.2.840.10008.5.1.4.1.1.2"
  def mr_image_storage, do: "1.2.840.10008.5.1.4.1.1.4"
  def cr_image_storage, do: "1.2.840.10008.5.1.4.1.1.1"
  def dx_image_storage, do: "1.2.840.10008.5.1.4.1.1.1.1"
  def us_image_storage, do: "1.2.840.10008.5.1.4.1.1.6.1"
  def nm_image_storage, do: "1.2.840.10008.5.1.4.1.1.20"
  def sc_image_storage, do: "1.2.840.10008.5.1.4.1.1.7"
  def enhanced_ct_image_storage, do: "1.2.840.10008.5.1.4.1.1.2.1"
  def enhanced_mr_image_storage, do: "1.2.840.10008.5.1.4.1.1.4.1"
  def rt_plan_storage, do: "1.2.840.10008.5.1.4.1.1.481.5"
  def rt_dose_storage, do: "1.2.840.10008.5.1.4.1.1.481.2"
  def rt_structure_set_storage, do: "1.2.840.10008.5.1.4.1.1.481.3"
  def basic_text_sr_storage, do: "1.2.840.10008.5.1.4.1.1.88.11"
  def enhanced_sr_storage, do: "1.2.840.10008.5.1.4.1.1.88.22"
  def comprehensive_sr_storage, do: "1.2.840.10008.5.1.4.1.1.88.33"
  def encapsulated_pdf_storage, do: "1.2.840.10008.5.1.4.1.1.104.1"
  def segmentation_storage, do: "1.2.840.10008.5.1.4.1.1.66.4"

  # Query/Retrieve SOP Classes
  def patient_root_qr_find, do: "1.2.840.10008.5.1.4.1.2.1.1"
  def patient_root_qr_move, do: "1.2.840.10008.5.1.4.1.2.1.2"
  def patient_root_qr_get, do: "1.2.840.10008.5.1.4.1.2.1.3"
  def study_root_qr_find, do: "1.2.840.10008.5.1.4.1.2.2.1"
  def study_root_qr_move, do: "1.2.840.10008.5.1.4.1.2.2.2"
  def study_root_qr_get, do: "1.2.840.10008.5.1.4.1.2.2.3"

  # Modality Worklist
  def modality_worklist_find, do: "1.2.840.10008.5.1.4.31"

  @doc """
  Returns true if the UID represents a transfer syntax.
  """
  @spec transfer_syntax?(String.t()) :: boolean()
  def transfer_syntax?(uid) when is_binary(uid) do
    String.starts_with?(uid, "1.2.840.10008.1.2")
  end

  @doc """
  Returns true if the UID represents a storage SOP class.
  """
  @spec storage_sop_class?(String.t()) :: boolean()
  def storage_sop_class?(uid) when is_binary(uid) do
    String.starts_with?(uid, "1.2.840.10008.5.1.4.1.1")
  end
end
