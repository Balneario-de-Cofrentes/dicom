# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.1] - 2026-03-20

### Fixed

- `Dicom.SR.ContentItem` now preserves numeric string inputs and formats float values without raising while building NUM content items

### Changed

- Coverage increased to 98.18% overall, with the new PS3.16 SR surface driven to 100% module coverage
- Added regression tests for SR wrapper defaults, measurement-group finding categories, observer-device omission branches, verification metadata, and mixed code/text template inputs
- Implementation version name updated to `DICOM_0.7.1`

## [0.7.0] - 2026-03-20

### Added

- Initial PS3.16 structured-report authoring foundation under `Dicom.SR`
- Reusable coded entries, content items, observation context helpers, measurement groups, and SR document rendering
- Focused builders for:
  - `TID 1500` Measurement Report
  - `TID 3300` Stress Testing Report
  - `TID 3700` ECG Report
- Regression coverage for SR tree rendering, template identifiers, and P10 roundtrips

### Changed

- README and standard coverage docs now describe PS3.16 support as a scoped foundation instead of an absent capability
- Implementation version name updated to `DICOM_0.7.0`
- Verified SR document construction now fails fast when required verification observer metadata is missing

### Conformance Notes

- This release does **not** claim full PS3.16 coverage
- The implemented surface focuses on reusable SR building blocks and three concrete root templates
- Full CID enforcement, exhaustive included-template coverage, and richer image/SEG/SCOORD linkage remain future work

## [0.6.3] - 2026-03-19

### Fixed

- Suppress `:json` undefined module warning on OTP 26 in code generation mix tasks (CI fix)

### Changed

- Implementation version name updated to `DICOM_0.6.3`

## [0.6.2] - 2026-03-19

### Added

- `Dicom.parse_data_set/2` — parse raw DIMSE data set payloads using an explicit transfer syntax UID
- `Dicom.write_data_set/2` — serialize raw DIMSE data set payloads without Part 10 file meta or preamble
- Raw-data-set roundtrip coverage across Implicit VR Little Endian, Explicit VR Little Endian, and Explicit VR Big Endian

### Changed

- Unknown transfer syntax errors now include the offending UID for eager parse, stream parse, and write paths
- Implementation version name updated to `DICOM_0.6.2`

## [0.6.1] - 2026-03-19

_Yanked — published before peer changes were merged. Use 0.6.2._

## [0.6.0] - 2026-03-18

### Changed

- Test coverage hardened from 94.87% to 98.60% (1309 tests, 16 properties, 35 doctests, 0 failures)
- Removed dead code in `Dicom.Json`: 4 unreachable clauses in decode fallbacks, string value catchall, numeric nil guard, and non-binary charset guard
- Added stability annotations to streaming modules: `Dicom.P10.Stream` and `Dicom.P10.Stream.Event` marked **stable**, `Dicom.P10.Stream.Source` marked **may change**
- 16 modules now at 100% coverage; `Dicom.Json` at 99.55%, `Dicom.P10.Stream.Parser` at 97.96%
- Implementation version name updated to `DICOM_0.6.0`

### Added

- Property-based tests (StreamData) for numeric VR encode/decode roundtrips (US, SS, UL, SL, FL, FD), stream parser/reader parity, JSON roundtrip, and string VR compliance roundtrip
- De-identification hardening tests: multi-level nested sequence UID remapping, temporal `:M` action, leap year Feb 29 edge cases, private tags inside sequence items
- Encapsulated pixel data edge case tests: BOT offset validation, multi-frame fragment grouping, `parse_encapsulated_value_field` boundary cases
- Implicit VR streaming tests for defined-length sequences and items
- Shared test helpers: `elem_implicit/2` and `build_encapsulated_fragments/1`

### Removed

- `docs/roadmap.md` — roadmap work is complete and embodied in the codebase

## [0.5.2] - 2026-03-18

### Changed

- README trimmed and updated with block-letter logo

## [0.5.1] - 2026-03-18

### Fixed

- Deflated Explicit VR Little Endian now uses raw RFC1951 deflate/inflate
  semantics instead of zlib-wrapped payload handling
- Streaming and eager parsing now fail closed on truncated encapsulated pixel
  fragments and other malformed binary edge cases that previously leaked
  partial or ambiguous values
- `Dicom.Value` and `Dicom.Json` now reject partial or malformed `DS`, `IS`,
  numeric VR, `PN`, and `AT` values instead of silently truncating, coercing,
  or exporting invalid JSON
- DICOM JSON now respects VM=1 text VRs, validates `AT` tuples on export,
  decodes multi-valued `AT` values correctly, and keeps compressed Pixel Data
  roundtrips writable when transfer syntax context is known
- Writer validation now rejects malformed encapsulated Pixel Data structure,
  invalid Basic Offset Tables, and other Pixel Data / transfer syntax
  mismatches before serialization
- `Dicom.PixelData` and `Dicom.DataSet.decoded_value/2` now fail safely on
  malformed numeric metadata instead of raising or leaking undecoded raw bytes

### Changed

- `Dicom.Json.from_map/2` now normalizes compressed Pixel Data to
  `{:encapsulated, fragments}` only when transfer syntax context is provided,
  and otherwise preserves raw binary payloads
- De-identification markers and option handling are now more honest and
  predictable, including support for direct boolean option flags and LO-safe
  `DeidentificationMethod` values
- Documentation now matches the hardened JSON boundary behavior, transfer
  syntax context requirements, de-identification option styles, and current
  release versioning
- Implementation version name updated to `DICOM_0.5.1`

## [0.5.0] - 2026-03-17

### Fixed

- Malformed input paths across the eager parser, streaming parser, DICOM JSON
  decoder, and pixel-data helpers now return structured errors instead of
  raising exceptions
- Top-level sequence de-identification now respects tag action rules instead of
  always preserving sequence containers
- File Meta Information validation now rejects empty or malformed required UID
  values before serialization
- `Dicom.PixelData` now handles parser-produced `{:encapsulated, fragments}`
  values, computes native frame sizes correctly for bit-packed data, and
  rejects ambiguous multi-frame encapsulated splitting
- `Dicom.P10.Stream.parse_file/2` now honors the documented `:read_ahead` option

### Changed

- `Dicom.Json.from_map/2` is now strict about malformed typed values and
  requires an explicit `bulk_data_resolver:` to materialize `BulkDataURI`
  content
- De-identification private-tag retention is now named and documented honestly
  via `retain_private_tags`; `retain_safe_private` remains as a compatibility
  alias for retaining all private tags
- Character set support now explicitly rejects ISO 2022 escape-sequence
  switching instead of implying code-extension support
- README and API docs were updated to match the stricter JSON, pixel-data,
  de-identification, and streaming behavior
- Implementation version name updated to `DICOM_0.5.0`

## [0.4.5] - 2026-03-17

### Fixed

- DICOM JSON multi-value handling now preserves array semantics for PN, AT,
  string VRs, and numeric VRs
- DICOM JSON encoder now omits Group Length attributes from output
- `Dicom.write_file/2` now returns writer errors instead of raising `MatchError`
- `Enumerable` slice implementation for `Dicom.DataSet` updated for Elixir 1.18's
  3-arity slice contract
- `Dicom.SOPClass` is now the canonical public module name

### Changed

- De-identification profile flags now affect supported tag groups instead of
  leaving most options inert
- Release docs corrected to match current registry counts and current behavior
- README and HexDocs now describe scope more precisely around PS3.10,
  compressed transfer syntaxes, DICOM JSON, and de-identification limits
- Hex package and HexDocs extras now include `SECURITY.md`, and source links
  default to the release tag
- Implementation version name updated to `DICOM_0.4.5`

## [0.4.2] - 2026-03-17

### Removed

- Dead code in `P10.Stream.Parser`: unreachable error branches guarded by `ensure_bytes`
  (9 branches across `read_tag`, `read_uint32`, `read_next_data_element`,
  `read_item_elements_until_delimiter_eager`, `read_item_elements_bounded_eager`,
  `read_fragments_eager`)
- Dead code in `CharacterSet`: unreachable `iso8859_to_unicode(byte, 1)` clause
  (`ISO_IR 100` maps to `:latin1`, never to `{:iso8859, 1}`)
- Dead code in `PixelData`: unreachable error branch in `frame/2`
  (`extract_encapsulated_frames` always returns `{:ok, ...}`)

## [0.4.0] - 2026-03-17

### Added

- **VR metadata** — `VR.all/0`, `VR.description/1`, `VR.max_length/1`,
  `VR.fixed_length?/1` backed by compile-time maps per PS3.5 Table 6.2-1.
- **Tag utilities** — `Tag.parse/1` for "(GGGG,EEEE)" and "GGGGEEEE" formats,
  `Tag.from_keyword/1` for dictionary keyword lookup, `Tag.repeating?/1` for
  50XX/60XX/7FXX repeating groups.
- **Date/time conversion** — `Value.to_date/1`, `Value.to_time/1`,
  `Value.to_datetime/1`, `Value.from_date/1`, `Value.from_time/1`,
  `Value.from_datetime/1` for bidirectional DICOM DA/TM/DT ↔ Elixir Date/Time/DateTime.
  Supports partial TM, fractional seconds, and timezone offsets.
- **DataSet ergonomics** — `DataSet.has_tag?/2`, `DataSet.get/3` (with default),
  `DataSet.fetch/2`, `DataSet.merge/2`, `DataSet.from_list/1`,
  `DataSet.decoded_value/2` (VR-aware decode).
- **Protocol implementations** — `Inspect` for `DataElement` (shows tag, VR,
  truncated value; SQ item count; encapsulated fragment count) and `DataSet`
  (element count, patient, modality). `Enumerable` for `DataSet` (sorted by tag,
  file_meta merged). `Access` behaviour for `DataSet` (`ds[tag]`, `get_in`,
  `put_in`, `pop`).

### Changed

- Expanded test suite to 1000+ tests (35 doctests, 7 property tests) at 97%+ coverage
- `UID.transfer_syntax?/1` now uses `TransferSyntax.known?/1` for authoritative
  O(1) registry lookup instead of prefix matching (fixes false positives for UIDs
  like Storage Commitment `1.2.840.10008.1.20.1`)
- Implementation version name updated from `DICOM_EX_0.1.1` to `DICOM_0.4.0`
- Updated AGENTS.md with current test counts and architecture diagram

## [0.3.0] - 2026-03-17

### Added

- **62 transfer syntaxes** — expanded from 29 to all 49 active + 13 retired
  DICOM transfer syntaxes. New fields: `retired` and `fragmentable` flags.
  New functions: `retired?/1`, `fragmentable?/1`, `active/0`.
- **Complete PS3.6 tag dictionary** — 5,035 entries generated from innolitics
  `attributes.json` via `mix dicom.gen_dictionary`. Keyword reverse lookup
  with `find_by_keyword/1`, retired tag detection with `retired?/1`, and
  expanded repeating group support (50XX curve, 60XX overlay, 7FXX waveform).
- **DICOM JSON model** (`Dicom.Json`) — encode/decode DataSets to/from the
  DICOM JSON format (PS3.18 Annex F.2) for DICOMweb. Supports all VR types,
  Person Name component groups, sequence recursion, InlineBinary (base64),
  and BulkDataURI callbacks. Zero runtime dependencies — produces plain maps.
- **Pixel data frame extraction** (`Dicom.PixelData`) — extract individual
  frames from native and encapsulated pixel data (PS3.5 Section A.4).
  O(1) native frame access via `binary_part/3`. Encapsulated support with
  Basic Offset Table, fragment-per-frame convention, and single-frame
  concatenation. Functions: `frames/1`, `frame/2`, `frame_count/1`,
  `encapsulated?/1`.
- **De-identification / anonymization** (`Dicom.DeIdentification`) — Basic
  Application Level Confidentiality Profile (PS3.15 Table E.1-1) with action
  codes D, Z, X, K, C, U. Consistent UID replacement across elements.
  Configurable profile with 10 boolean options. Recursive SQ processing and
  private tag stripping.
- **ISO 8859-{2..9} full lookup tables** — replaced identity mapping with
  correct Unicode codepoint tables for all 8 ISO 8859 variants.
- **JIS X 0201 character set** — `ISO_IR 13` support for Roman + half-width
  Katakana decoding.
- Mix task `mix dicom.gen_dictionary` for regenerating the tag dictionary
  from the innolitics DICOM standard JSON source.

### Changed

- Expanded test suite to 621 tests (5 doctests, 4 property tests) at 91%+ coverage
- VR module exposes `string_vrs/0`, `numeric_vrs/0`, `binary_vrs/0` list accessors
- Transfer syntax `all/0` and `active/0` cached at compile time

### Fixed

- De-identification `:D` action now computes correct `byte_size` for dummy values
- ISO 8859-4 table: removed erroneous `0xE3` mapping
- Character set decoding DRYed with shared `decode_bytewise/3`

## [0.2.0] - 2026-03-17

### Added

- Streaming DICOM P10 parser via `Dicom.P10.Stream` with lazy, event-based parsing
  - `Dicom.stream_parse/1` and `Dicom.stream_parse_file/2` convenience functions
  - `Dicom.P10.Stream.parse/1` for in-memory binary streaming (`Stream.unfold/2`)
  - `Dicom.P10.Stream.parse_file/2` for file I/O streaming (`Stream.resource/3`)
  - `Dicom.P10.Stream.to_data_set/1` to materialize a stream into a `DataSet`
  - Event types: `:file_meta_start`, `{:file_meta_end, ts_uid}`, `{:element, elem}`,
    `{:sequence_start, tag, length}`, `:sequence_end`, `{:item_start, length}`,
    `:item_end`, `{:pixel_data_start, tag, vr}`, `{:pixel_data_fragment, index, binary}`,
    `:pixel_data_end`, `:end`, `{:error, reason}`
  - Source abstraction (`Dicom.P10.Stream.Source`) for binary and file I/O with
    64 KB read-ahead buffering
  - State machine parser (`Dicom.P10.Stream.Parser`) supporting all 4 transfer
    syntaxes, sequences, items, and encapsulated pixel data
- BEAM DICOM library comparison table in the README covering licensing, features,
  test coverage, and CI status
- **Comprehensive PS3.6 data dictionary** — expanded from ~95 hand-written entries
  to 5032 entries generated from the DICOM standard. Overlay repeating group (60XX)
  support included. Previously-unknown tags (especially SQ) now resolve correctly
  in Implicit VR parsing.
- **Specific Character Set support** (`Dicom.CharacterSet`) — decodes text values
  according to (0008,0005). Supports default repertoire, ISO_IR 100 (Latin-1),
  ISO 8859-2 through 9, and ISO_IR 192 (UTF-8). Returns explicit errors for
  unsupported charsets instead of silently producing incorrect text.
- **Expanded transfer syntax registry** — from 9 to 29 entries. Added JPEG-LS,
  JPEG 2000 Part 2, MPEG-2/4, HEVC/H.265, HTJ2K, and JPIP transfer syntaxes.
- Interoperability test suite exercising unknown TS rejection, expanded dictionary
  in implicit VR parsing, rich multi-element roundtrips across all four uncompressed
  transfer syntaxes, encapsulated pixel data with compressed TSes, and character set
  integration through the parse pipeline.

### Fixed

- Reject serialization when required File Meta Information is missing
- Encode numeric values according to their VR width instead of forcing 32-bit
  little-endian output
- Respect transfer syntax endianness for numeric value encoding and decoding
- Preserve leading spaces for padded text VRs such as `LT` and `UT`
- Return `{:error, :unexpected_end}` for truncated defined-length sequence payloads
  instead of crashing the parser
- Tighten UID validation for invalid root arcs

### Changed

- **Strict transfer syntax policy** — `TransferSyntax.encoding/2` now returns
  `{:error, :unknown_transfer_syntax}` for unrecognized UIDs instead of silently
  falling back to Explicit VR Little Endian. Use `encoding(uid, lenient: true)` to
  opt in to the old fallback behavior. Reader and writer now propagate this error.
- Expanded test coverage to 448 tests (streaming, big-endian numeric value
  decode/encode, eager path, edge cases, property-based equivalence) at 91%+ coverage

## [0.1.0] - 2026-03-17

### Added

- P10 file parsing with `Dicom.parse/1` and `Dicom.parse_file/1`
- P10 file writing with `Dicom.write/1` and `Dicom.write_file/2`
- Data set creation and manipulation via `Dicom.DataSet`
- DICOM data dictionary (PS3.6) with tag lookup via `Dicom.Dictionary.Registry`
- Tag constants for common clinical attributes via `Dicom.Tag`
- UID constants for SOP Classes and Transfer Syntaxes via `Dicom.UID`
- UID generation and validation
- VR-aware value encoding and decoding via `Dicom.Value`
- Transfer syntax support:
  - Implicit VR Little Endian
  - Explicit VR Little Endian
  - Explicit VR Big Endian (retired)
  - Deflated Explicit VR Little Endian
- Sequence support (SQ) with defined and undefined length items
- Encapsulated pixel data with fragment parsing
- File Meta Information validation per PS3.10 Section 7.1
- Preamble validation and sanitization (PS3.10 Section 7.5)
- Data Set Trailing Padding support (FFFC,FFFC)

### Changed

- Expanded PS3.10 support with compliance tests, deflated transfer syntax support,
  sequence handling, additional VR coverage, and Explicit VR Big Endian support
- Hardened parsing and validation around malformed input, edge cases, and file meta handling
- Optimized hot paths in the reader, writer, transfer syntax registry, and VR utilities
- Prepared the project for public release with CI, licensing, contribution policy,
  security policy, and open-source documentation

### Performance

- Performance benchmarks (parse, write, roundtrip, VR lookup)
- 100% test coverage across all 12 modules (259 tests)
- Property-based tests with StreamData for encode/decode roundtrips

[Unreleased]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.6.3...v0.7.0
[0.6.3]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.5.2...v0.6.0
[0.5.2]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.4.5...v0.5.0
[0.4.5]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.4.2...v0.4.5
[0.4.2]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.4.0...v0.4.2
[0.4.0]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Balneario-de-Cofrentes/dicom/commit/cdd216b7adc62cb8282f7a150130f7b51d7e724f
