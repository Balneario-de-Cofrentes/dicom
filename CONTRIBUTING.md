# Contributing to Dicom

Thank you for your interest in contributing. This guide covers the process
for submitting changes.

## Development Setup

### Prerequisites

- Elixir >= 1.16
- Erlang/OTP >= 26

### Getting Started

```bash
git clone https://github.com/Balneario-de-Cofrentes/dicom.git
cd dicom
mix deps.get
mix test
```

### Common Commands

```bash
mix test                         # Run all tests
mix test --cover                 # Run with coverage report
mix format                       # Format code
mix format --check-formatted     # Check formatting (CI)
mix docs                         # Generate documentation
```

## Submitting Changes

1. Fork the repository and create a branch from `master`
2. Make your changes
3. Ensure all tests pass: `mix test`
4. Ensure code is formatted: `mix format --check-formatted`
5. Ensure coverage does not regress materially in the areas you changed
6. Open a pull request against `master`

### Pull Request Guidelines

- Keep PRs focused on a single change
- Include tests for new functionality
- Update documentation for public API changes
- Follow existing code style and conventions

## Code Conventions

- All public functions return `{:ok, result}` or `{:error, reason}`
- Tags are `{group, element}` tuples: `{0x0010, 0x0010}`
- VR types are atoms: `:PN`, `:DA`, `:UI`, `:OB`, etc.
- Binary parsing uses Elixir pattern matching -- no external parsers
- Use `@spec` on all public functions
- Use `@moduledoc` and `@doc` on all public modules and functions
- Reference specific DICOM standard sections in documentation (e.g., "PS3.5 Section 6.2")

## DICOM Domain Notes

If you are new to DICOM, these concepts are essential:

- **P10** -- the DICOM file format (PS3.10): 128-byte preamble + "DICM" + File Meta Info + Data Set
- **Data Element** -- a single attribute: tag + VR + value
- **Tag** -- `(group, element)` pair identifying an attribute, e.g., `(0010,0010)` = Patient Name
- **VR** -- Value Representation, the data type (PN = Person Name, DA = Date, UI = UID)
- **Transfer Syntax** -- encoding rules: byte order, VR explicit/implicit, pixel compression

The [DICOM standard](https://www.dicomstandard.org/current) is freely available online.

## AI-Assisted Contributions

We welcome AI-assisted contributions under the following conditions:

1. **You are the author.** You are fully responsible for every line you submit,
   regardless of what tools produced it.

2. **Review your changes.** Read and understand all code before submitting.
   You must be able to explain your changes in your own words during review.

3. **Write in your own words.** PR descriptions, issue comments, and review
   responses should be your own writing, not raw AI output.

4. **Meet the same quality bar.** AI-assisted code must compile, pass all tests,
   maintain coverage, and follow project conventions.

See [AGENTS.md](AGENTS.md) for instructions that AI coding assistants can use
to work with this codebase.

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include the Elixir and OTP versions you are using
- For DICOM parsing issues, include (or describe) the transfer syntax and
  the relevant data element tags

## Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating,
you are expected to uphold this code.

## License

By contributing, you agree that your contributions will be licensed under
the [MIT License](LICENSE).
