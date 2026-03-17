# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it
responsibly.

**Email:** david@balneariodecofrentes.es

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will acknowledge receipt within 48 hours and aim to provide a fix or
mitigation within 7 days for critical issues.

## Security Considerations

### DICOM-Specific Risks

- **Preamble injection** (PS3.10 Section 7.5): The 128-byte preamble can
  contain arbitrary data, including executable content for dual-format files.
  Use `Dicom.P10.FileMeta.sanitize_preamble/1` to zero out untrusted preambles.

- **Patient data (PHI)**: DICOM files contain Protected Health Information.
  This library includes de-identification helpers, but they are not a
  compliance guarantee. Users remain responsible for HIPAA/GDPR and local
  policy compliance when handling patient data.

- **Conformance scope**: This project does not claim regulatory certification
  or complete DICOM conformance across every standard part. It is primarily a
  Part 10 and data-set tooling library with selected helpers from adjacent
  parts of the standard.

- **UID injection**: DICOM UIDs used in file paths or URLs should be validated
  with `Dicom.UID.valid?/1` to prevent path traversal.

- **Denial of service**: Malformed DICOM files with deeply nested sequences or
  extremely large length fields could cause excessive memory allocation.
  Consider setting limits on input file size in production use.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.4.x   | Yes       |
