defmodule Pokerboy.Player do
    defstruct id: nil, name: nil, vote: nil, is_player?: true, is_dirty_vote?: false, is_admin?: false

    def sanitize_name(nil), do: nil
    def sanitize_name(name) do
        String.graphemes(name) 
        |> Enum.reject(&(byte_size(&1) > 1)) 
        |> Enum.join
        |> String.trim
    end

    def player_vote(id, vote, player_list) when is_list(player_list) do
        Enum.map(player_list, fn(x) -> player_vote(id, vote, x) end)
    end

    def player_vote(id, vote, player=%Pokerboy.Player{}) do
        if player.id != id do
            player
        else
            %{ player | vote: vote }
        end
    end
end