defmodule CreepyPay.Wallets do
  import Ecto.Query
  alias CreepyPay.Repo
  alias CreepyPay.Wallets.Wallet
  alias BlockKeys.{CKD, Ethereum, Mnemonic}

  @bip44_path "m/44'/60'/0'/0"

  @spec create_wallet(String.t()) :: {:ok, map()} | {:error, any()}
  def create_wallet(merchant_gem) do
    # Generate mnemonic and derive master private key
    mnemonic = Mnemonic.generate_phrase()
    seed = Mnemonic.generate_seed(mnemonic, hidden_seed_key())
    {master_priv, _master_pub} = CKD.master_keys(seed)

    # Derive child private key from master using BIP44 path
    index = get_next_wallet_index(merchant_gem)
    path = "#{@bip44_path}/#{index}"

    {:ok, child_priv} = CKD.child_key_private(master_priv, path)

    # Generate Ethereum address from child public key
    eth_address = Ethereum.address(child_priv, path)

    # Store wallet data
    wallet_attrs = %{
      merchant_gem: merchant_gem,
      wallet_index: index,
      mnemonic: mnemonic,
      root_key: master_priv,
      address: eth_address,
      private_key: child_priv
    }

    Wallet.new()
    |> Wallet.changeset(wallet_attrs)
    |> Repo.insert()
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
    Repo.get_by(Wallet, merchant_gem: merchant_gem)
  end

  defp hidden_seed_key, do: Application.get_env(:creepy_pay, :hidden_seed, nil)
end
