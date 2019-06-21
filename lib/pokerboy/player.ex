defmodule Pokerboy.Player do
  @moduledoc """
  This represents each player in a game
  """

  @derive Jason.Encoder
  defstruct id: nil, name: nil, vote: nil, is_player: false, original_vote: nil, is_admin: false

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
