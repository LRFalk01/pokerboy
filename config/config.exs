# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :pokerboy,
  ecto_repos: []

# Configures the endpoint
config :pokerboy, Pokerboy.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "lkcoXytve5e69nfjdzTdyO5e6aHaqpxcKn1IMfRmNQOvkHJW6W5GvxiMHjATcQvj",
  render_errors: [view: Pokerboy.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Pokerboy.PubSub, adapter: Phoenix.PubSub.PG2]

config :phoenix, :json_library, Jason

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :pokerboy, Pokerboy.Gameserver, valid_votes: ~w(0 1 2 3 5 8 13 21 34 55 89 ?)

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
