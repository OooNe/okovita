defmodule Okovita.Repo do
  use Ecto.Repo,
    otp_app: :okovita,
    adapter: Ecto.Adapters.Postgres
end
