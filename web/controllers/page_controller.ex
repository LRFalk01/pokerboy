defmodule Pokerboy.PageController do
  use Pokerboy.Web, :controller

  def index(conn, _params) do
      html(conn, File.read!("priv/static/index.html"))
  end
end
