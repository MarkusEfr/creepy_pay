defmodule CreepyPay.Wallets.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:wallet_index, :address, :inserted_at]}
  schema "wallets" do
    field(:wallet_index, :integer, default: 0)
    field(:address, :string)
    field(:private_key_shadow, :binary)

    timestamps()
  end

  def new(attrs \\ %{}), do: %__MODULE__{} |> changeset(attrs)

  @doc """
  Changeset for Wallet validation.
  """
  def changeset(wallet, attrs \\ %{}) do
    wallet
    |> cast(attrs, [
      :wallet_index,
      :address,
      :private_key_shadow
    ])
    |> validate_required([
      :wallet_index,
      :address,
      :private_key_shadow
    ])
    |> unique_constraint(:address)
  end
end
