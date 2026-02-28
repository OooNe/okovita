defmodule OkovitaWeb.Admin.ContentLive.EntryForm.SaveHandler do
  @moduledoc """
  Handles the data-assembly phase of the "save" event for EntryForm.

  `consume_uploaded_entries/3` is a LiveView macro and must be called from
  within the LiveView module itself.  EntryForm is responsible for consuming
  uploads and collecting raw `{:ok, media_id} | {:error, reason}` result lists
  per field.  This module takes over from that point:

    - `collect_results/1` — separates successes/errors per field and flashes errors
    - `build_data/4`      — assembles the final `%{field => value}` map to persist

  ## Typical call site in EntryForm

      raw = consume_fields(socket, model.schema_definition)
      {socket, upload_results} = SaveHandler.collect_results(socket, raw)
      data = SaveHandler.build_data(model.schema_definition, upload_results, params, socket.assigns.data)
  """
  alias Okovita.FieldTypes.Registry

  @doc """
  Separates upload results (from `consume_uploaded_entries`) into successes and
  errors, flashes any errors on the socket, and returns `{socket, upload_results}`.

  `raw_results` is a map of `%{field_name => [{:ok, media_id} | {:error, msg}]}`.

  Returns `{socket, %{field_name => %{successes: [id], errors: [msg]}}}`.
  """
  @spec collect_results(Phoenix.LiveView.Socket.t(), %{String.t() => list()}) ::
          {Phoenix.LiveView.Socket.t(), %{String.t() => map()}}
  def collect_results(socket, raw_results) do
    upload_results =
      Map.new(raw_results, fn {field_name, results} ->
        errors =
          results
          |> Enum.filter(&match?({:error, _}, &1))
          |> Enum.map(fn {:error, msg} -> msg end)

        successes =
          results
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, id} -> id end)

        {field_name, %{successes: successes, errors: errors}}
      end)

    all_errors =
      upload_results
      |> Map.values()
      |> Enum.flat_map(& &1.errors)

    socket =
      if all_errors != [],
        do: Phoenix.LiveView.put_flash(socket, :error, Enum.join(all_errors, " | ")),
        else: socket

    {socket, upload_results}
  end

  @doc """
  Assembles the final data map to persist.

  Merges uploaded media IDs (from `upload_results`) with existing picker-selected
  media (from `current_data`) and raw form params, giving priority to uploads.

  Returns a `%{field_name => value}` map covering all fields in the schema.
  """
  @spec build_data(map(), map(), map(), map()) :: map()
  def build_data(schema_definition, upload_results, params, current_data) do
    upload_ids =
      Map.new(upload_results, fn {field, result_map} ->
        {field, result_map.successes}
      end)

    # Resolve image/gallery fields from upload ids or current picker data
    upload_data_mapped =
      Enum.reduce(schema_definition || %{}, %{}, fn {field_name, def}, acc ->
        if config = Registry.upload_config(def["field_type"]) do
          uploaded_ids = Map.get(upload_ids, field_name, [])
          {max_entries, _} = config

          if max_entries == 1 do
            if uploaded_ids != [] do
              Map.put(acc, field_name, hd(uploaded_ids))
            else
              case Registry.extract_references(
                     def["field_type"],
                     Map.get(current_data, field_name)
                   ) do
                [id | _] -> Map.put(acc, field_name, id)
                [] -> acc
              end
            end
          else
            existing_from_params = Map.get(params, "#{field_name}__existing", [])
            all_ids = existing_from_params ++ uploaded_ids

            mapped =
              all_ids
              |> Enum.with_index()
              |> Enum.map(fn {id, i} -> %{"media_id" => id, "index" => i} end)

            Map.put(acc, field_name, mapped)
          end
        else
          acc
        end
      end)

    # Merge: upload_data_mapped > params > fallback
    Enum.into(schema_definition || %{}, %{}, fn {field_name, def} ->
      fallback =
        if Registry.targets_entry?(def["field_type"]) or
             match?({max, _} when max > 1, Registry.upload_config(def["field_type"])),
           do: [],
           else: ""

      {field_name, Map.get(upload_data_mapped, field_name, Map.get(params, field_name, fallback))}
    end)
  end
end
