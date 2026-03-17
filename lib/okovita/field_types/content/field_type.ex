defmodule Okovita.FieldTypes.Content do
  @moduledoc "Content field type using CKEditor 5 for Markdown."
  use Okovita.FieldTypes.Base

  @impl true
  def value_type, do: :string

  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, _field_name, _options) do
    changeset
  end

  @doc """
  Provide the `upload_url` for CKEditor 5 to upload images to the correct Tenant.
  """
  @impl true
  def form_assigns(_field_name, _field_def, assigns) do
    tenant = assigns[:current_tenant]

    if tenant && tenant.slug do
      %{upload_url: "/admin/api/tenants/#{tenant.slug}/ckeditor/upload"}
    else
      %{upload_url: nil}
    end
  end
end
