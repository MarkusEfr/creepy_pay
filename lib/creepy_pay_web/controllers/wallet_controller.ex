defmodule CreepyPayWeb.WalletController do
  use CreepyPayWeb, :controller
  alias CreepyPay.Wallets

  @doc """
  Creates a new stealth wallet for a merchant.
  """
  def create_wallet(conn, %{"merchant_gem" => gem}) do
    {:ok, %CreepyPay.Wallets.Wallet{} = wallet} = Wallets.create_wallet(gem)

    json(conn, %{wallet: wallet})
  end

  @doc """
  Retrieves wallet details by wallet ID.
  """
  def get_wallet(conn, %{"wallet_id" => wallet_id}) do
    case Wallets.get_wallet(wallet_id) do
      {:ok, wallet} ->
        json(conn, %{wallet: wallet})

      {:error, _reason} ->
        json(conn, %{error: "Wallet not found"})
    end
  end

  @doc """
  Lists all wallets associated with a merchant.
  """
  def list_wallets(conn, %{"merchant_gem" => merchant_gem}) do
    wallets = Wallets.get_wallet_by_merchant(merchant_gem)
    json(conn, %{wallets: wallets})
  end

  @doc """
  Updates a wallet's metadata or status.
  """
  def update_wallet(conn, %{"wallet_id" => wallet_id, "updates" => updates}) do
    case Wallets.update_wallet(wallet_id, updates) do
      {:ok, wallet} ->
        json(conn, %{message: "Wallet updated successfully", wallet: wallet})

      {:error, reason} ->
        json(conn, %{error: "Failed to update wallet", reason: reason})
    end
  end

  @doc """
  Deletes a wallet by ID (if allowed).
  """
  def delete_wallet(conn, %{"wallet_id" => wallet_id}) do
    case Wallets.delete_wallet(wallet_id) do
      {:ok, _} ->
        json(conn, %{message: "Wallet deleted successfully"})

      {:error, reason} ->
        json(conn, %{error: "Failed to delete wallet", reason: reason})
    end
  end
end
