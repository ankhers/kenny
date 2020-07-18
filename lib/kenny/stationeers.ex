defmodule Kenny.Stationeers do
  use GenServer

  @opts Application.fetch_env!(:kenny, :stationeers)
  @password Keyword.get(@opts, :password)
  @base_url Keyword.get(@opts, :url)
  @instance_id Keyword.get(@opts, :instance_id)
  @command_url @base_url <> "console/run?command="
  @authenticate_command @command_url <> "login%20" <> @password
  @status_command @command_url <> "status"
  @refresh_time 60 * 1_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start(pid) do
    GenServer.call(pid, :start)
  end

  def shutdown(pid) do
    GenServer.call(pid, :shutdown)
  end

  def status(pid) do
    GenServer.call(pid, :status)
  end

  def init(:ok) do
    send(self(), :authenticate)
    {:ok, :down}
  end

  def handle_info(:authenticate, :down) do
    state =
      @authenticate_command
      |> get()
      |> handle_response(:authenticate)

    {:noreply, state}
  end

  def handle_info(:check, {cookie, _n} = state) do
    state =
      @status_command
      |> get(cookie)
      |> handle_response(state, :check)

    {:noreply, state}
  end

  def handle_call(:status, _from, :down) do
    {:reply, :down, :down}
  end

  def handle_call(:status, _from, {_cookie, status} = state) do
    {:reply, status, state}
  end

  def handle_call(:start, _from, state) do
    do_start()
    {:reply, :ok, state}
  end

  def schedule_work() do
    Process.send_after(self(), :check, @refresh_time)
  end

  defp handle_response({:ok, 200, response_headers, _client_ref}, :authenticate) do
    msg = %{status: :up, n: 0}
    KennyWeb.Endpoint.broadcast("game:stationeers", "update_status", msg)

    schedule_work()
    {:proplists.get_value("Set-Cookie", response_headers), 0}
  end

  defp handle_response({:error, _response}, :authenticate) do
    Process.send_after(self(), :authenticate, @refresh_time)

    :down
  end

  defp handle_response({:ok, 200, _response_headers, client_ref}, {cookie, n}, :check) do
    {:ok, body} = :hackney.body(client_ref)

    cond do
      Regex.match?(~r/\d+ Player\(s\) connected/, body) ->
        msg = %{status: :up, n: 0}
        KennyWeb.Endpoint.broadcast("game:stationeers", "update_status", msg)
        schedule_work()
        {cookie, 0}

      Regex.match?(~r/Please login first\.$/, body) ->
        send(self(), :authenticate)
        :down

      true ->
        schedule_work()
        m = n + 1
        maybe_shutdown(n, m)
        msg = %{status: :up, n: m}
        KennyWeb.Endpoint.broadcast("game:stationeers", "update_status", msg)
        {cookie, m}
    end
  end

  defp handle_response({:error, _response}, _state, :check) do
    send(self(), :authenticate)
    :down
  end

  defp maybe_shutdown(9, 10), do: do_shutdown()
  defp maybe_shutdown(_n, _m), do: :ok

  defp do_shutdown() do
    [@instance_id]
    |> ExAws.EC2.stop_instances()
    |> ExAws.request()
    |> case do
      {:ok, _result} -> :ok
      {:error, _result} -> Process.send_after(self(), :shutdown, 2_000)
    end
  end

  defp do_start() do
    [@instance_id]
    |> ExAws.EC2.start_instances()
    |> ExAws.request()
    |> case do
      {:ok, _result} -> :ok
      {:error, _result} -> Process.send_after(self(), :start, 2_000)
    end
  end

  defp get(url, cookie \\ nil) do
    headers =
      case cookie do
        nil -> []
        _ -> [{"Cookie", cookie}]
      end

    payload = <<>>
    options = []
    :hackney.request(:get, url, headers, payload, options)
  end
end
