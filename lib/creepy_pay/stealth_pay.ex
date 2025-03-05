defmodule CreepyPay.StealthPay do
  require Logger
  alias Jason
  alias Finch

  def generate_payment_request(payment_id, recipient, amount_wei) do
    payment_link = generate_payment_link(payment_id, amount_wei)
    qr_code_url = generate_qr_code(payment_link)
    unsigned_tx = generate_unsigned_tx(payment_id, amount_wei)

    {:ok,
     %{
       payment_id: payment_id,
       recipient: recipient,
       amount: amount_wei,
       payment_link: payment_link,
       qr_code: qr_code_url,
       unsigned_tx: unsigned_tx
     }}
  end

  def receive_payment(payment_id, _recipient, amount_wei) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, _} ->
        {:error, "Payment already exists"}

      {:error, _} ->
        CreepyPay.Payments.store_payment(payment_id, nil, amount_wei)
        {:ok, "Payment recorded, awaiting processing"}
    end
  end

  def process_payment(payment_id) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, %{status: "pending", amount: amount}} when amount > 0 ->
        case generate_stealth_address(payment_id) do
          {:ok, stealth_address} ->
            CreepyPay.Payments.update_payment_status(payment_id, "stealth_created")
            {:ok, stealth_address}

          {_, reason} ->
            {:error, "Failed to generate stealth address: #{reason}"}
        end

      {:ok, %{status: _status}} ->
        {:error, "Payment already processed"}

      {:error, _} ->
        {:error, "Payment not found"}
    end
  end

  defp generate_stealth_address(payment_id) do
    key = get_private_key()
    hash = :crypto.hash(:sha3_256, payment_id <> key)
    stealth_address = "0x" <> Base.encode16(binary_part(hash, 12, 20), case: :lower)

    Logger.info("✅ Generated stealth address: #{stealth_address} for payment_id #{payment_id}")

    CreepyPay.Payments.store_payment(payment_id, stealth_address, 0)
    {:ok, stealth_address}
  end

  def verify_payment(payment_id) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, %{stealth_address: address}} when not is_nil(address) ->
        with {:ok, balance} <- balance(address),
             true <- balance > 0 do
          CreepyPay.Payments.update_payment_status(payment_id, "paid")
          {:ok, "Payment received"}
        else
          _ -> {:ok, "Payment pending"}
        end

      _ ->
        {:error, "Payment not found"}
    end
  end

  def claim(payment_id, recipient) do
    Logger.info("🔓 Attempting to claim funds for payment_id=#{payment_id}")

    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, %{stealth_address: _address, status: "paid"}} ->
        data = encode_claim(payment_id, recipient)
        send_tx(data)
        CreepyPay.Payments.update_payment_status(payment_id, "claimed")
        {:ok, "Funds claimed"}

      _ ->
        {:error, "Funds not available"}
    end
  end

  defp encode_claim(payment_id, recipient) do
    hash = :crypto.hash(:sha3_256, "#{payment_id}#{recipient}")
    "0x" <> Base.encode16(hash, case: :lower)
  end

  defp balance(address) do
    request_rpc("eth_getBalance", [address, "latest"])
    |> case do
      {:ok, balance} when is_binary(balance) -> {:ok, String.to_integer(balance, 16)}
      _ -> {:ok, 0}
    end
  end

  defp send_tx(data) do
    Logger.info("🚀 Sending transaction: #{data}")
    :ok
  end

  defp generate_payment_link(payment_id, amount_wei) do
    "ethereum:#{get_payment_processor()}?data=#{payment_id}&value=#{amount_wei}"
  end

  defp generate_qr_code(payment_link) do
    with png_setting <- %QRCode.Render.PngSettings{
           qrcode_color: "#6495ED",
           background_color: "#FFFFFF"
         },
         created_qr <- QRCode.create(payment_link),
         rendered_qr <- QRCode.render(created_qr, :png, png_setting),
         {:ok, base64} <- QRCode.to_base64(rendered_qr) do
      "data:image/png;base64,#{base64}"
    else
      {:error, reason} ->
        Logger.error("❌ Failed to generate QR: #{reason}")
        {:error, reason}
    end
  end

  defp generate_unsigned_tx(payment_id, amount_wei) do
    %{
      "to" => get_payment_processor(),
      "value" => "0x" <> Integer.to_string(amount_wei, 16),
      "data" => "0x" <> Base.encode16(payment_id, case: :lower),
      "gas" => "0x5208"
    }
  end

  defp request_rpc(method, params) do
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(%{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => 1})

    Finch.build(:post, get_rpc_url(), headers, body)
    |> Finch.request(CreepyPay.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        Jason.decode!(response_body)["result"] |> (&{:ok, &1}).()

      _ ->
        {:error, "Request failed"}
    end
  end

  def get_private_key, do: Application.get_env(:creepy_pay, :private_key, nil)
  def get_rpc_url, do: Application.get_env(:creepy_pay, :rpc_url, nil)
  def get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor, nil)
end
