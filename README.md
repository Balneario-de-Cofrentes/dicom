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

  DICOM P10 toolkit for Elixir · PS3.5/6/10/18
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
    {:dicom, "~> 0.6.1"}
  ]
end
```

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
