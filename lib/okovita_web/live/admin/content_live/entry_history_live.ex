defmodule OkovitaWeb.Admin.ContentLive.EntryHistoryLive do
  @moduledoc "Tenant admin: view history for a specific content entry."
  use OkovitaWeb, :live_view

  alias Okovita.Content.{Models, Entries}
  alias Okovita.Timeline
  alias Phoenix.LiveView.JS

  def mount(
        %{"model_slug" => model_slug, "id" => id, "tenant_slug" => tenant_slug},
        _session,
        socket
      ) do
    prefix = socket.assigns.tenant_prefix

    case {Models.get_model_by_slug(model_slug, prefix), Entries.get_entry(id, prefix)} do
      {nil, _} ->
        {:ok,
         put_flash(socket, :error, "Model not found")
         |> push_navigate(to: "/admin/tenants/#{tenant_slug}/models")}

      {_, nil} ->
        {:ok,
         put_flash(socket, :error, "Entry not found")
         |> push_navigate(to: "/admin/tenants/#{tenant_slug}/models/#{model_slug}/entries")}

      {model, entry} ->
        records = Timeline.list_records(entry.id, "entry", prefix)

        records_with_status =
          Enum.map(records, fn record ->
            can_restore? =
              if record.after do
                raw_data =
                  Map.get(record.after, "raw_data") || Map.get(record.after, "data") || %{}

                case Okovita.Content.DynamicChangeset.build(model.schema_definition, raw_data) do
                  {:ok, _} -> true
                  {:error, _} -> false
                end
              else
                false
              end

            Map.put(record, :can_restore?, can_restore?)
          end)

        {:ok,
         assign(socket,
           model: model,
           entry: entry,
           records: records_with_status,
           tenant_slug: tenant_slug
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 p-8">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900 flex items-center gap-3">
          Historia wpisu — <span class="text-indigo-600"><%= @model.name %></span>
        </h1>
      </div>

      <div class="border-b border-gray-200 mb-8">
        <nav class="-mb-px flex space-x-8" aria-label="Tabs">
          <a href={"/admin/tenants/#{@tenant_slug}/models/#{@model.slug}/entries/#{@entry.id}/edit"}
             class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 transition-colors">
            Edycja
          </a>

          <a href={"/admin/tenants/#{@tenant_slug}/models/#{@model.slug}/entries/#{@entry.id}/history"}
             class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm border-indigo-500 text-indigo-600"
             aria-current="page">
            Historia
          </a>
        </nav>
      </div>

      <%= if @records == [] do %>
        <div class="text-center py-12 px-4 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">Brak historii</h3>
          <p class="mt-1 text-sm text-gray-500">Nie znaleziono żadnych zapisów historycznych dla tego wpisu.</p>
        </div>
      <% else %>
        <div class="flow-root">
          <ul role="list" class="-mb-8">
            <%= for {record, index} <- Enum.with_index(@records) do %>
              <li>
                <div class="relative pb-8">
                  <%= if index < length(@records) - 1 do %>
                    <span class="absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
                  <% end %>
                  <div class="relative flex space-x-3">
                    <div>
                      <span class="h-8 w-8 rounded-full bg-indigo-50 flex items-center justify-center ring-8 ring-white shadow-sm">
                        <svg class="h-4 w-4 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </span>
                    </div>
                    <div class="min-w-0 flex-1 pt-1.5">
                      <div class="flex items-center justify-between">
                        <div class="flex items-center justify-start gap-4">
                          <p class="text-sm font-semibold text-gray-900 uppercase tracking-wider">
                            <%= record.action %>
                            <%= if record.actor_email do %>
                              <span class="text-xs font-normal text-gray-500 lowercase ml-2">(<%= record.actor_email %>)</span>
                            <% end %>
                          </p>

                          <%= if record.action == "update" and record.after do %>
                            <%= if record.can_restore? do %>
                              <button phx-click="restore_version" phx-value-record-id={record.id} class="text-xs font-medium text-indigo-600 hover:text-indigo-900 transition-colors bg-indigo-50 hover:bg-indigo-100 px-2.5 py-1.5 rounded-md border border-indigo-200">
                                Przywróć tę wersję
                              </button>
                            <% else %>
                              <span class="text-xs font-medium text-gray-400 bg-gray-50 px-2.5 py-1.5 rounded-md border border-gray-200 cursor-not-allowed" title="Struktura modelu uległa zmianie. Nie można przywrócić tej wersji.">
                                Wersja nieaktualna
                              </span>
                            <% end %>
                          <% end %>
                        </div>
                        <div class="text-right text-xs whitespace-nowrap text-gray-500 font-medium">
                          <time datetime={record.inserted_at}><%= Calendar.strftime(record.inserted_at, "%Y-%m-%d %H:%M:%S") %></time>
                        </div>
                      </div>

                      <div class="mt-4">
                          <details class="group" open>
                            <summary class="text-xs font-medium text-gray-500 hover:text-gray-900 transition-colors cursor-pointer list-none flex items-center gap-1">
                              <svg class="w-3 h-3 transition-transform group-open:rotate-90" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" /></svg>
                              Zmiany (Diff)
                            </summary>
                            <div class="relative mt-2 text-xs font-mono bg-gray-50 py-4 rounded-lg border border-gray-200 text-gray-800 overflow-x-auto group/json">
                              <%= if record.after do %>
                                <button type="button" phx-click={JS.show(to: "#json-modal-#{record.id}")} class="absolute top-3 right-3 text-xs font-medium text-gray-600 hover:text-gray-900 bg-white border border-gray-300 hover:border-gray-400 shadow-sm rounded-md px-2.5 py-1.5 z-10 opacity-0 group-hover/json:opacity-100 focus:opacity-100 transition-all flex items-center gap-1.5">
                                  <.icon name="hero-eye" class="w-4 h-4 text-gray-500" />
                                  Pełen stan w JSON
                                </button>
                                <.modal id={"json-modal-#{record.id}"} on_close={JS.hide(to: "#json-modal-#{record.id}")}>
                                  <:title>
                                    Pełen stan z <span class="text-indigo-600 font-mono text-sm ml-1"><%= Calendar.strftime(record.inserted_at, "%Y-%m-%d %H:%M:%S") %></span>
                                  </:title>
                                  <div class="mt-4 text-xs font-mono bg-gray-50 p-4 rounded-lg border border-gray-200 text-gray-800 overflow-x-auto max-h-[60vh] shadow-inner">
                                    <pre class="leading-relaxed"><%= record.after |> sanitize_for_diff() |> Jason.encode!(pretty: true) |> String.split("\n") |> Enum.map(&highlight_json/1) |> Enum.join("\n") |> Phoenix.HTML.raw() %></pre>
                                  </div>
                                </.modal>
                              <% end %>
                              <pre class="leading-relaxed"><%= for {action, lines} <- diff_json(record.before, record.after), line <- lines do %><%
                                {bg_class, text_class, sign} =
                                  case action do
                                    :eq -> {"hover:bg-gray-100", "text-gray-500", " "}
                                    :del -> {"bg-red-50 hover:bg-red-100", "text-red-700", "-"}
                                    :ins -> {"bg-green-50 hover:bg-green-100", "text-green-700", "+"}
                                  end
                              %><span class={["block px-4 transition-colors relative min-w-max", bg_class, text_class]}><span class="select-none opacity-50 mr-4 inline-block w-2 text-right"><%= sign %></span><%= Phoenix.HTML.raw(highlight_json(line)) %></span><% end %></pre>
                            </div>
                          </details>
                        </div>
                      </div>
                    </div>
                  </div>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="mt-12 pt-6 border-t border-gray-200">
        <a href={"/admin/tenants/#{@tenant_slug}/models/#{@model.slug}/entries"}
           class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors flex items-center gap-2">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
          Powrót do listy
        </a>
      </div>
    </div>
    """
  end

  def handle_event("restore_version", %{"record-id" => record_id}, socket) do
    prefix = socket.assigns.tenant_prefix
    entry_id = socket.assigns.entry.id
    actor_id = socket.assigns.current_admin.id

    case Entries.restore_entry(entry_id, record_id, prefix, actor_id) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Wersja została pomyślnie przywrócona.")
         |> push_navigate(
           to:
             "/admin/tenants/#{socket.assigns.tenant_slug}/models/#{socket.assigns.model.slug}/entries/#{entry_id}/history"
         )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Wystąpił błąd podczas przywracania wersji.")}
    end
  end

  defp diff_json(nil, after_data), do: diff_json(%{}, after_data)
  defp diff_json(before_data, nil), do: diff_json(before_data, %{})

  defp diff_json(before_data, after_data) do
    before_lines =
      before_data |> sanitize_for_diff() |> Jason.encode!(pretty: true) |> String.split("\n")

    after_lines =
      after_data |> sanitize_for_diff() |> Jason.encode!(pretty: true) |> String.split("\n")

    List.myers_difference(before_lines, after_lines)
  end

  defp sanitize_for_diff(data) when is_map(data) do
    # Extract the inner "data" map instead of the top-level envelope
    inner_data = Map.get(data, "data", Map.get(data, :data, %{}))

    inner_data
    |> Map.drop(["raw_data", :raw_data])
    |> deep_clean()
  end

  defp sanitize_for_diff(data), do: data

  defp deep_clean(data) when is_map(data) do
    data
    |> Map.drop(["model", :model, "model_id", :model_id])
    |> Enum.into(%{}, fn {k, v} -> {k, deep_clean(v)} end)
  end

  defp deep_clean(list) when is_list(list), do: Enum.map(list, &deep_clean/1)
  defp deep_clean(other), do: other

  defp highlight_json(line) do
    # Escape HTML to prevent injection, then highlight
    line
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace(
      ~r/(&quot;(?:\\.|.)*?&quot;)(?=:)/,
      "<span class=\"text-indigo-700 font-medium\">\\1</span>"
    )
    |> String.replace(
      ~r/(: )(&quot;(?:\\.|.)*?&quot;)/,
      "\\1<span class=\"text-emerald-700\">\\2</span>"
    )
    |> String.replace(~r/(: )(true|false)\b/, "\\1<span class=\"text-purple-700\">\\2</span>")
    |> String.replace(~r/(: )(null)\b/, "\\1<span class=\"text-gray-400 italic\">\\2</span>")
    |> String.replace(
      ~r/(: )(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/,
      "\\1<span class=\"text-amber-700\">\\2</span>"
    )
  end
end
