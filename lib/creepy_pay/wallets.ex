defmodule CreepyPay.Wallets do
  import Ecto.Query
  alias CreepyPay.Repo
  alias CreepyPay.Wallets.Wallet

  require Logger

  def create_wallet(merchant_gem) do
    case generate_wallet_from_node() do
      %{"address" => address, "privateKey" => pk, "mnemonic" => phrase} ->
        index = get_next_wallet_index(merchant_gem)

        wallet_attrs = %{
          merchant_gem: merchant_gem,
          wallet_index: index,
          mnemonic: phrase,
          private_key: pk,
          address: address
        }

        Logger.info("Wallet created: #{inspect(wallet_attrs)}")

        wallet_attrs
        |> Wallet.new()
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def generate_wallet_from_node do
    path = Path.join(["assets", "js", "generate_wallet.mjs"])

    case System.cmd("node", [path]) do
      {json, 0} -> Jason.decode!(json)
      {err, code} -> {:error, "Node script failed (code #{code}): #{err}"}
    end
  end

  @doc """
  Updates a wallet with the provided attributes.
  """
  def update_wallet(wallet_id, attrs) do
    Repo.get(Wallet, wallet_id)
    |> Wallet.changeset(attrs)
    |> Repo.update()
  end

  def delete_wallet(wallet_id), do: Repo.delete(Repo.get(Wallet, wallet_id))

  @doc """
  Retrieves the next available wallet index for a merchant.
  """
  def get_next_wallet_index(merchant_gem) do
    case Repo.one(
           from(w in Wallet, where: w.merchant_gem == ^merchant_gem, select: max(w.wallet_index))
         ) do
      nil -> 0
      index -> index + 1
    end
  end

  @doc """
  Retrieves a wallet by ID.
  """
  def get_wallet(wallet_id), do: Repo.get(Wallet, wallet_id)

  @doc """
  Retrieves a wallet by merchant_gem.
  """
  def get_wallet_by_merchant(merchant_gem) do
    from(w in Wallet,
      where: w.merchant_gem == ^merchant_gem,
      left_join: p in CreepyPay.Payments,
      on: p.stealth_address == w.address,
      where: is_nil(p.id),
      select: w
    )
    |> Repo.all()
  end

  defp hidden_seed_key, do: Application.get_env(:creepy_pay, :hidden_seed, nil)
end
