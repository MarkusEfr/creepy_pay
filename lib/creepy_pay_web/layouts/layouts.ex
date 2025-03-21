defmodule CreepyPayWeb.Layouts do
  use CreepyPayWeb, :html
  embed_templates("layouts/*")

  def root(assigns) do
    ~H"""
    <div class="flex flex-col h-screen">
    <%= @inner_content %>
    </div>
    """
  end
end
