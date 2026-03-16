# Dicom — AI Development Guide

## Overview

Pure Elixir DICOM P10 parser and writer. Zero runtime dependencies.

## Build Commands

```bash
mix deps.get     # Install dev/test deps only (ex_doc, stream_data)
mix compile      # Compile
mix test         # Run tests
mix format       # Format code
mix docs         # Generate documentation
```

## Architecture

```
lib/dicom/
  dicom.ex              — Public API (parse/1, parse_file/1, write/1, write_file/2)
  data_set.ex           — DataSet struct and accessors
  data_element.ex       — Individual DICOM data element (tag + VR + value)
  tag.ex                — Tag constants and lookup (generated from PS3.6)
  vr.ex                 — Value Representation types and parsing
  uid.ex                — UID constants (SOP Classes, Transfer Syntaxes)
  transfer_syntax.ex    — Transfer syntax definitions and codec dispatch
  p10/
    reader.ex           — P10 file reader (binary parsing)
    writer.ex           — P10 file writer (binary serialization)
    file_meta.ex        — File Meta Information (Group 0002)
  dictionary/
    registry.ex         — Generated tag→{name, vr, vm} lookup table
```

## Conventions

- All public functions return `{:ok, result}` or `{:error, reason}`
- Tags are `{group, element}` tuples: `{0x0010, 0x0010}` = Patient Name
- VR types are atoms: `:PN`, `:DA`, `:UI`, `:OB`, etc.
- Binary parsing uses Elixir pattern matching — no external parsers
- Property-based tests with StreamData for encode/decode roundtrips

## Key DICOM Concepts

- **P10**: The DICOM file format (PS3.10) — 128-byte preamble + "DICM" magic + File Meta Info + Data Set
- **Data Set**: Ordered collection of Data Elements (tag + VR + value)
- **Tag**: (group, element) pair identifying an attribute — e.g., (0010,0010) = Patient Name
- **VR**: Value Representation — the data type (PN=Person Name, DA=Date, UI=UID, etc.)
- **Transfer Syntax**: Encoding rules (byte order, VR explicit/implicit, pixel compression)

## Testing

- Property-based: encode → decode roundtrip with StreamData
- Fixture-based: sample .dcm files in test/fixtures/
- Conformance: validate against DICOM standard expectations
