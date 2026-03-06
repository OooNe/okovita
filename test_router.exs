defmodule TestRouter do
  def run do
    conn = Plug.Test.conn(:get, "/media/okovita-content/54adc8c7-c6b6-439c-a339-fcd46cc587dc?w=100")
    conn = Phoenix.Router.route_info(OkovitaWeb.Router, "GET", conn.request_path, "localstack")
    IO.inspect(conn)
  end
end
TestRouter.run()
