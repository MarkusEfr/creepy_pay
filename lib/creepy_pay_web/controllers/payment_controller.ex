defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.StealthPay

  require Logger

  def generate_payment_request(conn, %{
        "payment_id" => payment_id,
        "recipient" => _recipient,
        "amount_wei" => amount_wei
      }) do
    key = StealthPay.get_private_key()
    hash = :crypto.hash(:sha3_256, payment_id <> key)
    stealth_address = "0x" <> Base.encode16(binary_part(hash, 12, 20), case: :lower)

    Logger.info("✅ Generated stealth address: #{stealth_address} for payment_id #{payment_id}")

    CreepyPay.Payments.store_payment(payment_id, stealth_address, amount_wei)

    json(conn, %{status: "success", stealth_address: stealth_address, amount: amount_wei})
  end

  def process_payment(conn, %{"payment_id" => payment_id}) do
    case StealthPay.process_payment(payment_id) do
      {:ok, stealth_address} -> json(conn, %{status: "success", stealth_address: stealth_address})
      {:error, reason} -> json(conn, %{status: "failed", reason: reason})
    end
  end

  def verify(conn, %{"payment_id" => payment_id}) do
    case StealthPay.verify_payment(payment_id) do
      {:ok, status} -> json(conn, %{status: status})
      {:error, reason} -> json(conn, %{status: "failed", reason: reason})
    end
  end

  def claim(conn, %{"payment_id" => payment_id, "recipient" => recipient}) do
    case StealthPay.claim(payment_id, recipient) do
      {:ok, _} -> json(conn, %{status: "claimed"})
      _ -> json(conn, %{status: "failed"})
    end
  end
end
