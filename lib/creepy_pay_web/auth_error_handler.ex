defmodule CreepyPayWeb.AuthErrorHandler do
  import Plug.Conn
  require Logger

  @doc """
  Handles authentication errors and sends a JSON response with a clear error message.
  """
  def auth_error(conn, {type, reason}, _opts) do
    Logger.warning("Authentication error: #{inspect(type)} - #{inspect(reason)}")

    error_message =
      case type do
        :unauthenticated -> "You must be logged in to access this resource."
        :unauthorized -> "You are not authorized to perform this action."
        _ -> "Authentication failed. Please try again."
      end

    conn
    |> put_status(401)
    |> put_resp_content_type("application/json")
    |> Jason.encode(%{error: error_message})
  end
end
