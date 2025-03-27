defmodule CreepyPay.Repo.Migrations.CreatePaymentsTable do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add(:payment_metacore, :string, primary_key: true)
      add(:madness_key_hash, :string, null: false)
      add(:amount, :string, null: false)
      add(:status, :string, default: "pending", null: false)
      add(:invoice_details, :map, default: %{}, null: false)

      timestamps()
    end
  end
end
