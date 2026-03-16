# Dicom

Pure Elixir DICOM P10 parser and writer.

Zero external dependencies. Built on Elixir's binary pattern matching for fast, streaming-capable parsing of DICOM medical imaging files.

## Features

- **P10 file parsing** — read DICOM Part 10 files into structured data sets
- **P10 file writing** — serialize data sets back to conformant P10 files
- **Data dictionary** — complete DICOM PS3.6 tag registry with VR definitions
- **Transfer syntax support** — Implicit VR LE, Explicit VR LE (more planned)
- **Streaming** — parse large files without loading everything into memory
- **Zero dependencies** — pure Elixir, no NIFs, no external tools

## Installation

```elixir
def deps do
  [
    {:dicom, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
# Parse a DICOM file
{:ok, data_set} = Dicom.parse_file("/path/to/image.dcm")

# Access attributes
patient_name = Dicom.DataSet.get(data_set, Dicom.Tag.patient_name())
study_date = Dicom.DataSet.get(data_set, Dicom.Tag.study_date())

# Get SOP Class
sop_class = Dicom.DataSet.get(data_set, Dicom.Tag.sop_class_uid())

# Parse from binary
{:ok, data_set} = Dicom.parse(binary_data)

# Write to file
:ok = Dicom.write_file(data_set, "/path/to/output.dcm")

# Convert to map
map = Dicom.DataSet.to_map(data_set)
```

## DICOM Standard Coverage

| Part | Coverage | Notes |
|------|----------|-------|
| PS3.5 | Data encoding, VR types | Core parsing engine |
| PS3.6 | Data dictionary | Complete tag registry |
| PS3.10 | Media storage, file format | P10 read/write |

## License

Apache-2.0
