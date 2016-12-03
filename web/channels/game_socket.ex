defmodule Pokerboy.GameChannel do
  use Pokerboy.Web, :channel

  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("game:" <> uuid, %{"name" => name}, socket) do
    alias Pokerboy.{Gameserver, Player}

    name = Player.sanitize_name(name)

    cond do
      !Gameserver.game_exists?(uuid) ->
        {:error, %{reason: "unauthorized"}}

      !Gameserver.user_available?(uuid, name) ->
        {:error, %{reason: "username unavailable"}}

      is_nil(name) || String.length(name) == 0 ->
        {:error, %{reason: "invalid username"}}

      true ->
        {:ok,
          socket
          |> assign(:game_id, uuid)
          |> assign(:name, name)
          |> assign(:user_id, Gameserver.user_join(uuid, name))
        }
    end
  end

  def handle_in("create", %{"name"=>name}, socket) do
    uuid = Ecto.UUID.generate()
    password = Ecto.UUID.generate()
    game_settings = %{name: name, uuid: uuid, password: password}
    Pokerboy.Gamesupervisor.start_game(game_settings)

    push socket, "created", %{ uuid: uuid, password: password }
    {:noreply, socket}
  end

  def handle_in("become_admin", %{"password"=>password}, socket) do
    resp = Pokerboy.Gameserver.become_admin(socket.assigns.game_id, socket.assigns.name, password)

    push socket, "user_authenticated", resp
    {:noreply, socket}
  end

  def handle_in("user_promote", %{"user"=>name}, socket) do
    resp = Pokerboy.Gameserver.user_promote(socket.assigns.game_id, socket.assigns.user_id, name)

    push socket, "user_authenticated", resp
    {:noreply, socket}
  end

  def handle_in("toggle_playing", %{"user"=>name}, socket) do
    resp = Pokerboy.Gameserver.toggle_playing(socket.assigns.game_id, socket.assigns.user_id, name)

    push socket, "user_toggled", resp
    {:noreply, socket}
  end
end