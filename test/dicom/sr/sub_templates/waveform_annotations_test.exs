defmodule Dicom.SR.SubTemplates.WaveformAnnotationsTest do
  use ExUnit.Case, async: true

  alias Dicom.SR.Code
  alias Dicom.SR.Codes
  alias Dicom.SR.SubTemplates.WaveformAnnotations

  @ms Code.new("ms", "UCUM", "millisecond")
  @mv Code.new("mV", "UCUM", "millivolt")
  @hz Code.new("Hz", "UCUM", "hertz")
  @s Code.new("s", "UCUM", "second")
  @lead_i Code.new("2:1", "MDC", "Lead I")
  @lead_ii Code.new("2:2", "MDC", "Lead II")
  @ecg_modality Code.new("ECG", "DCM", "Electrocardiography")
  @algorithm Code.new("122160", "DCM", "Algorithm")
  @sinusoidal Code.new("251104001", "SCT", "Sinusoidal waveform")
  @pvc Code.new("164884008", "SCT", "Premature ventricular complex")

  # -- TID 3751 Waveform Pattern or Event ------------------------------------

  describe "waveform_pattern/1" do
    test "builds waveform pattern container" do
      [item] =
        WaveformAnnotations.waveform_pattern(
          pattern: @pvc,
          temporal_location: "at 2.5 seconds",
          morphology: @sinusoidal,
          description: "Single PVC with compensatory pause"
        )

      assert item.value_type == :container
      assert item.concept_name == @pvc
      assert length(item.children) == 3
    end

    test "defaults to waveform annotation concept" do
      [item] = WaveformAnnotations.waveform_pattern()
      assert item.concept_name == Codes.waveform_annotation()
      assert item.children == []
    end
  end

  # -- TID 3752 Waveform Measurement -----------------------------------------

  describe "waveform_measurement/1" do
    test "builds waveform measurement" do
      r_amplitude = Code.new("122176", "DCM", "R-wave Amplitude")

      [item] =
        WaveformAnnotations.waveform_measurement(
          concept: r_amplitude,
          value: 1.2,
          units: @mv,
          lead: @lead_i,
          temporal_location: "at peak",
          method: @algorithm
        )

      assert item.value_type == :num
      assert item.concept_name == r_amplitude
      assert item.value.units == @mv
      assert length(item.children) == 3
    end

    test "builds minimal waveform measurement" do
      rr_interval = Code.new("122172", "DCM", "RR Interval")

      [item] =
        WaveformAnnotations.waveform_measurement(
          concept: rr_interval,
          value: 830,
          units: @ms
        )

      assert item.value_type == :num
      assert item.children == []
    end
  end

  # -- TID 3753 Annotation Note ----------------------------------------------

  describe "annotation_note/1" do
    test "builds annotation note" do
      [item] =
        WaveformAnnotations.annotation_note(
          note: "Artifact detected at lead V1",
          temporal_location: "at 5.2 seconds"
        )

      assert item.value_type == :text
      assert item.concept_name == Codes.waveform_annotation()
      assert item.value == "Artifact detected at lead V1"
      assert length(item.children) == 1
    end

    test "builds minimal annotation note" do
      [item] = WaveformAnnotations.annotation_note(note: "Normal rhythm")
      assert item.value == "Normal rhythm"
      assert item.children == []
    end
  end

  # -- TID 3754 Waveform Library Entry ----------------------------------------

  describe "library_entry/1" do
    test "builds waveform library entry container" do
      [item] =
        WaveformAnnotations.library_entry(
          description: "12-lead ECG waveform",
          descriptors: [
            modality: @ecg_modality,
            sample_rate: 500,
            sample_rate_units: @hz,
            duration: 10,
            duration_units: @s
          ],
          multiplex: [
            group_label: "Standard 12-Lead",
            number_of_channels: 12
          ],
          channel: [
            channel_label: "Lead I",
            channel_source: @lead_i,
            sensitivity: 10.0,
            sensitivity_units: @mv
          ]
        )

      assert item.value_type == :container
      assert item.concept_name == Codes.waveform_reference()
      # 1 description + 3 descriptors + 2 multiplex + 3 channel = 9
      assert length(item.children) == 9
    end

    test "builds minimal library entry" do
      [item] = WaveformAnnotations.library_entry()
      assert item.children == []
    end
  end

  # -- TID 3755 Waveform Library Descriptors ---------------------------------

  describe "library_descriptors/1" do
    test "builds library descriptors" do
      items =
        WaveformAnnotations.library_descriptors(
          modality: @ecg_modality,
          sample_rate: 500,
          sample_rate_units: @hz,
          duration: 10,
          duration_units: @s
        )

      assert length(items) == 3
    end

    test "partial descriptors" do
      items = WaveformAnnotations.library_descriptors(modality: @ecg_modality)
      assert length(items) == 1
    end

    test "empty returns empty list" do
      assert WaveformAnnotations.library_descriptors() == []
    end
  end

  # -- TID 3756 Waveform Multiplex Group Descriptors -------------------------

  describe "multiplex_descriptors/1" do
    test "builds multiplex descriptors" do
      items =
        WaveformAnnotations.multiplex_descriptors(
          group_label: "Standard 12-Lead",
          number_of_channels: 12
        )

      assert length(items) == 2
    end

    test "label only" do
      items = WaveformAnnotations.multiplex_descriptors(group_label: "Group A")
      assert length(items) == 1
      [item] = items
      assert item.value_type == :text
    end

    test "empty returns empty list" do
      assert WaveformAnnotations.multiplex_descriptors() == []
    end
  end

  # -- TID 3757 Waveform Channel Descriptors ---------------------------------

  describe "channel_descriptors/1" do
    test "builds channel descriptors" do
      items =
        WaveformAnnotations.channel_descriptors(
          channel_label: "Lead II",
          channel_source: @lead_ii,
          sensitivity: 10.0,
          sensitivity_units: @mv
        )

      assert length(items) == 3
    end

    test "label only" do
      items = WaveformAnnotations.channel_descriptors(channel_label: "V1")
      assert length(items) == 1
    end

    test "empty returns empty list" do
      assert WaveformAnnotations.channel_descriptors() == []
    end
  end
end
