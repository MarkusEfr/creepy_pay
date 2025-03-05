defmodule CreepyPay.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets) do
      add :merchant_gem, :string, null: false
      add :wallet_index, :integer, default: 0, null: false
      add :mnemonic, :string, null: false
      add :root_key, :string, null: false
      add :address, :string, null: false
      add :private_key, :string, null: false

      timestamps()
    end

    create unique_index(:wallets, [:merchant_gem, :wallet_index])
    create unique_index(:wallets, [:address])
  end
end
