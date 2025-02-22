defmodule CreepyPay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CreepyPayWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:creepy_pay, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CreepyPay.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CreepyPay.Finch},
      # Start a worker by calling: CreepyPay.Worker.start_link(arg)
      # {CreepyPay.Worker, arg},
      # Start to serve requests, typically the last entry
      CreepyPayWeb.Endpoint
    ]
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    CreepyPay.Payments.setup()
    opts = [strategy: :one_for_one, name: CreepyPay.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CreepyPayWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
