defmodule Pokerboy.Player do
  @moduledoc """
  This represents each player in a game
  """
  alias __MODULE__, as: Player

  defstruct id: nil, name: nil, vote: nil, is_player: false, original_vote: nil, is_admin: false

  @type id :: binary()
  @type t :: %Player{
          id: id(),
          name: String.t(),
          is_player: boolean(),
          is_admin: boolean()
        }

  @spec new(String.t()) :: Player.t()
  def new(playername) do
    %Player{id: Ecto.UUID.generate(), name: playername}
  end

  @spec reset_votes(Player.t()) :: Player.t()
  def reset_votes(%Player{} = player) do
    %{player | vote: nil, original_vote: nil}
  end

  def sanitize_name(nil), do: nil

  def sanitize_name(name) do
    name
    |> String.graphemes()
    |> Enum.reject(&(byte_size(&1) > 1))
    |> Enum.join()
    |> String.trim()
    |> String.slice(0, 10)
  end
end
