# Dicom

[![Hex.pm](https://img.shields.io/hexpm/v/dicom.svg)](https://hex.pm/packages/dicom)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/dicom)
[![CI](https://github.com/Balneario-de-Cofrentes/dicom/actions/workflows/ci.yml/badge.svg)](https://github.com/Balneario-de-Cofrentes/dicom/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Pure Elixir DICOM toolkit focused on DICOM Part 10 files. Zero runtime dependencies.

Built on Elixir's binary pattern matching for fast, correct parsing of
[DICOM](https://www.dicomstandard.org/) medical imaging files.

## Features

- **P10 file parsing** -- read DICOM Part 10 files into structured data sets
- **P10 file writing** -- serialize data sets back to DICOM Part 10 binaries with validated File Meta Information
- **Streaming parser** -- lazy, event-based parsing for large files and pipelines
- **Data dictionary** -- comprehensive PS3.6 tag registry (5,035 entries) with VR, VM, keyword lookup, and retired flags
- **DICOM JSON** -- encode/decode DataSets to/from the DICOM JSON model (PS3.18 Annex F.2) for DICOMweb, with strict decode errors, explicit `BulkDataURI` resolution, compressed Pixel Data normalization when transfer syntax context is known, and correct VM=1 handling for `UT`/`ST`/`LT`/`UR`/`UC`
- **Pixel data frames** -- extract individual frames from native and encapsulated pixel data (PS3.5 Section A.4)
- **De-identification** -- best-effort PS3.15 Basic Profile helpers with supported-tag cleaning, consistent UID replacement, and an explicit `retain_private_tags` switch for retaining all private tags
- **Character set support** -- decode text values for supported single-byte Specific Character Set repertoires plus UTF-8; ISO 2022 escape-sequence switching is not implemented, and multi-valued Specific Character Set extraction is explicit
- **Value decoding** -- automatic VR-aware decoding (numeric, string, date, UID, etc.)
- **SOP Class registry** -- 232 SOP Classes (183 storage + service/Q-R/print/worklist) with modality mapping, retired flags, and O(1) lookup
- **Transfer syntaxes** -- 49 transfer syntaxes tracked by the library (34 active + 15 retired); strict rejection of unknown UIDs with opt-in lenient mode
- **Sequences** -- defined-length and undefined-length SQ with nested items
- **Encapsulated pixel data** -- fragments with Basic Offset Table
- **Validation** -- File Meta Information validation per PS3.10 Section 7.1
- **Zero dependencies** -- pure Elixir, no NIFs, no external tools

## Scope

This library is strongest in DICOM file and data-set workflows:

- PS3.10 read/write for Part 10 files
- PS3.5/PS3.6 value, VR, transfer syntax, dictionary, sequence, and pixel data helpers
- PS3.18 Annex F.2 DICOM JSON conversion for DataSets, including resolver-based `BulkDataURI` decode and transfer-syntax-aware normalization of compressed Pixel Data

It is not a full DICOM stack. In particular:

- It does not implement DIMSE networking or provide a DICOMweb server
- It preserves encapsulated pixel payloads and frame boundaries, but it does not decode JPEG/JPEG 2000/JPEG-LS/MPEG/HEVC codec bitstreams
- De-identification support is a best-effort helper over the library's supported tag/action set, not a regulatory or standards-conformance guarantee
- `retain_private_tags` retains all private tags; this library does not claim PS3.15 safe-private evaluation
- `Dicom.DeIdentification.apply/2` accepts either `profile: %Profile{}` or direct boolean profile flags in its options

## Installation

Add `dicom` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:dicom, "~> 0.5.1"}
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

# Serialize to binary and write
{:ok, binary} = Dicom.write(ds)
:ok = Dicom.write_file(ds, "/path/to/output.dcm")

# Parse from binary
{:ok, parsed} = Dicom.parse(binary)

# DataSet bracket access and Enumerable
patient = data_set[Dicom.Tag.patient_name()]
tags = Enum.map(data_set, fn {tag, _elem} -> tag end)

# Tag parsing and date/time conversion
{:ok, tag} = Dicom.Tag.parse("(0010,0010)")
{:ok, date} = Dicom.Value.to_date("20240115")

# Inspect for quick debugging
IO.inspect(data_set)
```

### Streaming

```elixir
# Stream events lazily from a file (constant memory)
events = Dicom.stream_parse_file("/path/to/large_image.dcm")

# Tune file read-ahead when needed
events = Dicom.stream_parse_file("/path/to/large_image.dcm", read_ahead: 8_192)

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

## Architecture

```
lib/dicom/
  dicom.ex              -- Public API: parse, write, stream_parse, stream_parse_file
  data_set.ex           -- DataSet struct (elements + file meta)
  data_element.ex       -- DataElement struct (tag + VR + value + length)
  tag.ex                -- Tag constants and utilities
  vr.ex                 -- Value Representation types and padding
  uid.ex                -- UID constants, generation, and validation
  value.ex              -- VR-aware value encoding and decoding
  transfer_syntax.ex    -- Transfer syntax registry (49 TSes) and encoding dispatch
  sop_class.ex          -- Dicom.SOPClass registry (232 classes) with modality mapping
  character_set.ex      -- Specific Character Set decoding for supported single-byte repertoires and UTF-8
  character_set/
    tables.ex           -- ISO 8859-{2..9} and JIS X 0201 lookup tables
  json.ex               -- DICOM JSON model encoder/decoder (PS3.18 Annex F.2)
  pixel_data.ex         -- Pixel data frame extraction (PS3.5 Section A.4)
  de_identification.ex  -- De-identification / anonymization (PS3.15 Table E.1-1)
  de_identification/
    profile.ex          -- Profile options struct (10 boolean columns)
  p10/
    reader.ex           -- P10 binary parser (preamble, file meta, data set)
    writer.ex           -- P10 binary serializer (iodata pipeline)
    file_meta.ex        -- Preamble validation and File Meta Information
    stream.ex           -- Streaming API: parse/1, parse_file/2, to_data_set/1
    stream/
      event.ex          -- Event type definitions
      source.ex         -- Data source abstraction (binary + file I/O)
      parser.ex         -- State machine: preamble -> file_meta -> data_set -> done
  dictionary/
    registry.ex         -- PS3.6 tag -> {name, VR, VM} lookup (5,035 entries)
```

## DICOM Standard Coverage

| Part | Title | Coverage |
|------|-------|----------|
| PS3.4 | Service Class Specifications | 232 SOP Classes (storage, Q/R, print, worklist, etc.) with modality mapping |
| PS3.5 | Data Structures and Encoding | VR types, transfer syntax handling, data encoding, sequences, pixel data frame extraction |
| PS3.6 | Data Dictionary | Comprehensive tag registry (5,035 entries), keyword lookup, retired flags |
| PS3.10 | Media Storage and File Format | P10 read/write, File Meta Information, preamble |
| PS3.15 | Security and System Management | Best-effort Basic Application Level Confidentiality Profile helpers for the supported tag/action set |
| PS3.18 | Web Services | DICOM JSON model encoding/decoding for DataSets (Annex F.2) |

### Transfer Syntaxes

| Transfer Syntax | Read | Write |
|----------------|------|-------|
| Implicit VR Little Endian (1.2.840.10008.1.2) | Yes | Yes |
| Explicit VR Little Endian (1.2.840.10008.1.2.1) | Yes | Yes |
| Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99) | Yes | Yes |
| Explicit VR Big Endian (1.2.840.10008.1.2.2, retired) | Yes | Yes |
| Other registered compressed and video transfer syntaxes | Metadata only | Metadata only |

Unknown transfer syntaxes are rejected by default. Use `TransferSyntax.encoding(uid, lenient: true)`
to fall back to Explicit VR Little Endian for unrecognized UIDs.

## Performance

Indicative measurements on one Apple Silicon machine (Elixir 1.18, OTP 27):

| Operation | Throughput |
|-----------|-----------|
| Parse 50-element data set | ~10 us |
| Parse 200-element data set | ~50 us |
| Stream parse 50 elements | ~20 us |
| Stream parse 200 elements | ~80 us |
| Stream enumerate 200 elements | ~55 us |
| Write 50-element data set | ~13 us |
| Write 200-element data set | ~55 us |
| Roundtrip 100 elements | ~37 us |

Run benchmarks with `mix test test/dicom/benchmark_test.exs`.
Set `DICOM_ENFORCE_BENCHMARKS=1` only on a stable machine if you want to enforce the documented timing budgets.

## Testing

```bash
mix test              # Run all tests (1100+ tests)
mix test --cover      # Run with coverage report
mix format --check-formatted
```

Property-based tests using [StreamData](https://hex.pm/packages/stream_data)
verify encode/decode roundtrips across all VR types and streaming parser equivalence.

## Project Positioning

`dicom` is aimed at file-centric DICOM workflows in Elixir: parse, inspect,
transform, write, stream, and validate Part 10 objects without native code or
external tooling.

That means the library is a strong fit for ingestion pipelines, metadata
processing, archive tooling, DICOM JSON conversion, and controlled
de-identification passes over known data. If you need DIMSE networking, a full
codec stack for compressed pixel payloads, or formal privacy/compliance
validation, those concerns should sit alongside this library rather than inside it.

For DICOM JSON specifically, `BulkDataURI` entries are not treated as raw bytes.
Use `Dicom.Json.from_map/2` with `bulk_data_resolver:` when you want to resolve
external bulk data during decode.

JSON decode preserves binary payloads by default. When transfer syntax context
is known and indicates compressed Pixel Data, `Dicom.Json.from_map/2`
normalizes `(7FE0,0010)` to encapsulated fragments and fails closed if the
incoming Value Field is not a valid encapsulated Pixel Data payload.

For charset-sensitive text export, `Dicom.Json.to_map/2` decodes a single
declared `SpecificCharacterSet` to Unicode before building JSON values. If a
data set declares multiple Specific Character Set values, JSON export fails
closed instead of guessing.

On export, binary `InlineBinary` and `BulkDataURI` payloads follow PS3.18 Annex
F.2.7 and refer to the attribute's full Value Field. For encapsulated Pixel
Data, that means the Basic Offset Table item, fragment items, and sequence
delimiter are preserved as part of the exported payload.

## AI-Assisted Development

This project welcomes AI-assisted contributions. See [AGENTS.md](AGENTS.md)
for instructions that AI coding assistants can use to work with this codebase,
and [CONTRIBUTING.md](CONTRIBUTING.md) for our AI contribution policy.

## Contributing

Contributions are welcome. Please read our [Contributing Guide](CONTRIBUTING.md)
and [Code of Conduct](CODE_OF_CONDUCT.md) before opening a PR.

## License

MIT -- see [LICENSE](LICENSE) for details.
