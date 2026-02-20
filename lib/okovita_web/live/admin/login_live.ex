defmodule OkovitaWeb.Admin.LoginLive do
  @moduledoc "Admin login page."
  use OkovitaWeb, :live_view

  alias Okovita.Auth

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: :login), error: nil)}
  end

  def handle_event("login", %{"login" => %{"email" => email, "password" => password}}, socket) do
    case Auth.authenticate_admin(email, password) do
      {:ok, admin} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome back!")
         |> redirect(to: "/admin/session?admin_id=#{admin.id}")}

      {:error, _reason} ->
        {:noreply, assign(socket, error: "Invalid email or password")}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="max-width: 400px; margin: 100px auto; padding: 40px; border: 1px solid #ddd; border-radius: 8px;">
      <h1 style="text-align: center; margin-bottom: 24px;">Okovita Admin</h1>

      <.form for={@form} phx-submit="login">
        <div style="margin-bottom: 16px;">
          <label for="login_email" style="display: block; margin-bottom: 4px; font-weight: 600;">Email</label>
          <input type="email" name="login[email]" id="login_email" required
                 style="width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px;" />
        </div>

        <div style="margin-bottom: 16px;">
          <label for="login_password" style="display: block; margin-bottom: 4px; font-weight: 600;">Password</label>
          <input type="password" name="login[password]" id="login_password" required
                 style="width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px;" />
        </div>

        <%= if @error do %>
          <p style="color: red; margin-bottom: 16px;"><%= @error %></p>
        <% end %>

        <button type="submit"
                style="width: 100%; padding: 10px; background: #4F46E5; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px;">
          Sign in
        </button>
      </.form>
    </div>
    """
  end
end
