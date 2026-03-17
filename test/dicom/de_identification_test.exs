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
end
