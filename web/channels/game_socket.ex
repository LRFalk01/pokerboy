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
        #TODO: broadcast game state to all users on user join
        %{uuid: user_uuid, state: _} = Gameserver.user_join(uuid, name)
        {:ok,
          socket
          |> assign(:game_id, uuid)
          |> assign(:name, name)
          |> assign(:user_id, user_uuid)
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

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("user_promote", %{"user"=>name}, socket) do
    resp = Pokerboy.Gameserver.user_promote(socket.assigns.game_id, socket.assigns.user_id, name)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("user_vote", %{"vote"=>vote}, socket) do
    resp = Pokerboy.Gameserver.user_vote(socket.assigns.game_id, socket.assigns.user_id, vote)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("toggle_playing", %{"user"=>name}, socket) do
    resp = Pokerboy.Gameserver.toggle_playing(socket.assigns.game_id, socket.assigns.user_id, name)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("reveal", _, socket) do
    resp = Pokerboy.Gameserver.reveal(socket.assigns.game_id, socket.assigns.user_id)

    update_game(socket, resp)
    {:noreply, socket}
  end

  def handle_in("reset", _, socket) do
    resp = Pokerboy.Gameserver.reset(socket.assigns.game_id, socket.assigns.user_id)  

    update_game(socket, resp)
    {:noreply, socket}
  end

  def terminate(_, socket) do
    cond do
      !Map.has_key?(socket.assigns, :user_id) ->
        :ok
      true ->
        resp = Pokerboy.Gameserver.leave(socket.assigns.game_id, socket.assigns.user_id)
        update_game(socket, resp)
        :ok
    end
  end

  defp update_game(socket, response) do
    broadcast! socket, "game_update", (response |> sanatize_state)
  end

  defp sanatize_state(%{status: :error, message: message}) do
    %{status: :error, message: message}
  end

  defp sanatize_state(%{status: :ok, state: state}) do
    %{status: :ok, 
    state: %{
      name: state.name,
      is_showing?: state.is_showing?,
      users: sanatize_users(state.users, state.is_showing?)
    }}
  end

  defp sanatize_users(users, show_vote?) do
    Map.values(users)
      |> Enum.map(fn(x) -> 
          x = Map.delete(x, :id)
          cond do
            !show_vote? ->
              %{x | vote: !is_nil(x.vote)}
            true ->
              x
          end
        end)
      |> Map.new(fn(x) -> {x.name, x} end)
  end
end