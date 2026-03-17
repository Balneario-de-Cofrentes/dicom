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
- **Data dictionary** -- DICOM PS3.6 tag registry with VR and VM definitions
- **Value decoding** -- automatic VR-aware decoding (numeric, string, date, UID, etc.)
- **Transfer syntaxes** -- Implicit VR LE, Explicit VR LE, Explicit VR BE (retired), Deflated Explicit VR LE
- **Sequences** -- defined-length and undefined-length SQ with nested items
- **Encapsulated pixel data** -- fragments with Basic Offset Table
- **Validation** -- File Meta Information validation per PS3.10 Section 7.1
- **Zero dependencies** -- pure Elixir, no NIFs, no external tools

## Installation

Add `dicom` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:dicom, "~> 0.1.0"}
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
```

## Architecture

```
lib/dicom/
  dicom.ex              -- Public API: parse/1, parse_file/1, write/1, write_file/2
  data_set.ex           -- DataSet struct (elements + file meta)
  data_element.ex       -- DataElement struct (tag + VR + value + length)
  tag.ex                -- Tag constants and utilities
  vr.ex                 -- Value Representation types and padding
  uid.ex                -- UID constants, generation, and validation
  value.ex              -- VR-aware value encoding and decoding
  transfer_syntax.ex    -- Transfer syntax registry and encoding dispatch
  p10/
    reader.ex           -- P10 binary parser (preamble, file meta, data set)
    writer.ex           -- P10 binary serializer (iodata pipeline)
    file_meta.ex        -- Preamble validation and File Meta Information
  dictionary/
    registry.ex         -- PS3.6 tag -> {name, VR, VM} lookup
```

## DICOM Standard Coverage

| Part | Title | Coverage |
|------|-------|----------|
| PS3.5 | Data Structures and Encoding | VR types, transfer syntaxes, data encoding, sequences |
| PS3.6 | Data Dictionary | Tag registry (most common clinical tags) |
| PS3.10 | Media Storage and File Format | P10 read/write, File Meta Information, preamble |

### Transfer Syntaxes

| Transfer Syntax | Read | Write |
|----------------|------|-------|
| Implicit VR Little Endian (1.2.840.10008.1.2) | Yes | Yes |
| Explicit VR Little Endian (1.2.840.10008.1.2.1) | Yes | Yes |
| Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99) | Yes | Yes |
| Explicit VR Big Endian (1.2.840.10008.1.2.2, retired) | Yes | Yes |
| JPEG Baseline, JPEG 2000, RLE (compressed) | Metadata only | Metadata only |

## Performance

Benchmarked on Apple Silicon (Elixir 1.18, OTP 27):

| Operation | Throughput |
|-----------|-----------|
| Parse 50-element data set | ~10 us |
| Parse 200-element data set | ~50 us |
| Write 50-element data set | ~13 us |
| Write 200-element data set | ~55 us |
| Roundtrip 100 elements | ~37 us |
| Parse 1 MB pixel data | ~1 us |

Run benchmarks with `mix test test/dicom/benchmark_test.exs`.

## Testing

```bash
mix test              # Run all tests (259 tests)
mix test --cover      # Run with coverage report (100%)
mix format --check-formatted
```

Property-based tests using [StreamData](https://hex.pm/packages/stream_data)
verify encode/decode roundtrips across all VR types.

## AI-Assisted Development

This project welcomes AI-assisted contributions. See [AGENTS.md](AGENTS.md)
for instructions that AI coding assistants can use to work with this codebase,
and [CONTRIBUTING.md](CONTRIBUTING.md) for our AI contribution policy.

## Contributing

Contributions are welcome. Please read our [Contributing Guide](CONTRIBUTING.md)
and [Code of Conduct](CODE_OF_CONDUCT.md) before opening a PR.

## License

MIT -- see [LICENSE](LICENSE) for details.
