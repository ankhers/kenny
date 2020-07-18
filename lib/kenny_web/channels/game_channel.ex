defmodule KennyWeb.GameChannel do
  use KennyWeb, :channel

  def join("game:" <> game, _message, socket) do
    socket = assign(socket, :game, game)
    status = status_to_json(Kenny.Stationeers.status(Kenny.Stationeers))
    {:ok, status, socket}
  end

  def handle_in("start_server", _params, socket) do
    response = Kenny.Stationeers.start(Kenny.Stationeers)
    {:reply, {:ok, %{status: response}}, socket}
  end

  defp status_to_json(:down), do: %{status: :down}
  defp status_to_json(n), do: %{status: :up, n: n}
end
