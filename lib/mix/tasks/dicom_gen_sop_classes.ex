defmodule Mix.Tasks.Dicom.GenSopClasses do
  @compile {:no_warn_undefined, :json}
  @moduledoc """
  Generates `Dicom.SOPClass` from innolitics sops.json and service_sop_classes.exs.

  Reads `priv/sops.json` (175 storage SOP classes from innolitics/dicom-standard)
  and `priv/service_sop_classes.exs` (hand-maintained non-storage SOP classes),
  derives modality from SOP name, marks retired UIDs, and generates a compile-time
  registry module.

  ## Usage

      mix dicom.gen_sop_classes
  """
  @shortdoc "Generate DICOM SOP Class registry from PS3.4 data"

  use Mix.Task

  @output_path "lib/dicom/sop_class.ex"

  # ── Known retired storage SOP classes ─────────────────────────
  @retired_uids MapSet.new([
                  # Nuclear Medicine Image Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.5",
                  # Ultrasound Image Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.6",
                  # Ultrasound Multi-frame Image Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.3",
                  # Standalone Curve Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.9",
                  # Standalone Modality LUT Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.10",
                  # Standalone VOI LUT Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.11",
                  # X-Ray Angiographic Bi-Plane Image Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.12.3",
                  # Digital X-Ray Image Storage - For Processing
                  "1.2.840.10008.5.1.4.1.1.1.1.1",
                  # Digital Mammography X-Ray Image Storage - For Processing
                  "1.2.840.10008.5.1.4.1.1.1.2.1",
                  # Digital Intra-Oral X-Ray Image Storage - For Processing
                  "1.2.840.10008.5.1.4.1.1.1.3.1",
                  # Standalone PET Curve Storage (Retired)
                  "1.2.840.10008.5.1.4.1.1.129",
                  # RT Image Storage (Retired? No, active — remove)
                  "1.2.840.10008.5.1.4.1.1.481.1"
                ])

  # ── Name → modality mapping ──────────────────────────────────
  # Order matters: more specific patterns first.
  @modality_patterns [
    # RT sub-modalities
    {"RT Plan", "RTPLAN"},
    {"RT Dose", "RTDOSE"},
    {"RT Structure Set", "RTSTRUCT"},
    {"RT Beams Treatment Record", "RTRECORD"},
    {"RT Brachy Treatment Record", "RTRECORD"},
    {"RT Treatment Summary Record", "RTRECORD"},
    {"RT Ion Plan", "RTPLAN"},
    {"RT Ion Beams Treatment Record", "RTRECORD"},
    {"RT Beams Delivery Instruction", "RTPLAN"},
    {"RT Physician Intent", "RTPLAN"},
    {"RT Segment Annotation", "RTSTRUCT"},
    {"RT Radiation Set", "RTPLAN"},
    {"RT Radiation", "RTPLAN"},
    {"RT Image", "RTIMAGE"},
    {"Radiopharmaceutical Radiation Dose SR", "SR"},
    # Imaging modalities — more specific first
    {"Enhanced CT", "CT"},
    {"Legacy Converted Enhanced CT", "CT"},
    {"CT Defined Procedure Protocol", "CT"},
    {"CT Image", "CT"},
    {"CT Performed Procedure Protocol", "CT"},
    {"Enhanced MR Color", "MR"},
    {"Enhanced MR", "MR"},
    {"Legacy Converted Enhanced MR", "MR"},
    {"MR Spectroscopy", "MR"},
    {"MR Image", "MR"},
    {"Ultrasound Multi-frame", "US"},
    {"Ultrasound Image", "US"},
    {"Ultrasound", "US"},
    {"Enhanced US Volume", "US"},
    {"Digital X-Ray", "DX"},
    {"Digital Mammography X-Ray", "MG"},
    {"Digital Intra-Oral X-Ray", "IO"},
    {"Mammography CAD SR", "SR"},
    {"Computed Radiography", "CR"},
    {"X-Ray Angiographic", "XA"},
    {"XA Defined Procedure Protocol", "XA"},
    {"XA Performed Procedure Protocol", "XA"},
    {"XA/XRF Grayscale Softcopy Presentation State", "XA"},
    {"X-Ray Radiofluoroscopic", "RF"},
    {"X-Ray 3D Angiographic", "XA"},
    {"X-Ray 3D Craniofacial", "DX"},
    {"Breast Tomosynthesis", "MG"},
    {"Breast Projection X-Ray", "MG"},
    {"Wide Field Ophthalmic Photography", "OP"},
    {"Ophthalmic Photography", "OP"},
    {"Ophthalmic Tomography", "OPT"},
    {"Ophthalmic Axial Measurements", "OPM"},
    {"Ophthalmic Visual Field", "OPV"},
    {"Ophthalmic Thickness Map", "OPT"},
    {"Ophthalmic Optical Coherence Tomography", "OPT"},
    {"Lensometry Measurements", "LEN"},
    {"Autorefraction Measurements", "AR"},
    {"Keratometry Measurements", "KER"},
    {"Subjective Refraction Measurements", "SRF"},
    {"Visual Acuity Measurements", "VA"},
    {"Intraocular Lens Calculations", "IOL"},
    {"Nuclear Medicine", "NM"},
    {"Positron Emission Tomography", "PT"},
    {"PET Image", "PT"},
    {"Enhanced PET", "PT"},
    {"Legacy Converted Enhanced PET", "PT"},
    {"Secondary Capture", "SC"},
    {"Multi-frame Single Bit Secondary Capture", "SC"},
    {"Multi-frame Grayscale Byte Secondary Capture", "SC"},
    {"Multi-frame Grayscale Word Secondary Capture", "SC"},
    {"Multi-frame True Color Secondary Capture", "SC"},
    {"VL Endoscopic", "ES"},
    {"VL Microscopic", "GM"},
    {"VL Slide-Coordinates Microscopic", "SM"},
    {"VL Photographic", "XC"},
    {"VL Whole Slide Microscopy", "SM"},
    {"Video Endoscopic", "ES"},
    {"Video Microscopic", "GM"},
    {"Video Photographic", "XC"},
    {"Dermoscopic Photography", "DMS"},
    # SR sub-types
    {"Acquisition Context SR", "SR"},
    {"Comprehensive 3D SR", "SR"},
    {"Extensible SR", "SR"},
    {"Comprehensive SR", "SR"},
    {"Enhanced SR", "SR"},
    {"Basic Text SR", "SR"},
    {"Procedure Log", "SR"},
    {"Chest CAD SR", "SR"},
    {"Colon CAD SR", "SR"},
    {"Implantation Plan SR", "SR"},
    {"Spectacle Prescription Report", "SR"},
    {"Macular Grid Thickness and Volume Report", "SR"},
    # Encapsulated documents
    {"Encapsulated PDF", "DOC"},
    {"Encapsulated CDA", "DOC"},
    {"Encapsulated STL", "M3D"},
    {"Encapsulated OBJ", "M3D"},
    {"Encapsulated MTL", "M3D"},
    # Presentation states
    {"Blending Softcopy Presentation State", "PR"},
    {"Color Softcopy Presentation State", "PR"},
    {"Grayscale Softcopy Presentation State", "PR"},
    {"Pseudo-Color Softcopy Presentation State", "PR"},
    {"Advanced Blending Presentation State", "PR"},
    {"Compositing Planar MPR Volumetric Presentation State", "PR"},
    {"Volume Rendering Volumetric Presentation State", "PR"},
    {"Softcopy Presentation State", "PR"},
    {"Presentation State", "PR"},
    # Structured data
    {"Key Object Selection Document", "KO"},
    {"Segmentation", "SEG"},
    {"Surface Segmentation", "SEG"},
    {"Parametric Map", "OT"},
    {"Surface Scan Mesh", "M3D"},
    {"Surface Scan Point Cloud", "M3D"},
    {"Tractography Results", "OT"},
    # Waveforms
    {"12-Lead ECG Waveform", "ECG"},
    {"General ECG Waveform", "ECG"},
    {"Ambulatory ECG Waveform", "ECG"},
    {"Hemodynamic Waveform", "HD"},
    {"Cardiac Electrophysiology Waveform", "EPS"},
    {"Basic Voice Audio Waveform", "AU"},
    {"General Audio Waveform", "AU"},
    {"Arterial Pulse Waveform", "HD"},
    {"Respiratory Waveform", "RESP"},
    {"Multi-channel Respiratory Waveform", "RESP"},
    {"Routine Scalp Electroencephalogram Waveform", "EEG"},
    {"Electromyogram Waveform", "EMG"},
    {"Electrooculogram Waveform", "EOG"},
    {"Sleep Electroencephalogram Waveform", "EEG"},
    {"Body Position Waveform", "OT"},
    # Spatial data
    {"Spatial Registration", "REG"},
    {"Spatial Fiducials", "FID"},
    {"Deformable Spatial Registration", "REG"},
    # Misc
    {"Real World Value Mapping", "OT"},
    {"Raw Data", "OT"},
    {"Stereometric Relationship", "SMR"},
    {"Content Assessment Results", "OT"},
    {"Robotic-Arm Radiation", "RTPLAN"},
    {"Microscopy Bulk Simple Annotations", "ANN"},
    {"Confocal Microscopy", "CFM"},
    {"Photoacoustic", "PA"},
    {"Inventory", "OT"}
  ]

  @impl Mix.Task
  def run(_args) do
    storage_path = "priv/sops.json"
    service_path = "priv/service_sop_classes.exs"

    unless File.exists?(storage_path) do
      Mix.raise("#{storage_path} not found. Download from innolitics/dicom-standard.")
    end

    unless File.exists?(service_path) do
      Mix.raise("#{service_path} not found.")
    end

    Mix.shell().info("Reading #{storage_path}...")
    storage_entries = storage_path |> File.read!() |> :json.decode() |> parse_storage_entries()

    Mix.shell().info("Reading #{service_path}...")
    {service_entries, _} = Code.eval_file(service_path)
    service_entries = parse_service_entries(service_entries)

    all_entries = merge_entries(storage_entries, service_entries)

    Mix.shell().info(
      "Total: #{length(all_entries)} SOP classes " <>
        "(#{length(storage_entries)} storage + #{length(service_entries)} service)"
    )

    source = generate_source(all_entries)
    File.write!(@output_path, source)
    Mix.shell().info("Written to #{@output_path}")
    Mix.shell().info("Run `mix format #{@output_path}` to format.")
  end

  # ── Parse storage entries from sops.json ──────────────────────

  defp parse_storage_entries(json_entries) do
    Enum.map(json_entries, fn %{"id" => uid, "name" => name} ->
      retired = retired?(uid, name)
      modality = derive_modality(name)

      %{uid: uid, name: name, type: :storage, modality: modality, retired: retired}
    end)
  end

  # ── Parse service entries from .exs ───────────────────────────

  defp parse_service_entries(entries) do
    Enum.map(entries, fn {uid, name, type} ->
      retired = String.contains?(name, "(Retired)")

      %{uid: uid, name: name, type: type, modality: nil, retired: retired}
    end)
  end

  # ── Merge and deduplicate ─────────────────────────────────────

  defp merge_entries(storage, service) do
    storage_uids = MapSet.new(storage, & &1.uid)

    # Service entries that don't overlap with storage
    unique_service = Enum.reject(service, fn entry -> MapSet.member?(storage_uids, entry.uid) end)

    (storage ++ unique_service)
    |> Enum.sort_by(& &1.uid)
  end

  # ── Retired detection ─────────────────────────────────────────

  defp retired?(uid, name) do
    MapSet.member?(@retired_uids, uid) or String.contains?(name, "(Retired)")
  end

  # ── Modality derivation ───────────────────────────────────────

  defp derive_modality(name) do
    Enum.find_value(@modality_patterns, fn {pattern, modality} ->
      if String.contains?(name, pattern), do: modality
    end)
  end

  # ── Source generation ─────────────────────────────────────────

  defp generate_source(entries) do
    registry_entries =
      entries
      |> Enum.map(&format_entry/1)
      |> Enum.join(",\n")

    storage_count = Enum.count(entries, fn e -> e.type == :storage end)
    service_count = length(entries) - storage_count
    total = length(entries)

    """
    defmodule Dicom.SOPClass do
      @moduledoc \"\"\"
      DICOM SOP Class registry.

      Provides compile-time lookup of all #{total} DICOM SOP Classes
      (#{storage_count} storage + #{service_count} service/query/print/etc.).

      Each SOP class has a struct with uid, name, type, modality, and retired status.
      All lookups are O(1) via compile-time maps and MapSets.

      Generated via `mix dicom.gen_sop_classes` from:
      - `priv/sops.json` (innolitics/dicom-standard)
      - `priv/service_sop_classes.exs` (hand-maintained)

      Reference: DICOM PS3.4.
      \"\"\"

      @type sop_type ::
              :storage
              | :query_retrieve
              | :verification
              | :print
              | :worklist
              | :media
              | :protocol
              | :service

      @type t :: %__MODULE__{
              uid: String.t(),
              name: String.t(),
              type: sop_type(),
              modality: String.t() | nil,
              retired: boolean()
            }

      defstruct [:uid, :name, :type, :modality, retired: false]

      @registry %{
    #{registry_entries}
      }

      @all_classes Map.values(@registry)
      @active_classes Enum.filter(@all_classes, &(not &1.retired))
      @storage_classes Enum.filter(@all_classes, &(&1.type == :storage))
      @storage_uids MapSet.new(@storage_classes, & &1.uid)

      @by_type Enum.group_by(@all_classes, & &1.type)
      @by_modality @all_classes
                   |> Enum.filter(& &1.modality)
                   |> Enum.group_by(& &1.modality)

      @doc "Returns the SOP class for the given UID."
      @spec from_uid(String.t()) :: {:ok, t()} | {:error, :unknown_sop_class}
      def from_uid(uid) do
        case Map.get(@registry, uid) do
          nil -> {:error, :unknown_sop_class}
          sop -> {:ok, sop}
        end
      end

      @doc "Returns true if the UID is a known SOP class."
      @spec known?(String.t()) :: boolean()
      def known?(uid), do: Map.has_key?(@registry, uid)

      @doc "Returns all registered SOP classes."
      @spec all() :: [t()]
      def all, do: @all_classes

      @doc "Returns only active (non-retired) SOP classes."
      @spec active() :: [t()]
      def active, do: @active_classes

      @doc "Returns all storage SOP classes."
      @spec storage() :: [t()]
      def storage, do: @storage_classes

      @doc "Returns SOP classes of the given type."
      @spec by_type(sop_type()) :: [t()]
      def by_type(type), do: Map.get(@by_type, type, [])

      @doc "Returns storage SOP classes for the given DICOM modality code."
      @spec by_modality(String.t()) :: [t()]
      def by_modality(modality), do: Map.get(@by_modality, modality, [])

      @doc "Returns true if the UID is a storage SOP class. O(1) MapSet lookup."
      @spec storage?(String.t()) :: boolean()
      def storage?(uid), do: MapSet.member?(@storage_uids, uid)

      @doc "Returns true if the UID is a retired SOP class."
      @spec retired?(String.t()) :: boolean()
      def retired?(uid) do
        case from_uid(uid) do
          {:ok, %{retired: retired}} -> retired
          _ -> false
        end
      end

      @doc "Returns the human-readable name of the SOP class."
      @spec name(String.t()) :: {:ok, String.t()} | {:error, :unknown_sop_class}
      def name(uid) do
        case from_uid(uid) do
          {:ok, %{name: name}} -> {:ok, name}
          error -> error
        end
      end
    end
    """
  end

  defp format_entry(%{uid: uid, name: name, type: type, modality: modality, retired: retired}) do
    modality_str = if modality, do: inspect(modality), else: "nil"

    "    #{inspect(uid)} => %{__struct__: __MODULE__, uid: #{inspect(uid)}, " <>
      "name: #{inspect(name)}, type: #{inspect(type)}, " <>
      "modality: #{modality_str}, retired: #{inspect(retired)}}"
  end
end
