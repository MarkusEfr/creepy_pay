defmodule CreepyPay.StealthPay do
  require Logger
  alias Jason
  alias Finch
  alias QRCode

  @recipient "0x8888ee107011dFb0b8C51448f21C33DD690e7C88"

  # Step 1: Generate Payment Request
  def generate_payment_request(merchant_gem, amount_wei) do
    new_payment = %{
      merchant_gem: merchant_gem,
      amount: amount_wei
    }

    {:ok,
     %CreepyPay.Payments{
       payment_id: payment_id,
       status: _,
       merchant_gem: _,
       amount: _,
       stealth_address: _
     } = created_payment} = CreepyPay.Payments.store_payment(new_payment)

    {:ok, %{created_payment | payment_id: payment_id}}
  end

  # Step 2: Process Payment (Generate Unsigned TX + Ethereum Payment Link + QR Code)
  def process_payment(payment_id) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok,
       %CreepyPay.Payments{amount: amount_wei, status: "pending"} =
           payment}
      when amount_wei > 0 ->
        with {:ok, unsigned_tx} <- create_unsigned_tx(payment_id, @recipient, amount_wei),
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
  def verify_payment(payment_id) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, %{payment_status: status}} -> {:ok, status}
      _ -> {:error, "Payment not found"}
    end
  end

  # Generates an unsigned transaction for payment processing
  defp create_unsigned_tx(payment_id, recipient, amount) do
    encoded_tx =
      encode_function("processPayment(bytes32,address,uint256)", [payment_id, recipient, amount])

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
         payment_id: payment_id,
         amount: amount_wei,
         merchant_gem: _merchant_gem
       }) do
    factory_address = get_payment_processor()
    # Sepolia Testnet
    chain_id = "11155111"
    hashed_payment_id = payment_id |> transform_payment_id()

    unlock_time = generate_unlock_time(24)

    eth_payment_link =
      "ethereum:#{factory_address}@#{chain_id}/processPayment" <>
        "?payment_id=#{hashed_payment_id}" <>
        "&recipient=#{@recipient}" <>
        "&unlock_time=#{unlock_time}" <>
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
      |> Enum.join()

    "0x" <> selector <> encoded_args
  end

  defp transform_payment_id(payment_id) do
    # Remove hyphens and downcase to ensure uniformity
    cleaned_id = String.replace(payment_id, "-", "") |> String.downcase()

    # Hash the cleaned ID using SHA3-256
    hash = :crypto.hash(:sha3_256, cleaned_id)

    # Convert binary hash to hex string with "0x" prefix for Solidity compatibility
    "0x" <> Base.encode16(hash, case: :lower)
  end

  defp get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor, nil)
end
