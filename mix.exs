defmodule Ueberauth.PingFed.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [app: :ueberauth_pingfed,
     version: @version,
     name: "Ueberauth PingFed",
     package: package(),
     elixir: "~> 1.7",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     source_url: "https://github.com/borodark/ueberauth_pingfed",
     homepage_url: "https://github.com/borodark/ueberauth_pingfed",
     description: description(),
     deps: deps(),
     docs: docs()]
  end

  def application do
    [applications: [:logger, :ueberauth, :oauth2]]
  end

  defp deps do
    [
     {:oauth2, "~> 0.9"},
     {:ueberauth, "~> 0.6"},

     # dev/test only dependencies
     {:credo, "~> 0.8", only: [:dev, :test]},

     # docs dependencies
     {:earmark, ">= 0.0.0", only: :dev},
     {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [extras: ["README.md"]]
  end

  defp description do
    "An Ueberauth strategy for using Ping Federate to authenticate your users."
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Igor Ostaptchenko"],
      licenses: ["MIT"],
      links: %{"GitHub": "https://github.com/borodark/ueberauth_pingfed"}]
  end
end
