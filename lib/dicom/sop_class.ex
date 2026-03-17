defmodule Dicom.SopClass do
  @moduledoc """
  DICOM SOP Class registry.

  Provides compile-time lookup of all 232 DICOM SOP Classes
  (183 storage + 49 service/query/print/etc.).

  Each SOP class has a struct with uid, name, type, modality, and retired status.
  All lookups are O(1) via compile-time maps and MapSets.

  Generated via `mix dicom.gen_sop_classes` from:
  - `priv/sops.json` (innolitics/dicom-standard)
  - `priv/service_sop_classes.exs` (hand-maintained)

  Reference: DICOM PS3.4.
  """

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
    "1.2.840.10008.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.1.1",
      name: "Verification SOP Class",
      type: :verification,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.1.20.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.1.20.1",
      name: "Storage Commitment Push Model SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.1.20.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.1.20.2",
      name: "Storage Commitment Pull Model SOP Class (Retired)",
      type: :service,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.1.3.10" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.1.3.10",
      name: "Media Storage Directory Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.3.1.2.3.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.3.1.2.3.3",
      name: "Modality Performed Procedure Step SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.3.1.2.3.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.3.1.2.3.4",
      name: "Modality Performed Procedure Step Retrieve SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.3.1.2.3.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.3.1.2.3.5",
      name: "Modality Performed Procedure Step Notification SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.1",
      name: "Basic Film Session SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.14" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.14",
      name: "Print Job SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.15" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.15",
      name: "Basic Annotation Box SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.16" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.16",
      name: "Printer SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.16.376" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.16.376",
      name: "Printer Configuration Retrieval SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.18" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.18",
      name: "Basic Color Print Management Meta SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.2",
      name: "Basic Film Box SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.29" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.29",
      name: "Presentation LUT SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.4",
      name: "Basic Grayscale Image Box SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.4.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.4.1",
      name: "Basic Color Image Box SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.40" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.40",
      name: "Display System SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.1.9" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.1.9",
      name: "Basic Grayscale Print Management Meta SOP Class",
      type: :print,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.1",
      name: "Computed Radiography Image Storage",
      type: :storage,
      modality: "CR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.1.1",
      name: "Digital X-Ray Image Storage - For Presentation",
      type: :storage,
      modality: "DX",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.1.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.1.1.1",
      name: "Digital X-Ray Image Storage - For Processing",
      type: :storage,
      modality: "DX",
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.1.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.1.2",
      name: "Digital Mammography X-Ray Image Storage - For Presentation",
      type: :storage,
      modality: "MG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.1.2.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.1.2.1",
      name: "Digital Mammography X-Ray Image Storage - For Processing",
      type: :storage,
      modality: "MG",
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.1.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.1.3",
      name: "Digital Intra-Oral X-Ray Image Storage - For Presentation",
      type: :storage,
      modality: "IO",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.1.3.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.1.3.1",
      name: "Digital Intra-Oral X-Ray Image Storage - For Processing",
      type: :storage,
      modality: "IO",
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.10" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.10",
      name: "Standalone Modality LUT Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.104.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.104.1",
      name: "Encapsulated PDF Storage",
      type: :storage,
      modality: "DOC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.104.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.104.2",
      name: "Encapsulated CDA Storage",
      type: :storage,
      modality: "DOC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.104.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.104.3",
      name: "Encapsulated STL Storage",
      type: :storage,
      modality: "M3D",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.104.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.104.4",
      name: "Encapsulated OBJ Storage",
      type: :storage,
      modality: "M3D",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.104.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.104.5",
      name: "Encapsulated MTL Storage",
      type: :storage,
      modality: "M3D",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11",
      name: "Standalone VOI LUT Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.11.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.1",
      name: "Grayscale Softcopy Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.10" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.10",
      name: "Segmented Volume Rendering Volumetric Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.11" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.11",
      name: "Multiple Volume Rendering Volumetric Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.12" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.12",
      name: "Variable Modality LUT Softcopy Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.2",
      name: "Color Softcopy Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.3",
      name: "Pseudo-Color Softcopy Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.4",
      name: "Blending Softcopy Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.5",
      name: "XA/XRF Grayscale Softcopy Presentation State Storage",
      type: :storage,
      modality: "XA",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.6",
      name: "Grayscale Planar MPR Volumetric Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.7",
      name: "Compositing Planar MPR Volumetric Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.8" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.8",
      name: "Advanced Blending Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.11.9" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.11.9",
      name: "Volume Rendering Volumetric Presentation State Storage",
      type: :storage,
      modality: "PR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.12.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.12.1",
      name: "X-Ray Angiographic Image Storage",
      type: :storage,
      modality: "XA",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.12.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.12.1.1",
      name: "Enhanced XA Image Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.12.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.12.2",
      name: "X-Ray Radiofluoroscopic Image Storage",
      type: :storage,
      modality: "RF",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.12.2.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.12.2.1",
      name: "Enhanced XRF Image Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.12.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.12.3",
      name: "X-Ray Angiographic Bi-Plane Image Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.128" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.128",
      name: "Positron Emission Tomography Image Storage",
      type: :storage,
      modality: "PT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.128.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.128.1",
      name: "Legacy Converted Enhanced PET Image Storage",
      type: :storage,
      modality: "PT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.129" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.129",
      name: "Standalone PET Curve Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.13.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.13.1.1",
      name: "X-Ray 3D Angiographic Image Storage",
      type: :storage,
      modality: "XA",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.13.1.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.13.1.2",
      name: "X-Ray 3D Craniofacial Image Storage",
      type: :storage,
      modality: "DX",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.13.1.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.13.1.3",
      name: "Breast Tomosynthesis Image Storage",
      type: :storage,
      modality: "MG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.13.1.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.13.1.4",
      name: "Breast Projection X-Ray Image Storage - For Presentation",
      type: :storage,
      modality: "MG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.13.1.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.13.1.5",
      name: "Breast Projection X-Ray Image Storage - For Processing",
      type: :storage,
      modality: "MG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.130" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.130",
      name: "Enhanced PET Image Storage",
      type: :storage,
      modality: "PT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.131" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.131",
      name: "Basic Structured Display Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.14.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.14.1",
      name: "Intravascular Optical Coherence Tomography Image Storage - For Presentation",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.14.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.14.2",
      name: "Intravascular Optical Coherence Tomography Image Storage - For Processing",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.2",
      name: "CT Image Storage",
      type: :storage,
      modality: "CT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.2.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.2.1",
      name: "Enhanced CT Image Storage",
      type: :storage,
      modality: "CT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.2.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.2.2",
      name: "Legacy Converted Enhanced CT Image Storage",
      type: :storage,
      modality: "CT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.20" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.20",
      name: "Nuclear Medicine Image Storage",
      type: :storage,
      modality: "NM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.200.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.200.1",
      name: "CT Defined Procedure Protocol Storage",
      type: :storage,
      modality: "CT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.200.10" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.200.10",
      name: "Defined Procedure Protocol Information Model - GET",
      type: :protocol,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.200.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.200.2",
      name: "CT Performed Procedure Protocol Storage",
      type: :storage,
      modality: "CT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.200.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.200.3",
      name: "Protocol Approval Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.200.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.200.7",
      name: "XA Defined Procedure Protocol Storage",
      type: :storage,
      modality: "XA",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.200.8" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.200.8",
      name: "XA Performed Procedure Protocol Storage",
      type: :storage,
      modality: "XA",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.200.9" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.200.9",
      name: "Defined Procedure Protocol Information Model - MOVE",
      type: :protocol,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.201.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.201.1",
      name: "Inventory Storage",
      type: :storage,
      modality: "OT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.201.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.201.2",
      name: "Inventory - FIND",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.201.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.201.3",
      name: "Inventory - MOVE",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.201.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.201.4",
      name: "Inventory - GET",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.201.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.201.6",
      name: "Inventory Creation",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.3",
      name: "Ultrasound Multi-frame Image Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.3.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.3.1",
      name: "Ultrasound Multi-frame Image Storage",
      type: :storage,
      modality: "US",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.30" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.30",
      name: "Parametric Map Storage",
      type: :storage,
      modality: "OT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.4",
      name: "MR Image Storage",
      type: :storage,
      modality: "MR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.4.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.4.1",
      name: "Enhanced MR Image Storage",
      type: :storage,
      modality: "MR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.4.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.4.2",
      name: "MR Spectroscopy Storage",
      type: :storage,
      modality: "MR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.4.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.4.3",
      name: "Enhanced MR Color Image Storage",
      type: :storage,
      modality: "MR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.4.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.4.4",
      name: "Legacy Converted Enhanced MR Image Storage",
      type: :storage,
      modality: "MR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.1",
      name: "RT Image Storage",
      type: :storage,
      modality: "RTIMAGE",
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.481.10" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.10",
      name: "RT Physician Intent Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.11" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.11",
      name: "RT Segment Annotation Storage",
      type: :storage,
      modality: "RTSTRUCT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.12" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.12",
      name: "RT Radiation Set Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.13" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.13",
      name: "C-Arm Photon-Electron Radiation Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.14" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.14",
      name: "Tomotherapeutic Radiation Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.15" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.15",
      name: "Robotic-Arm Radiation Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.16" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.16",
      name: "RT Radiation Record Set Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.17" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.17",
      name: "RT Radiation Salvage Record Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.18" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.18",
      name: "Tomotherapeutic Radiation Record Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.19" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.19",
      name: "C-Arm Photon-Electron Radiation Record Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.2",
      name: "RT Dose Storage",
      type: :storage,
      modality: "RTDOSE",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.20" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.20",
      name: "Robotic Radiation Record Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.21" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.21",
      name: "RT Radiation Set Delivery Instruction Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.22" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.22",
      name: "RT Treatment Preparation Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.23" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.23",
      name: "Enhanced RT Image Storage",
      type: :storage,
      modality: "RTIMAGE",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.24" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.24",
      name: "Enhanced Continuous RT Image Storage",
      type: :storage,
      modality: "RTIMAGE",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.25" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.25",
      name: "RT Patient Position Acquisition Instruction Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.3",
      name: "RT Structure Set Storage",
      type: :storage,
      modality: "RTSTRUCT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.4",
      name: "RT Beams Treatment Record Storage",
      type: :storage,
      modality: "RTRECORD",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.5",
      name: "RT Plan Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.6",
      name: "RT Brachy Treatment Record Storage",
      type: :storage,
      modality: "RTRECORD",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.7",
      name: "RT Treatment Summary Record Storage",
      type: :storage,
      modality: "RTRECORD",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.8" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.8",
      name: "RT Ion Plan Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.481.9" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.481.9",
      name: "RT Ion Beams Treatment Record Storage",
      type: :storage,
      modality: "RTRECORD",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.5",
      name: "Nuclear Medicine Image Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.6",
      name: "Ultrasound Image Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.6.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.6.1",
      name: "Ultrasound Image Storage",
      type: :storage,
      modality: "US",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.6.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.6.2",
      name: "Enhanced US Volume Storage",
      type: :storage,
      modality: "US",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.6.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.6.3",
      name: "Photoacoustic Image Storage",
      type: :storage,
      modality: "PA",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.66" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.66",
      name: "Raw Data Storage",
      type: :storage,
      modality: "OT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.66.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.66.1",
      name: "Spatial Registration Storage",
      type: :storage,
      modality: "REG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.66.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.66.2",
      name: "Spatial Fiducials Storage",
      type: :storage,
      modality: "FID",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.66.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.66.3",
      name: "Deformable Spatial Registration Storage",
      type: :storage,
      modality: "REG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.66.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.66.4",
      name: "Segmentation Storage",
      type: :storage,
      modality: "SEG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.66.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.66.5",
      name: "Surface Segmentation Storage",
      type: :storage,
      modality: "SEG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.66.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.66.6",
      name: "Tractography Results Storage",
      type: :storage,
      modality: "OT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.67" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.67",
      name: "Real World Value Mapping Storage",
      type: :storage,
      modality: "OT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.68.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.68.1",
      name: "Surface Scan Mesh Storage",
      type: :storage,
      modality: "M3D",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.68.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.68.2",
      name: "Surface Scan Point Cloud Storage",
      type: :storage,
      modality: "M3D",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.7",
      name: "Secondary Capture Image Storage",
      type: :storage,
      modality: "SC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.7.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.7.1",
      name: "Multi-frame Single Bit Secondary Capture Image Storage",
      type: :storage,
      modality: "SC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.7.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.7.2",
      name: "Multi-frame Grayscale Byte Secondary Capture Image Storage",
      type: :storage,
      modality: "SC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.7.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.7.3",
      name: "Multi-frame Grayscale Word Secondary Capture Image Storage",
      type: :storage,
      modality: "SC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.7.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.7.4",
      name: "Multi-frame True Color Secondary Capture Image Storage",
      type: :storage,
      modality: "SC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.1",
      name: "VL Endoscopic Image Storage",
      type: :storage,
      modality: "ES",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.1.1",
      name: "Video Endoscopic Image Storage",
      type: :storage,
      modality: "ES",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.2",
      name: "VL Microscopic Image Storage",
      type: :storage,
      modality: "GM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.2.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.2.1",
      name: "Video Microscopic Image Storage",
      type: :storage,
      modality: "GM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.3",
      name: "VL Slide-Coordinates Microscopic Image Storage",
      type: :storage,
      modality: "SM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.4",
      name: "VL Photographic Image Storage",
      type: :storage,
      modality: "XC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.4.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.4.1",
      name: "Video Photographic Image Storage",
      type: :storage,
      modality: "XC",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.1",
      name: "Ophthalmic Photography 8 Bit Image Storage",
      type: :storage,
      modality: "OP",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.2",
      name: "Ophthalmic Photography 16 Bit Image Storage",
      type: :storage,
      modality: "OP",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.3",
      name: "Stereometric Relationship Storage",
      type: :storage,
      modality: "SMR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.4",
      name: "Ophthalmic Tomography Image Storage",
      type: :storage,
      modality: "OPT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.5",
      name: "Wide Field Ophthalmic Photography Stereographic Projection Image Storage",
      type: :storage,
      modality: "OP",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.6",
      name: "Wide Field Ophthalmic Photography 3D Coordinates Image Storage",
      type: :storage,
      modality: "OP",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.7",
      name: "Ophthalmic Optical Coherence Tomography En Face Image Storage",
      type: :storage,
      modality: "OPT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.5.8" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.5.8",
      name: "Ophthalmic Optical Coherence Tomography B-scan Volume Analysis Storage",
      type: :storage,
      modality: "OPT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.6",
      name: "VL Whole Slide Microscopy Image Storage",
      type: :storage,
      modality: "SM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.7",
      name: "Dermoscopic Photography Image Storage",
      type: :storage,
      modality: "DMS",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.8" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.8",
      name: "Confocal Microscopy Image Storage",
      type: :storage,
      modality: "CFM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.77.1.9" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.77.1.9",
      name: "Confocal Microscopy Tiled Pyramidal Image Storage",
      type: :storage,
      modality: "CFM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.1",
      name: "Lensometry Measurements Storage",
      type: :storage,
      modality: "LEN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.2",
      name: "Autorefraction Measurements Storage",
      type: :storage,
      modality: "AR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.3",
      name: "Keratometry Measurements Storage",
      type: :storage,
      modality: "KER",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.4",
      name: "Subjective Refraction Measurements Storage",
      type: :storage,
      modality: "SRF",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.5",
      name: "Visual Acuity Measurements Storage",
      type: :storage,
      modality: "VA",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.6" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.6",
      name: "Spectacle Prescription Report Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.7",
      name: "Ophthalmic Axial Measurements Storage",
      type: :storage,
      modality: "OPM",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.78.8" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.78.8",
      name: "Intraocular Lens Calculations Storage",
      type: :storage,
      modality: "IOL",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.79.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.79.1",
      name: "Macular Grid Thickness and Volume Report",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.80.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.80.1",
      name: "Ophthalmic Visual Field Static Perimetry Measurements Storage",
      type: :storage,
      modality: "OPV",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.81.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.81.1",
      name: "Ophthalmic Thickness Map Storage",
      type: :storage,
      modality: "OPT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.82.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.82.1",
      name: "Corneal Topography Map Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.11" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.11",
      name: "Basic Text SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.22" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.22",
      name: "Enhanced SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.33" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.33",
      name: "Comprehensive SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.34" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.34",
      name: "Comprehensive 3D SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.35" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.35",
      name: "Extensible SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.40" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.40",
      name: "Procedure Log Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.50" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.50",
      name: "Mammography CAD SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.59" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.59",
      name: "Key Object Selection Document Storage",
      type: :storage,
      modality: "KO",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.65" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.65",
      name: "Chest CAD SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.67" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.67",
      name: "X-Ray Radiation Dose SR Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.68" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.68",
      name: "Radiopharmaceutical Radiation Dose SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.69" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.69",
      name: "Colon CAD SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.70" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.70",
      name: "Implantation Plan SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.71" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.71",
      name: "Acquisition Context SR Storage",
      type: :storage,
      modality: "SR",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.72" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.72",
      name: "Simplified Adult Echo SR Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.73" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.73",
      name: "Patient Radiation Dose SR Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.74" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.74",
      name: "Planned Imaging Agent Administration SR Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.75" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.75",
      name: "Performed Imaging Agent Administration SR Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.88.76" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.88.76",
      name: "Enhanced X-Ray Radiation Dose SR Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9",
      name: "Standalone Curve Storage (Retired)",
      type: :storage,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.1.9.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.1.1",
      name: "12-lead ECG Waveform Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.1.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.1.2",
      name: "General ECG Waveform Storage",
      type: :storage,
      modality: "ECG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.1.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.1.3",
      name: "Ambulatory ECG Waveform Storage",
      type: :storage,
      modality: "ECG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.1.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.1.4",
      name: "General 32-bit ECG Waveform Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.2.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.2.1",
      name: "Hemodynamic Waveform Storage",
      type: :storage,
      modality: "HD",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.3.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.3.1",
      name: "Cardiac Electrophysiology Waveform Storage",
      type: :storage,
      modality: "EPS",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.4.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.4.1",
      name: "Basic Voice Audio Waveform Storage",
      type: :storage,
      modality: "AU",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.4.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.4.2",
      name: "General Audio Waveform Storage",
      type: :storage,
      modality: "AU",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.5.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.5.1",
      name: "Arterial Pulse Waveform Storage",
      type: :storage,
      modality: "HD",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.6.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.6.1",
      name: "Respiratory Waveform Storage",
      type: :storage,
      modality: "RESP",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.6.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.6.2",
      name: "Multi-channel Respiratory Waveform Storage",
      type: :storage,
      modality: "RESP",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.7.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.7.1",
      name: "Routine Scalp Electroencephalogram Waveform Storage",
      type: :storage,
      modality: "EEG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.7.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.7.2",
      name: "Electromyogram Waveform Storage",
      type: :storage,
      modality: "EMG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.7.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.7.3",
      name: "Electrooculogram Waveform Storage",
      type: :storage,
      modality: "EOG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.7.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.7.4",
      name: "Sleep Electroencephalogram Waveform Storage",
      type: :storage,
      modality: "EEG",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.9.8.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.9.8.1",
      name: "Body Position Waveform Storage",
      type: :storage,
      modality: "OT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.90.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.90.1",
      name: "Content Assessment Results Storage",
      type: :storage,
      modality: "OT",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.1.91.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.1.91.1",
      name: "Microscopy Bulk Simple Annotations Storage",
      type: :storage,
      modality: "ANN",
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.1.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.1.1",
      name: "Patient Root Query/Retrieve Information Model - FIND",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.1.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.1.2",
      name: "Patient Root Query/Retrieve Information Model - MOVE",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.1.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.1.3",
      name: "Patient Root Query/Retrieve Information Model - GET",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.2.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.2.1",
      name: "Study Root Query/Retrieve Information Model - FIND",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.2.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.2.2",
      name: "Study Root Query/Retrieve Information Model - MOVE",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.2.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.2.3",
      name: "Study Root Query/Retrieve Information Model - GET",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.3.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.3.1",
      name: "Patient/Study Only Query/Retrieve Information Model - FIND (Retired)",
      type: :query_retrieve,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.2.3.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.3.2",
      name: "Patient/Study Only Query/Retrieve Information Model - MOVE (Retired)",
      type: :query_retrieve,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.2.3.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.3.3",
      name: "Patient/Study Only Query/Retrieve Information Model - GET (Retired)",
      type: :query_retrieve,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.1.2.4.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.4.2",
      name: "Composite Instance Root Retrieve - MOVE",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.4.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.4.3",
      name: "Composite Instance Root Retrieve - GET",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.1.2.5.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.1.2.5.3",
      name: "Composite Instance Retrieve Without Bulk Data - GET",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.31" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.31",
      name: "Modality Worklist Information Model - FIND",
      type: :worklist,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.32.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.32.1",
      name: "General Purpose Worklist Information Model - FIND (Retired)",
      type: :worklist,
      modality: nil,
      retired: true
    },
    "1.2.840.10008.5.1.4.33" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.33",
      name: "Instance Availability Notification SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.34.10" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.34.10",
      name: "RT Brachy Application Setup Delivery Instruction Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.34.6.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.34.6.1",
      name: "UPS Push SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.34.6.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.34.6.2",
      name: "UPS Watch SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.34.6.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.34.6.3",
      name: "UPS Pull SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.34.6.4" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.34.6.4",
      name: "UPS Event SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.34.6.5" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.34.6.5",
      name: "UPS Query SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.34.7" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.34.7",
      name: "RT Beams Delivery Instruction Storage",
      type: :storage,
      modality: "RTPLAN",
      retired: false
    },
    "1.2.840.10008.5.1.4.37.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.37.1",
      name: "General Relevant Patient Information Query",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.37.2" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.37.2",
      name: "Breast Imaging Relevant Patient Information Query",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.37.3" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.37.3",
      name: "Cardiac Relevant Patient Information Query",
      type: :query_retrieve,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.38.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.38.1",
      name: "Hanging Protocol Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.39.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.39.1",
      name: "Color Palette Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.41" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.41",
      name: "Product Characteristics Query SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.42" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.42",
      name: "Substance Approval Query SOP Class",
      type: :service,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.43.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.43.1",
      name: "Generic Implant Template Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.44.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.44.1",
      name: "Implant Assembly Template Storage",
      type: :storage,
      modality: nil,
      retired: false
    },
    "1.2.840.10008.5.1.4.45.1" => %{
      __struct__: __MODULE__,
      uid: "1.2.840.10008.5.1.4.45.1",
      name: "Implant Template Group Storage",
      type: :storage,
      modality: nil,
      retired: false
    }
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
