defmodule Okovita.Backup.Exporter do
  @moduledoc """
  Exports tenant data to JSON backup format.

  Handles export of models, entries (with denormalized relations),
  and media metadata.
  """

  require Logger

  alias Okovita.Content
  alias Okovita.Tenants
  alias Okovita.Backup.RelationResolver

  @doc """
  Exports a tenant's data to a JSON backup file.

  ## Options
    * `:output_dir` - Directory to write the backup file (default: ".")
    * `:pretty` - Pretty-print JSON (default: false)

  Returns `{:ok, file_path}` on success or `{:error, reason}` on failure.
  """
  @spec export_tenant(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def export_tenant(tenant_slug, opts \\ []) do
    output_dir = Keyword.get(opts, :output_dir, ".")
    pretty = Keyword.get(opts, :pretty, false)

    with {:ok, tenant} <- get_tenant_by_slug(tenant_slug),
         prefix = Tenants.tenant_prefix(tenant),
         {:ok, backup_data} <- build_backup_data(tenant, prefix),
         {:ok, json} <- encode_json(backup_data, pretty),
         {:ok, file_path} <- write_backup_file(json, tenant_slug, output_dir) do
      Logger.info("Backup completed: #{file_path}")
      {:ok, file_path}
    else
      {:error, reason} = error ->
        Logger.error("Export failed: #{inspect(reason)}")
        error
    end
  end

  # Private functions

  defp get_tenant_by_slug(slug) do
    case Tenants.get_tenant_by_slug(slug) do
      nil -> {:error, :tenant_not_found}
      tenant -> {:ok, tenant}
    end
  end

  defp build_backup_data(tenant, prefix) do
    Logger.info("Exporting models...")
    models = export_models(prefix)

    Logger.info("Exporting entries...")
    entries = export_entries(prefix, models)

    Logger.info("Exporting media...")
    media = export_media(prefix)

    backup_data = %{
      "version" => Okovita.Backup.Format.current_version(),
      "tenant" => %{
        "slug" => tenant.slug,
        "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      "models" => models,
      "entries" => entries,
      "media" => media
    }

    {:ok, backup_data}
  end

  defp export_models(prefix) do
    prefix
    |> Content.list_models()
    |> Enum.map(&format_model/1)
  end

  defp export_entries(prefix, models) do
    models
    |> Enum.flat_map(fn model_data ->
      model_slug = model_data["slug"]

      # Get model struct to access schema_definition
      case Content.get_model_by_slug(model_slug, prefix) do
        nil ->
          Logger.warning("Model #{model_slug} not found during entry export, skipping")
          []

        model ->
          model.id
          |> Content.list_entries(prefix)
          |> Enum.map(&format_entry(&1, model, prefix))
      end
    end)
  end

  defp export_media(prefix) do
    prefix
    |> Content.list_media()
    |> Enum.map(&format_media/1)
  end

  defp format_model(model) do
    %{
      "slug" => model.slug,
      "name" => model.name,
      "publishable" => model.publishable,
      "is_component" => model.is_component,
      "slug_field" => model.slug_field,
      "schema_definition" => model.schema_definition
    }
  end

  defp format_entry(entry, model, prefix) do
    # Denormalize relations in entry.data
    denormalized_data =
      RelationResolver.denormalize_relations(
        entry.data,
        model.schema_definition,
        prefix
      )

    %{
      "model_slug" => model.slug,
      "slug" => entry.slug,
      "published_at" => format_datetime(entry.published_at),
      "data" => denormalized_data
    }
  end

  defp format_media(media) do
    %{
      "id" => media.id,
      "file_name" => media.file_name,
      "url" => media.url,
      "mime_type" => media.mime_type,
      "size" => media.size,
      "width" => media.width,
      "height" => media.height
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)

  defp encode_json(data, pretty) do
    json_opts = if pretty, do: [pretty: true], else: []

    case Jason.encode(data, json_opts) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, {:json_encode, reason}}
    end
  end

  defp write_backup_file(json, tenant_slug, output_dir) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    filename = "backup_#{tenant_slug}_#{timestamp}.json"
    file_path = Path.join(output_dir, filename)

    case File.write(file_path, json) do
      :ok ->
        {:ok, file_path}

      {:error, reason} ->
        {:error, {:file_write, reason}}
    end
  rescue
    e ->
      {:error, {:file_write, Exception.message(e)}}
  end
end
