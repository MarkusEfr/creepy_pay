defmodule CreepyPay.StealthPay do
  require Logger
  import CreepyPay.Validates.PaymentFlow
  alias QRCode

  @node_script "assets/js/payment_contractor.mjs"
  @default_data "0x"

  def generate_payment_request(%{amount: amount_wei, madness_key_hash: madness_key_hash}) do
    CreepyPay.Payments.store_payment(%{
      amount: amount_wei,
      madness_key_hash: madness_key_hash
    })
  end

  def release_payment(%{madness_key: madness_key, recipient: recipient}) do
    key_hash_hex = hash_hex(madness_key)
    trace_id = payment_metacore_to_integer(madness_key)

    Logger.info("Processing payment trace_id=#{trace_id} and key #{key_hash_hex} to #{recipient}")

    case call_node("releasePayment", [key_hash_hex, recipient, inspect(trace_id), @default_data]) do
      {result, 0} ->
        case safe_decode(result) do
          {:ok, decoded} -> {:ok, decoded}
          err -> err
        end

      {result, 1} ->
        case safe_decode(result) do
          {:ok, decoded} -> {:error, decoded["error"] || "Unknown reason"}
          err -> err
        end
    end
  end

  def process_payment(%{payment_metacore: metacore}) do
    with {:ok, %{amount: amount_wei, madness_key_hash: key_hash} = _payment} <-
           validate_payment_waiting_invoke(%{"payment_metacore" => metacore}),
         trace_id <- payment_metacore_to_integer(metacore),
         contract <- get_payment_processor(),
         key_hash_hex <- hash_hex(key_hash),
         {result, 0} <-
           call_node("offerBloodOath", [
             key_hash_hex,
             contract,
             inspect(trace_id),
             amount_wei
           ]),
         {:ok, %{"data" => data, "link" => eth_link, "value" => value}} <- safe_decode(result),
         {:ok, qr_code} <- generate_qr_code(eth_link) do
      Logger.info(
        "✅ Payment prepared for trace_id: #{trace_id}, amount: #{amount_wei}, with key_hash_hex: #{key_hash_hex}"
      )

      deeplinks = build_deeplinks(to: contract, value: value, data: data)

      invoice_details = %{
        link: eth_link,
        qr_code: qr_code,
        data: data,
        deeplinks: deeplinks
      }

      {:ok, %CreepyPay.Payments{}} =
        CreepyPay.Payments.update_invoice_details(metacore, invoice_details)
    else
      {error_result, 1} ->
        with {:ok, decoded} <- safe_decode(error_result),
             reason <- decoded["error"] || decoded["reason"] || "Unknown failure" do
          Logger.error("❌ Payment processing failed: #{reason}")
          {:error, reason}
        else
          _ -> {:error, "Unrecognized failure"}
        end

      {:error, %Jason.DecodeError{} = decode_err} ->
        Logger.error("❌ Failed to decode JSON: #{inspect(decode_err)}")
        {:error, "Decode error"}

      result ->
        Logger.error("❌ Unexpected process result: #{inspect(result)}")
        {:error, "Unexpected error: #{inspect(result)}"}
    end
  end

  def vault_balance(%{madness_key_hash: key_hash}) do
    call_node("scryInfernalBalance", [hash_hex(key_hash)])
  end

  def get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor)

  defp call_node(function, args) do
    System.cmd("node", [@node_script, function | args], env: node_env())
  end

  defp node_env do
    %{
      "RPC_URL" => Application.get_env(:creepy_pay, :rpc_url),
      "PRIVATE_KEY" => Application.get_env(:creepy_pay, :private_key),
      "PAYMENT_PROCESSOR" => get_payment_processor()
    }
  end

  defp build_deeplinks(to: to, value: value, data: data) do
    %{
      metamask: "https://metamask.app.link/send/#{to}?value=#{value}&data=#{data}",
      trustwallet: "https://link.trustwallet.com/send?to=#{to}&value=#{value}&data=#{data}"
    }
  end

  defp payment_metacore_to_integer(payment_metacore) do
    payment_metacore
    |> normalize_hex_string()
    |> then(&:crypto.hash(:sha3_256, &1))
    |> :binary.decode_unsigned()
  end

  defp hash_hex(str) do
    str
    |> normalize_hex_string()
    |> then(&:crypto.hash(:sha3_256, &1))
    |> Base.encode16(case: :lower)
    |> then(&("0x" <> &1))
  end

  defp normalize_hex_string(str) do
    str
    |> String.replace(~r/[-0x]/, "")
    |> String.downcase()
  end

  defp safe_decode(result) do
    result
    |> String.trim()
    |> case do
      "" -> {:error, "Empty result from Node"}
      body -> Jason.decode(body)
    end
  end

  defp generate_qr_code(link) do
    with {:ok, %QRCode.QR{}} = qr <-
           QRCode.create(link),
         {:ok, _image} = bin_qr <-
           QRCode.render(qr, :png, %QRCode.Render.PngSettings{
             scale: 4,
             qrcode_color: {0, 128, 0},
             background_color: {255, 255, 255}
           }),
         {:ok, base64} <- QRCode.Render.to_base64(bin_qr) do
      {:ok, "data:image/png;base64," <> base64}
    end
  end
end
