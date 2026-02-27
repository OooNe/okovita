defmodule OkovitaWeb.Admin.ContentLive.EntryForm.PickerHandler do
  @moduledoc """
  Handles media picker events for EntryForm.

  Extracts the four picker-related `handle_event` clauses — open, toggle, confirm,
  cancel — so that `EntryForm` delegates to this module with a single line each.

  All public functions accept a `Phoenix.LiveView.Socket.t()` and return
  `{:noreply, socket}` to be passed through directly.
  """

  @doc """
  Opens the media picker for `field` in `:single` or `:multi` mode.
  """
  @spec open(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def open(socket, field, mode) do
    mode_atom = if mode == "single", do: :single, else: :multi

    {:noreply,
     Phoenix.Component.assign(socket,
       picker_open: %{field: field, mode: mode_atom},
       picker_selection: MapSet.new()
     )}
  end

  @doc """
  Toggles item selection in the picker.

  In `:single` mode, replaces the current selection with the new id.
  In `:multi` mode, adds or removes the id from the selection set.
  """
  @spec toggle(Phoenix.LiveView.Socket.t(), String.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def toggle(socket, id) do
    selection = socket.assigns.picker_selection
    mode = socket.assigns.picker_open.mode

    updated =
      cond do
        MapSet.member?(selection, id) -> MapSet.delete(selection, id)
        mode == :single -> MapSet.new([id])
        true -> MapSet.put(selection, id)
      end

    {:noreply, Phoenix.Component.assign(socket, picker_selection: updated)}
  end

  @doc """
  Confirms the selection and writes the result back into `socket.assigns.data`.

  - `:single` mode: stores a single media map `%{"id", "url", "file_name", "mime_type"}`.
  - `:multi` mode: appends new selections to the existing list (deduplicates), stores
    as `[%{"media_id", "index", "url", "file_name"}]`.
  """
  @spec confirm(Phoenix.LiveView.Socket.t(), String.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def confirm(socket, field_name) do
    selected_ids = MapSet.to_list(socket.assigns.picker_selection)
    data = socket.assigns.data
    picker_open = socket.assigns.picker_open

    media_map =
      socket.assigns.media_items
      |> Enum.map(&{&1.id, &1})
      |> Enum.into(%{})

    updated_data =
      case picker_open.mode do
        :single ->
          [selected_id | _] = selected_ids

          value =
            case Map.get(media_map, selected_id) do
              nil ->
                selected_id

              media ->
                %{
                  "id" => media.id,
                  "url" => media.url,
                  "file_name" => media.file_name,
                  "mime_type" => media.mime_type
                }
            end

          Map.put(data, field_name, value)

        :multi ->
          existing = Map.get(data, field_name, []) || []

          existing_ids =
            Enum.map(existing, fn
              %{"media_id" => id} -> id
              %{media_id: id} -> id
              id when is_binary(id) -> id
            end)

          existing_set = MapSet.new(existing_ids)
          new_ids = Enum.reject(selected_ids, &MapSet.member?(existing_set, &1))
          all_ids = existing_ids ++ new_ids

          mapped =
            all_ids
            |> Enum.with_index()
            |> Enum.map(fn {id, i} ->
              base = %{"media_id" => id, "index" => i}

              case Map.get(media_map, id) do
                nil -> base
                media -> Map.merge(base, %{"url" => media.url, "file_name" => media.file_name})
              end
            end)

          Map.put(data, field_name, mapped)
      end

    {:noreply,
     Phoenix.Component.assign(socket,
       data: updated_data,
       picker_open: nil,
       picker_selection: MapSet.new()
     )}
  end

  @doc """
  Cancels the picker without making any changes to the data.
  """
  @spec cancel(Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def cancel(socket) do
    {:noreply, Phoenix.Component.assign(socket, picker_open: nil, picker_selection: MapSet.new())}
  end
end
