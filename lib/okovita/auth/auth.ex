defmodule Okovita.Auth do
  @moduledoc """
  Context module for admin authentication.
  """
  import Ecto.Query
  alias Okovita.Auth.Admin
  alias Okovita.Repo

  @doc "Creates a new admin."
  def create_admin(attrs) do
    %Admin{}
    |> Admin.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Gets an admin by ID."
  def get_admin(id) do
    Repo.get(Admin, id)
  end

  @doc "Gets an admin by email."
  def get_admin_by_email(email) when is_binary(email) do
    Repo.get_by(Admin, email: email)
  end

  @doc "Authenticates an admin by email and password."
  def authenticate_admin(email, password) do
    admin = get_admin_by_email(email)

    if Admin.valid_password?(admin, password) do
      {:ok, admin}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc "Lists all admins, optionally filtered by tenant_id."
  def list_admins(opts \\ []) do
    query =
      case Keyword.get(opts, :tenant_id) do
        nil -> from(a in Admin)
        tenant_id -> from(a in Admin, where: a.tenant_id == ^tenant_id)
      end

    Repo.all(query)
  end
end
