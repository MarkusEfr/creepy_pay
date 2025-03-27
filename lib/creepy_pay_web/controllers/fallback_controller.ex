defmodule CreepyPayWeb.FallbackController do
  use CreepyPayWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> render("404.html")
  end
end
