defmodule Dicom.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/Balneario-de-Cofrentes/dicom"

  def project do
    [
      app: :dicom,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Dicom",
      description: "Pure Elixir DICOM P10 parser and writer",
      package: package(),
      docs: docs(),
      source_url: @source_url,
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
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md AGENTS.md)
    ]
  end

  defp docs do
    [
      main: "Dicom",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: System.get_env("SOURCE_REF") || "master"
    ]
  end
end
