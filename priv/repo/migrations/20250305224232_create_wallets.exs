defmodule CreepyPay.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets) do
      add :merchant_gem_crypton, :binary, null: false
      add :wallet_index, :integer, default: 0, null: false
      add :address, :string, null: false
      add :private_key_shadow, :binary, null: false

      timestamps()
    end

    create unique_index(:wallets, [:merchant_gem_crypton, :wallet_index])
    create unique_index(:wallets, [:address])
  end
end
