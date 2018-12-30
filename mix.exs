defmodule Arpeggiate.Mixfile do
  use Mix.Project

  def project do
    [
      app: :arpeggiate,
      version: "1.2.0",
      elixir: "~> 1.0",
      elixirc_paths: elixirc_paths(Mix.env),
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [applications: applications(Mix.env)]
  end

  #
  # Private
  #

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["test/support"] ++ elixirc_paths(:prod)
  defp elixirc_paths(_),     do: ["lib", "lib/arpeggiate"]

  defp applications(_) do
    []
  end

  defp deps do
    [{:ecto, "~> 3.0.0"},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Dan Connor Consulting"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/onyxrev/arpeggiate"}
    ]
  end

  defp description do
    """
    Write step operations with input validation, type casting, and error handling.
    """
  end
end
