defmodule Dicom.Dictionary.Registry do
  @moduledoc """
  DICOM Data Dictionary tag registry.

  Maps `{group, element}` tags to their name, VR, and VM (Value Multiplicity).
  This is a subset of the full PS3.6 dictionary covering the most commonly
  used tags. The full dictionary will be generated from the DICOM standard XML.

  Reference: DICOM PS3.6.
  """

  @type entry :: {String.t(), Dicom.VR.t(), String.t()}

  @doc """
  Looks up a tag in the dictionary.

  Returns `{:ok, name, vr, vm}` or `:error` if not found.
  """
  @spec lookup(Dicom.Tag.t()) :: {:ok, String.t(), Dicom.VR.t(), String.t()} | :error
  def lookup(tag)

  # File Meta Information
  def lookup({0x0002, 0x0000}), do: {:ok, "FileMetaInformationGroupLength", :UL, "1"}
  def lookup({0x0002, 0x0001}), do: {:ok, "FileMetaInformationVersion", :OB, "1"}
  def lookup({0x0002, 0x0002}), do: {:ok, "MediaStorageSOPClassUID", :UI, "1"}
  def lookup({0x0002, 0x0003}), do: {:ok, "MediaStorageSOPInstanceUID", :UI, "1"}
  def lookup({0x0002, 0x0010}), do: {:ok, "TransferSyntaxUID", :UI, "1"}
  def lookup({0x0002, 0x0012}), do: {:ok, "ImplementationClassUID", :UI, "1"}
  def lookup({0x0002, 0x0013}), do: {:ok, "ImplementationVersionName", :SH, "1"}
  def lookup({0x0002, 0x0016}), do: {:ok, "SourceApplicationEntityTitle", :AE, "1"}

  # SOP Common
  def lookup({0x0008, 0x0005}), do: {:ok, "SpecificCharacterSet", :CS, "1-n"}
  def lookup({0x0008, 0x0008}), do: {:ok, "ImageType", :CS, "2-n"}
  def lookup({0x0008, 0x0012}), do: {:ok, "InstanceCreationDate", :DA, "1"}
  def lookup({0x0008, 0x0013}), do: {:ok, "InstanceCreationTime", :TM, "1"}
  def lookup({0x0008, 0x0016}), do: {:ok, "SOPClassUID", :UI, "1"}
  def lookup({0x0008, 0x0018}), do: {:ok, "SOPInstanceUID", :UI, "1"}
  def lookup({0x0008, 0x0020}), do: {:ok, "StudyDate", :DA, "1"}
  def lookup({0x0008, 0x0021}), do: {:ok, "SeriesDate", :DA, "1"}
  def lookup({0x0008, 0x0030}), do: {:ok, "StudyTime", :TM, "1"}
  def lookup({0x0008, 0x0031}), do: {:ok, "SeriesTime", :TM, "1"}
  def lookup({0x0008, 0x0050}), do: {:ok, "AccessionNumber", :SH, "1"}
  def lookup({0x0008, 0x0060}), do: {:ok, "Modality", :CS, "1"}
  def lookup({0x0008, 0x0070}), do: {:ok, "Manufacturer", :LO, "1"}
  def lookup({0x0008, 0x0080}), do: {:ok, "InstitutionName", :LO, "1"}
  def lookup({0x0008, 0x0090}), do: {:ok, "ReferringPhysicianName", :PN, "1"}
  def lookup({0x0008, 0x1030}), do: {:ok, "StudyDescription", :LO, "1"}
  def lookup({0x0008, 0x103E}), do: {:ok, "SeriesDescription", :LO, "1"}

  # Patient
  def lookup({0x0010, 0x0010}), do: {:ok, "PatientName", :PN, "1"}
  def lookup({0x0010, 0x0020}), do: {:ok, "PatientID", :LO, "1"}
  def lookup({0x0010, 0x0030}), do: {:ok, "PatientBirthDate", :DA, "1"}
  def lookup({0x0010, 0x0040}), do: {:ok, "PatientSex", :CS, "1"}
  def lookup({0x0010, 0x1010}), do: {:ok, "PatientAge", :AS, "1"}
  def lookup({0x0010, 0x1020}), do: {:ok, "PatientSize", :DS, "1"}
  def lookup({0x0010, 0x1030}), do: {:ok, "PatientWeight", :DS, "1"}

  # Equipment
  def lookup({0x0018, 0x0015}), do: {:ok, "BodyPartExamined", :CS, "1"}
  def lookup({0x0018, 0x0050}), do: {:ok, "SliceThickness", :DS, "1"}
  def lookup({0x0018, 0x0060}), do: {:ok, "KVP", :DS, "1"}
  def lookup({0x0018, 0x0088}), do: {:ok, "SpacingBetweenSlices", :DS, "1"}
  def lookup({0x0018, 0x1100}), do: {:ok, "ReconstructionDiameter", :DS, "1"}
  def lookup({0x0018, 0x1150}), do: {:ok, "ExposureTime", :IS, "1"}
  def lookup({0x0018, 0x1151}), do: {:ok, "XRayTubeCurrent", :IS, "1"}
  def lookup({0x0018, 0x1152}), do: {:ok, "Exposure", :IS, "1"}
  def lookup({0x0018, 0x5100}), do: {:ok, "PatientPosition", :CS, "1"}

  # Study/Series/Instance UIDs
  def lookup({0x0020, 0x000D}), do: {:ok, "StudyInstanceUID", :UI, "1"}
  def lookup({0x0020, 0x000E}), do: {:ok, "SeriesInstanceUID", :UI, "1"}
  def lookup({0x0020, 0x0010}), do: {:ok, "StudyID", :SH, "1"}
  def lookup({0x0020, 0x0011}), do: {:ok, "SeriesNumber", :IS, "1"}
  def lookup({0x0020, 0x0013}), do: {:ok, "InstanceNumber", :IS, "1"}
  def lookup({0x0020, 0x0032}), do: {:ok, "ImagePositionPatient", :DS, "3"}
  def lookup({0x0020, 0x0037}), do: {:ok, "ImageOrientationPatient", :DS, "6"}
  def lookup({0x0020, 0x0052}), do: {:ok, "FrameOfReferenceUID", :UI, "1"}
  def lookup({0x0020, 0x1041}), do: {:ok, "SliceLocation", :DS, "1"}

  # Image Pixel
  def lookup({0x0028, 0x0002}), do: {:ok, "SamplesPerPixel", :US, "1"}
  def lookup({0x0028, 0x0004}), do: {:ok, "PhotometricInterpretation", :CS, "1"}
  def lookup({0x0028, 0x0008}), do: {:ok, "NumberOfFrames", :IS, "1"}
  def lookup({0x0028, 0x0010}), do: {:ok, "Rows", :US, "1"}
  def lookup({0x0028, 0x0011}), do: {:ok, "Columns", :US, "1"}
  def lookup({0x0028, 0x0030}), do: {:ok, "PixelSpacing", :DS, "2"}
  def lookup({0x0028, 0x0100}), do: {:ok, "BitsAllocated", :US, "1"}
  def lookup({0x0028, 0x0101}), do: {:ok, "BitsStored", :US, "1"}
  def lookup({0x0028, 0x0102}), do: {:ok, "HighBit", :US, "1"}
  def lookup({0x0028, 0x0103}), do: {:ok, "PixelRepresentation", :US, "1"}
  def lookup({0x0028, 0x1050}), do: {:ok, "WindowCenter", :DS, "1-n"}
  def lookup({0x0028, 0x1051}), do: {:ok, "WindowWidth", :DS, "1-n"}
  def lookup({0x0028, 0x1052}), do: {:ok, "RescaleIntercept", :DS, "1"}
  def lookup({0x0028, 0x1053}), do: {:ok, "RescaleSlope", :DS, "1"}

  # Pixel Data
  def lookup({0x7FE0, 0x0010}), do: {:ok, "PixelData", :OW, "1"}

  # Catch-all
  def lookup(_), do: :error
end
