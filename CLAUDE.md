# Dicom -- AI Development Guide

## Overview

Pure Elixir DICOM P10 parser and writer. Zero runtime dependencies.
MIT licensed. See [AGENTS.md](AGENTS.md) for agent-specific instructions.

## Build Commands

```bash
mix deps.get                     # Install dev/test deps (ex_doc, stream_data)
mix compile                      # Compile
mix test                         # Run tests (259 tests, 100% coverage)
mix test --cover                 # Run with HTML coverage report
mix format                       # Format code
mix format --check-formatted     # Check formatting (CI uses this)
mix docs                         # Generate documentation
```

## Architecture

```
lib/dicom/
  dicom.ex              -- Public API (parse/1, parse_file/1, write/1, write_file/2)
  data_set.ex           -- DataSet struct: elements + file_meta maps
  data_element.ex       -- DataElement struct: tag + VR + value + length
  tag.ex                -- Tag constants and lookup (generated from PS3.6)
  vr.ex                 -- Value Representation types, parsing, padding
  uid.ex                -- UID constants, generation, validation
  value.ex              -- VR-aware value encoding and decoding
  transfer_syntax.ex    -- Transfer syntax registry and encoding dispatch
  p10/
    reader.ex           -- P10 binary parser (list accumulator + Map.new)
    writer.ex           -- P10 binary serializer (iodata pipeline)
    file_meta.ex        -- Preamble validation and File Meta Information
  dictionary/
    registry.ex         -- PS3.6 tag -> {name, vr, vm} lookup table
```

## Conventions

- All public functions return `{:ok, result}` or `{:error, reason}`
- Tags are `{group, element}` tuples: `{0x0010, 0x0010}` = Patient Name
- VR types are atoms: `:PN`, `:DA`, `:UI`, `:OB`, etc.
- Binary parsing uses Elixir pattern matching -- no external parsers
- `@spec` on all public functions
- `@compile {:inline, ...}` on hot-path functions
- Property-based tests with StreamData for encode/decode roundtrips
- 100% test coverage maintained -- do not decrease it
- Shared test helpers in `test/support/dicom_test_helpers.ex`

## Key DICOM Concepts

- **P10**: The DICOM file format (PS3.10) -- 128-byte preamble + "DICM" magic + File Meta Info + Data Set
- **Data Set**: Ordered collection of Data Elements (tag + VR + value)
- **Tag**: (group, element) pair identifying an attribute -- e.g., (0010,0010) = Patient Name
- **VR**: Value Representation -- the data type (PN=Person Name, DA=Date, UI=UID, etc.)
- **Transfer Syntax**: Encoding rules (byte order, VR explicit/implicit, pixel compression)

## Performance Notes

- Reader uses list accumulation + `Map.new/1` instead of per-element `Map.put`
- Writer uses iodata pipeline with single `IO.iodata_to_binary` at serialize exit
- `:erlang.iolist_size` for length computation (avoids intermediate binary allocation)
- TransferSyntax registry is a compile-time `@registry` module attribute
