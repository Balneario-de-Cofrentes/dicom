# DICOM PS3.16 SR Template Conformance Plan

## Overview

Full implementation roadmap for all DICOM Structured Report templates defined in PS3.16.
Authoritative source: https://dicom.nema.org/medical/dicom/current/output/chtml/part16/chapter_A.html

## Implementation Status

### Root Templates (33 total)

| TID | Name | Domain | Status | Priority |
|-----|------|--------|--------|----------|
| 1500 | Measurement Report | General Imaging | DONE | - |
| 2000 | Key Object Selection | General | DONE | - |
| 2010 | Basic Diagnostic Imaging Report | General | DONE (alias of 2000) | - |
| 3300 | Stress Testing Report | Cardiology | DONE | - |
| 3700 | ECG Report | Cardiology | DONE | - |
| 2005 | Transcribed Diagnostic Imaging Report | General | TODO | T1 |
| 2006 | Imaging Report + Radiation Exposure | General | TODO | T1 |
| 3001 | Procedure Log | Interventional | TODO | T1 |
| 3750 | Waveform Annotations | Cardiology | TODO | T1 |
| 3250 | IVUS Report | Cardiology | TODO | T2 |
| 3500 | Hemodynamics Report | Cardiology | TODO | T2 |
| 3800 | Cardiac Catheterization Report | Cardiology | TODO | T2 |
| 3900 | CT/MR Cardiovascular Analysis Report | Cardiac Imaging | TODO | T2 |
| 4200 | Breast Imaging Report | Breast | TODO | T2 |
| 4300 | Prostate Multiparametric MR Report | Prostate | TODO | T2 |
| 5000 | OB-GYN Ultrasound Procedure Report | OB-GYN | TODO | T2 |
| 5100 | Vascular Ultrasound Report | Vascular | TODO | T2 |
| 5200 | Echocardiography Procedure Report | Cardiology | TODO | T2 |
| 12000 | General Ultrasound Report | Ultrasound | TODO | T2 |
| 4000 | Mammography CAD Document Root | CAD | TODO | T3 |
| 4100 | Chest CAD Document Root | CAD | TODO | T3 |
| 4120 | Colon CAD Document Root | CAD | TODO | T3 |
| 5220 | Pediatric/Fetal Cardiac US Reports | Cardiology | TODO | T3 |
| 5300 | Simplified Echo Procedure Report | Cardiology | TODO | T3 |
| 5320 | Structural Heart Measurement Report | Cardiology | TODO | T3 |
| 10001 | Projection X-Ray Radiation Dose | Dose | TODO | T3 |
| 10011 | CT Radiation Dose | Dose | TODO | T3 |
| 10021 | Radiopharmaceutical Radiation Dose | Dose | TODO | T3 |
| 10030 | Patient Radiation Dose | Dose | TODO | T3 |
| 10040 | Enhanced X-Ray Radiation Dose | Dose | TODO | T3 |
| 11001 | Planned Imaging Agent Administration | Agent | TODO | T3 |
| 11020 | Performed Imaging Agent Administration | Agent | TODO | T3 |
| 2020 | Spectacle Prescription Report | Ophthalmology | TODO | T4 |
| 2100 | Macular Grid Thickness/Volume Report | Ophthalmology | TODO | T4 |
| 7000 | Implantation Plan | Orthopedic | TODO | T4 |
| 8101 | Preclinical Small Animal Acq Context | Preclinical | TODO | T4 |

### Implementation Streams

#### Stream 1: Diagnostic Imaging Reports (T1)
- **Templates**: TID 2005, 2006
- **Complexity**: Low (text-based reports, minimal sub-templates)
- **Dependencies**: Existing Observer, Document modules sufficient
- **New codes needed**: ~10-15
- **PS3.16 refs**: sect_TID_2005, sect_TID_2006

#### Stream 2: Procedure Log (T1)
- **Templates**: TID 3001 + sub-templates 3010, 3100-3115
- **Complexity**: Medium (event-based structure, many sub-template types)
- **Dependencies**: New procedure action helpers needed
- **New codes needed**: ~30-40
- **PS3.16 refs**: sect_TID_3001

#### Stream 3: Waveform Annotations (T1)
- **Templates**: TID 3750 + sub-templates 3751-3757
- **Complexity**: Medium (waveform-specific patterns)
- **Dependencies**: Temporal coordinate support
- **New codes needed**: ~15-20
- **PS3.16 refs**: sect_TID_3750

#### Stream 4: Cardiology Deep (T2)
- **Templates**: TID 3250 (IVUS), 3500 (Hemodynamics), 3800 (Cath Report)
- **Complexity**: High (extensive sub-template hierarchies)
- **Dependencies**: Hemodynamic measurement helpers, pressure waveform support
- **New codes needed**: ~100+
- **PS3.16 refs**: sect_TID_3250, sect_TID_3500, sect_TID_3800

#### Stream 5: Cardiovascular CT/MR (T2)
- **Templates**: TID 3900 + sub-templates 3901-3990
- **Complexity**: High (calcium scoring, vascular analysis, ventricular analysis)
- **Dependencies**: Vascular/ventricular measurement helpers
- **New codes needed**: ~60-80
- **PS3.16 refs**: sect_TID_3900

#### Stream 6: Breast & Prostate Imaging (T2)
- **Templates**: TID 4200, 4300 + sub-templates
- **Complexity**: Medium (BI-RADS/PI-RADS scoring, structured findings)
- **Dependencies**: Assessment category helpers
- **New codes needed**: ~40-50
- **PS3.16 refs**: sect_TID_4200, sect_TID_4300

#### Stream 7: OB-GYN Ultrasound (T2)
- **Templates**: TID 5000 + sub-templates 5001-5030
- **Complexity**: High (fetal biometry, BPP, multiple sections)
- **Dependencies**: Biometry measurement helpers, gestational age calculations
- **New codes needed**: ~60-80
- **PS3.16 refs**: sect_TID_5000

#### Stream 8: Vascular & General Ultrasound (T2)
- **Templates**: TID 5100, 12000 + sub-templates
- **Complexity**: Medium
- **Dependencies**: Vascular measurement helpers
- **New codes needed**: ~30-40
- **PS3.16 refs**: sect_TID_5100, sect_TID_12000

#### Stream 9: Echocardiography (T2-T3)
- **Templates**: TID 5200, 5220, 5300, 5320 + sub-templates
- **Complexity**: Very High (wall motion, strain, pediatric/fetal)
- **Dependencies**: Echo measurement helpers, wall motion segment model
- **New codes needed**: ~80-100
- **PS3.16 refs**: sect_TID_5200, sect_TID_5220, sect_TID_5300

#### Stream 10: CAD Documents (T3)
- **Templates**: TID 4000, 4100, 4120 + sub-templates
- **Complexity**: High (algorithm identification, operating points, CAD findings)
- **Dependencies**: CAD algorithm helpers, detection/analysis performers
- **New codes needed**: ~60-80
- **PS3.16 refs**: sect_TID_4000, sect_TID_4100, sect_TID_4120

#### Stream 11: Radiation Dose (T3)
- **Templates**: TID 10001, 10011, 10021, 10030, 10040 + sub-templates
- **Complexity**: Very High (5 root templates, ~35 sub-templates)
- **Dependencies**: Dose accumulation, irradiation event helpers
- **New codes needed**: ~100+
- **PS3.16 refs**: sect_TID_10001, sect_TID_10011, sect_TID_10021

#### Stream 12: Imaging Agent Administration (T3)
- **Templates**: TID 11001, 11020 + sub-templates
- **Complexity**: Medium
- **Dependencies**: Agent information, administration step helpers
- **New codes needed**: ~30-40
- **PS3.16 refs**: sect_TID_11001, sect_TID_11020

#### Stream 13: Ophthalmology (T4)
- **Templates**: TID 2020, 2100 + sub-templates
- **Complexity**: Medium (specialty measurements)
- **Dependencies**: Ophthalmic measurement helpers
- **New codes needed**: ~30-40
- **PS3.16 refs**: sect_TID_2020, sect_TID_2100

#### Stream 14: Niche (T4)
- **Templates**: TID 7000, 8101
- **Complexity**: Medium
- **Dependencies**: Implant/preclinical-specific helpers
- **New codes needed**: ~20-30
- **PS3.16 refs**: sect_TID_7000, sect_TID_8101

### Key Sub-Template Groups (Shared Foundation)

These sub-templates are reused across multiple root templates and should be
validated/enhanced as part of the foundation work:

| TID Range | Name | Used By | Current Status |
|-----------|------|---------|----------------|
| 300-400 | Measurement/Reference | Most templates | Partially covered by Measurement module |
| 1001-1021 | Observation Context | All root templates | Covered by Observer module |
| 1200-1211 | Language | All root templates | Covered by Observer.language/1 |
| 1400-1420 | Measurement Types | TID 1500 and derivatives | Covered by MeasurementGroup |
| 1501-1502 | Measurement Group | TID 1500 | Covered by MeasurementGroup |
| 1600-1608 | Image Library | TID 1500, imaging reports | Covered by ImageLibrary module |

### Architecture Notes

**Pattern for each template builder:**
1. Module at `lib/dicom/sr/templates/<snake_name>.ex`
2. `new/1` function taking keyword options
3. Required fields via `Keyword.fetch!`, optional via `Keyword.get`
4. Root children built via list accumulation + `add_optional/2`
5. Wrapped in `ContentItem.container` + `Document.new`
6. New codes added to `codes.ex`
7. Tests in `test/dicom/sr_test.exs` or dedicated test files

**Shared resource coordination:**
- `codes.ex` is the main shared file — each stream adds domain-specific codes
- When working in parallel worktrees, codes are merged post-implementation
- Each template module is fully independent (no cross-template dependencies)

### Statistics

- **Total root templates in standard**: 33
- **Currently implemented**: 4 (12%)
- **Remaining**: 29
- **Total sub-templates**: ~280
- **Estimated new codes needed**: ~600-800
- **Target**: 100% root template coverage
