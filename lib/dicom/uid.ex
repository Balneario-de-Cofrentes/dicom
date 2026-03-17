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
  Returns true if the UID represents a known transfer syntax.

  Uses the `Dicom.TransferSyntax` registry for authoritative O(1) lookup.
  """
  @spec transfer_syntax?(String.t()) :: boolean()
  def transfer_syntax?(uid) when is_binary(uid) do
    Dicom.TransferSyntax.known?(uid)
  end

  @doc """
  Returns true if the UID represents a storage SOP class.

  Delegates to `Dicom.SopClass.storage?/1` for accurate O(1) lookup
  against the full registry of storage SOP classes.
  """
  @spec storage_sop_class?(String.t()) :: boolean()
  def storage_sop_class?(uid) when is_binary(uid) do
    Dicom.SopClass.storage?(uid)
  end

  @org_root "1.2.826.0.1.3680043.10.1137"

  @doc """
  Generates a unique DICOM UID.

  Uses the library's org root followed by a timestamp and random component.
  The result is guaranteed to be <= 64 characters.
  """
  @spec generate() :: String.t()
  def generate do
    timestamp = System.system_time(:microsecond)
    random = :rand.uniform(999_999_999)
    "#{@org_root}.#{timestamp}.#{random}"
  end

  @doc """
  Validates a DICOM UID format.

  Per PS3.5 Section 9: UIDs are max 64 characters, contain only digits and dots,
  no leading zeros in components (except "0" itself), and must have at least
  two components.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(uid) when is_binary(uid) do
    byte_size(uid) > 0 and
      byte_size(uid) <= 64 and
      Regex.match?(~r/^[0-9.]+$/, uid) and
      valid_components?(uid)
  end

  def valid?(_), do: false

  defp valid_components?(uid) do
    components = String.split(uid, ".")

    case components do
      [first, second | _rest] ->
        Enum.all?(components, &valid_component?/1) and valid_root_components?(first, second)

      _ ->
        false
    end
  end

  defp valid_component?(""), do: false
  defp valid_component?("0"), do: true
  defp valid_component?(<<"0", _::binary>>), do: false
  defp valid_component?(_), do: true

  defp valid_root_components?(first, second) do
    with {first_arc, ""} <- Integer.parse(first),
         {second_arc, ""} <- Integer.parse(second),
         true <- first_arc in 0..2 do
      if first_arc < 2, do: second_arc <= 39, else: true
    else
      _ -> false
    end
  end
end
