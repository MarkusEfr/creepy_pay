defmodule CreepyPay.Repo.Migrations.CreatePaymentsTable do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add :payment_metacore, :binary, primary_key: true
      add :merchant_gem_crypton, :binary, null: false
      add :stealth_address, :string
      add :amount, :string, null: false
      add :status, :string, default: "pending", null: false

      timestamps()
    end
  end
end
