defmodule CreepyPay.Wallets.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:merchant_gem, :wallet_index, :address, :inserted_at]}
  schema "wallets" do
    field(:merchant_gem, :string)
    field(:wallet_index, :integer, default: 0)
    field(:mnemonic, :string)
    field(:address, :string)
    field(:private_key, :string)

    timestamps()
  end

  def new(attrs \\ %{}), do: %__MODULE__{} |> changeset(attrs)

  @doc """
  Changeset for Wallet validation.
  """
  def changeset(wallet, attrs \\ %{}) do
    wallet
    |> cast(attrs, [:merchant_gem, :wallet_index, :mnemonic, :address, :private_key])
    |> validate_required([
      :merchant_gem,
      :wallet_index,
      :mnemonic,
      :address,
      :private_key
    ])
    |> unique_constraint(:address)
  end
end
