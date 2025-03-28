import Config
import Dotenvy
require Logger

source!([
  Path.expand("./.env"),
  Path.expand("./envs/#{config_env()}.env"),
  System.get_env()
])

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
# PHX_SERVER=true
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.

rpc_url = env!("RPC_URL") || (Logger.error("❌ Missing RPC_URL") && raise "Missing RPC_URL")

payment_processor =
  env!("PAYMENT_PROCESSOR") ||
    (Logger.error("❌ Missing PAYMENT_PROCESSOR") && raise "Missing PAYMENT_PROCESSOR")

creepy_wallet =
  env!("CREEPY_WALLET") ||
    (Logger.error("❌ Missing CREEPY_WALLET") && raise "Missing CREEPY_WALLET")

private_key =
  env!("PRIVATE_KEY") || (Logger.error("❌ Missing PRIVATE_KEY") && raise "Missing PRIVATE_KEY")

hidden_seed =
  env!("HIDDEN_SEED") || (Logger.error("❌ Missing HIDDEN_SEED") && raise "Missing HIDDEN_SEED")

config :creepy_pay, :rpc_url, rpc_url
config :creepy_pay, :payment_processor, payment_processor
config :creepy_pay, :private_key, private_key
config :creepy_pay, :creepy_wallet, creepy_wallet
config :creepy_pay, :hidden_seed, hidden_seed

config :creepy_pay, CreepyPay.Repo,
  username: "postgres",
  password: "postgres",
  database: "creepy_pay_db",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  ecto_repos: [CreepyPay.Repo]

config :creepy_pay, CreepyPay.Auth.Guardian,
  issuer: :creepy_pay,
  secret_key: hidden_seed

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  config :creepy_pay, CreepyPayWeb.Endpoint,
    https: [
      port: 443,
      cipher_suite: :strong,
      keyfile: System.get_env("SSL_KEY_PATH"),
      certfile: System.get_env("SSL_CERT_PATH")
    ]

  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :creepy_pay, CreepyPayWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :creepy_pay, CreepyPay.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
