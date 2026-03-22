defmodule Dicom.SR.SubTemplates.ImageLibraryDescriptorsTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.ImageLibraryDescriptors

  @ct Code.new("CT", "DCM", "Computed Tomography")
  @mr Code.new("MR", "DCM", "Magnetic Resonance")
  @pt Code.new("PT", "DCM", "Positron emission tomography")
  @dx Code.new("DX", "DCM", "Digital Radiography")
  @mm Code.new("mm", "UCUM", "millimeter")
  @mgy Code.new("mGy", "UCUM", "milligray")
  @mbq Code.new("MBq", "UCUM", "megabecquerel")
  @ml Code.new("mL", "UCUM", "milliliter")
  @s_mm2 Code.new("s/mm2", "UCUM", "s/mm2")
  @left Code.new("L", "DCM", "Left")
  @fbp Code.new("113961", "DCM", "Filtered Back Projection")
  @two_d Code.new("110800", "DCM", "2D")

  # -- TID 1602 Common Descriptors ------------------------------------------

  describe "common_descriptors/1" do
    test "empty options returns empty list" do
      assert ImageLibraryDescriptors.common_descriptors([]) == []
    end

    test "builds modality descriptor" do
      items = ImageLibraryDescriptors.common_descriptors(modality: @ct)

      assert length(items) == 1
      [item] = items
      assert item.value_type == :code
      assert item.concept_name == Codes.modality()
      assert item.value == @ct
      assert item.relationship_type == "HAS ACQ CONTEXT"
    end

    test "builds full common descriptor set" do
      anterior = Code.new("A", "DCM", "Anterior")
      right = Code.new("R", "DCM", "Right")

      items =
        ImageLibraryDescriptors.common_descriptors(
          modality: @ct,
          frame_of_reference_uid: "1.2.3.4.5",
          pixel_spacing: 0.5,
          spacing_units: @mm,
          slice_thickness: 1.5,
          thickness_units: @mm,
          image_laterality: @left,
          patient_orientation_row: anterior,
          patient_orientation_column: right
        )

      assert length(items) == 7

      types = Enum.map(items, & &1.value_type)
      assert Enum.count(types, &(&1 == :code)) == 4
      assert Enum.count(types, &(&1 == :uidref)) == 1
      assert Enum.count(types, &(&1 == :num)) == 2
    end
  end

  # -- TID 1603 Projection Radiography Descriptors --------------------------

  describe "projection_radiography_descriptors/1" do
    test "includes common plus radiography-specific fields" do
      ap_view = Code.new("399067008", "SCT", "Anteroposterior")

      items =
        ImageLibraryDescriptors.projection_radiography_descriptors(
          modality: @dx,
          positioner_primary_angle: 0.0,
          positioner_secondary_angle: 15.0,
          view_code: ap_view
        )

      assert length(items) == 4
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.modality() in concepts
      assert Codes.positioner_primary_angle() in concepts
      assert Codes.positioner_secondary_angle() in concepts
      assert Codes.radiographic_view() in concepts
    end

    test "radiography with only common fields" do
      items =
        ImageLibraryDescriptors.projection_radiography_descriptors(modality: @dx)

      assert length(items) == 1
    end
  end

  # -- TID 1604 Cross-Sectional Descriptors ---------------------------------

  describe "cross_sectional_descriptors/1" do
    test "includes common plus cross-sectional fields" do
      items =
        ImageLibraryDescriptors.cross_sectional_descriptors(
          modality: @ct,
          image_position_patient: "0\\0\\0",
          image_orientation_patient: "1\\0\\0\\0\\1\\0",
          pixel_spacing_value: 0.78,
          pixel_spacing_units: @mm,
          spacing_between_slices: 5.0,
          spacing_units: @mm
        )

      assert length(items) == 5
      text_items = Enum.filter(items, &(&1.value_type == :text))
      assert length(text_items) == 2
    end
  end

  # -- TID 1605 CT Descriptors ----------------------------------------------

  describe "ct_descriptors/1" do
    test "builds full CT descriptor set" do
      items =
        ImageLibraryDescriptors.ct_descriptors(
          modality: @ct,
          kvp: 120,
          tube_current: 200,
          exposure_time: 500,
          ctdi_vol: 15.3,
          ctdi_units: @mgy,
          reconstruction_algorithm: @fbp,
          convolution_kernel: "B30f",
          spiral_pitch_factor: 0.9
        )

      assert length(items) == 8

      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.kvp() in concepts
      assert Codes.tube_current() in concepts
      assert Codes.exposure_time() in concepts
      assert Codes.ctdi_vol() in concepts
      assert Codes.reconstruction_algorithm() in concepts
      assert Codes.convolution_kernel() in concepts
      assert Codes.spiral_pitch_factor() in concepts
    end

    test "CT with only KVP and tube current" do
      items =
        ImageLibraryDescriptors.ct_descriptors(
          kvp: 120,
          tube_current: 350
        )

      assert length(items) == 2
      assert Enum.all?(items, &(&1.value_type == :num))
    end

    test "inherits cross-sectional fields" do
      items =
        ImageLibraryDescriptors.ct_descriptors(
          modality: @ct,
          image_position_patient: "0\\0\\0",
          kvp: 120
        )

      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.modality() in concepts
      assert Codes.image_position_patient() in concepts
      assert Codes.kvp() in concepts
    end
  end

  # -- TID 1606 MR Descriptors ----------------------------------------------

  describe "mr_descriptors/1" do
    test "builds full MR descriptor set" do
      items =
        ImageLibraryDescriptors.mr_descriptors(
          modality: @mr,
          echo_time: 80.0,
          repetition_time: 3000.0,
          flip_angle: 90,
          inversion_time: 150.0,
          pulse_sequence_name: "GRE",
          mr_acquisition_type: @two_d
        )

      assert length(items) == 7
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.echo_time() in concepts
      assert Codes.repetition_time() in concepts
      assert Codes.flip_angle() in concepts
      assert Codes.inversion_time() in concepts
      assert Codes.pulse_sequence_name() in concepts
      assert Codes.mr_acquisition_type() in concepts
    end

    test "MR with only echo and repetition time" do
      items =
        ImageLibraryDescriptors.mr_descriptors(
          echo_time: 30.0,
          repetition_time: 500.0
        )

      assert length(items) == 2
    end
  end

  # -- TID 1607 PET Descriptors ---------------------------------------------

  describe "pet_descriptors/1" do
    test "builds full PET descriptor set" do
      fdg = Code.new("35321007", "SCT", "FDG")
      f18 = Code.new("21613005", "SCT", "Fluorine-18")

      items =
        ImageLibraryDescriptors.pet_descriptors(
          modality: @pt,
          radiopharmaceutical: fdg,
          radionuclide: f18,
          radiopharmaceutical_volume: 10.0,
          volume_units: @ml,
          administered_activity: 370.0,
          activity_units: @mbq,
          radiopharmaceutical_start_datetime: "20260101120000"
        )

      assert length(items) == 6
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.radiopharmaceutical() in concepts
      assert Codes.radionuclide() in concepts
      assert Codes.administered_activity() in concepts
    end

    test "PET with only radiopharmaceutical" do
      fdg = Code.new("35321007", "SCT", "FDG")

      items =
        ImageLibraryDescriptors.pet_descriptors(radiopharmaceutical: fdg)

      assert length(items) == 1
    end
  end

  # -- TID 1608 Prostate Multiparametric MR Descriptors ---------------------

  describe "prostate_mr_descriptors/1" do
    test "extends MR descriptors with prostate-specific fields" do
      adc = Code.new("113041", "DCM", "ADC")

      items =
        ImageLibraryDescriptors.prostate_mr_descriptors(
          modality: @mr,
          echo_time: 80.0,
          repetition_time: 5000.0,
          diffusion_b_value: 800,
          b_value_units: @s_mm2,
          adc_map: adc,
          dynamic_contrast_enhanced: "Phase 3"
        )

      assert length(items) == 6
      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.diffusion_b_value() in concepts
      assert Codes.adc_map_indicator() in concepts
      assert Codes.dynamic_contrast_enhanced() in concepts
    end

    test "prostate MR inherits MR and cross-sectional fields" do
      items =
        ImageLibraryDescriptors.prostate_mr_descriptors(
          modality: @mr,
          image_position_patient: "0\\0\\0",
          echo_time: 80.0,
          diffusion_b_value: 1000,
          b_value_units: @s_mm2
        )

      concepts = Enum.map(items, & &1.concept_name)
      assert Codes.modality() in concepts
      assert Codes.image_position_patient() in concepts
      assert Codes.echo_time() in concepts
      assert Codes.diffusion_b_value() in concepts
    end

    test "empty prostate MR returns empty" do
      assert ImageLibraryDescriptors.prostate_mr_descriptors([]) == []
    end
  end

  # -- Relationship type consistency ----------------------------------------

  describe "relationship types" do
    test "all items use HAS ACQ CONTEXT" do
      items =
        ImageLibraryDescriptors.ct_descriptors(
          modality: @ct,
          kvp: 120,
          convolution_kernel: "B30f",
          frame_of_reference_uid: "1.2.3"
        )

      Enum.each(items, fn item ->
        assert item.relationship_type == "HAS ACQ CONTEXT",
               "Expected HAS ACQ CONTEXT for #{inspect(item.concept_name)}"
      end)
    end
  end
end
