defmodule CreepyPay.StealthPay do
  require Logger
  import CreepyPay.Validates.PaymentFlow
  alias QRCode

  @node_script "assets/js/payment_contractor.mjs"
  @default_data "0x"
  @default_trace "0x"

  def generate_payment_request(%{amount: amount_wei, madness_key_hash: madness_key_hash}) do
    CreepyPay.Payments.store_payment(%{
      amount: amount_wei,
      madness_key_hash: madness_key_hash
    })
  end

  def release_payment(%{madness_key: madness_key, recipient: recipient}) do
    call_node("unleashDamnation", [
      hash_hex(madness_key),
      recipient,
      @default_data,
      @default_trace,
      "0x"
    ])

    :ok
  end

  def process_payment(%{payment_metacore: metacore}) do
    with {:ok, %{amount: amount_wei, madness_key_hash: key_hash} = payment} <-
           validate_payment_waiting_invoke(%{"payment_metacore" => metacore}),
         trace_id <- payment_metacore_to_integer(metacore),
         contract <- get_payment_processor() do
      {result_json, 0} =
        call_node("offerBloodOath", [
          hash_hex(key_hash),
          contract,
          inspect(trace_id),
          amount_wei
        ])

      %{"data" => data, "eth_link" => eth_link, "value" => value} = Jason.decode!(result_json)
      {:ok, qr_code} = generate_qr_code(eth_link)

      {:ok,
       %{
         link: eth_link,
         qr_code: qr_code,
         data: data,
         deeplinks: build_deeplinks(to: contract, value: value, data: data),
         entity: payment
       }}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Unexpected error"}
    end
  end

  def vault_balance(%{madness_key_hash: key_hash}) do
    call_node("scryInfernalBalance", [hash_hex(key_hash)])
  end

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

  defp generate_qr_code(link) do
    with {:ok, %QRCode.QR{}} = qr <-
           QRCode.create(link) |> IO.inspect(label: "[DEBUG] create qr"),
         {:ok, image} = bin_qr <-
           QRCode.render(qr, :png, %QRCode.Render.PngSettings{
             scale: 4,
             qrcode_color: {0, 128, 0},
             background_color: {255, 255, 255}
           })
           |> IO.inspect(label: "[DEBUG] render qr"),
         {:ok, base64} = base_qr <- QRCode.Render.to_base64(bin_qr) do
      {:ok, "data:image/png;base64," <> base64}
    end
  end

  defp get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor)
end
