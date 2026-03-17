# Non-storage DICOM SOP Classes
# Hand-maintained from DICOM PS3.4 Table B.5-1 and related annexes.
# Format: {uid, name, type}
# Types: :verification, :query_retrieve, :worklist, :print, :media,
#        :protocol, :service, :ups, :substance_admin
[
  # ── Verification ────────────────────────────────────────────────
  {"1.2.840.10008.1.1", "Verification SOP Class", :verification},

  # ── Storage Commitment ──────────────────────────────────────────
  {"1.2.840.10008.1.20.1", "Storage Commitment Push Model SOP Class", :service},
  {"1.2.840.10008.1.20.2", "Storage Commitment Pull Model SOP Class (Retired)", :service},

  # ── Query/Retrieve — Patient Root ───────────────────────────────
  {"1.2.840.10008.5.1.4.1.2.1.1", "Patient Root Query/Retrieve Information Model - FIND", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.1.2", "Patient Root Query/Retrieve Information Model - MOVE", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.1.3", "Patient Root Query/Retrieve Information Model - GET", :query_retrieve},

  # ── Query/Retrieve — Study Root ─────────────────────────────────
  {"1.2.840.10008.5.1.4.1.2.2.1", "Study Root Query/Retrieve Information Model - FIND", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.2.2", "Study Root Query/Retrieve Information Model - MOVE", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.2.3", "Study Root Query/Retrieve Information Model - GET", :query_retrieve},

  # ── Query/Retrieve — Patient/Study Only (Retired) ───────────────
  {"1.2.840.10008.5.1.4.1.2.3.1", "Patient/Study Only Query/Retrieve Information Model - FIND (Retired)", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.3.2", "Patient/Study Only Query/Retrieve Information Model - MOVE (Retired)", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.3.3", "Patient/Study Only Query/Retrieve Information Model - GET (Retired)", :query_retrieve},

  # ── Composite Instance Retrieve ─────────────────────────────────
  {"1.2.840.10008.5.1.4.1.2.4.2", "Composite Instance Root Retrieve - MOVE", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.4.3", "Composite Instance Root Retrieve - GET", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.2.5.3", "Composite Instance Retrieve Without Bulk Data - GET", :query_retrieve},

  # ── Modality Worklist ───────────────────────────────────────────
  {"1.2.840.10008.5.1.4.31", "Modality Worklist Information Model - FIND", :worklist},

  # ── General Purpose Worklist (Retired) ──────────────────────────
  {"1.2.840.10008.5.1.4.32.1", "General Purpose Worklist Information Model - FIND (Retired)", :worklist},

  # ── MPPS ────────────────────────────────────────────────────────
  {"1.2.840.10008.3.1.2.3.3", "Modality Performed Procedure Step SOP Class", :service},
  {"1.2.840.10008.3.1.2.3.4", "Modality Performed Procedure Step Retrieve SOP Class", :service},
  {"1.2.840.10008.3.1.2.3.5", "Modality Performed Procedure Step Notification SOP Class", :service},

  # ── Print Management ────────────────────────────────────────────
  {"1.2.840.10008.5.1.1.1", "Basic Film Session SOP Class", :print},
  {"1.2.840.10008.5.1.1.2", "Basic Film Box SOP Class", :print},
  {"1.2.840.10008.5.1.1.4", "Basic Grayscale Image Box SOP Class", :print},
  {"1.2.840.10008.5.1.1.4.1", "Basic Color Image Box SOP Class", :print},
  {"1.2.840.10008.5.1.1.14", "Print Job SOP Class", :print},
  {"1.2.840.10008.5.1.1.15", "Basic Annotation Box SOP Class", :print},
  {"1.2.840.10008.5.1.1.16", "Printer SOP Class", :print},
  {"1.2.840.10008.5.1.1.16.376", "Printer Configuration Retrieval SOP Class", :print},
  {"1.2.840.10008.5.1.1.9", "Basic Grayscale Print Management Meta SOP Class", :print},
  {"1.2.840.10008.5.1.1.18", "Basic Color Print Management Meta SOP Class", :print},
  {"1.2.840.10008.5.1.1.29", "Presentation LUT SOP Class", :print},

  # ── Media ───────────────────────────────────────────────────────
  {"1.2.840.10008.1.3.10", "Media Storage Directory Storage", :media},

  # ── Instance Availability Notification ──────────────────────────
  {"1.2.840.10008.5.1.4.33", "Instance Availability Notification SOP Class", :service},

  # ── Unified Procedure Step (UPS) ────────────────────────────────
  {"1.2.840.10008.5.1.4.34.6.1", "UPS Push SOP Class", :service},
  {"1.2.840.10008.5.1.4.34.6.2", "UPS Watch SOP Class", :service},
  {"1.2.840.10008.5.1.4.34.6.3", "UPS Pull SOP Class", :service},
  {"1.2.840.10008.5.1.4.34.6.4", "UPS Event SOP Class", :service},
  {"1.2.840.10008.5.1.4.34.6.5", "UPS Query SOP Class", :service},

  # ── Substance Administration ────────────────────────────────────
  {"1.2.840.10008.5.1.4.41", "Product Characteristics Query SOP Class", :service},
  {"1.2.840.10008.5.1.4.42", "Substance Approval Query SOP Class", :service},

  # ── Relevant Patient Information Query ──────────────────────────
  {"1.2.840.10008.5.1.4.37.1", "General Relevant Patient Information Query", :query_retrieve},
  {"1.2.840.10008.5.1.4.37.2", "Breast Imaging Relevant Patient Information Query", :query_retrieve},
  {"1.2.840.10008.5.1.4.37.3", "Cardiac Relevant Patient Information Query", :query_retrieve},

  # ── Protocol Management ─────────────────────────────────────────
  {"1.2.840.10008.5.1.4.1.1.200.8", "Defined Procedure Protocol Information Model - FIND", :protocol},
  {"1.2.840.10008.5.1.4.1.1.200.9", "Defined Procedure Protocol Information Model - MOVE", :protocol},
  {"1.2.840.10008.5.1.4.1.1.200.10", "Defined Procedure Protocol Information Model - GET", :protocol},

  # ── Inventory ───────────────────────────────────────────────────
  {"1.2.840.10008.5.1.4.1.1.201.2", "Inventory - FIND", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.1.201.3", "Inventory - MOVE", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.1.201.4", "Inventory - GET", :query_retrieve},
  {"1.2.840.10008.5.1.4.1.1.201.6", "Inventory Creation", :service},

  # ── Display System ──────────────────────────────────────────────
  {"1.2.840.10008.5.1.1.40", "Display System SOP Class", :service},

  # ── Retired Storage SOP Classes (not in innolitics sops.json) ──
  {"1.2.840.10008.5.1.4.1.1.5", "Nuclear Medicine Image Storage (Retired)", :storage},
  {"1.2.840.10008.5.1.4.1.1.6", "Ultrasound Image Storage (Retired)", :storage},
  {"1.2.840.10008.5.1.4.1.1.3", "Ultrasound Multi-frame Image Storage (Retired)", :storage},
  {"1.2.840.10008.5.1.4.1.1.9", "Standalone Curve Storage (Retired)", :storage},
  {"1.2.840.10008.5.1.4.1.1.10", "Standalone Modality LUT Storage (Retired)", :storage},
  {"1.2.840.10008.5.1.4.1.1.11", "Standalone VOI LUT Storage (Retired)", :storage},
  {"1.2.840.10008.5.1.4.1.1.12.3", "X-Ray Angiographic Bi-Plane Image Storage (Retired)", :storage},
  {"1.2.840.10008.5.1.4.1.1.129", "Standalone PET Curve Storage (Retired)", :storage}
]
