defmodule Pokerboy.GameChannel do
  @moduledoc """
  Responsible for the back-and-forth messaging of web socket information for
  each game.
  """
  use Pokerboy.Web, :channel

  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("game:" <> uuid, %{"name" => name}, socket) do
    alias Pokerboy.{GameServer, Player}

    name = Player.sanitize_name(name)

    cond do
      !GameServer.game_exists?(uuid) ->
        %{uuid: uuid, password: _password} = create_game(uuid)
        socket = join_game(socket, name, uuid)
        {:ok, socket}

      !GameServer.user_available?(uuid, name) ->
        {:error, %{reason: "username unavailable"}}

      is_nil(name) || String.length(name) == 0 ->
        {:error, %{reason: "invalid username"}}

      true ->
        socket = join_game(socket, name, uuid)
        {:ok, socket}
    end
  end

  def handle_in("create", _, socket) do
    uuid = Ecto.UUID.generate()
    %{uuid: uuid, password: password} = create_game(uuid)
    push(socket, "created", %{uuid: uuid, password: password})
    {:noreply, socket}
  end

  def handle_in("become_admin", %{"password" => password}, socket) do
    resp = Pokerboy.GameServer.become_admin(socket.assigns.game_id, socket.assigns.name, password)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("user_promote", %{"user" => name}, socket) do
    resp = Pokerboy.GameServer.user_promote(socket.assigns.game_id, socket.assigns.user_id, name)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("user_vote", %{"vote" => vote}, socket) do
    resp = Pokerboy.GameServer.user_vote(socket.assigns.game_id, socket.assigns.user_id, vote)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("toggle_playing", %{"user" => name}, socket) do
    resp =
      Pokerboy.GameServer.toggle_playing(socket.assigns.game_id, socket.assigns.user_id, name)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("kick_player", %{"user" => name}, socket) do
    resp = Pokerboy.GameServer.kick_player(socket.assigns.game_id, socket.assigns.user_id, name)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("reveal", _, socket) do
    resp = Pokerboy.GameServer.reveal(socket.assigns.game_id, socket.assigns.user_id)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("reset", _, socket) do
    resp = Pokerboy.GameServer.reset(socket.assigns.game_id, socket.assigns.user_id)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("valid_votes", _, socket) do
    resp = Pokerboy.GameServer.valid_votes()

    push(socket, "valid_votes", resp)
    {:noreply, socket}
  end

  def terminate(_, socket) do
    if Map.has_key?(socket.assigns, :user_id) do
      resp = Pokerboy.GameServer.leave(socket.assigns.game_id, socket.assigns.user_id)
      update_game(socket, resp)
    end

    :ok
  end

  def handle_info(:after_join, socket) do
    resp = Pokerboy.GameServer.get_state(socket.assigns.game_id)

    push(socket, "current_user", %{status: :ok, name: socket.assigns.name})

    update_game(socket, resp)
    {:noreply, socket}
  end

  intercept(["game_update"])

  def handle_out("game_update", %{state: _} = response, socket) do
    if Map.has_key?(response.state.users, socket.assigns.user_id) do
      push(socket, "game_update", response |> sanatize_state)
    end

    {:noreply, socket}
  end

  def handle_out("game_update", %{message: _} = response, socket) do
    push(socket, "game_update", response |> sanatize_state)
    {:noreply, socket}
  end

  defp update_game(socket, response) do
    broadcast!(socket, "game_update", response)
  end

  defp sanatize_state(%{status: :error, message: message}) do
    %{status: :error, message: message}
  end

  defp sanatize_state(%{status: :ok, state: state}) do
    %{
      status: :ok,
      state: %{
        is_showing: state.is_showing,
        users: sanatize_users(state.users, state.is_showing)
      }
    }
  end

  defp sanatize_users(users, show_vote?) do
    users
    |> Map.values()
    |> Enum.map(fn x ->
      x = x |> Map.from_struct() |> Map.delete(:id)

      if show_vote? do
        x
      else
        x = Map.delete(x, :original_vote)
        %{x | vote: !is_nil(x.vote)}
      end
    end)
    |> Map.new(fn x -> {x.name, x} end)
  end

  defp create_game(key) do
    password = Ecto.UUID.generate()
    game_settings = %{uuid: key, password: password}
    Pokerboy.GameSupervisor.start_game(game_settings)
    %{uuid: key, password: password}
  end

  defp join_game(socket, name, uuid) do
    alias Pokerboy.GameServer

    %{uuid: user_uuid, state: _} = GameServer.user_join(uuid, name)

    socket =
      socket
      |> assign(:game_id, uuid)
      |> assign(:name, name)
      |> assign(:user_id, user_uuid)

    send(self(), :after_join)

    socket
  end
end
