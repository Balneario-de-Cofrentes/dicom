# Dicom

[![Hex.pm](https://img.shields.io/hexpm/v/dicom.svg)](https://hex.pm/packages/dicom)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/dicom)
[![CI](https://github.com/Balneario-de-Cofrentes/dicom/actions/workflows/ci.yml/badge.svg)](https://github.com/Balneario-de-Cofrentes/dicom/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Pure Elixir DICOM P10 parser and writer. Zero runtime dependencies.

Built on Elixir's binary pattern matching for fast, correct parsing of
[DICOM](https://www.dicomstandard.org/) medical imaging files.

## Features

- **P10 file parsing** -- read DICOM Part 10 files into structured data sets
- **P10 file writing** -- serialize data sets back to conformant P10 files
- **Streaming parser** -- lazy, event-based parsing for large files and pipelines
- **Data dictionary** -- comprehensive PS3.6 tag registry (5,035 entries) with VR, VM, keyword lookup, and retired flags
- **DICOM JSON** -- encode/decode DataSets to/from the DICOM JSON model (PS3.18 Annex F.2) for DICOMweb
- **Pixel data frames** -- extract individual frames from native and encapsulated pixel data (PS3.5 Section A.4)
- **De-identification** -- best-effort PS3.15 Basic Profile helpers with 10 profile flags, supported-tag cleaning, and consistent UID replacement
- **Character set support** -- decode text values per (0008,0005) SpecificCharacterSet (Latin-1 through Latin-5, Cyrillic, Arabic, Greek, Hebrew, JIS X 0201, UTF-8)
- **Value decoding** -- automatic VR-aware decoding (numeric, string, date, UID, etc.)
- **SOP Class registry** -- 232 SOP Classes (183 storage + service/Q-R/print/worklist) with modality mapping, retired flags, and O(1) lookup
- **Transfer syntaxes** -- 49 transfer syntaxes tracked by the library (34 active + 15 retired); strict rejection of unknown UIDs with opt-in lenient mode
- **Sequences** -- defined-length and undefined-length SQ with nested items
- **Encapsulated pixel data** -- fragments with Basic Offset Table
- **Validation** -- File Meta Information validation per PS3.10 Section 7.1
- **Zero dependencies** -- pure Elixir, no NIFs, no external tools

## Installation

Add `dicom` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:dicom, "~> 0.4.5"}
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
  character_set.ex      -- Specific Character Set decoding (0008,0005)
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
| PS3.15 | Security and System Management | Basic Application Level Confidentiality Profile (de-identification) |
| PS3.18 | Web Services | DICOM JSON model encoding/decoding (Annex F.2) |

### Transfer Syntaxes

| Transfer Syntax | Read | Write |
|----------------|------|-------|
| Implicit VR Little Endian (1.2.840.10008.1.2) | Yes | Yes |
| Explicit VR Little Endian (1.2.840.10008.1.2.1) | Yes | Yes |
| Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99) | Yes | Yes |
| Explicit VR Big Endian (1.2.840.10008.1.2.2, retired) | Yes | Yes |
| JPEG, JPEG-LS, JPEG 2000, JPEG XL, RLE, MPEG, HEVC, HTJ2K, SMPTE (58 TSes) | Metadata only | Metadata only |

Unknown transfer syntaxes are rejected by default. Use `TransferSyntax.encoding(uid, lenient: true)`
to fall back to Explicit VR Little Endian for unrecognized UIDs.

## Performance

Benchmarked on Apple Silicon (Elixir 1.18, OTP 27):

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
| Parse 1 MB pixel data | ~1 us |

Run benchmarks with `mix test test/dicom/benchmark_test.exs`.

## Testing

```bash
mix test              # Run all tests (1000+ tests)
mix test --cover      # Run with coverage report (97%+)
mix format --check-formatted
```

Property-based tests using [StreamData](https://hex.pm/packages/stream_data)
verify encode/decode roundtrips across all VR types and streaming parser equivalence.

## Comparison with Other BEAM DICOM Libraries

Five DICOM libraries exist for the BEAM. Only two others are published to Hex.pm.

| Feature | **dicom** | dicom\_ex 0.3.0 | ex\_dicom 0.2.0 | DCMfx 0.43.0 | WolfPACS |
|---------|-----------|-----------------|-----------------|--------------|----------|
| **Language** | Elixir | Elixir | Elixir | Gleam + Rust | Erlang |
| **License** | MIT | Apache-2.0 | MIT | AGPL-3.0 | AGPL-3.0 |
| **On Hex.pm** | Yes | Yes | Yes | No (git only) | No (git only) |
| **Runtime deps** | 0 | 0 | 0 | 6 | 2 |
| **P10 parse** | Yes | Yes | Yes | Yes | Basic |
| **P10 write** | Yes | Yes | Yes | Yes | No |
| **Transfer syntaxes** | 49 (34 active + 15 retired) | 3 | 3 | 47 | 3 |
| **Sequences (SQ)** | Yes | Yes | Yes | Yes | Yes |
| **Tag dictionary** | 5,035 tags | ~5,200 tags | None | ~13,600+ tags | None |
| **UID generation** | Yes | Yes | No | No | No |
| **UID validation** | Yes | No | No | No | No |
| **File Meta validation** | Yes | Partial | Partial | Yes | Yes |
| **Character sets** | ISO 8859-{1..9}, JIS X 0201, UTF-8 | No | No | Full (ISO 2022, CJK, GB18030) | No |
| **Value decoding** | Yes (all 34 VRs) | Yes | Basic | Yes | Yes (25 VRs) |
| **Streaming parser** | Yes | No | No | Yes | No |
| **DIMSE networking** | No | C-ECHO/C-FIND/C-STORE | No | No | C-ECHO/C-STORE |
| **DICOM JSON** | Yes (PS3.18 F.2) | No | No | Yes | No |
| **Anonymization** | Yes (best-effort PS3.15 profile helpers) | No | No | Yes | No |
| **Pixel data frames** | Yes (native + encapsulated) | No | No | Yes | No |
| **SOP Class registry** | 232 classes, modality mapping | None | None | Yes | None |
| **Test suite** | 1000+ tests, 97%+ cov | 4 test files | 1 test file | 6 test suites | 80+ tests |
| **CI** | Passing | None | None | Passing | Passing |
| **Docs** | HexDocs + @moduledoc | HexDocs | HexDocs | Dedicated site | Project site |
| **Production-ready** | Yes | Explicitly no | No | Yes (if AGPL ok) | Alpha |
| **Gleam toolchain** | Not required | Not required | Not required | Required | Not required |

**dicom** is the most feature-complete DICOM library on Hex.pm: zero
dependencies, streaming + read + write, DICOM JSON, anonymization, pixel
data extraction, 232 SOP classes, 49 transfer syntaxes, and MIT-licensed. DCMfx has a larger
tag dictionary (including well-known private tags) and full CJK/ISO 2022
character set support but requires the Gleam toolchain, carries AGPL-3.0
licensing, and is not published to Hex.pm. For DIMSE networking, `dicom_ex`
provides C-ECHO/C-FIND/C-STORE SCP support (educational, not production).

## AI-Assisted Development

This project welcomes AI-assisted contributions. See [AGENTS.md](AGENTS.md)
for instructions that AI coding assistants can use to work with this codebase,
and [CONTRIBUTING.md](CONTRIBUTING.md) for our AI contribution policy.

## Contributing

Contributions are welcome. Please read our [Contributing Guide](CONTRIBUTING.md)
and [Code of Conduct](CODE_OF_CONDUCT.md) before opening a PR.

## License

MIT -- see [LICENSE](LICENSE) for details.
