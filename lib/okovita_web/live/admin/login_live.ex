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
    <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8 bg-white p-10 rounded-xl shadow-lg ring-1 ring-gray-900/5">
        <div>
          <h1 class="text-center text-3xl font-extrabold text-gray-900">Okovita Admin</h1>
          <p class="mt-2 text-center text-sm text-gray-600">Sign in to your account</p>
        </div>

        <.form for={@form} phx-submit="login" class="mt-8 space-y-6">
          <div class="space-y-4">
            <div>
              <label for="login_email" class="block text-sm font-medium text-gray-700">Email address</label>
              <div class="mt-1">
                <input type="email" name="login[email]" id="login_email" required
                       class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              </div>
            </div>

            <div>
              <label for="login_password" class="block text-sm font-medium text-gray-700">Password</label>
              <div class="mt-1">
                <input type="password" name="login[password]" id="login_password" required
                       class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              </div>
            </div>
          </div>

          <%= if @error do %>
            <div class="rounded-md bg-red-50 p-4">
              <div class="flex">
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-red-800"><%= @error %></h3>
                </div>
              </div>
            </div>
          <% end %>

          <div>
            <button type="submit"
                    class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors">
              Sign in
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
