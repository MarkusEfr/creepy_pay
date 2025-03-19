defmodule CreepyPay.StealthPay do
  require Logger
  alias Finch
  alias Jason
  alias QRCode

  # Step 1: Generate Payment Request
  def generate_payment_request(
        %{merchant_gem_crypton: merchant_gem_crypton, amount: amount_wei} = _params
      ) do
    %CreepyPay.Wallets.Wallet{address: _address} =
      wallet = CreepyPay.Wallets.create_wallet(%{merchant_gem_crypton: merchant_gem_crypton})

    {:ok, _payment} =
      CreepyPay.Payments.store_payment(%{
        merchant_gem_crypton: merchant_gem_crypton,
        amount: amount_wei,
        wallet: wallet
      })
  end

  # Step 2: Process Payment (Generate Unsigned TX + Ethereum Payment Link + QR Code)
  def process_payment(payment_metacore) do
    case CreepyPay.Payments.get_payment(payment_metacore)
         |> IO.inspect(label: "[DEBUG] Payment") do
      {:ok,
       %CreepyPay.Payments{amount: amount_wei, status: "pending", stealth_address: address} =
           payment}
      when amount_wei > 0 ->
        with {:ok, unsigned_tx} <-
               create_unsigned_tx(payment_metacore, address, amount_wei)
               |> IO.inspect(label: "[DEBUG] Unsigned TX"),
             {:ok, eth_payment_link} <- generate_ethereum_payment_link(payment),
             {:ok, qr_base64} <- generate_qr_code(eth_payment_link) do
          payment_data = %{
            unsigned_tx: unsigned_tx,
            eth_payment_link: eth_payment_link,
            amount: amount_wei,
            qr_code: qr_base64
          }

          {:ok, payment_data}
        else
          {:error, msg} -> {:error, "Failed to process payment: #{inspect(msg)}"}
        end

      {:ok, _} ->
        {:error, "Payment already processed"}

      {:error, _} ->
        {:error, "Payment not found"}
    end
  end

  # Step 3: Verify Payment Status
  def verify_payment(payment_metacore) do
    case CreepyPay.Payments.get_payment(payment_metacore)
         |> IO.inspect(label: "[DEBUG] Payment") do
      {:ok, %{payment_status: status}} -> {:ok, status}
      _ -> {:error, "Payment not found"}
    end
  end

  # Generates an unsigned transaction for payment processing
  defp create_unsigned_tx(payment_metacore, recipient, amount) do
    encoded_tx =
      encode_function("processPayment(bytes32,address,uint256)", [
        payment_metacore,
        recipient,
        amount
      ])

    {:ok,
     %{
       "to" => get_payment_processor(),
       "gas" => "0x5208",
       "gasPrice" => "0x3B9ACA00",
       "value" => "0x" <> amount,
       "data" => encoded_tx
     }}
  end

  defp generate_ethereum_payment_link(%{
         payment_metacore: payment_metacore,
         amount: amount_wei,
         merchant_gem_crypton: _merchant_gem,
         stealth_address: address
       }) do
    payment_contract = get_payment_processor()
    # Sepolia Testnet
    chain_id = "11155111"
    hashed_payment_id = payment_metacore |> transform_payment_id()

    eth_payment_link =
      "ethereum:#{payment_contract}@#{chain_id}/createPayment" <>
        "?payment_metacore=#{hashed_payment_id}" <>
        "&stealth_address=#{address}" <>
        "&value=#{amount_wei}"

    {:ok, eth_payment_link}
  end

  def generate_unlock_time(hours_from_now) do
    DateTime.utc_now()
    # Convert hours to seconds
    |> DateTime.add(hours_from_now * 3600, :second)
    |> DateTime.to_unix()
  end

  defp generate_qr_code(eth_payment_link) do
    qr_png =
      eth_payment_link
      |> QRCode.create()
      |> QRCode.render(:png, %QRCode.Render.PngSettings{
        background_color: {11, 214, 106},
        scale: 5
      })

    {:ok, _} = QRCode.to_base64(qr_png)
  end

  # Encodes contract function calls for Ethereum transactions
  defp encode_function(function_name, args) do
    string_function_name = to_string(function_name)

    selector =
      :sha3_256
      |> :crypto.hash(string_function_name)
      |> binary_part(0, 4)
      |> Base.encode16(case: :lower)

    encoded_args =
      Enum.map(args, fn
        arg when is_integer(arg) ->
          Integer.to_string(arg, 16) |> String.pad_leading(64, "0")

        arg when is_integer(arg) ->
          Integer.to_string(arg, 16) |> String.pad_leading(64, "0")

        # Convert Decimal to integer
        arg when is_struct(arg, Decimal) ->
          Decimal.to_integer(arg)

        arg when is_binary(arg) ->
          arg

        arg ->
          raise ArgumentError, "Unsupported argument type: #{inspect(arg)}"
      end)
      |> Enum.map_join("-")

    "0x" <> selector <> encoded_args
  end

  defp transform_payment_id(payment_metacore) do
    # Remove hyphens and downcase to ensure uniformity
    cleaned_id = String.replace(payment_metacore, "-", "") |> String.downcase()

    # Hash the cleaned ID using SHA3-256
    hash = :crypto.hash(:sha3_256, cleaned_id)

    # Convert binary hash to hex string with "0x" prefix for Solidity compatibility
    "0x" <> Base.encode16(hash, case: :lower)
  end

  defp get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor, nil)
end
