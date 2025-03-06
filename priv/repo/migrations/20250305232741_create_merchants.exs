defmodule CreepyPay.Repo.Migrations.CreateMerchants do
  use Ecto.Migration

  def change do
    create table(:merchants) do
      add :merchant_gem, :string, null: false
      add :shitty_name, :string, null: false
      add :email, :string, null: false, unique: true
      add :madness_key_hash, :string, null: false
      timestamps()
    end

    create unique_index(:merchants, [:merchant_gem])
    create unique_index(:merchants, [:email])
  end
end
