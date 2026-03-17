# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Performance benchmarks (parse, write, roundtrip, VR lookup)
- 100% test coverage across all 12 modules (259 tests)
- Property-based tests with StreamData for encode/decode roundtrips

[Unreleased]: https://github.com/Balneario-de-Cofrentes/dicom/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Balneario-de-Cofrentes/dicom/releases/tag/v0.1.0
