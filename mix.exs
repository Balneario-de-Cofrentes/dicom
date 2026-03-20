defmodule Dicom.MixProject do
  use Mix.Project

  @version "0.7.1"
  @source_url "https://github.com/Balneario-de-Cofrentes/dicom"

  def project do
    [
      app: :dicom,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Dicom",
      description:
        "Pure Elixir DICOM toolkit for P10 files, DICOM JSON, de-identification, and structured-report foundations",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      test_coverage: [
        ignore_modules: [
          Mix.Tasks.Dicom.GenSopClasses,
          Mix.Tasks.Dicom.GenDictionary
        ]
      ],
      preferred_cli_env: [
        test: :test,
        "test.all": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:stream_data, "~> 1.0", only: [:test, :dev]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/dicom",
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md"
      },
      files:
        ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md SECURITY.md AGENTS.md CONTRIBUTING.md CODE_OF_CONDUCT.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "SECURITY.md",
        "AGENTS.md",
        "CONTRIBUTING.md",
        "CODE_OF_CONDUCT.md",
        "LICENSE"
      ],
      source_ref: System.get_env("SOURCE_REF") || "v#{@version}"
    ]
  end
end
