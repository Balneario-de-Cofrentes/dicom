defmodule Dicom.Tag do
  @moduledoc """
  DICOM Tag constants and utilities.

  Tags are `{group, element}` tuples identifying DICOM attributes.
  This module provides constants for commonly used tags and lookup
  functions for the full PS3.6 data dictionary.

  ## Examples

      iex> Dicom.Tag.patient_name()
      {0x0010, 0x0010}

      iex> Dicom.Tag.name({0x0010, 0x0010})
      "PatientName"
  """

  @type t :: {non_neg_integer(), non_neg_integer()}

  # File Meta Information (Group 0002)
  def file_meta_information_group_length, do: {0x0002, 0x0000}
  def file_meta_information_version, do: {0x0002, 0x0001}
  def media_storage_sop_class_uid, do: {0x0002, 0x0002}
  def media_storage_sop_instance_uid, do: {0x0002, 0x0003}
  def transfer_syntax_uid, do: {0x0002, 0x0010}
  def implementation_class_uid, do: {0x0002, 0x0012}
  def implementation_version_name, do: {0x0002, 0x0013}
  def source_application_entity_title, do: {0x0002, 0x0016}
  def sending_application_entity_title, do: {0x0002, 0x0017}
  def receiving_application_entity_title, do: {0x0002, 0x0018}
  def source_presentation_address, do: {0x0002, 0x0026}
  def sending_presentation_address, do: {0x0002, 0x0027}
  def receiving_presentation_address, do: {0x0002, 0x0028}
  def private_information_creator_uid, do: {0x0002, 0x0100}
  def private_information, do: {0x0002, 0x0102}

  # Data Set Trailing Padding (PS3.10 Section 7.2)
  def data_set_trailing_padding, do: {0xFFFC, 0xFFFC}

  # Patient (Group 0010)
  def patient_name, do: {0x0010, 0x0010}
  def patient_id, do: {0x0010, 0x0020}
  def patient_birth_date, do: {0x0010, 0x0030}
  def patient_sex, do: {0x0010, 0x0040}
  def patient_age, do: {0x0010, 0x1010}

  # Study (Group 0008/0020)
  def study_date, do: {0x0008, 0x0020}
  def study_time, do: {0x0008, 0x0030}
  def accession_number, do: {0x0008, 0x0050}
  def referring_physician_name, do: {0x0008, 0x0090}
  def study_description, do: {0x0008, 0x1030}
  def study_instance_uid, do: {0x0020, 0x000D}
  def study_id, do: {0x0020, 0x0010}

  # Series
  def modality, do: {0x0008, 0x0060}
  def series_description, do: {0x0008, 0x103E}
  def series_instance_uid, do: {0x0020, 0x000E}
  def series_number, do: {0x0020, 0x0011}
  def body_part_examined, do: {0x0018, 0x0015}

  # Instance / SOP Common
  def sop_class_uid, do: {0x0008, 0x0016}
  def sop_instance_uid, do: {0x0008, 0x0018}
  def instance_number, do: {0x0020, 0x0013}
  def instance_creation_date, do: {0x0008, 0x0012}
  def instance_creation_time, do: {0x0008, 0x0013}

  # Image
  def rows, do: {0x0028, 0x0010}
  def columns, do: {0x0028, 0x0011}
  def bits_allocated, do: {0x0028, 0x0100}
  def bits_stored, do: {0x0028, 0x0101}
  def high_bit, do: {0x0028, 0x0102}
  def pixel_representation, do: {0x0028, 0x0103}
  def samples_per_pixel, do: {0x0028, 0x0002}
  def photometric_interpretation, do: {0x0028, 0x0004}
  def pixel_data, do: {0x7FE0, 0x0010}
  def number_of_frames, do: {0x0028, 0x0008}

  # Sequence delimitation
  def item, do: {0xFFFE, 0xE000}
  def item_delimitation, do: {0xFFFE, 0xE00D}
  def sequence_delimitation, do: {0xFFFE, 0xE0DD}

  @doc """
  Returns the human-readable name for a tag, or a hex string if unknown.
  """
  @spec name(t()) :: String.t()
  def name(tag) do
    case Dicom.Dictionary.Registry.lookup(tag) do
      {:ok, name, _vr, _vm} -> name
      :error -> format(tag)
    end
  end

  @doc """
  Formats a tag as a `(GGGG,EEEE)` hex string.

  ## Examples

      iex> Dicom.Tag.format({0x0010, 0x0010})
      "(0010,0010)"
  """
  @spec format(t()) :: String.t()
  def format({group, element}) do
    g = group |> Integer.to_string(16) |> String.pad_leading(4, "0")
    e = element |> Integer.to_string(16) |> String.pad_leading(4, "0")
    "(#{g},#{e})"
  end

  @doc """
  Returns true if the tag is a private tag (odd group number).
  """
  @spec private?(t()) :: boolean()
  def private?({group, _element}), do: rem(group, 2) == 1

  @doc """
  Returns true if the tag is a group length tag (element 0000).
  """
  @spec group_length?(t()) :: boolean()
  def group_length?({_group, 0x0000}), do: true
  def group_length?(_), do: false
end
