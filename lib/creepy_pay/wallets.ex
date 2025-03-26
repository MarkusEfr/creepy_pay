defmodule CreepyPay.Wallets do
  alias CreepyPay.Repo
  alias CreepyPay.Wallets.Wallet

  require Logger

  def create_wallet do
    case(generate_wallet_from_node()) do
      %{"address" => address, "privateKey" => private_key} ->
        index = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

        wallet_attrs = %{
          wallet_index: index,
          private_key_shadow: private_key,
          address: address
        }

        case wallet_attrs |> Wallet.new() |> Repo.insert() do
          {:ok, wallet} -> wallet
          {:error, changeset} -> {:error, changeset.errors}
        end

      err ->
        Logger.error("❌ Wallet creation failed: #{inspect(err)}")
        {:error, err}
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
  Retrieves a wallet by ID.
  """
  def get_wallet(wallet_id), do: Repo.get(Wallet, wallet_id)
end
