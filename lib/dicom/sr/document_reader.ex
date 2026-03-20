defmodule Dicom.SR.DocumentReader do
  @moduledoc """
  Extracts document-level SR metadata from a parsed DICOM data set.

  Complements `Dicom.SR.Document` (the write path) by providing the
  reverse extraction of SR document attributes from a parsed data set.

  ## Usage

      {:ok, data_set} = Dicom.parse(p10_binary)
      {:ok, metadata} = Dicom.SR.DocumentReader.from_data_set(data_set)
      metadata.completion_flag       #=> "COMPLETE"
      metadata.template_identifier   #=> "1500"

  Reference: DICOM PS3.3 Section C.17.2 (SR Document General Module).
  """

  alias Dicom.{DataSet, Tag}

  @doc """
  Extracts document-level SR metadata from a parsed data set.

  Returns a map with the following keys:

    * `:completion_flag` - "COMPLETE" or "PARTIAL" (tag 0040,A491)
    * `:completion_flag_description` - optional description (tag 0040,A492)
    * `:verification_flag` - "VERIFIED" or "UNVERIFIED" (tag 0040,A493)
    * `:content_date` - content date as DICOM DA string (tag 0008,0023)
    * `:content_time` - content time as DICOM TM string (tag 0008,0033)
    * `:template_identifier` - template ID from Content Template Sequence (tag 0040,A504)
    * `:mapping_resource` - mapping resource from Content Template Sequence (tag 0008,0105)
    * `:sop_class_uid` - SOP Class UID (tag 0008,0016)
    * `:sop_instance_uid` - SOP Instance UID (tag 0008,0018)
    * `:study_instance_uid` - Study Instance UID (tag 0020,000D)
    * `:series_instance_uid` - Series Instance UID (tag 0020,000E)
    * `:modality` - Modality (tag 0008,0060)
    * `:verification_datetime` - verification timestamp (tag 0040,A030)
    * `:verifying_observer_name` - observer name from Verifying Observer Sequence (tag 0040,A073)
  """
  @spec from_data_set(DataSet.t()) :: {:ok, map()} | {:error, term()}
  def from_data_set(%DataSet{} = ds) do
    {template_id, mapping_resource} = extract_template_info(ds)
    {verification_datetime, verifying_observer_name} = extract_verification_info(ds)

    metadata = %{
      completion_flag: get_trimmed(ds, Tag.completion_flag()),
      completion_flag_description: get_trimmed(ds, Tag.completion_flag_description()),
      verification_flag: get_trimmed(ds, Tag.verification_flag()),
      content_date: get_trimmed(ds, Tag.content_date()),
      content_time: get_trimmed(ds, Tag.content_time()),
      template_identifier: template_id,
      mapping_resource: mapping_resource,
      sop_class_uid: get_decoded(ds, Tag.sop_class_uid()),
      sop_instance_uid: get_decoded(ds, Tag.sop_instance_uid()),
      study_instance_uid: get_decoded(ds, Tag.study_instance_uid()),
      series_instance_uid: get_decoded(ds, Tag.series_instance_uid()),
      modality: get_trimmed(ds, Tag.modality()),
      verification_datetime: verification_datetime,
      verifying_observer_name: verifying_observer_name
    }

    {:ok, metadata}
  end

  # -- Template Info ----------------------------------------------------------

  defp extract_template_info(ds) do
    case DataSet.get(ds, Tag.content_template_sequence()) do
      [template_item | _] ->
        id = get_item_trimmed(template_item, Tag.template_identifier())
        resource = get_item_trimmed(template_item, Tag.mapping_resource())
        {id, resource}

      _ ->
        {nil, nil}
    end
  end

  # -- Verification Info ------------------------------------------------------

  defp extract_verification_info(ds) do
    datetime = get_trimmed(ds, Tag.verification_date_time())

    observer_name =
      case DataSet.get(ds, Tag.verifying_observer_sequence()) do
        [item | _] -> get_item_trimmed(item, Tag.verifying_observer_name())
        _ -> nil
      end

    {datetime, observer_name}
  end

  # -- Helpers ----------------------------------------------------------------

  defp get_trimmed(ds, tag) do
    case DataSet.get(ds, tag) do
      nil -> nil
      value when is_binary(value) -> String.trim(value)
    end
  end

  defp get_decoded(ds, tag) do
    DataSet.decoded_value(ds, tag)
  end

  defp get_item_trimmed(item, tag) do
    case Map.get(item, tag) do
      %{value: value} when is_binary(value) -> String.trim(value)
      _ -> nil
    end
  end
end
