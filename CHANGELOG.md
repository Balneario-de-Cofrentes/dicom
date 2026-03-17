# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version boundaries below are reconstructed from git history. No git tags or GitHub
releases have been cut yet.

## [Unreleased]

### Added

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
- Expanded test suite to 323 tests (from 269) with 100% coverage maintained

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

[Unreleased]: https://github.com/Balneario-de-Cofrentes/dicom/compare/cdd216b7adc62cb8282f7a150130f7b51d7e724f...HEAD
[0.1.0]: https://github.com/Balneario-de-Cofrentes/dicom/commit/cdd216b7adc62cb8282f7a150130f7b51d7e724f
