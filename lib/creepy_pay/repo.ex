defmodule CreepyPay.Repo do
  use Ecto.Repo,
    otp_app: :creepy_pay,
    adapter: Ecto.Adapters.Postgres
end
