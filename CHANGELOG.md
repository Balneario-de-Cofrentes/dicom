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

- Expanded regression coverage to 269 tests with the suite remaining at 100% coverage

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
