defmodule CreepyPayWeb.Router do
  use CreepyPayWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :auth do
    plug(Guardian.Plug.Pipeline,
      module: CreepyPay.Auth.Guardian,
      error_handler: CreepyPayWeb.AuthErrorHandler
    )

    plug(Guardian.Plug.VerifyHeader, scheme: "Bearer")
    plug(Guardian.Plug.LoadResource)

    plug(Plug.Parsers,
      parsers: [:json],
      pass: ["application/json"],
      json_decoder: Jason
    )
  end

  scope "/api/merchant", CreepyPayWeb do
    pipe_through(:api)

    # Merchant API
    post("/register", MerchantController, :register)
    post("/login", MerchantController, :login)
  end

  scope "/api", CreepyPayWeb do
    pipe_through(:api)
    pipe_through(:auth)

    # Payment API
    post("/payment/create", PaymentController, :create_payment)
    post("/payment/process", PaymentController, :process_payment)
    get("/payment/details/:payment_metacore", PaymentController, :get_payment_details)
    get("/payment/verify/:payment_metacore", PaymentController, :verify_payment)
    post("/payment/claim", PaymentController, :claim)

    # Wallet API
    post("/wallet/create", WalletController, :create_wallet)
    get("/wallet/:wallet_id", WalletController, :get_wallet)
    get("/wallets/:merchant_gem_crypton", WalletController, :list_wallets)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:creepy_pay, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: CreepyPayWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
