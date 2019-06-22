defmodule Pokerboy.Game do
  @moduledoc """
  The goal of this is to handle all of the state changes for
  a planning pokergame to relieve the amount of actual logical
  lifting done by the `Pokerboy.GameServer`
  """

  alias __MODULE__, as: Game
  alias Pokerboy.Player, as: Player

  defstruct users: %{},
            password: "",
            is_showing: false,
            last_action: nil

  @type t :: %Game{
          users: %{binary() => Player.t()},
          password: String.t(),
          is_showing: boolean(),
          last_action: DateTime.t()
        }
  @type duration_granularity :: :hours | :minutes | :seconds
  @type vote :: nil | String.t()

  @spec new(String.t()) :: Game.t()
  def new(password) do
    %Game{password: password, last_action: DateTime.utc_now()}
  end

  @spec time_from_last_action(Game.t(), duration_granularity()) :: integer()
  def time_from_last_action(%Game{last_action: last_action}, granularity) do
    Timex.diff(Timex.now(), last_action, granularity)
  end

  @spec remove_all_users!(Game.t()) :: Game.t()
  def remove_all_users!(%Game{} = game) do
    %{game | users: %{}, last_action: DateTime.utc_now()}
  end

  @spec add_new_user(Game.t(), String.t()) :: {Player.id(), Game.t()}
  def add_new_user(%Game{users: users} = game, username) do
    user = username |> Player.new() |> Map.put(:is_admin, map_size(users) == 0)
    updated = decide_showing(put_in(game.users[user.id], user))
    {user.id, updated}
  end

  @spec username_available?(Game.t(), String.t()) :: boolean()
  def username_available?(%Game{users: users}, username) do
    Enum.all?(users, fn {_, user} -> user.name != username end)
  end

  @spec kick_user(Game.t(), Player.id(), String.t()) :: {:ok, Game.t()} | {:error, String.t()}
  def kick_user(%Game{users: users} = game, requester_id, username) do
    if users[requester_id] && users[requester_id].is_admin do
      case Enum.find(users, fn {_, user} -> user.name == username end) do
        nil ->
          {:error, "invalid user"}

        {id, _} ->
          {:ok, decide_showing(%{game | users: Map.delete(users, id)})}
      end
    else
      {:error, "invalid requester"}
    end
  end

  @spec promote_admin(Game.t(), Player.id(), String.t()) :: {:ok, Game.t()} | {:error, String.t()}
  def promote_admin(%Game{users: users} = game, requester_id, username) do
    case users[requester_id] do
      %{is_admin: true} -> become_admin(game, game.password, username)
      _ -> {:error, "invalid admin"}
    end
  end

  @spec become_admin(Game.t(), String.t(), String.t()) :: {:ok, Game.t()} | {:error, String.t()}
  def become_admin(%Game{password: password, users: users} = game, password, username) do
    case Enum.find(users, fn {_, user} -> user.name == username end) do
      nil -> {:error, "invalid user"}
      {id, _} -> {:ok, put_in(game.users[id].is_admin, true)}
    end
  end

  def become_admin(_, _, _), do: {:error, "invalid password"}

  @spec remove_user_by_id(Game.t(), Player.id()) :: {:ok, Game.t()} | {:error, String.t()}
  def remove_user_by_id(%Game{users: users} = game, user_id) do
    case Enum.find(users, fn {id, _} -> id == user_id end) do
      nil ->
        {:error, "invalid user"}

      {id, _} ->
        {:ok, decide_showing(%{game | users: Map.delete(users, id)})}
    end
  end

  @spec force_reveal(Game.t(), Player.id()) :: {:ok, Game.t()} | {:error, String.t()}
  def force_reveal(%Game{users: users} = game, requester_id) do
    if users[requester_id] && users[requester_id].is_admin do
      {:ok, %{game | is_showing: true, last_action: DateTime.utc_now()}}
    else
      {:error, "invalid requester"}
    end
  end

  @spec reset_votes(Game.t(), Player.id()) :: {:ok, Game.t()} | {:error, String.t()}
  def reset_votes(%Game{users: users} = game, requester_id) do
    if users[requester_id] && users[requester_id].is_admin do
      reset =
        users
        |> Enum.map(fn {id, user} -> {id, Player.reset_votes(user)} end)
        |> Enum.into(%{})

      {:ok, %{game | users: reset, is_showing: false, last_action: DateTime.utc_now()}}
    else
      {:error, "invalid requester"}
    end
  end

  @spec vote_for_user_id(Game.t(), Player.id(), Game.vote()) ::
          {:ok, Game.t()} | {:error, String.t()}
  def vote_for_user_id(%Game{users: users} = game, user_id, vote) do
    case users[user_id] do
      nil ->
        {:error, "invalid user"}

      user ->
        {:ok, user |> do_vote(game, vote) |> decide_showing()}
    end
  end

  @spec toggle_playing(Game.t(), Player.id(), String.t()) ::
          {:ok, Game.t()} | {:error, String.t()}
  def toggle_playing(%Game{users: users} = game, requester_id, username) do
    case users[requester_id] do
      %{name: ^username} = user ->
        {:ok, do_toggle_playing(game, user)}

      %{is_admin: true} ->
        case Enum.find(users, fn {_, user} -> user.name == username end) do
          nil -> {:error, "invalid user"}
          {_, user} -> {:ok, do_toggle_playing(game, user)}
        end

      _ ->
        {:error, "invalid requester"}
    end
  end

  ## Private Functions

  defp do_toggle_playing(game, %{id: id, is_player: is_player}) do
    decide_showing(put_in(game.users[id].is_player, !is_player))
  end

  defp do_vote(player, %Game{is_showing: is_showing?} = game, vote) do
    updated_player =
      if is_showing? do
        %{player | vote: vote}
      else
        %{player | vote: vote, original_vote: vote}
      end

    put_in(game.users[player.id], updated_player)
  end

  defp decide_showing(%Game{is_showing: true} = game) do
    %{game | last_action: DateTime.utc_now()}
  end

  defp decide_showing(%Game{users: users} = game) do
    case Enum.filter(users, fn {_, user} -> user.is_player end) do
      [] ->
        %{game | last_action: DateTime.utc_now()}

      players ->
        if Enum.all?(players, fn {_, player} -> player.vote end) do
          %{game | is_showing: true, last_action: DateTime.utc_now()}
        else
          %{game | last_action: DateTime.utc_now()}
        end
    end
  end
end
