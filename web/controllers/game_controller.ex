defmodule Pokerboy.GameController do
  use Pokerboy.Web, :controller
  plug :put_view, Pokerboy.JsonView

  def index(conn, _params) do
    t = %{message: "Hi"}

    render(conn, "show.json", data: t)
  end
end