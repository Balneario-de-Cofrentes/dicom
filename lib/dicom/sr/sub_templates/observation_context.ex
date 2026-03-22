defmodule Dicom.SR.SubTemplates.ObservationContext do
  @moduledoc """
  TID 1001 Observation Context and related sub-templates.

  Implements the observation context sub-template hierarchy:

  - TID 1001 — Observation Context (root)
  - TID 1002 — Observer Context (person or device)
  - TID 1003 — Person Observer Identifying Attributes
  - TID 1004 — Device Observer Identifying Attributes
  - TID 1005 — Procedure Study Context
  - TID 1006 — Subject Context
  - TID 1007 — Subject Context, Patient
  - TID 1008 — Subject Context, Fetus
  - TID 1009 — Subject Context, Specimen

  These sub-templates provide observation context for all SR documents.
  The existing `Dicom.SR.Observer` module covers basic TID 1002-1004;
  this module extends coverage to the full TID 1001-1009 hierarchy.
  """

  alias Dicom.SR.{Code, Codes, ContentItem, Observer}

  # -- TID 1001: Observation Context ----------------------------------------

  @doc """
  Builds TID 1001 Observation Context content items.

  Returns a list of content items covering observer, procedure, and subject
  context. All three sections are optional (MC — required if not inherited).

  ## Options

    * `:observer` — observer context (see `observer_context/1`)
    * `:procedure` — procedure study context (see `procedure_context/1`)
    * `:subject` — subject context (see `subject_context/1`)

  """
  @spec observation_context(keyword()) :: [ContentItem.t()]
  def observation_context(opts \\ []) do
    []
    |> add_items(observer_items(opts[:observer]))
    |> add_items(procedure_items(opts[:procedure]))
    |> add_items(subject_items(opts[:subject]))
  end

  # -- TID 1002: Observer Context -------------------------------------------

  @doc """
  Builds TID 1002 Observer Context content items.

  Delegates to `Dicom.SR.Observer.person/1` or `Dicom.SR.Observer.device/1`
  for basic context, and adds extended attributes (login name, organization,
  roles, physical location, station AE title, UDI).

  ## Person observer options

    * `:name` — (required) person observer name (PN)
    * `:login_name` — login name (TEXT)
    * `:organization` — organization name (TEXT)
    * `:role_in_organization` — role in organization (Code)
    * `:role_in_procedure` — role in procedure (Code)
    * `:identifier_within_role` — identifier within person's role (TEXT)

  ## Device observer options

    * `:uid` — (required) device observer UID
    * `:name` — device name (TEXT)
    * `:manufacturer` — manufacturer (TEXT)
    * `:model_name` — model name (TEXT)
    * `:serial_number` — serial number (TEXT)
    * `:physical_location` — physical location during observation (TEXT)
    * `:role_in_procedure` — device role in procedure (Code)
    * `:station_ae_title` — station AE title (TEXT)
    * `:manufacturer_class_uid` — device manufacturer class UID

  """
  @spec observer_context(keyword()) :: [ContentItem.t()]
  def observer_context(opts) when is_list(opts) do
    cond do
      Keyword.has_key?(opts, :uid) -> device_observer_context(opts)
      Keyword.has_key?(opts, :name) -> person_observer_context(opts)
      true -> []
    end
  end

  # -- TID 1005: Procedure Study Context ------------------------------------

  @doc """
  Builds TID 1005 Procedure Study Context content items.

  ## Options

    * `:study_instance_uid` — procedure study instance UID
    * `:study_component_uid` — procedure study component UID
    * `:placer_number` — placer order number (with optional `:placer_issuer`)
    * `:placer_issuer` — issuer of placer number
    * `:filler_number` — filler order number (with optional `:filler_issuer`)
    * `:filler_issuer` — issuer of filler number
    * `:accession_number` — accession number (with optional `:accession_issuer`)
    * `:accession_issuer` — issuer of accession number
    * `:procedure_code` — procedure code (Code)

  """
  @spec procedure_context(keyword()) :: [ContentItem.t()]
  def procedure_context(opts) when is_list(opts) do
    []
    |> add_uidref(Codes.procedure_study_instance_uid(), opts[:study_instance_uid])
    |> add_uidref(Codes.procedure_study_component_uid(), opts[:study_component_uid])
    |> add_text_with_issuer(
      Codes.placer_number(),
      opts[:placer_number],
      opts[:placer_issuer]
    )
    |> add_text_with_issuer(
      Codes.filler_number(),
      opts[:filler_number],
      opts[:filler_issuer]
    )
    |> add_text_with_issuer(
      Codes.accession_number(),
      opts[:accession_number],
      opts[:accession_issuer]
    )
    |> add_code(Codes.procedure_code(), opts[:procedure_code])
  end

  # -- TID 1006: Subject Context --------------------------------------------

  @doc """
  Builds TID 1006 Subject Context content items.

  ## Options

    * `:class` — subject class Code (:patient, :fetus, :specimen, or Code)
    * `:patient` — patient context options (see `patient_context/1`)
    * `:fetus` — fetus context options (see `fetus_context/1`)
    * `:specimen` — specimen context options (see `specimen_context/1`)

  """
  @spec subject_context(keyword()) :: [ContentItem.t()]
  def subject_context(opts) when is_list(opts) do
    class = opts[:class]

    []
    |> add_subject_class(class)
    |> add_items(patient_items(opts[:patient]))
    |> add_items(fetus_items(opts[:fetus]))
    |> add_items(specimen_items(opts[:specimen]))
  end

  # -- TID 1007: Subject Context, Patient -----------------------------------

  @doc """
  Builds TID 1007 Subject Context, Patient content items.

  ## Options

    * `:uid` — subject UID
    * `:name` — subject name (PN)
    * `:id` — subject ID (TEXT)
    * `:birth_date` — birth date (Date or string)
    * `:sex` — subject sex (Code)
    * `:age` — subject age (number, with optional `:age_units` Code)
    * `:age_units` — units for age measurement
    * `:species` — subject species (Code)
    * `:breed` — subject breed (Code)

  """
  @spec patient_context(keyword()) :: [ContentItem.t()]
  def patient_context(opts) when is_list(opts) do
    []
    |> add_uidref(Codes.subject_uid(), opts[:uid])
    |> add_pname(Codes.subject_name(), opts[:name])
    |> add_text(Codes.subject_id(), opts[:id])
    |> add_date(Codes.subject_birth_date(), opts[:birth_date])
    |> add_code(Codes.subject_sex(), opts[:sex])
    |> add_num(Codes.subject_age(), opts[:age], opts[:age_units])
    |> add_code(Codes.subject_species(), opts[:species])
    |> add_code(Codes.subject_breed(), opts[:breed])
  end

  # -- TID 1008: Subject Context, Fetus ------------------------------------

  @doc """
  Builds TID 1008 Subject Context, Fetus content items.

  ## Options

    * `:mother_name` — mother of fetus (PN)
    * `:uid` — fetus subject UID
    * `:id` — fetus subject ID (TEXT)
    * `:fetus_id` — fetus identifier (TEXT)
    * `:number_by_us` — number of fetuses by ultrasound (number)
    * `:number` — number of fetuses (number)

  """
  @spec fetus_context(keyword()) :: [ContentItem.t()]
  def fetus_context(opts) when is_list(opts) do
    []
    |> add_pname(Codes.mother_of_fetus(), opts[:mother_name])
    |> add_uidref(Codes.subject_uid(), opts[:uid])
    |> add_text(Codes.subject_id(), opts[:id])
    |> add_text(Codes.fetus_id(), opts[:fetus_id])
    |> add_num(Codes.number_of_fetuses_by_us(), opts[:number_by_us], nil)
    |> add_num(Codes.number_of_fetuses(), opts[:number], nil)
  end

  # -- TID 1009: Subject Context, Specimen ----------------------------------

  @doc """
  Builds TID 1009 Subject Context, Specimen content items.

  ## Options

    * `:uid` — specimen UID
    * `:patient` — nested patient context (keyword, see `patient_context/1`)
    * `:identifier` — specimen identifier (TEXT)
    * `:issuer` — issuer of specimen identifier (TEXT)
    * `:type` — specimen type (Code)
    * `:container_id` — specimen container identifier (TEXT)

  """
  @spec specimen_context(keyword()) :: [ContentItem.t()]
  def specimen_context(opts) when is_list(opts) do
    []
    |> add_uidref(Codes.specimen_uid(), opts[:uid])
    |> add_items(patient_items(opts[:patient]))
    |> add_text(Codes.specimen_identifier(), opts[:identifier])
    |> add_text(Codes.issuer_of_specimen_identifier(), opts[:issuer])
    |> add_code(Codes.specimen_type(), opts[:type])
    |> add_text(Codes.specimen_container_identifier(), opts[:container_id])
  end

  # -- Private helpers ------------------------------------------------------

  defp observer_items(nil), do: []
  defp observer_items(opts), do: observer_context(opts)

  defp procedure_items(nil), do: []
  defp procedure_items(opts), do: procedure_context(opts)

  defp subject_items(nil), do: []
  defp subject_items(opts), do: subject_context(opts)

  defp patient_items(nil), do: []
  defp patient_items(opts), do: patient_context(opts)

  defp fetus_items(nil), do: []
  defp fetus_items(opts), do: fetus_context(opts)

  defp specimen_items(nil), do: []
  defp specimen_items(opts), do: specimen_context(opts)

  defp person_observer_context(opts) do
    name = Keyword.fetch!(opts, :name)

    Observer.person(name)
    |> add_text(Codes.person_observer_login_name(), opts[:login_name])
    |> add_text(Codes.person_observer_organization_name(), opts[:organization])
    |> add_code(Codes.person_observer_role_in_organization(), opts[:role_in_organization])
    |> add_role_with_identifier(opts[:role_in_procedure], opts[:identifier_within_role])
  end

  defp device_observer_context(opts) do
    Observer.device(opts)
    |> add_text(Codes.device_physical_location(), opts[:physical_location])
    |> add_code(Codes.device_role_in_procedure(), opts[:role_in_procedure])
    |> add_text(Codes.station_ae_title(), opts[:station_ae_title])
    |> add_uidref(Codes.device_manufacturer_class_uid(), opts[:manufacturer_class_uid])
  end

  defp add_subject_class(items, nil), do: items

  defp add_subject_class(items, %Code{} = code) do
    items ++
      [ContentItem.code(Codes.subject_class(), code, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_subject_class(items, :patient),
    do: add_subject_class(items, Code.new("121025", "DCM", "Patient"))

  defp add_subject_class(items, :fetus),
    do: add_subject_class(items, Code.new("121026", "DCM", "Fetus"))

  defp add_subject_class(items, :specimen),
    do: add_subject_class(items, Code.new("121027", "DCM", "Specimen"))

  defp add_role_with_identifier(items, nil, _identifier), do: items

  defp add_role_with_identifier(items, %Code{} = role, identifier) do
    role_item =
      ContentItem.code(Codes.person_observer_role_in_procedure(), role,
        relationship_type: "HAS OBS CONTEXT",
        children: role_children(identifier)
      )

    items ++ [role_item]
  end

  defp role_children(nil), do: []

  defp role_children(identifier) when is_binary(identifier) do
    [
      ContentItem.text(Codes.identifier_within_role(), identifier,
        relationship_type: "HAS CONCEPT MOD"
      )
    ]
  end

  defp add_items(items, []), do: items
  defp add_items(items, more), do: items ++ more

  defp add_text(items, _concept, nil), do: items

  defp add_text(items, concept, value) when is_binary(value) do
    items ++ [ContentItem.text(concept, value, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_pname(items, _concept, nil), do: items

  defp add_pname(items, concept, value) when is_binary(value) do
    items ++ [ContentItem.pname(concept, value, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_code(items, _concept, nil), do: items

  defp add_code(items, concept, %Code{} = code) do
    items ++ [ContentItem.code(concept, code, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_uidref(items, _concept, nil), do: items

  defp add_uidref(items, concept, uid) when is_binary(uid) do
    items ++ [ContentItem.uidref(concept, uid, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_date(items, _concept, nil), do: items

  defp add_date(items, concept, %Date{} = date) do
    items ++ [ContentItem.date(concept, date, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_date(items, concept, date_string) when is_binary(date_string) do
    items ++ [ContentItem.date(concept, date_string, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_num(items, _concept, nil, _units), do: items

  defp add_num(items, concept, value, nil) when is_number(value) do
    items ++
      [
        ContentItem.num(concept, value, Code.new("1", "UCUM", "no units"),
          relationship_type: "HAS OBS CONTEXT"
        )
      ]
  end

  defp add_num(items, concept, value, %Code{} = units) when is_number(value) do
    items ++ [ContentItem.num(concept, value, units, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_text_with_issuer(items, _concept, nil, _issuer), do: items

  defp add_text_with_issuer(items, concept, value, nil) when is_binary(value) do
    items ++ [ContentItem.text(concept, value, relationship_type: "HAS OBS CONTEXT")]
  end

  defp add_text_with_issuer(items, concept, value, issuer)
       when is_binary(value) and is_binary(issuer) do
    child =
      ContentItem.text(Codes.issuer_of_identifier(), issuer, relationship_type: "HAS CONCEPT MOD")

    items ++
      [
        ContentItem.text(concept, value,
          relationship_type: "HAS OBS CONTEXT",
          children: [child]
        )
      ]
  end
end
