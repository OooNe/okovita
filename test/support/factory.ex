defmodule Okovita.Factory do
  @moduledoc """
  ExMachina factory for test data.
  """
  use ExMachina.Ecto, repo: Okovita.Repo

  alias Okovita.Tenants.Tenant
  alias Okovita.Auth.Admin

  def tenant_factory do
    %Tenant{
      name: sequence(:name, &"Tenant #{&1}"),
      slug: sequence(:slug, &"tenant-#{&1}"),
      status: :active
    }
  end

  def admin_factory do
    %Admin{
      email: sequence(:email, &"admin#{&1}@example.com"),
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      role: :super_admin,
      tenant_id: nil
    }
  end

  def tenant_admin_factory do
    %Admin{
      email: sequence(:email, &"tenantadmin#{&1}@example.com"),
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      role: :tenant_admin,
      tenant: build(:tenant)
    }
  end
end
