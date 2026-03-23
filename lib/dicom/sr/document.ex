defmodule Dicom.SR.Document do
  @moduledoc """
  SR document wrapper that renders a content tree into a DICOM data set.
  """

  alias Dicom.{DataElement, DataSet, Tag, UID, Value}
  alias Dicom.SR.{ContentConstraint, ContentItem}

  @enforce_keys [:root_content, :study_instance_uid, :series_instance_uid, :sop_instance_uid]
  defstruct [
    :root_content,
    :study_instance_uid,
    :series_instance_uid,
    :sop_instance_uid,
    :template_identifier,
    :mapping_resource,
    :content_datetime,
    :series_number,
    :instance_number,
    :series_description,
    :completion_flag,
    :completion_flag_description,
    :verification_flag,
    :verifying_observer_name,
    :verification_datetime,
    :patient_id,
    :patient_name,
    :study_id,
    :accession_number,
    :study_description,
    :sop_class_uid
  ]

  @type t :: %__MODULE__{
          root_content: ContentItem.t(),
          study_instance_uid: String.t(),
          series_instance_uid: String.t(),
          sop_instance_uid: String.t(),
          template_identifier: String.t() | nil,
          mapping_resource: String.t() | nil,
          content_datetime: NaiveDateTime.t() | DateTime.t(),
          series_number: pos_integer(),
          instance_number: pos_integer(),
          series_description: String.t() | nil,
          completion_flag: String.t(),
          completion_flag_description: String.t() | nil,
          verification_flag: String.t(),
          verifying_observer_name: String.t() | nil,
          verification_datetime: NaiveDateTime.t() | DateTime.t() | nil,
          patient_id: String.t() | nil,
          patient_name: String.t() | nil,
          study_id: String.t() | nil,
          accession_number: String.t() | nil,
          study_description: String.t() | nil,
          sop_class_uid: String.t()
        }

  @spec new(ContentItem.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def new(%ContentItem{} = root_content, opts) when is_list(opts) do
    with :ok <- validate_root(root_content),
         {:ok, study_instance_uid} <- fetch_uid(opts, :study_instance_uid),
         {:ok, series_instance_uid} <- fetch_uid(opts, :series_instance_uid),
         {:ok, sop_instance_uid} <- fetch_uid(opts, :sop_instance_uid),
         :ok <- validate_verification_opts(opts) do
      document =
        %__MODULE__{
          root_content: root_content,
          study_instance_uid: study_instance_uid,
          series_instance_uid: series_instance_uid,
          sop_instance_uid: sop_instance_uid,
          template_identifier: opts[:template_identifier],
          mapping_resource: opts[:mapping_resource] || "DCMR",
          content_datetime:
            opts[:content_datetime] ||
              NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          series_number: opts[:series_number] || 1,
          instance_number: opts[:instance_number] || 1,
          series_description: opts[:series_description],
          completion_flag: opts[:completion_flag] || "COMPLETE",
          completion_flag_description: opts[:completion_flag_description],
          verification_flag: opts[:verification_flag] || "UNVERIFIED",
          verifying_observer_name: opts[:verifying_observer_name],
          verification_datetime: opts[:verification_datetime],
          patient_id: opts[:patient_id],
          patient_name: opts[:patient_name],
          study_id: opts[:study_id],
          accession_number: opts[:accession_number],
          study_description: opts[:study_description],
          sop_class_uid: opts[:sop_class_uid] || UID.comprehensive_sr_storage()
        }

      if opts[:validate] do
        case maybe_validate_content(document) do
          :ok -> {:ok, document}
          {:error, _} = error -> error
        end
      else
        {:ok, document}
      end
    end
  end

  @spec to_data_set(t()) :: {:ok, DataSet.t()} | {:error, term()}
  def to_data_set(%__MODULE__{} = document) do
    root_elements = ContentItem.to_root_elements(document.root_content)

    ds =
      DataSet.new()
      |> put_file_meta(document)
      |> put_if_value(Tag.sop_class_uid(), :UI, document.sop_class_uid)
      |> put_if_value(Tag.sop_instance_uid(), :UI, document.sop_instance_uid)
      |> put_if_value(Tag.study_instance_uid(), :UI, document.study_instance_uid)
      |> put_if_value(Tag.series_instance_uid(), :UI, document.series_instance_uid)
      |> put_if_value(Tag.modality(), :CS, "SR")
      |> put_if_value(Tag.series_number(), :IS, document.series_number)
      |> put_if_value(Tag.instance_number(), :IS, document.instance_number)
      |> put_if_value(
        Tag.content_date(),
        :DA,
        Value.from_date(content_date(document.content_datetime))
      )
      |> put_if_value(
        Tag.content_time(),
        :TM,
        Value.from_time(content_time(document.content_datetime))
      )
      |> put_if_value(Tag.completion_flag(), :CS, document.completion_flag)
      |> put_if_value(Tag.verification_flag(), :CS, document.verification_flag)
      |> put_if_value(Tag.series_description(), :LO, document.series_description)
      |> put_if_value(Tag.patient_id(), :LO, document.patient_id)
      |> put_if_value(Tag.patient_name(), :PN, document.patient_name)
      |> put_if_value(Tag.study_id(), :SH, document.study_id)
      |> put_if_value(Tag.accession_number(), :SH, document.accession_number)
      |> put_if_value(Tag.study_description(), :LO, document.study_description)
      |> put_if_value(
        Tag.completion_flag_description(),
        :LO,
        document.completion_flag_description
      )
      |> put_template_sequence(document)
      |> put_verification(document)
      |> put_root_elements(root_elements)

    {:ok, ds}
  end

  defp put_file_meta(ds, document) do
    ds
    |> DataSet.put(Tag.media_storage_sop_class_uid(), :UI, document.sop_class_uid)
    |> DataSet.put(Tag.media_storage_sop_instance_uid(), :UI, document.sop_instance_uid)
    |> DataSet.put(Tag.transfer_syntax_uid(), :UI, UID.explicit_vr_little_endian())
  end

  defp put_root_elements(ds, root_elements) do
    Enum.reduce(root_elements, ds, fn {tag, element}, acc ->
      %{acc | elements: Map.put(acc.elements, tag, element)}
    end)
  end

  defp put_template_sequence(ds, %__MODULE__{template_identifier: nil}), do: ds

  defp put_template_sequence(ds, %__MODULE__{} = document) do
    template_item = %{
      Tag.mapping_resource() =>
        DataElement.new(Tag.mapping_resource(), :CS, document.mapping_resource || "DCMR"),
      Tag.template_identifier() =>
        DataElement.new(Tag.template_identifier(), :CS, document.template_identifier)
    }

    DataSet.put(ds, Tag.content_template_sequence(), :SQ, [template_item])
  end

  defp put_verification(ds, %__MODULE__{verification_flag: "VERIFIED"} = document) do
    ds
    |> put_if_value(
      Tag.verification_date_time(),
      :DT,
      Value.from_datetime(document.verification_datetime)
    )
    |> put_if_value(
      Tag.verifying_observer_sequence(),
      :SQ,
      [
        %{
          Tag.verifying_observer_name() =>
            DataElement.new(
              Tag.verifying_observer_name(),
              :PN,
              document.verifying_observer_name
            )
        }
      ]
    )
  end

  defp put_verification(ds, _document), do: ds

  defp put_if_value(ds, _tag, _vr, nil), do: ds

  defp put_if_value(ds, tag, vr, value) do
    DataSet.put(ds, tag, vr, value)
  end

  defp fetch_uid(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, uid} when is_binary(uid) and uid != "" ->
        if UID.valid?(uid) do
          {:ok, uid}
        else
          {:error, {:invalid_uid, key}}
        end

      {:ok, _uid} ->
        {:error, {:invalid_uid, key}}

      :error ->
        {:error, {:missing_uid, key}}
    end
  end

  defp validate_root(%ContentItem{value_type: :container, relationship_type: nil}), do: :ok
  defp validate_root(_), do: {:error, :invalid_root_content}

  defp validate_verification_opts(opts) do
    case opts[:verification_flag] || "UNVERIFIED" do
      "VERIFIED" ->
        with :ok <- require_binary(opts[:verifying_observer_name], :verifying_observer_name),
             :ok <- require_datetime(opts[:verification_datetime], :verification_datetime) do
          :ok
        end

      _other ->
        :ok
    end
  end

  defp require_binary(value, _field) when is_binary(value) and value != "", do: :ok
  defp require_binary(_value, field), do: {:error, {:missing_required_field, field}}

  defp require_datetime(%NaiveDateTime{}, _field), do: :ok
  defp require_datetime(%DateTime{}, _field), do: :ok
  defp require_datetime(_value, field), do: {:error, {:missing_required_field, field}}

  defp content_date(%NaiveDateTime{} = dt), do: NaiveDateTime.to_date(dt)
  defp content_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp content_time(%NaiveDateTime{} = dt), do: NaiveDateTime.to_time(dt)
  defp content_time(%DateTime{} = dt), do: DateTime.to_time(dt)

  @constraint_registry %{
    "1500" => Dicom.SR.Constraints.MeasurementReport,
    "2000" => Dicom.SR.Constraints.KeyObjectSelection
  }

  defp maybe_validate_content(%__MODULE__{template_identifier: tid, root_content: root})
       when is_map_key(@constraint_registry, tid) do
    constraint_mod = Map.fetch!(@constraint_registry, tid)
    ContentConstraint.validate_tree(root.children, constraint_mod.constraints())
  end

  defp maybe_validate_content(_document), do: :ok
end
