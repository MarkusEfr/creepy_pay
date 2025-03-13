defmodule CreepyPay.Guardian.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :creepy_pay,
    module: CreepyPay.Auth.Guardian,
    error_handler: CreepyPay.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, scheme: "Bearer")
  # setup the upstream pipeline
  plug(Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"})
  plug(Guardian.Plug.EnsureAuthenticated, key: :jwt)
  plug(Guardian.Plug.LoadResource)
end
