defmodule TestParams do
  def run do
    # Simulate what Phoenix Router does
    conn = Plug.Test.conn(:get, "/media/okovita-content/test.png?w=100")
    conn = Plug.Conn.fetch_query_params(conn)

    params =
      Map.merge(conn.query_params, %{"bucket" => "okovita-content", "filename" => "test.png"})

    proc_params = Map.drop(params, ["bucket", "filename"])
    IO.inspect(proc_params, label: "Dropped params")
    IO.puts("Size: #{map_size(proc_params)}")

    # Check if 0
    if map_size(proc_params) == 0 do
      IO.puts("Would redirect!")
    else
      IO.puts("Would process!")
    end
  end
end

TestParams.run()
