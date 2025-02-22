defmodule CreepyPayWeb.PaymentControllerTest do
  use CreepyPayWeb.ConnCase
  alias CreepyPay.StealthPay

  @valid_recipient "0xabc123456789abcdef0123456789abcdef0123456"
  @valid_payment_id "A1B2C3D4E5F6G7H8"
  @valid_signature "0xsignature123"

  describe "POST /api/payment" do
    test "creates a stealth address", %{conn: conn} do
      conn = post(conn, "/api/payment", %{"recipient" => @valid_recipient})
      assert %{"payment_id" => _, "stealth_address" => _, "payment_link" => _} = json_response(conn, 200)
    end
  end

  describe "POST /api/payment/pay" do
    test "processes a valid payment", %{conn: conn} do
      conn = post(conn, "/api/payment/pay", %{"payment_id" => @valid_payment_id, "amount_wei" => "1000000000000000000"})
      assert %{"status" => "payment_sent"} = json_response(conn, 200)
    end

    test "fails on invalid amount", %{conn: conn} do
      conn = post(conn, "/api/payment/pay", %{"payment_id" => @valid_payment_id, "amount_wei" => "invalid_amount"})
      assert %{"status" => "failed"} = json_response(conn, 400)
    end
  end

  describe "GET /api/payment/:payment_id/verify" do
    test "verifies an existing stealth address", %{conn: conn} do
      StealthPay.generate_stealth_address(@valid_payment_id, @valid_recipient)
      conn = get(conn, "/api/payment/#{@valid_payment_id}/verify")
      assert %{"status" => "confirmed", "stealth_address" => _} = json_response(conn, 200)
    end

    test "returns not found for invalid payment_id", %{conn: conn} do
      conn = get(conn, "/api/payment/invalid_id/verify")
      assert %{"status" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/payment/claim" do
    test "claims funds with valid signature", %{conn: conn} do
      conn = post(conn, "/api/payment/claim", %{"payment_id" => @valid_payment_id, "recipient" => @valid_recipient, "signature" => @valid_signature})
      assert %{"status" => "claimed"} = json_response(conn, 200)
    end

    test "fails with invalid signature", %{conn: conn} do
      conn = post(conn, "/api/payment/claim", %{"payment_id" => @valid_payment_id, "recipient" => @valid_recipient, "signature" => "invalid_signature"})
      assert %{"status" => "failed"} = json_response(conn, 400)
    end
  end
end
