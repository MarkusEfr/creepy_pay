import Config

config :creepy_pay,
  generators: [timestamp_type: :utc_datetime]

config :creepy_pay, ecto_repos: [CreepyPay.Repo]
# Configures the endpoint
config :creepy_pay, CreepyPayWeb.Endpoint,
  url: [host: "127.0.0.1", port: 4000],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CreepyPayWeb.ErrorJSON],
    layout: true
  ],
  pubsub_server: CreepyPay.PubSub,
  live_view: [signing_salt: "l7Bz3vHs"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  creepy_pay: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  creepy_pay: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
