# AGENTS.md

Instructions for AI coding assistants working with this codebase.

## Project Overview

Pure Elixir DICOM P10 parser and writer. Zero runtime dependencies.
Parses and serializes medical imaging files per the DICOM standard (PS3.5, PS3.6, PS3.10).

## Build and Test

```bash
mix deps.get                     # Install dev/test dependencies
mix compile                      # Compile
mix test                         # Run all tests (expect 259 tests, 0 failures)
mix test --cover                 # Run with coverage (expect 100%)
mix format --check-formatted     # Check formatting
mix docs                         # Generate documentation
```

## Architecture

```
lib/dicom.ex              -- Public API: parse/1, parse_file/1, write/1, write_file/2
lib/dicom/
  data_set.ex             -- DataSet struct: elements + file_meta maps
  data_element.ex         -- DataElement struct: tag + VR + value + length
  tag.ex                  -- Tag constants: patient_name/0 -> {0x0010, 0x0010}
  vr.ex                   -- Value Representation: types, padding, from_binary/1
  uid.ex                  -- UID constants, generate/0, valid?/1
  value.ex                -- VR-aware encode/decode between binary and Elixir types
  transfer_syntax.ex      -- Transfer syntax registry, encoding/1 dispatch
  p10/
    reader.ex             -- Binary parser: preamble -> file meta -> data set
    writer.ex             -- Binary serializer: iodata pipeline -> IO.iodata_to_binary
    file_meta.ex          -- Preamble validation, skip_preamble/1, sanitize_preamble/1
  dictionary/
    registry.ex           -- PS3.6 lookup: tag -> {:ok, name, vr, vm} | :error
```

## Conventions

- Return `{:ok, result}` or `{:error, reason}` from all public functions
- Tags are `{group, element}` tuples: `{0x0010, 0x0010}` = Patient Name
- VR types are atoms: `:PN`, `:DA`, `:UI`, `:OB`, `:SQ`, etc.
- Binary parsing uses Elixir pattern matching exclusively
- `@spec` on all public functions
- `@moduledoc` and `@doc` on all public modules and functions
- Reference DICOM standard sections in docs (e.g., "PS3.5 Section 6.2")

## Code Style

- Run `mix format` before committing
- Use `@compile {:inline, ...}` for hot-path functions
- Prefer iodata over binary concatenation in serialization paths
- Use list accumulation + `Map.new/1` over incremental `Map.put` in parsing loops

## Testing

- Property-based tests with StreamData for encode/decode roundtrips
- Shared test helpers in `test/support/dicom_test_helpers.ex`
- Benchmark tests in `test/dicom/benchmark_test.exs`
- 100% test coverage is expected -- do not decrease it
- Run `mix test --cover` and check the HTML report in `cover/`

## DICOM Domain

Key concepts for working with this codebase:

- **P10**: File format (PS3.10) = 128-byte preamble + "DICM" + File Meta Info + Data Set
- **Data Set**: Ordered map of `{tag => DataElement}` pairs
- **Tag**: `{group, element}` pair, e.g., `{0x0010, 0x0010}` = Patient Name
- **VR**: Value Representation = data type (PN = Person Name, DA = Date, UI = UID)
- **Transfer Syntax**: Encoding rules (byte order + VR explicit/implicit + compression)
- **File Meta Info**: Group 0002 elements, always Explicit VR Little Endian
- **Sequence (SQ)**: Nested data -- a list of item maps, each item is a `%{tag => DataElement}`

## Security

- Never execute DICOM file content as code
- Preamble bytes (first 128 bytes) can contain arbitrary data -- use `sanitize_preamble/1`
- Validate UIDs with `Dicom.UID.valid?/1` before using them in file paths or URLs
- Do not hardcode credentials or PHI (Protected Health Information) in tests
- DICOM files may contain patient data -- handle with care in examples and fixtures

## PR Guidelines

- Keep changes focused on a single concern
- Include tests for new functionality
- Maintain 100% test coverage
- Update `@doc` and `@moduledoc` for public API changes
- Add `Assisted-by: <tool name>` commit trailer if AI tools were used
