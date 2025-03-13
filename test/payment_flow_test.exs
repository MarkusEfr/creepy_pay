defmodule CreepyPay.PaymentFlowTest do
  use CreepyPayWeb.ConnCase, async: true

  test "full merchant register, auth, and payment flow", %{conn: conn} do
    email = "test#{System.unique_integer()}@merchant.com"

    merchant_data = %{
      "shitty_name" => "TestMerchant",
      "email" => email,
      "madness_key" => :crypto.strong_rand_bytes(32)
    }

    # Register
    conn = post(conn, "/api/merchant/register", merchant_data)
    assert %{"merchant_gem_crypton" => merchant_gem_crypton} = json_response(conn, 200)

    # Login
    conn =
      post(conn, "/api/merchant/login", %{
        "identifier" => email,
        "madness_key" => merchant_data["madness_key"]
      })

    assert %{"token" => token} = json_response(conn, 200)

    # Create Wallet
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> post("/api/wallet/create", %{"merchant_gem_crypton" => merchant_gem_crypton})

    assert %{
      "wallet" => %{
        "address" => _,
        "inserted_at" => _,
        "merchant_gem_crypton" => ^merchant_gem_crypton,
        "wallet_index" => 0
      }
    } = json_response(conn, 200)

    # Generate Payment
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> post("/api/payment/generate", %{
        "merchant_gem_crypton" => merchant_gem_crypton,
        "amount_wei" => "1000000000000000000"
      })

    assert %{"payment" => %{"payment_metacore" => _payment_id}} = json_response(conn, 200)
  end
end
