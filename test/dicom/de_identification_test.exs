defmodule Dicom.DeIdentificationTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, DataElement, DeIdentification, Tag, UID}

  # ── Helper: build a realistic data set ─────────────────────────

  defp sample_data_set do
    DataSet.new()
    |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
    |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9")
    |> DataSet.put({0x0002, 0x0010}, :UI, UID.explicit_vr_little_endian())
    |> DataSet.put(Tag.patient_name(), :PN, "DOE^JOHN")
    |> DataSet.put(Tag.patient_id(), :LO, "PAT001")
    |> DataSet.put(Tag.patient_birth_date(), :DA, "19800101")
    |> DataSet.put(Tag.patient_sex(), :CS, "M")
    |> DataSet.put(Tag.patient_age(), :AS, "044Y")
    |> DataSet.put(Tag.study_date(), :DA, "20240315")
    |> DataSet.put(Tag.study_time(), :TM, "140000")
    |> DataSet.put(Tag.accession_number(), :SH, "ACC123")
    |> DataSet.put(Tag.referring_physician_name(), :PN, "SMITH^JANE^DR")
    |> DataSet.put(Tag.study_instance_uid(), :UI, "1.2.3.4.5.6.7.8.9.10")
    |> DataSet.put(Tag.series_instance_uid(), :UI, "1.2.3.4.5.6.7.8.9.11")
    |> DataSet.put(Tag.sop_instance_uid(), :UI, "1.2.3.4.5.6.7.8.9.12")
    |> DataSet.put(Tag.modality(), :CS, "CT")
    |> DataSet.put(Tag.study_description(), :LO, "CT HEAD W/O CONTRAST")
    |> DataSet.put(Tag.series_description(), :LO, "AXIAL 5MM")
    |> DataSet.put(Tag.instance_number(), :IS, "1")
  end

  # ── Profile ────────────────────────────────────────────────────

  describe "basic_profile/0" do
    test "returns a profile struct" do
      profile = DeIdentification.basic_profile()
      assert %DeIdentification.Profile{} = profile
      refute profile.retain_uids
      refute profile.retain_device_identity
      refute profile.retain_patient_characteristics
      refute profile.retain_institution_identity
    end
  end

  describe "Profile options" do
    test "retain_uids option" do
      profile = %DeIdentification.Profile{retain_uids: true}
      assert profile.retain_uids
    end

    test "all options default to false" do
      profile = %DeIdentification.Profile{}
      refute profile.retain_uids
      refute profile.retain_device_identity
      refute profile.retain_patient_characteristics
      refute profile.retain_institution_identity
      refute profile.retain_long_full_dates
      refute profile.retain_long_modified_dates
      refute profile.clean_descriptions
      refute profile.clean_structured_content
      refute profile.clean_graphics
      refute profile.retain_private_tags
      refute profile.retain_safe_private
    end

    test "retain_private_tags option" do
      profile = %DeIdentification.Profile{retain_private_tags: true}
      assert profile.retain_private_tags
    end
  end

  # ── Action codes ──────────────────────────────────────────────

  describe "action_for/2" do
    test "PatientName gets action :D (replace with dummy)" do
      profile = DeIdentification.basic_profile()
      assert DeIdentification.action_for(Tag.patient_name(), profile) == :D
    end

    test "PatientID gets action :Z (zero-length)" do
      profile = DeIdentification.basic_profile()
      assert DeIdentification.action_for(Tag.patient_id(), profile) == :Z
    end

    test "PatientBirthDate gets action :Z" do
      profile = DeIdentification.basic_profile()
      assert DeIdentification.action_for(Tag.patient_birth_date(), profile) == :Z
    end

    test "UIDs get action :U (replace with consistent mapping)" do
      profile = DeIdentification.basic_profile()
      assert DeIdentification.action_for(Tag.study_instance_uid(), profile) == :U
      assert DeIdentification.action_for(Tag.series_instance_uid(), profile) == :U
      assert DeIdentification.action_for(Tag.sop_instance_uid(), profile) == :U
    end

    test "Modality gets action :K (keep)" do
      profile = DeIdentification.basic_profile()
      assert DeIdentification.action_for(Tag.modality(), profile) == :K
    end

    test "StudyDescription gets :X by default, :C with clean_descriptions" do
      basic = DeIdentification.basic_profile()
      assert DeIdentification.action_for(Tag.study_description(), basic) == :X

      clean = %DeIdentification.Profile{clean_descriptions: true}
      assert DeIdentification.action_for(Tag.study_description(), clean) == :C
    end

    test "UIDs retain with retain_uids option" do
      profile = %DeIdentification.Profile{retain_uids: true}
      assert DeIdentification.action_for(Tag.study_instance_uid(), profile) == :K
    end

    test "unknown tags default to :X (remove)" do
      profile = DeIdentification.basic_profile()
      assert DeIdentification.action_for({0x0099, 0x0099}, profile) == :X
    end
  end

  # ── apply/2 ───────────────────────────────────────────────────

  describe "apply/2 - basic de-identification" do
    test "removes patient name (action D: replaced with dummy)" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      # PatientName should be replaced with dummy, not original
      pn = DataSet.get(result, Tag.patient_name())
      assert pn != "DOE^JOHN"
      assert is_binary(pn)
    end

    test "zeros patient birth date (action Z)" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.patient_birth_date()) == ""
    end

    test "zeros patient ID (action Z)" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.patient_id()) == ""
    end

    test "replaces UIDs consistently (action U)" do
      ds = sample_data_set()
      {:ok, result, uid_map} = DeIdentification.apply(ds)

      orig_study = DataSet.get(ds, Tag.study_instance_uid())
      new_study = DataSet.get(result, Tag.study_instance_uid())

      assert new_study != orig_study
      assert UID.valid?(new_study)
      assert uid_map[orig_study] == new_study
    end

    test "UID replacement is consistent across elements" do
      ds = sample_data_set()
      {:ok, result, uid_map} = DeIdentification.apply(ds)

      # Each original UID maps to one new UID
      orig_study = "1.2.3.4.5.6.7.8.9.10"
      assert uid_map[orig_study] != nil
      assert DataSet.get(result, Tag.study_instance_uid()) == uid_map[orig_study]
    end

    test "replaces Media Storage SOP Instance UID consistently with SOP Instance UID" do
      shared_uid = "1.2.3.4.5.6.7.8.9.12"

      ds =
        sample_data_set()
        |> DataSet.put({0x0002, 0x0003}, :UI, shared_uid)
        |> DataSet.put(Tag.sop_instance_uid(), :UI, shared_uid)

      {:ok, result, uid_map} = DeIdentification.apply(ds)

      new_file_meta_uid = DataSet.get(result, {0x0002, 0x0003})
      new_sop_instance_uid = DataSet.get(result, Tag.sop_instance_uid())

      assert new_file_meta_uid != shared_uid
      assert new_file_meta_uid == new_sop_instance_uid
      assert uid_map[shared_uid] == new_file_meta_uid
    end

    test "keeps modality (action K)" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.modality()) == "CT"
    end

    test "removes study description by default (action X)" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.study_description()) == nil
    end

    test "zeros referring physician name (action Z per PS3.15)" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.referring_physician_name()) == ""
    end

    test "adds de-identification marker tags" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)

      # Patient Identity Removed (0012,0062) = "YES"
      assert DataSet.get(result, {0x0012, 0x0062}) == "YES"

      # De-identification Method (0012,0063)
      method = DataSet.get(result, {0x0012, 0x0063})
      assert method != nil
      assert String.contains?(method, "Basic")
    end

    test "removes private tags" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0009, 0x0010}, :LO, "PrivateCreator")
        |> DataSet.put({0x0009, 0x1001}, :LO, "PrivateValue")

      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, {0x0009, 0x0010}) == nil
      assert DataSet.get(result, {0x0009, 0x1001}) == nil
    end
  end

  describe "apply/2 - with retain_uids option" do
    test "keeps UIDs unchanged" do
      ds = sample_data_set()
      profile = %DeIdentification.Profile{retain_uids: true}
      {:ok, result, uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, Tag.study_instance_uid()) ==
               DataSet.get(ds, Tag.study_instance_uid())

      assert uid_map == %{}
    end

    test "keeps Media Storage SOP Instance UID unchanged" do
      ds = sample_data_set()
      profile = %DeIdentification.Profile{retain_uids: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, {0x0002, 0x0003}) == DataSet.get(ds, {0x0002, 0x0003})
    end
  end

  describe "apply/2 - option-specific behavior" do
    test "retain_device_identity keeps device-identifying tags" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0008, 0x1010}, :SH, "STATION_A")
        |> DataSet.put({0x0018, 0x1000}, :LO, "DEVICE_SN")

      profile = %DeIdentification.Profile{retain_device_identity: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, {0x0008, 0x1010}) == "STATION_A"
      assert DataSet.get(result, {0x0018, 0x1000}) == "DEVICE_SN"
    end

    test "retain_patient_characteristics keeps sex and age" do
      ds = sample_data_set()
      profile = %DeIdentification.Profile{retain_patient_characteristics: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, Tag.patient_sex()) == "M"
      assert DataSet.get(result, Tag.patient_age()) == "044Y"
    end

    test "retain_institution_identity keeps institution tags" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0008, 0x0080}, :LO, "Balneario Hospital")
        |> DataSet.put({0x0008, 0x0081}, :ST, "123 Example St")

      profile = %DeIdentification.Profile{retain_institution_identity: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, {0x0008, 0x0080}) == "Balneario Hospital"
      assert DataSet.get(result, {0x0008, 0x0081}) == "123 Example St"
    end

    test "retain_long_full_dates keeps temporal tags unchanged" do
      ds = sample_data_set()
      profile = %DeIdentification.Profile{retain_long_full_dates: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, Tag.study_date()) == "20240315"
      assert DataSet.get(result, Tag.study_time()) == "140000"
    end

    test "retain_long_modified_dates shifts dates while preserving temporal structure" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0008, 0x002A}, :DT, "20240315140000")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, Tag.study_date()) == "20140315"
      assert DataSet.get(result, Tag.study_time()) == "140000"
      assert DataSet.get(result, {0x0008, 0x002A}) == "20140315140000"
    end

    test "clean_structured_content preserves SR structure and cleans values" do
      item = %{
        {0x0040, 0xA010} => DataElement.new({0x0040, 0xA010}, :CS, "CONTAINS"),
        {0x0040, 0xA040} => DataElement.new({0x0040, 0xA040}, :CS, "TEXT"),
        {0x0040, 0xA160} => DataElement.new({0x0040, 0xA160}, :UT, "Free-text note"),
        {0x0040, 0xA123} => DataElement.new({0x0040, 0xA123}, :PN, "AUTHOR^NAME")
      }

      ds = sample_data_set()
      sq_elem = DataElement.new({0x0040, 0xA730}, :SQ, [item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0040, 0xA730}, sq_elem)}

      profile = %DeIdentification.Profile{clean_structured_content: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)
      [cleaned_item] = DataSet.get_element(result, {0x0040, 0xA730}).value

      assert cleaned_item[{0x0040, 0xA010}].value == "CONTAINS"
      assert cleaned_item[{0x0040, 0xA160}].value == "CLEANED"
      assert cleaned_item[{0x0040, 0xA123}].value == "CLEANED"
    end

    test "clean_graphics keeps graphic sequences and cleans text" do
      graphic_item = %{
        {0x0070, 0x0006} => DataElement.new({0x0070, 0x0006}, :ST, "Burned in name")
      }

      ds = sample_data_set()
      sq_elem = DataElement.new({0x0070, 0x0001}, :SQ, [graphic_item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0070, 0x0001}, sq_elem)}

      profile = %DeIdentification.Profile{clean_graphics: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)
      [item] = DataSet.get_element(result, {0x0070, 0x0001}).value

      assert item[{0x0070, 0x0006}].value == "CLEANED"
    end
  end

  describe "apply/2 - with clean_descriptions option" do
    test "cleans descriptions instead of removing" do
      ds = sample_data_set()
      profile = %DeIdentification.Profile{clean_descriptions: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      # Description should be cleaned (replaced with generic text), not removed
      desc = DataSet.get(result, Tag.study_description())
      assert desc != nil
      assert desc != "CT HEAD W/O CONTRAST"
    end
  end

  describe "apply/2 - sequence recursion" do
    test "de-identifies elements inside sequences" do
      inner_item = %{
        Tag.patient_name() => DataElement.new(Tag.patient_name(), :PN, "INNER^NAME"),
        {0x0008, 0x1150} => DataElement.new({0x0008, 0x1150}, :UI, "1.2.3.4.5")
      }

      ds = sample_data_set()
      sq_elem = DataElement.new({0x0028, 0x9145}, :SQ, [inner_item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0028, 0x9145}, sq_elem)}

      {:ok, result, uid_map} = DeIdentification.apply(ds)
      sq = DataSet.get_element(result, {0x0028, 0x9145})
      [item] = sq.value

      # Patient name in sequence should be replaced
      assert item[Tag.patient_name()].value != "INNER^NAME"

      # UID in sequence should be replaced consistently
      assert item[{0x0008, 0x1150}].value != "1.2.3.4.5"
      assert uid_map["1.2.3.4.5"] == item[{0x0008, 0x1150}].value
    end

    test "removes top-level referenced sequences whose action is :X" do
      inner_item = %{
        Tag.patient_name() => DataElement.new(Tag.patient_name(), :PN, "INNER^NAME")
      }

      ds = sample_data_set()
      sq_elem = DataElement.new({0x0008, 0x1110}, :SQ, [inner_item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1110}, sq_elem)}

      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      refute DataSet.has_tag?(result, {0x0008, 0x1110})
    end

    test "removes top-level content sequence by default" do
      item = %{
        {0x0040, 0xA123} => DataElement.new({0x0040, 0xA123}, :PN, "AUTHOR^NAME")
      }

      ds = sample_data_set()
      sq_elem = DataElement.new({0x0040, 0xA730}, :SQ, [item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0040, 0xA730}, sq_elem)}

      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      refute DataSet.has_tag?(result, {0x0040, 0xA730})
    end
  end

  # ── apply/2 - retain_private_tags option ──────────────────────

  describe "apply/2 - with retain_private_tags option" do
    test "removes private tags by default" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0009, 0x0010}, :LO, "PrivateCreator")
        |> DataSet.put({0x0009, 0x1001}, :LO, "PrivateValue")

      {:ok, result, _uid_map} = DeIdentification.apply(ds)

      # Default action for unknown tags is :X (remove)
      refute DataSet.has_tag?(result, {0x0009, 0x0010})
      refute DataSet.has_tag?(result, {0x0009, 0x1001})
    end

    test "retain_private_tags preserves private tags" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0009, 0x0010}, :LO, "PrivateCreator")
        |> DataSet.put({0x0009, 0x1001}, :LO, "PrivateValue")

      profile = %DeIdentification.Profile{retain_private_tags: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, {0x0009, 0x0010}) == "PrivateCreator"
      assert DataSet.get(result, {0x0009, 0x1001}) == "PrivateValue"
    end

    test "retain_safe_private remains a compatibility alias for retaining all private tags" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0009, 0x0010}, :LO, "PrivateCreator")
        |> DataSet.put({0x0009, 0x1001}, :LO, "PrivateValue")

      profile = %DeIdentification.Profile{retain_safe_private: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, {0x0009, 0x0010}) == "PrivateCreator"
      assert DataSet.get(result, {0x0009, 0x1001}) == "PrivateValue"
    end
  end

  # ── action_for/2 - exhaustive tag coverage ──────────────────

  describe "action_for/2 - all tag action paths" do
    setup do
      %{profile: DeIdentification.basic_profile()}
    end

    # Patient identifiers - D, Z, X
    test "PatientSex gets :Z", %{profile: p} do
      assert DeIdentification.action_for({0x0010, 0x0040}, p) == :Z
    end

    test "PatientWeight gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0010, 0x1030}, p) == :X
    end

    test "PatientSize gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0010, 0x1020}, p) == :X
    end

    test "OtherPatientIDs gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0010, 0x1000}, p) == :X
    end

    test "OtherPatientNames gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0010, 0x1001}, p) == :X
    end

    test "EthnicGroup gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0010, 0x2160}, p) == :X
    end

    test "AdditionalPatientHistory gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0010, 0x21B0}, p) == :X
    end

    # Study identifiers
    test "InstitutionName gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0080}, p) == :X
    end

    test "InstitutionAddress gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0081}, p) == :X
    end

    test "StationName gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1010}, p) == :X
    end

    test "InstitutionalDepartmentName gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1040}, p) == :X
    end

    test "PhysiciansReadingStudy gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1048}, p) == :X
    end

    test "PerformingPhysicianName gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1050}, p) == :X
    end

    test "OperatorsName gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1070}, p) == :X
    end

    # Descriptions - X_or_C
    test "SeriesDescription gets :X by default", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x103E}, p) == :X
    end

    test "ManufacturerModelName gets :X by default", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1090}, p) == :X
    end

    test "ImageComments gets :X by default", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x4000}, p) == :X
    end

    test "all descriptions get :C with clean_descriptions" do
      profile = %DeIdentification.Profile{clean_descriptions: true}

      for tag <- [{0x0008, 0x1030}, {0x0008, 0x103E}, {0x0008, 0x1090}, {0x0020, 0x4000}] do
        assert DeIdentification.action_for(tag, profile) == :C
      end
    end

    # UIDs
    test "ReferencedSOPClassUID gets :U", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1150}, p) == :U
    end

    test "ReferencedSOPInstanceUID gets :U", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x1155}, p) == :U
    end

    test "SOPClassUID gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0016}, p) == :K
    end

    # Keep - structural
    test "ImageType gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0008}, p) == :K
    end

    test "SeriesNumber gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x0011}, p) == :K
    end

    test "StudyID gets :Z", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x0010}, p) == :Z
    end

    test "group 0028 (image info) gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0028, 0x0010}, p) == :K
      assert DeIdentification.action_for({0x0028, 0x0100}, p) == :K
    end

    test "pixel data group 7FE0 gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x7FE0, 0x0010}, p) == :K
    end

    test "ImagePositionPatient gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x0032}, p) == :K
    end

    test "ImageOrientationPatient gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x0037}, p) == :K
    end

    test "FrameOfReferenceUID gets :U", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x0052}, p) == :U
    end

    test "SliceLocation gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x1041}, p) == :K
    end

    test "group 0018 (acquisition) gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0018, 0x0050}, p) == :K
    end

    test "group 0002 (file meta) gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0002, 0x0010}, p) == :K
    end

    test "group 0012 (de-identification) gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0012, 0x0062}, p) == :K
    end

    # Dates
    test "StudyDate gets :Z", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0020}, p) == :Z
    end

    test "StudyTime gets :Z", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0030}, p) == :Z
    end

    test "SeriesDate gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0021}, p) == :X
    end

    test "AcquisitionDate gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0022}, p) == :X
    end

    test "ContentDate gets :D (Z/D compound → D)", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0023}, p) == :D
    end

    test "SeriesTime gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0031}, p) == :X
    end

    test "AcquisitionTime gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0032}, p) == :X
    end

    test "ContentTime gets :D (Z/D compound → D)", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0033}, p) == :D
    end

    test "AcquisitionDateTime gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x002A}, p) == :X
    end
  end

  # ── apply/2 - dummy value coverage ──────────────────────────

  describe "apply/2 - dummy values for action :D" do
    test "PatientName replaced with ANONYMOUS" do
      ds = sample_data_set()
      {:ok, result, _} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.patient_name()) == "ANONYMOUS"
    end

    test "exercises all dummy_value/1 clauses" do
      # Build a data set where tag_action returns :D for different VR types
      # Only PatientName ({0x0010, 0x0010}) maps to :D, so we exercise it
      # We can test dummy_value indirectly by creating a custom scenario:
      # 1. Create a data set where PatientName has each VR value
      # These test the actual dummy_value results

      # PN dummy
      ds = DataSet.from_list([{Tag.patient_name(), :PN, "ORIGINAL"}])
      {:ok, result, _} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.patient_name()) == "ANONYMOUS"
    end
  end

  describe "apply/2 - UID null padding" do
    test "strips null padding from UID values before mapping" do
      ds =
        sample_data_set()
        |> DataSet.put(Tag.sop_instance_uid(), :UI, "1.2.3.4.5\0")

      {:ok, result, uid_map} = DeIdentification.apply(ds)
      # The null-trimmed UID should be in the map
      assert Map.has_key?(uid_map, "1.2.3.4.5")
      new_uid = DataSet.get(result, Tag.sop_instance_uid())
      assert new_uid != "1.2.3.4.5\0"
      assert new_uid != "1.2.3.4.5"
    end
  end

  # ── apply/2 - date actions ──────────────────────────────────

  describe "apply/2 - date handling" do
    test "StudyDate zeroed, SeriesDate/AcquisitionDate removed" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0008, 0x0021}, :DA, "20240316")
        |> DataSet.put({0x0008, 0x0022}, :DA, "20240316")
        |> DataSet.put({0x0008, 0x0023}, :DA, "20240316")
        |> DataSet.put({0x0008, 0x0031}, :TM, "140000")
        |> DataSet.put({0x0008, 0x0032}, :TM, "140000")
        |> DataSet.put({0x0008, 0x0033}, :TM, "140000")
        |> DataSet.put({0x0008, 0x002A}, :DT, "20240316140000")

      {:ok, result, _} = DeIdentification.apply(ds)

      assert DataSet.get(result, {0x0008, 0x0020}) == ""
      assert DataSet.get(result, {0x0008, 0x0030}) == ""
      assert DataSet.get(result, {0x0008, 0x0021}) == nil
      assert DataSet.get(result, {0x0008, 0x0022}) == nil
      # ContentDate: Z/D compound → D (dummy date)
      assert DataSet.get(result, {0x0008, 0x0023}) == "19000101"
      assert DataSet.get(result, {0x0008, 0x0031}) == nil
      assert DataSet.get(result, {0x0008, 0x0032}) == nil
      # ContentTime: Z/D compound → D (dummy time)
      assert DataSet.get(result, {0x0008, 0x0033}) == "000000"
      assert DataSet.get(result, {0x0008, 0x002A}) == nil
    end
  end

  # ── apply/2 - UID action with non-binary value ──────────────

  describe "apply/2 - UID action edge cases" do
    test "consistent UID mapping for same UID in multiple elements" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0008, 0x1150}, :UI, "1.2.3.4.5.6.7.8.9.12")
        |> DataSet.put({0x0008, 0x1155}, :UI, "1.2.3.4.5.6.7.8.9.12")

      {:ok, result, uid_map} = DeIdentification.apply(ds)

      # Same original UID should map to same new UID
      ref_class = DataSet.get(result, {0x0008, 0x1150})
      ref_inst = DataSet.get(result, {0x0008, 0x1155})
      assert ref_class == ref_inst
      assert uid_map["1.2.3.4.5.6.7.8.9.12"] == ref_class
    end
  end

  # ── apply/2 - SQ with :K action ────────────────────────────

  describe "apply/2 - SQ recursion via :K action" do
    test "keeps SQ elements and recurses into them" do
      # Put a SQ element tagged as a kept tag (Modality is :K but not SQ)
      # Use a known-kept SQ element: a tag in group 0028
      inner_item = %{
        {0x0010, 0x0010} => DataElement.new({0x0010, 0x0010}, :PN, "INNER")
      }

      ds = sample_data_set()
      sq_elem = DataElement.new({0x0028, 0x0100}, :SQ, [inner_item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0028, 0x0100}, sq_elem)}

      {:ok, result, _} = DeIdentification.apply(ds)
      sq = DataSet.get_element(result, {0x0028, 0x0100})
      assert sq != nil
      assert sq.vr == :SQ
      [item] = sq.value
      # Patient name inside should be replaced
      refute item[{0x0010, 0x0010}].value == "INNER"
    end
  end

  # ── apply_action :U with non-binary UID ─────────────────────

  describe "apply/2 - UID action with non-binary value" do
    test "keeps element unchanged when UID value is not a binary" do
      ds = sample_data_set()
      # Put a non-binary value in a UID element to exercise the fallback
      elem = %DataElement{tag: {0x0020, 0x000D}, vr: :UI, value: 12345, length: 0}
      ds = %{ds | elements: Map.put(ds.elements, {0x0020, 0x000D}, elem)}

      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      result_elem = DataSet.get_element(result, {0x0020, 0x000D})
      assert result_elem.value == 12345
    end
  end

  # ── apply_action :C with clean_descriptions ──────────────────

  describe "apply/2 - clean action on all description tags" do
    test "cleans series description and manufacturer model name" do
      ds =
        sample_data_set()
        |> DataSet.put({0x0008, 0x103E}, :LO, "AXIAL 5MM")
        |> DataSet.put({0x0008, 0x1090}, :LO, "Scanner Model X")
        |> DataSet.put({0x0020, 0x4000}, :LT, "Some image comments")

      profile = %DeIdentification.Profile{clean_descriptions: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, {0x0008, 0x103E}) == "CLEANED"
      assert DataSet.get(result, {0x0008, 0x1090}) == "CLEANED"
      assert DataSet.get(result, {0x0020, 0x4000}) == "CLEANED"
    end
  end

  # ── DataSet.delete/2 ──────────────────────────────────────────

  describe "DataSet.delete/2" do
    test "removes an element" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> DataSet.put({0x0010, 0x0020}, :LO, "PAT001")

      ds = DataSet.delete(ds, {0x0010, 0x0010})
      assert DataSet.get(ds, {0x0010, 0x0010}) == nil
      assert DataSet.get(ds, {0x0010, 0x0020}) == "PAT001"
    end

    test "removes file meta element" do
      ds = DataSet.new() |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
      ds = DataSet.delete(ds, {0x0002, 0x0010})
      assert DataSet.get(ds, {0x0002, 0x0010}) == nil
    end

    test "no-op for missing tag" do
      ds = DataSet.new()
      ds2 = DataSet.delete(ds, {0x0010, 0x0010})
      assert DataSet.size(ds2) == 0
    end
  end

  # ── apply/2 — additional edge cases ──────────────────────────

  describe "apply/2 - SQ element with K action in sequence recursion" do
    test "nested SQ in sequence item gets recursed" do
      nested_item = %{
        {0x0008, 0x0060} => DataElement.new({0x0008, 0x0060}, :CS, "CT")
      }

      nested_sq = DataElement.new({0x0040, 0xA730}, :SQ, [nested_item])

      outer_item = %{
        {0x0040, 0xA730} => nested_sq,
        Tag.patient_name() => DataElement.new(Tag.patient_name(), :PN, "NESTED^PERSON")
      }

      outer_sq = DataElement.new({0x0028, 0x9145}, :SQ, [outer_item])

      ds = sample_data_set()
      ds = %{ds | elements: Map.put(ds.elements, {0x0028, 0x9145}, outer_sq)}

      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      sq = DataSet.get_element(result, {0x0028, 0x9145})
      [item] = sq.value
      # Patient name in outer item should be de-identified
      assert item[Tag.patient_name()].value != "NESTED^PERSON"
    end
  end

  describe "apply/2 - action C cleans description text" do
    test "C action replaces value with CLEANED" do
      profile = %DeIdentification.Profile{clean_descriptions: true}

      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put(Tag.study_description(), :LO, "CT HEAD W/O CONTRAST")
        |> DataSet.put(Tag.series_description(), :LO, "AXIAL 5MM")

      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      assert DataSet.get(result, Tag.study_description()) == "CLEANED"
      assert DataSet.get(result, Tag.series_description()) == "CLEANED"
    end
  end

  describe "apply/2 - all action Z VR types" do
    test "Z action zeroes DA, LO, SH, CS elements" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put(Tag.patient_birth_date(), :DA, "19800101")
        |> DataSet.put(Tag.patient_id(), :LO, "PAT001")
        |> DataSet.put(Tag.patient_sex(), :CS, "M")
        |> DataSet.put(Tag.accession_number(), :SH, "ACC123")

      {:ok, result, _uid_map} = DeIdentification.apply(ds)

      # All Z-action elements should be zero-length
      assert DataSet.get(result, Tag.patient_birth_date()) == ""
      assert DataSet.get(result, Tag.patient_id()) == ""
      assert DataSet.get(result, Tag.patient_sex()) == ""
      assert DataSet.get(result, Tag.accession_number()) == ""
    end

    test "X action removes PatientAge (AS VR)" do
      ds =
        DataSet.new()
        |> DataSet.put(Tag.patient_age(), :AS, "044Y")

      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.patient_age()) == nil
    end
  end

  describe "apply/2 — SQ with :K action via deidentify_sequence" do
    test "SQ element inside sequence item with :K tag gets recursed" do
      inner_item = %{
        {0x0010, 0x0010} => DataElement.new({0x0010, 0x0010}, :PN, "INNERPATIENT")
      }

      nested_sq = %DataElement{
        tag: {0x0028, 0x9145},
        vr: :SQ,
        value: [inner_item],
        length: 0
      }

      outer_item = %{
        {0x0028, 0x9145} => nested_sq,
        {0x0010, 0x0020} => DataElement.new({0x0010, 0x0020}, :LO, "PAT123")
      }

      outer_sq = %DataElement{
        tag: {0x0028, 0x9145},
        vr: :SQ,
        value: [outer_item],
        length: 0
      }

      ds = %DataSet{
        file_meta: %{},
        elements: %{
          {0x0028, 0x9145} => outer_sq
        }
      }

      {:ok, result, _uid_map} = DeIdentification.apply(ds)

      result_sq = DataSet.get_element(result, {0x0028, 0x9145})
      assert result_sq.vr == :SQ
      [result_item] = result_sq.value

      nested = result_item[{0x0028, 0x9145}]
      assert nested.vr == :SQ

      [nested_item] = nested.value
      assert nested_item[{0x0010, 0x0010}].value == "ANONYMOUS"
    end
  end

  # ── Comprehensive tag_action coverage ──────────────────────────

  describe "action_for/2 - patient identifier tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "all patient :X tags", %{p: p} do
      x_tags = [
        {0x0010, 0x0032},
        {0x0010, 0x1010},
        {0x0010, 0x1020},
        {0x0010, 0x1030},
        {0x0010, 0x1000},
        {0x0010, 0x1001},
        {0x0010, 0x1002},
        {0x0010, 0x1005},
        {0x0010, 0x1040},
        {0x0010, 0x1050},
        {0x0010, 0x1060},
        {0x0010, 0x1080},
        {0x0010, 0x1081},
        {0x0010, 0x1090},
        {0x0010, 0x2000},
        {0x0010, 0x2110},
        {0x0010, 0x2150},
        {0x0010, 0x2152},
        {0x0010, 0x2154},
        {0x0010, 0x2155},
        {0x0010, 0x2160},
        {0x0010, 0x2180},
        {0x0010, 0x21A0},
        {0x0010, 0x21B0},
        {0x0010, 0x21C0},
        {0x0010, 0x21D0},
        {0x0010, 0x21F0},
        {0x0010, 0x2203},
        {0x0010, 0x2297},
        {0x0010, 0x2299},
        {0x0010, 0x4000},
        {0x0010, 0x0050},
        {0x0010, 0x1100}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end
  end

  describe "action_for/2 - study/series identifier tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "ReferringPhysicianName gets :Z", %{p: p} do
      assert DeIdentification.action_for({0x0008, 0x0090}, p) == :Z
    end

    test "NameOfPhysiciansReadingStudy gets :Z", %{p: p} do
      assert DeIdentification.action_for({0x0008, 0x009C}, p) == :Z
    end

    test "all study/series :X tags", %{p: p} do
      x_tags = [
        {0x0008, 0x0092},
        {0x0008, 0x0094},
        {0x0008, 0x0096},
        {0x0008, 0x009D},
        {0x0008, 0x0080},
        {0x0008, 0x0081},
        {0x0008, 0x0082},
        {0x0008, 0x1010},
        {0x0008, 0x1040},
        {0x0008, 0x1041},
        {0x0008, 0x1048},
        {0x0008, 0x1049},
        {0x0008, 0x1050},
        {0x0008, 0x1052},
        {0x0008, 0x1060},
        {0x0008, 0x1062},
        {0x0008, 0x1070},
        {0x0008, 0x1072},
        {0x0008, 0x4000}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end
  end

  describe "action_for/2 - UID tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "all UID tags get :U", %{p: p} do
      uid_tags = [
        {0x0008, 0x0014},
        {0x0008, 0x0017},
        {0x0008, 0x0018},
        {0x0008, 0x0058},
        {0x0008, 0x1150},
        {0x0008, 0x1155},
        {0x0008, 0x1195},
        {0x0008, 0x3010},
        {0x0002, 0x0003},
        {0x0004, 0x1511},
        {0x0018, 0x1002},
        {0x0018, 0x100B},
        {0x0018, 0x2042},
        {0x0020, 0x000D},
        {0x0020, 0x000E},
        {0x0020, 0x0052},
        {0x0020, 0x0200},
        {0x0020, 0x9161},
        {0x0020, 0x9164},
        {0x0028, 0x1199},
        {0x0028, 0x1214},
        {0x003A, 0x0310},
        {0x0040, 0x0554},
        {0x0040, 0x4023},
        {0x0040, 0xA124},
        {0x0040, 0xA171},
        {0x0040, 0xA402},
        {0x0040, 0xDB0C},
        {0x0040, 0xDB0D},
        {0x0062, 0x0021},
        {0x0064, 0x0003},
        {0x0070, 0x031A},
        {0x0070, 0x1101},
        {0x0070, 0x1102},
        {0x0088, 0x0140},
        {0x0400, 0x0100},
        {0x3006, 0x0024},
        {0x3006, 0x00C2},
        {0x300A, 0x0013},
        {0x300A, 0x0054},
        {0x300A, 0x0609},
        {0x300A, 0x0650},
        {0x300A, 0x0700},
        {0x3010, 0x0006},
        {0x3010, 0x000B},
        {0x3010, 0x0013},
        {0x3010, 0x0015},
        {0x3010, 0x003B},
        {0x3010, 0x006E},
        {0x3010, 0x006F}
      ]

      for tag <- uid_tags do
        assert DeIdentification.action_for(tag, p) == :U,
               "Expected :U for tag #{inspect(tag)}"
      end
    end
  end

  describe "action_for/2 - content creator/observer tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "content creator tags get :D", %{p: p} do
      d_tags = [
        {0x0070, 0x0084},
        {0x0040, 0xA123},
        {0x0040, 0x1101},
        {0x0040, 0xA075},
        {0x0040, 0xA073},
        {0x0040, 0xA027},
        {0x0040, 0xA030}
      ]

      for tag <- d_tags do
        assert DeIdentification.action_for(tag, p) == :D,
               "Expected :D for tag #{inspect(tag)}"
      end
    end

    test "content observer tags get :X or :Z", %{p: p} do
      assert DeIdentification.action_for({0x0070, 0x0086}, p) == :X
      assert DeIdentification.action_for({0x0040, 0xA160}, p) == :X
      assert DeIdentification.action_for({0x0040, 0xA730}, p) == :X
      assert DeIdentification.action_for({0x0040, 0xA088}, p) == :Z
      assert DeIdentification.action_for({0x0040, 0xA082}, p) == :Z
      assert DeIdentification.action_for({0x0040, 0xA078}, p) == :X
      assert DeIdentification.action_for({0x0040, 0xA07A}, p) == :X
    end
  end

  describe "action_for/2 - device identifiers in group 0018" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "device identifier tags get :X", %{p: p} do
      x_tags = [
        {0x0018, 0x1000},
        {0x0018, 0x1004},
        {0x0018, 0x1005},
        {0x0018, 0x1007},
        {0x0018, 0x1008},
        {0x0018, 0x1009},
        {0x0018, 0x100A},
        {0x0018, 0x1010},
        {0x0018, 0x1011},
        {0x0018, 0x1200},
        {0x0018, 0x1201},
        {0x0018, 0x1400},
        {0x0018, 0x4000},
        {0x0018, 0x9424},
        {0x0018, 0x0027},
        {0x0018, 0x0035},
        {0x0018, 0x1042},
        {0x0018, 0x1043},
        {0x0018, 0x1078},
        {0x0018, 0x1079},
        {0x0018, 0xA002},
        {0x0018, 0xA003}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end

    test "ContrastBolusAgent gets :D", %{p: p} do
      assert DeIdentification.action_for({0x0018, 0x0010}, p) == :D
    end

    test "DetectorCalibrationData gets :Z", %{p: p} do
      assert DeIdentification.action_for({0x0018, 0x1203}, p) == :Z
    end

    test "remaining 0018 tags get :K", %{p: p} do
      assert DeIdentification.action_for({0x0018, 0x0050}, p) == :K
      assert DeIdentification.action_for({0x0018, 0x0088}, p) == :K
    end
  end

  describe "action_for/2 - clinical trial tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "clinical trial :D tags", %{p: p} do
      d_tags = [
        {0x0012, 0x0010},
        {0x0012, 0x0020},
        {0x0012, 0x0040},
        {0x0012, 0x0042},
        {0x0012, 0x0081}
      ]

      for tag <- d_tags do
        assert DeIdentification.action_for(tag, p) == :D,
               "Expected :D for tag #{inspect(tag)}"
      end
    end

    test "clinical trial :Z tags", %{p: p} do
      z_tags = [
        {0x0012, 0x0021},
        {0x0012, 0x0030},
        {0x0012, 0x0031},
        {0x0012, 0x0050},
        {0x0012, 0x0060}
      ]

      for tag <- z_tags do
        assert DeIdentification.action_for(tag, p) == :Z,
               "Expected :Z for tag #{inspect(tag)}"
      end
    end

    test "clinical trial :X tags", %{p: p} do
      x_tags = [{0x0012, 0x0051}, {0x0012, 0x0071}, {0x0012, 0x0072}, {0x0012, 0x0082}]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end

    test "de-identification markers :K", %{p: p} do
      assert DeIdentification.action_for({0x0012, 0x0062}, p) == :K
      assert DeIdentification.action_for({0x0012, 0x0063}, p) == :K
    end

    test "unknown 0012 tags get :X", %{p: p} do
      assert DeIdentification.action_for({0x0012, 0x9999}, p) == :X
    end
  end

  describe "action_for/2 - date/time tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "InstanceCreationDate/Time gets :X", %{p: p} do
      assert DeIdentification.action_for({0x0008, 0x0012}, p) == :X
      assert DeIdentification.action_for({0x0008, 0x0013}, p) == :X
      assert DeIdentification.action_for({0x0008, 0x0015}, p) == :X
    end
  end

  describe "action_for/2 - procedure/scheduling tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "group 0032 (study management) gets :X", %{p: p} do
      assert DeIdentification.action_for({0x0032, 0x000A}, p) == :X
      assert DeIdentification.action_for({0x0032, 0x1060}, p) == :X
    end

    test "group 0038 (visit) gets :X", %{p: p} do
      assert DeIdentification.action_for({0x0038, 0x0010}, p) == :X
      assert DeIdentification.action_for({0x0038, 0x0500}, p) == :X
    end

    test "scheduling 0040 tags get :X", %{p: p} do
      x_tags = [
        {0x0040, 0x0006},
        {0x0040, 0x0007},
        {0x0040, 0x0241},
        {0x0040, 0x0242},
        {0x0040, 0x0243},
        {0x0040, 0x0244},
        {0x0040, 0x0245},
        {0x0040, 0x0250},
        {0x0040, 0x0251},
        {0x0040, 0x0254},
        {0x0040, 0x0275},
        {0x0040, 0x0280},
        {0x0040, 0x0310},
        {0x0040, 0x1001},
        {0x0040, 0x1010},
        {0x0040, 0x1400},
        {0x0040, 0x2001},
        {0x0040, 0x2400}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end

    test "scheduling 0040 :Z tags", %{p: p} do
      assert DeIdentification.action_for({0x0040, 0x2016}, p) == :Z
      assert DeIdentification.action_for({0x0040, 0x2017}, p) == :Z
    end
  end

  describe "action_for/2 - digital signature tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "digital signature :X tags", %{p: p} do
      x_tags = [
        {0xFFFA, 0xFFFA},
        {0x0400, 0x0310},
        {0x0400, 0x0402},
        {0x0400, 0x0403},
        {0x0400, 0x0404},
        {0x0400, 0x0550},
        {0x0400, 0x0561}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end

    test "digital signature :D tags", %{p: p} do
      d_tags = [
        {0x0400, 0x0115},
        {0x0400, 0x0105},
        {0x0400, 0x0562},
        {0x0400, 0x0563},
        {0x0400, 0x0565}
      ]

      for tag <- d_tags do
        assert DeIdentification.action_for(tag, p) == :D,
               "Expected :D for tag #{inspect(tag)}"
      end
    end
  end

  describe "action_for/2 - graphics/presentation tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "graphics :D tags", %{p: p} do
      assert DeIdentification.action_for({0x0070, 0x0001}, p) == :D
      assert DeIdentification.action_for({0x0070, 0x0006}, p) == :D
    end

    test "graphics :X tags", %{p: p} do
      assert DeIdentification.action_for({0x0070, 0x0008}, p) == :X
      assert DeIdentification.action_for({0x0070, 0x0082}, p) == :X
      assert DeIdentification.action_for({0x0070, 0x0083}, p) == :X
    end
  end

  describe "action_for/2 - radiotherapy tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "RT Plan :D tags", %{p: p} do
      assert DeIdentification.action_for({0x300A, 0x0002}, p) == :D
      assert DeIdentification.action_for({0x3006, 0x0002}, p) == :D
    end

    test "RT Plan :X tags", %{p: p} do
      x_tags = [
        {0x300A, 0x0003},
        {0x300A, 0x0004},
        {0x300A, 0x0006},
        {0x300A, 0x0007},
        {0x300A, 0x000E},
        {0x300A, 0x0016},
        {0x300A, 0x00C3},
        {0x3006, 0x0004},
        {0x3006, 0x0006},
        {0x3006, 0x0028},
        {0x3006, 0x0038},
        {0x3006, 0x0085},
        {0x3006, 0x0088},
        {0x3008, 0x0054},
        {0x3008, 0x0056},
        {0x3008, 0x0250},
        {0x3008, 0x0251},
        {0x300E, 0x0008}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end

    test "RT Structure :Z tags", %{p: p} do
      z_tags = [
        {0x3006, 0x0008},
        {0x3006, 0x0009},
        {0x3006, 0x0026},
        {0x3006, 0x00A6},
        {0x300E, 0x0004},
        {0x300E, 0x0005}
      ]

      for tag <- z_tags do
        assert DeIdentification.action_for(tag, p) == :Z,
               "Expected :Z for tag #{inspect(tag)}"
      end
    end
  end

  describe "action_for/2 - specimen tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "specimen :X tags", %{p: p} do
      x_tags = [
        {0x0040, 0x050A},
        {0x0040, 0x051A},
        {0x0040, 0x0600},
        {0x0040, 0x0602}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end

    test "specimen :D tags", %{p: p} do
      assert DeIdentification.action_for({0x0040, 0x0512}, p) == :D
      assert DeIdentification.action_for({0x0040, 0x0551}, p) == :D
    end

    test "specimen :Z tags", %{p: p} do
      assert DeIdentification.action_for({0x0040, 0x0513}, p) == :Z
      assert DeIdentification.action_for({0x0040, 0x0562}, p) == :Z
      assert DeIdentification.action_for({0x0040, 0x0610}, p) == :Z
    end
  end

  describe "action_for/2 - referenced sequences" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "referenced sequence tags get :X", %{p: p} do
      x_tags = [
        {0x0008, 0x1110},
        {0x0008, 0x1111},
        {0x0008, 0x1120},
        {0x0008, 0x1140}
      ]

      for tag <- x_tags do
        assert DeIdentification.action_for(tag, p) == :X,
               "Expected :X for tag #{inspect(tag)}"
      end
    end
  end

  describe "action_for/2 - overlay/curve/interpretation tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "curve data (50XX) gets :X", %{p: p} do
      assert DeIdentification.action_for({0x5000, 0x0001}, p) == :X
      assert DeIdentification.action_for({0x5010, 0x3000}, p) == :X
      assert DeIdentification.action_for({0x50FF, 0x0001}, p) == :X
    end

    test "overlay comments (60XX,4000) gets :X", %{p: p} do
      assert DeIdentification.action_for({0x6000, 0x4000}, p) == :X
      assert DeIdentification.action_for({0x6010, 0x4000}, p) == :X
    end

    test "overlay data (60XX,3000) gets :X", %{p: p} do
      assert DeIdentification.action_for({0x6000, 0x3000}, p) == :X
      assert DeIdentification.action_for({0x60FF, 0x3000}, p) == :X
    end

    test "interpretation group 4008 gets :X", %{p: p} do
      assert DeIdentification.action_for({0x4008, 0x0010}, p) == :X
      assert DeIdentification.action_for({0x4008, 0x0100}, p) == :X
    end

    test "trailing padding gets :X", %{p: p} do
      assert DeIdentification.action_for({0xFFFC, 0xFFFC}, p) == :X
    end
  end

  describe "action_for/2 - description tags" do
    setup do
      %{p: DeIdentification.basic_profile()}
    end

    test "DerivationDescription gets :X (always, not X_or_C)", %{p: p} do
      assert DeIdentification.action_for({0x0008, 0x2111}, p) == :X
    end

    test "ImageComments group 0028 gets :X", %{p: p} do
      assert DeIdentification.action_for({0x0028, 0x4000}, p) == :X
    end
  end

  # ── Dummy value coverage ───────────────────────────────────────

  describe "apply/2 - dummy values for all VR types" do
    test "DT dummy value" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0008, 0x0023}, :DA, "20240101")
        |> DataSet.put({0x0008, 0x0033}, :TM, "120000")

      {:ok, result, _} = DeIdentification.apply(ds)
      assert DataSet.get(result, {0x0008, 0x0023}) == "19000101"
      assert DataSet.get(result, {0x0008, 0x0033}) == "000000"
    end

    test "SH dummy value for ANON" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0018, 0x0010}, :SH, "Contrast Agent XYZ")

      {:ok, result, _} = DeIdentification.apply(ds)
      # ContrastBolusAgent mapped to :D, VR is SH in our test
      # But dummy_value is dispatched on the element's VR
      val = DataSet.get(result, {0x0018, 0x0010})
      assert is_binary(val)
      assert val != "Contrast Agent XYZ"
    end

    test "LO dummy for clinical trial tags" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0012, 0x0010}, :LO, "TrialSponsor")
        |> DataSet.put({0x0012, 0x0020}, :LO, "ProtocolID")

      {:ok, result, _} = DeIdentification.apply(ds)
      assert DataSet.get(result, {0x0012, 0x0010}) == "ANONYMOUS"
      assert DataSet.get(result, {0x0012, 0x0020}) == "ANONYMOUS"
    end

    test "CS dummy value" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0010, 0x0010}, :CS, "PATIENT")

      {:ok, result, _} = DeIdentification.apply(ds)
      # PatientName is :D action; CS VR → "ANON"
      assert DataSet.get(result, {0x0010, 0x0010}) == "ANON"
    end

    test "UI dummy generates new UID" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0400, 0x0115}, :UI, "1.2.3.4")

      {:ok, result, _} = DeIdentification.apply(ds)
      val = DataSet.get(result, {0x0400, 0x0115})
      assert is_binary(val)
      assert UID.valid?(val)
    end

    test "DS and IS dummy values via RT plan tags" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x300A, 0x0002}, :DS, "99.5")
        |> DataSet.put({0x3006, 0x0002}, :IS, "42")

      {:ok, result, _} = DeIdentification.apply(ds)
      assert DataSet.get(result, {0x300A, 0x0002}) == "0"
      assert DataSet.get(result, {0x3006, 0x0002}) == "0"
    end

    test "unknown VR dummy is empty string" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0070, 0x0001}, :OB, <<1, 2, 3>>)

      {:ok, result, _} = DeIdentification.apply(ds)
      assert DataSet.get(result, {0x0070, 0x0001}) == ""
    end

    test "AS dummy value via patient characteristics" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0040, 0xA030}, :AS, "045Y")

      {:ok, result, _} = DeIdentification.apply(ds)
      assert DataSet.get(result, {0x0040, 0xA030}) == "000Y"
    end
  end

  # ── Modify temporal value / :M action coverage ─────────────────

  describe "apply/2 - :M action (retain_long_modified_dates)" do
    test "DA value gets shifted by -10 years" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0008, 0x0020}, :DA, "20260101")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      assert DataSet.get(result, {0x0008, 0x0020}) == "20160101"
    end

    test "DT value shifts date prefix preserving time suffix" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0008, 0x002A}, :DT, "20261231235959.000000+0100")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      val = DataSet.get(result, {0x0008, 0x002A})
      assert String.starts_with?(val, "20161231")
      assert String.contains?(val, "235959")
    end

    test "TM value is trimmed (no date shift for time-only)" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0008, 0x0030}, :TM, "140000  ")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      assert DataSet.get(result, {0x0008, 0x0030}) == "140000"
    end

    test "non-temporal tag not affected by modified dates option" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0010, 0x0010}, :PN, "SMITH^JOHN")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      assert DataSet.get(result, {0x0010, 0x0010}) == "ANONYMOUS"
    end

    test "invalid date string passes through unchanged" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0008, 0x0020}, :DA, "BADDATE")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      assert DataSet.get(result, {0x0008, 0x0020}) == "BADDATE"
    end

    test "short DT value (< 8 chars) passes through trimmed" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0008, 0x002A}, :DT, "2026")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      assert DataSet.get(result, {0x0008, 0x002A}) == "2026"
    end

    test "leap year Feb 29 shifted to non-leap year becomes Feb 28" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0008, 0x0020}, :DA, "20240229")

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      # 2024 - 10 = 2014 (not a leap year), so Feb 29 → Feb 28
      assert DataSet.get(result, {0x0008, 0x0020}) == "20140228"
    end

    test "unknown VR for temporal value returns empty string" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      # Create an element with weird VR on a temporal tag
      elem = DataElement.new({0x0008, 0x0020}, :OB, <<1, 2, 3>>)
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x0020}, elem)}

      profile = %DeIdentification.Profile{retain_long_modified_dates: true}
      {:ok, result, _} = DeIdentification.apply(ds, profile: profile)
      assert DataSet.get(result, {0x0008, 0x0020}) == ""
    end
  end
end
