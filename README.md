# Dicom

[![Hex.pm](https://img.shields.io/hexpm/v/dicom.svg)](https://hex.pm/packages/dicom)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/dicom)
[![CI](https://github.com/Balneario-de-Cofrentes/dicom/actions/workflows/ci.yml/badge.svg)](https://github.com/Balneario-de-Cofrentes/dicom/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

```
██████╗ ██╗ ██████╗ ██████╗ ███╗   ███╗
██╔══██╗██║██╔════╝██╔═══██╗████╗ ████║
██║  ██║██║██║     ██║   ██║██╔████╔██║
██║  ██║██║██║     ██║   ██║██║╚██╔╝██║
██████╔╝██║╚██████╗╚██████╔╝██║ ╚═╝ ██║
╚═════╝ ╚═╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝

  DICOM toolkit for Elixir · PS3.5/6/10/15/16/18
```

Pure Elixir DICOM toolkit for DICOM Part 10 files. Zero runtime dependencies.

## Features

- **P10 file parsing** -- read DICOM Part 10 files into structured data sets
- **P10 file writing** -- serialize data sets back to Part 10 binaries with File Meta Information
- **Streaming parser** -- lazy, event-based parsing for large files and pipelines (stable API)
- **Data dictionary** -- PS3.6 tag registry (5,035 entries) with VR, VM, keyword lookup, and retired flags
- **DICOM JSON** -- encode/decode DataSets to/from the DICOM JSON model (PS3.18 Annex F.2) for DICOMweb
- **Pixel data frames** -- extract individual frames from native and encapsulated pixel data (PS3.5 §A.4)
- **De-identification** -- PS3.15 Basic Profile helpers with consistent UID replacement and private tag control
- **Structured Reports** -- reusable PS3.16 building blocks plus focused builders for TID 1500, TID 3300, and TID 3700
- **Character set support** -- single-byte Specific Character Set repertoires and UTF-8
- **SOP Class registry** -- 232 SOP Classes with modality mapping and O(1) lookup
- **Transfer syntaxes** -- 49 tracked (34 active + 15 retired); unknown UIDs rejected by default
- **Sequences** -- defined-length and undefined-length SQ with nested items
- **Zero dependencies** -- pure Elixir, no NIFs, no external tools

## Installation

Add `dicom` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:dicom, "~> 0.9.1"}
  ]
end
```

## Structured Reports

`dicom` includes complete PS3.16 SR authoring with all 33 root template builders:

- coded entries via `Dicom.SR.Code` (372 normative codes)
- content-tree construction via `Dicom.SR.ContentItem` (13 value types incl. TCOORD)
- observation context helpers via `Dicom.SR.Observer`
- SR document rendering via `Dicom.SR.Document`
- **34 template builders** covering every PS3.16 root template:

| Domain | Templates |
|--------|-----------|
| General Imaging | `MeasurementReport` (1500), `TranscribedDiagnosticImagingReport` (2005), `ImagingReport` (2006), `KeyObjectSelection` (2010) |
| Ophthalmology | `SpectaclePrescriptionReport` (2020), `MacularGridReport` (2100) |
| Procedure Log | `ProcedureLog` (3001) |
| Cardiology | `IVUSReport` (3250), `StressTestingReport` (3300), `HemodynamicsReport` (3500), `ECGReport` (3700), `WaveformAnnotation` (3750), `CardiacCatheterizationReport` (3800), `CardiovascularAnalysisReport` (3900) |
| CAD | `MammographyCAD` (4000), `ChestCAD` (4100), `ColonCAD` (4120) |
| Breast/Prostate | `BreastImagingReport` (4200, BI-RADS), `ProstateMRReport` (4300, PI-RADS) |
| Ultrasound | `OBGYNUltrasoundReport` (5000), `VascularUltrasoundReport` (5100), `EchocardiographyReport` (5200), `PediatricCardiacUSReport` (5220), `SimplifiedEchoReport` (5300), `StructuralHeartReport` (5320), `GeneralUltrasoundReport` (12000) |
| Radiation Dose | `ProjectionXRayRadiationDose` (10001), `CTRadiationDose` (10011), `RadiopharmaceuticalRadiationDose` (10021), `PatientRadiationDose` (10030), `EnhancedXrayRadiationDose` (10040) |
| Imaging Agent | `PlannedImagingAgentAdministration` (11001), `PerformedImagingAgentAdministration` (11020) |
| Other | `ImplantationPlan` (7000), `PreclinicalAcquisitionContext` (8101) |

Example:

```elixir
alias Dicom.SR.{Code, Measurement, MeasurementGroup}
alias Dicom.SR.Templates.MeasurementReport

measurement =
  Measurement.new(
    Code.new("8867-4", "LN", "Heart rate"),
    62,
    Code.new("/min", "UCUM", "beats per minute")
  )

group =
  MeasurementGroup.new("lesion-1", Dicom.UID.generate(),
    measurements: [measurement]
  )

{:ok, document} =
  MeasurementReport.new(
    study_instance_uid: Dicom.UID.generate(),
    series_instance_uid: Dicom.UID.generate(),
    sop_instance_uid: Dicom.UID.generate(),
    observer_name: "REPORTER^ALICE",
    procedure_reported: [Code.new("P5-09051", "SRT", "Chest CT")],
    measurement_groups: [group]
  )

{:ok, data_set} = Dicom.SR.Document.to_data_set(document)
{:ok, binary} = Dicom.write(data_set)
```

All 33 PS3.16 root templates are implemented. Current scope:

- implemented: all root template builders, 372 normative codes, TCOORD value type, shared helpers
- not yet implemented: full CID validation, exhaustive sub-template hierarchies, complete spatial/segmentation linkage

Each builder produces a valid P10-serializable document following the `new/1` keyword option pattern.

## Quick Start

```elixir
# Parse a DICOM file
{:ok, data_set} = Dicom.parse_file("/path/to/image.dcm")

# Access attributes by tag
patient_name = Dicom.DataSet.get(data_set, Dicom.Tag.patient_name())
study_date   = Dicom.DataSet.get(data_set, Dicom.Tag.study_date())
modality     = Dicom.DataSet.get(data_set, Dicom.Tag.modality())

# Decode values with VR awareness
raw_element = Dicom.DataSet.get_element(data_set, Dicom.Tag.rows())
rows = Dicom.Value.decode(raw_element.value, raw_element.vr)

# Build a data set from scratch
ds = Dicom.DataSet.new()
    |> Dicom.DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
    |> Dicom.DataSet.put({0x0002, 0x0003}, :UI, Dicom.UID.generate())
    |> Dicom.DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())
    |> Dicom.DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
    |> Dicom.DataSet.put({0x0010, 0x0020}, :LO, "PAT001")

# Serialize and write
{:ok, binary} = Dicom.write(ds)
:ok = Dicom.write_file(ds, "/path/to/output.dcm")

# DataSet bracket access and Enumerable
patient = data_set[Dicom.Tag.patient_name()]
tags = Enum.map(data_set, fn {tag, _elem} -> tag end)

# Tag parsing and date/time conversion
{:ok, tag}  = Dicom.Tag.parse("(0010,0010)")
{:ok, date} = Dicom.Value.to_date("20240115")

# Inspect for quick debugging
IO.inspect(data_set)
```

### Streaming

```elixir
# Stream events lazily from a file (constant memory)
events = Dicom.stream_parse_file("/path/to/large_image.dcm")

# Filter for specific tags without loading the entire file
patient_tags =
  events
  |> Stream.filter(&match?({:element, %{tag: {0x0010, _}}}, &1))
  |> Enum.map(fn {:element, elem} -> {elem.tag, elem.value} end)

# Or materialize back into a DataSet
{:ok, data_set} =
  Dicom.stream_parse(binary)
  |> Dicom.P10.Stream.to_data_set()
```

## DICOM Standard Coverage

| Part | Coverage |
|------|----------|
| PS3.4 | 232 SOP Classes (storage, Q/R, print, worklist) with modality mapping |
| PS3.5 | VR types, transfer syntax handling, sequences, pixel data frame extraction |
| PS3.6 | Tag dictionary (5,035 entries), keyword lookup, retired flags |
| PS3.10 | P10 read/write, File Meta Information, preamble |
| PS3.15 | Best-effort Basic Application Level Confidentiality Profile helpers |
| PS3.16 | Partial SR authoring foundation with focused TID 1500 / 3300 / 3700 builders |
| PS3.18 | DICOM JSON model encoding/decoding for DataSets (Annex F.2) |

Transfer syntaxes: Implicit VR LE, Explicit VR LE, Deflated Explicit VR LE, and Explicit VR BE
(retired) are fully supported for read and write. Other registered syntaxes (compressed,
video) are supported as metadata-only. Unknown UIDs are rejected by default; use
`TransferSyntax.encoding(uid, lenient: true)` to fall back to Explicit VR LE.

## Performance

Indicative measurements on Apple Silicon (Elixir 1.18, OTP 27):

| Operation | Throughput |
|-----------|-----------|
| Parse 50-element data set | ~10 µs |
| Parse 200-element data set | ~50 µs |
| Stream parse 200 elements | ~80 µs |
| Write 50-element data set | ~13 µs |
| Write 200-element data set | ~55 µs |
| Roundtrip 100 elements | ~37 µs |

## Testing

1300+ tests, 16 property-based tests, 35 doctests at 98%+ coverage.

```bash
mix test              # 0 failures
mix test --cover      # HTML report in cover/
mix format --check-formatted
```

## Contributing

Contributions are welcome. Please read our [Contributing Guide](CONTRIBUTING.md)
and [Code of Conduct](CODE_OF_CONDUCT.md) before opening a PR.

## License

MIT -- see [LICENSE](LICENSE) for details.
