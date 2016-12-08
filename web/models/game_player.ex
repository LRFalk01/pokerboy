defmodule Pokerboy.Player do
    defstruct id: nil, name: nil, vote: nil, is_player?: true, original_vote: nil, is_admin?: false

    def sanitize_name(nil), do: nil
    def sanitize_name(name) do
        String.graphemes(name) 
        |> Enum.reject(&(byte_size(&1) > 1)) 
        |> Enum.join
        |> String.trim
    end
end