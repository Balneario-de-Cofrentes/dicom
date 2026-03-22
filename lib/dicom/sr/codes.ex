defmodule Dicom.SR.Codes do
  @moduledoc """
  Common normative codes used by the current SR helpers and templates.
  """

  alias Dicom.SR.Code

  @spec imaging_measurement_report() :: Code.t()
  def imaging_measurement_report,
    do: Code.new("126000", "DCM", "Imaging Measurement Report")

  @spec imaging_measurements() :: Code.t()
  def imaging_measurements, do: Code.new("126010", "DCM", "Imaging Measurements")

  @spec measurement_group() :: Code.t()
  def measurement_group, do: Code.new("125007", "DCM", "Measurement Group")

  @spec tracking_identifier() :: Code.t()
  def tracking_identifier, do: Code.new("112039", "DCM", "Tracking Identifier")

  @spec tracking_unique_identifier() :: Code.t()
  def tracking_unique_identifier, do: Code.new("112040", "DCM", "Tracking Unique Identifier")

  @spec finding() :: Code.t()
  def finding, do: Code.new("121071", "DCM", "Finding")

  @spec finding_site() :: Code.t()
  def finding_site, do: Code.new("363698007", "SCT", "Finding Site")

  @spec impression() :: Code.t()
  def impression, do: Code.new("121073", "DCM", "Impression")

  @spec recommendation() :: Code.t()
  def recommendation, do: Code.new("121075", "DCM", "Recommendation")

  @spec procedure_reported() :: Code.t()
  def procedure_reported, do: Code.new("121058", "DCM", "Procedure reported")

  @spec language_of_content_item_and_descendants() :: Code.t()
  def language_of_content_item_and_descendants,
    do: Code.new("121049", "DCM", "Language of Content Item and Descendants")

  @spec observer_type() :: Code.t()
  def observer_type, do: Code.new("121005", "DCM", "Observer Type")

  @spec person() :: Code.t()
  def person, do: Code.new("121006", "DCM", "Person")

  @spec device() :: Code.t()
  def device, do: Code.new("121007", "DCM", "Device")

  @spec device_observer_uid() :: Code.t()
  def device_observer_uid, do: Code.new("121012", "DCM", "Device Observer UID")

  @spec device_observer_name() :: Code.t()
  def device_observer_name, do: Code.new("121013", "DCM", "Device Observer Name")

  @spec device_observer_manufacturer() :: Code.t()
  def device_observer_manufacturer,
    do: Code.new("121014", "DCM", "Device Observer Manufacturer")

  @spec device_observer_model_name() :: Code.t()
  def device_observer_model_name, do: Code.new("121015", "DCM", "Device Observer Model Name")

  @spec device_observer_serial_number() :: Code.t()
  def device_observer_serial_number,
    do: Code.new("121016", "DCM", "Device Observer Serial Number")

  @spec person_observer_name() :: Code.t()
  def person_observer_name, do: Code.new("121008", "DCM", "Person Observer Name")

  @spec source() :: Code.t()
  def source, do: Code.new("260753009", "SCT", "Source")

  @spec image_library() :: Code.t()
  def image_library, do: Code.new("111028", "DCM", "Image Library")

  @spec image_region() :: Code.t()
  def image_region, do: Code.new("111030", "DCM", "Image Region")

  @spec original_source() :: Code.t()
  def original_source, do: Code.new("111040", "DCM", "Original Source")

  @spec procedure_description() :: Code.t()
  def procedure_description, do: Code.new("121065", "DCM", "Procedure Description")

  @spec activity_session() :: Code.t()
  def activity_session, do: Code.new("C67447", "NCIt", "Activity Session")

  @spec finding_category() :: Code.t()
  def finding_category, do: Code.new("276214006", "SCT", "Finding category")

  @spec ecg_report() :: Code.t()
  def ecg_report, do: Code.new("28010-7", "LN", "ECG Report")

  @spec ecg_global_measurements() :: Code.t()
  def ecg_global_measurements, do: Code.new("122158", "DCM", "ECG Global Measurements")

  @spec ecg_lead_measurements() :: Code.t()
  def ecg_lead_measurements, do: Code.new("122159", "DCM", "ECG Lead Measurements")

  @spec stress_testing_report() :: Code.t()
  def stress_testing_report, do: Code.new("18752-6", "LN", "Stress Testing Report")

  # Key Object Selection codes (TID 2000)

  @spec key_object_selection() :: Code.t()
  def key_object_selection, do: Code.new("113000", "DCM", "Of Interest")

  @spec key_object_description() :: Code.t()
  def key_object_description, do: Code.new("113012", "DCM", "Key Object Description")

  @spec rejected_for_quality_reasons() :: Code.t()
  def rejected_for_quality_reasons,
    do: Code.new("113001", "DCM", "Rejected for Quality Reasons")

  @spec best_in_set() :: Code.t()
  def best_in_set, do: Code.new("113018", "DCM", "Best In Set")

  # Waveform Annotation codes (TID 3750)

  @spec waveform_annotation() :: Code.t()
  def waveform_annotation, do: Code.new("122172", "DCM", "Waveform Annotation")

  @spec comment() :: Code.t()
  def comment, do: Code.new("121106", "DCM", "Comment")

  @spec waveform_reference() :: Code.t()
  def waveform_reference, do: Code.new("122175", "DCM", "Waveform Reference")
end
