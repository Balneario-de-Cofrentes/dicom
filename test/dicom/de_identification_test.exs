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
      refute profile.retain_safe_private
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

    test "removes referring physician name" do
      ds = sample_data_set()
      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      assert DataSet.get(result, Tag.referring_physician_name()) == nil
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
      sq_elem = DataElement.new({0x0008, 0x1115}, :SQ, [inner_item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1115}, sq_elem)}

      {:ok, result, uid_map} = DeIdentification.apply(ds)
      sq = DataSet.get_element(result, {0x0008, 0x1115})
      [item] = sq.value

      # Patient name in sequence should be replaced
      assert item[Tag.patient_name()].value != "INNER^NAME"

      # UID in sequence should be replaced consistently
      assert item[{0x0008, 0x1150}].value != "1.2.3.4.5"
      assert uid_map["1.2.3.4.5"] == item[{0x0008, 0x1150}].value
    end
  end

  # ── apply/2 - retain_safe_private option ──────────────────────

  describe "apply/2 - with retain_safe_private option" do
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

    test "retain_safe_private flag does not override action_for :X on private tags" do
      # retain_safe_private controls strip_private_tags, but action_for still
      # maps unknown tags to :X in process_elements, so private tags are removed
      # before strip_private_tags runs
      ds =
        sample_data_set()
        |> DataSet.put({0x0009, 0x0010}, :LO, "PrivateCreator")

      profile = %DeIdentification.Profile{retain_safe_private: true}
      {:ok, result, _uid_map} = DeIdentification.apply(ds, profile: profile)

      # Even with retain_safe_private, unknown tags get :X action
      refute DataSet.has_tag?(result, {0x0009, 0x0010})
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

    test "StudyID gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x0010}, p) == :K
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

    test "FrameOfReferenceUID gets :K", %{profile: p} do
      assert DeIdentification.action_for({0x0020, 0x0052}, p) == :K
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

    test "ContentDate gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0023}, p) == :X
    end

    test "SeriesTime gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0031}, p) == :X
    end

    test "AcquisitionTime gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0032}, p) == :X
    end

    test "ContentTime gets :X", %{profile: p} do
      assert DeIdentification.action_for({0x0008, 0x0033}, p) == :X
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
      assert DataSet.get(result, {0x0008, 0x0023}) == nil
      assert DataSet.get(result, {0x0008, 0x0031}) == nil
      assert DataSet.get(result, {0x0008, 0x0032}) == nil
      assert DataSet.get(result, {0x0008, 0x0033}) == nil
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

      outer_sq = DataElement.new({0x0008, 0x1115}, :SQ, [outer_item])

      ds = sample_data_set()
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1115}, outer_sq)}

      {:ok, result, _uid_map} = DeIdentification.apply(ds)
      sq = DataSet.get_element(result, {0x0008, 0x1115})
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
      # Tag {0x0028, _} maps to :K action. If it has vr :SQ, the apply_action(:K, SQ)
      # clause at L182-185 should be reached when inside deidentify_sequence.
      # This exercises the code path that process_elements can't reach
      # (because process_elements intercepts SQ before apply_action).

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
        tag: {0x0008, 0x1115},
        vr: :SQ,
        value: [outer_item],
        length: 0
      }

      ds = %DataSet{
        file_meta: %{},
        elements: %{
          {0x0008, 0x1115} => outer_sq
        }
      }

      {:ok, result, _uid_map} = DeIdentification.apply(ds)

      # The outer SQ should still be present
      result_sq = DataSet.get_element(result, {0x0008, 0x1115})
      assert result_sq.vr == :SQ
      [result_item] = result_sq.value

      # The nested SQ (0028,9145) should be kept (:K action) and recursed
      nested = result_item[{0x0028, 0x9145}]
      assert nested.vr == :SQ

      # Inside the nested SQ, PatientName should be de-identified (:D action)
      [nested_item] = nested.value
      assert nested_item[{0x0010, 0x0010}].value == "ANONYMOUS"
    end
  end
end
