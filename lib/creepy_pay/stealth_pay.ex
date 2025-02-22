defmodule CreepyPay.StealthPay do
  require Logger
  alias QRCode
  alias QRCode.Render.PngSettings
  alias Jason
  alias Finch

  def get_stealth_address(payment_id) do
    data = %{
      "jsonrpc" => "2.0",
      "method" => "eth_call",
      "params" => [
        %{
          "to" => get_creepy_wallet(),
          "data" => encode_payment("stealthAddresses(bytes32)", payment_id)
        },
        "latest"
      ],
      "id" => 1
    }
    url = get_rpc_url()
    case request(:post, url, data) do
      {:ok, "0x"} ->
        {:error, "Stealth address not found"}

      {:ok, address} ->
        {:ok, "0x" <> String.slice(address, 26, 40)}
      {:error, reason} ->
        Logger.error("❌ Failed to get stealth address: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec generate_stealth_address(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_stealth_address(payment_id, sender) do
    key = get_private_key()
    hash = :crypto.hash(:sha3_256, payment_id <> key)
    stealth_address = "0x" <> Base.encode16(binary_part(hash, 12, 20), case: :lower)
    Logger.info("✅ Generated stealth address: #{stealth_address} for payment_id #{payment_id}")
    case CreepyPay.Payments.store_payment(payment_id, 0, "pending") do
      %CreepyPay.Payments{} = payment ->
        {:ok, stealth_address}
      {:error, reason} ->
        Logger.error("❌ Failed to store payment: #{inspect(reason)}")
        {:error, "Failed to store payment"}
    end
  end

  def pay_link(payment_id, amount_wei, sender_address) do
    case get_stealth_address(payment_id) do
      {:ok, stealth_address} when is_binary(stealth_address) ->
        unsigned_tx = %{
          "from" => sender_address,
          "to" => stealth_address,
          "value" => "0x" <> Integer.to_string(amount_wei, 16),
          "gas" => "0x5208"
        }

        payment_link = "ethereum:#{stealth_address}?value=#{amount_wei}"
        qr_data_url = generate_qr_data_url(payment_link)

        {:ok,
         %{
           payment_id: payment_id,
           stealth_address: stealth_address,
           payment_link: payment_link,
           qr_data_url: qr_data_url,
           unsigned_tx: unsigned_tx
         }}

      {:error, reason} ->
        Logger.error("❌ Failed to fetch stealth address: #{reason}")
        {:error, reason}
    end
  end

  defp generate_qr_data_url(payment_link) do
    with png_setting <- %PngSettings{qrcode_color: "#6495ED", background_color: "#FFFFFF"},
         created_qr <- payment_link |> QRCode.create(),
         rendered_qr <- created_qr |> QRCode.render(:png, png_setting),
         {:ok, base64} <- QRCode.to_base64(rendered_qr) do
      "data:image/png;base64,#{base64}"
    else
      {:error, reason} ->
        Logger.error("❌ Failed to generate QR code: #{reason}")
        {:error, reason}
    end
  end

  def verify_payment(payment_id) do
    with {:ok, balance} <- balance(payment_id) do
      cond do
        balance > 0 ->
          Logger.info("✅ Payment received for #{payment_id}")
          {:ok, "Payment received"}

        balance == 0 ->
          Logger.warning("⚠️ Payment pending for #{payment_id}")
          {:ok, "Payment pending"}
      end
    else
      {:error, reason} ->
        Logger.error("❌ Payment verification failed: #{inspect(reason)}")
        {:error, "Failed to verify payment"}
    end
  end

  def balance(payment_id) do
    data = %{
      "jsonrpc" => "2.0",
      "method" => "eth_call",
      "params" => [
        %{
          "to" => get_creepy_wallet(),
          "data" => encode_payment("balance(bytes32)", payment_id)
        },
        "latest"
      ],
      "id" => 1
    }

    url = get_rpc_url()

    case request(:post, url, data) do
      {:ok, "0x"} ->
        {:ok, 0}

      {:ok, balance} when is_binary(balance) ->
        {:ok, String.to_integer(balance, 16)}

      {:error, reason} ->
        Logger.error("❌ Failed to get balance: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def claim(payment_id, recipient, signature) do
    Logger.info("🔓 Attempting to claim funds for payment_id=#{payment_id}")

    data = %{
      "jsonrpc" => "2.0",
      "method" => "eth_call",
      "params" => [
        %{
          "from" => recipient,
          "to" => get_creepy_wallet(),
          "data" => encode_claim(payment_id, recipient, signature),
          "gas" => "0xD2F0"
        }
      ],
      "id" => 1
    }

    url = get_rpc_url()

    case request(:post, url, data) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.error("❌ Claim failed for #{payment_id}: #{reason}")
        {:error, reason}
    end
  end

  def get_payment_status(payment_id) do
    data = %{
      "jsonrpc" => "2.0",
      "method" => "eth_call",
      "params" => [
        %{
          "to" => get_creepy_wallet(),
          "data" => encode_payment("getPaymentStatus(bytes32)", payment_id)
        },
        "latest"
      ],
      "id" => 1
    }

    url = get_rpc_url()

    case request(:post, url, data) do
      {:ok, status} ->
        {:ok, status}

      {:error, reason} ->
        Logger.error("❌ Failed to get payment status: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp encode_payment(function_name, payment_id) do
    function_selector = :crypto.hash(:sha3_256, function_name) |> binary_part(0, 4)
    padded_id = Base.decode16!(payment_id, case: :mixed) |> String.pad_leading(32, <<0>>)
    "0x" <> Base.encode16(function_selector <> padded_id, case: :lower)
  end

  defp encode_claim(payment_id, recipient, signature),
    do: "0x" <> Base.encode16(:crypto.hash(:sha3_256, "#{payment_id}#{recipient}#{signature}"))

  defp request(method, url, body) do
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(body)

    Finch.build(method, url, headers, body)
    |> Finch.request(CreepyPay.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"result" => result}} ->
            {:ok, result}

          {:ok, %{"error" => error}} ->
            Logger.error("❌ JSON-RPC Error: #{inspect(error)}")
            {:error, error["message"] || "Unknown JSON-RPC error"}

          {:error, decode_error} ->
            Logger.error("❌ JSON Decoding Error: #{inspect(decode_error)}")
            {:error, "Failed to parse JSON response"}
        end

      {:ok, %Finch.Response{status: status, body: error_body}} ->
        Logger.error("❌ Unexpected HTTP Error (#{status}): #{inspect(error_body)}")
        {:error, "Unexpected HTTP error: #{status}"}

      {:error, request_error} ->
        Logger.error("❌ Request Execution Error: #{inspect(request_error)}")
        {:error, "Failed to send request"}
    end
  end

  defp get_creepy_wallet, do: Application.get_env(:creepy_pay, :creepy_wallet)
  defp get_rpc_url, do: Application.get_env(:creepy_pay, :rpc_url)
  defp get_private_key, do: Application.get_env(:creepy_pay, :private_key)
end
