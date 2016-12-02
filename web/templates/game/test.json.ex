defmodule Pokerboy.JsonView  do
    use Pokerboy.Web, :view
    @attributes ~W(id message title user comments inserted_at)a
  
    def render("show.json", %{data: data}) do
        data
        |> Map.take(@attributes)
    end   
end