defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.StealthPay

  def generate_stealth(conn, %{"payment_id" => payment_id}) do
    case StealthPay.generate_stealth_address(payment_id) do
      {:ok, stealth_address} ->
        json(conn, %{status: "success", stealth_address: stealth_address})
      _ ->
        json(conn, %{status: "failed", reason: "Failed to generate stealth address"})
    end
  end

  def get_stealth_address(conn, %{"payment_id" => payment_id}) do
    case StealthPay.get_stealth_address(payment_id) do
      {:ok, stealth_address} ->
        json(conn, %{status: "success", stealth_address: stealth_address})
      {:error, reason} ->
        json(conn, %{status: "failed", reason: reason})
    end
  end

  def pay(conn, %{"payment_id" => payment_id, "amount_wei" => amount_wei, "sender_address" => sender_address}) do
    case StealthPay.pay_link(payment_id, amount_wei, sender_address) do
      {:ok, %{payment_link: payment_link, qr_data_url: qr_data_url, stealth_address: stealth_address}} ->
        json(conn, %{
          status: "waiting_for_payment",
          payment_link: payment_link,
          qr_data_url: qr_data_url,
          stealth_address: stealth_address
        })
      {:error, reason} ->
        json(conn, %{status: "failed", reason: reason})
    end
  end

  def verify(conn, %{"payment_id" => payment_id}) do
    case StealthPay.verify_payment(payment_id) do
      {:ok, status} -> json(conn, %{status: status})
      {:error, reason} -> json(conn, %{status: "failed", reason: reason})
    end
  end

  def balance(conn, %{"payment_id" => payment_id}) do
    case StealthPay.balance(payment_id) do
      {:ok, balance} -> json(conn, %{payment_id: payment_id, balance: balance})
      _ -> json(conn, %{status: "failed"})
    end
  end

  def claim(conn, %{"payment_id" => payment_id, "recipient" => recipient, "signature" => signature}) do
    case StealthPay.claim(payment_id, recipient, signature) do
      {:ok, _} -> json(conn, %{status: "claimed"})
      _ -> json(conn, %{status: "failed"})
    end
  end

  def get_status(conn, %{"payment_id" => payment_id}) do
    case StealthPay.get_payment_status(payment_id) do
      {:ok, status} -> json(conn, %{status: status})
      {:error, reason} -> json(conn, %{status: "failed", reason: reason})
    end
  end
end
