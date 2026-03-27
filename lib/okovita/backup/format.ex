defmodule Okovita.Backup.Format do
  @moduledoc """
  Validates and manages backup JSON format versions.

  Ensures backup files conform to expected schema and handles
  version migrations if needed.
  """

  @current_version "1.0"
  @required_keys ~w(version tenant models entries media)

  @doc """
  Validates backup JSON structure.

  Returns `{:ok, data}` if valid, `{:error, reason}` otherwise.
  """
  @spec validate(map()) :: {:ok, map()} | {:error, term()}
  def validate(data) when is_map(data) do
    with :ok <- validate_required_keys(data),
         :ok <- validate_version(data["version"]),
         :ok <- validate_tenant_section(data["tenant"]),
         :ok <- validate_models_section(data["models"]),
         :ok <- validate_entries_section(data["entries"]),
         :ok <- validate_media_section(data["media"]) do
      {:ok, data}
    end
  end

  def validate(_), do: {:error, :invalid_format}

  @doc """
  Returns the current backup format version.
  """
  @spec current_version() :: String.t()
  def current_version, do: @current_version

  # Private validation functions

  defp validate_required_keys(data) do
    missing_keys = @required_keys -- Map.keys(data)

    if Enum.empty?(missing_keys) do
      :ok
    else
      {:error, {:missing_keys, missing_keys}}
    end
  end

  defp validate_version(@current_version), do: :ok

  defp validate_version(version) when is_binary(version) do
    {:error, {:unsupported_version, version}}
  end

  defp validate_version(_), do: {:error, :invalid_version_format}

  defp validate_tenant_section(%{"slug" => slug, "exported_at" => exported_at})
       when is_binary(slug) and is_binary(exported_at) do
    :ok
  end

  defp validate_tenant_section(_) do
    {:error, {:invalid_tenant_section, "must have 'slug' and 'exported_at' fields"}}
  end

  defp validate_models_section(models) when is_list(models) do
    if Enum.all?(models, &valid_model?/1) do
      :ok
    else
      {:error, {:invalid_models, "one or more models have invalid structure"}}
    end
  end

  defp validate_models_section(_), do: {:error, {:invalid_models, "must be a list"}}

  defp validate_entries_section(entries) when is_list(entries) do
    if Enum.all?(entries, &valid_entry?/1) do
      :ok
    else
      {:error, {:invalid_entries, "one or more entries have invalid structure"}}
    end
  end

  defp validate_entries_section(_), do: {:error, {:invalid_entries, "must be a list"}}

  defp validate_media_section(media) when is_list(media) do
    if Enum.all?(media, &valid_media?/1) do
      :ok
    else
      {:error, {:invalid_media, "one or more media items have invalid structure"}}
    end
  end

  defp validate_media_section(_), do: {:error, {:invalid_media, "must be a list"}}

  # Structural validators

  defp valid_model?(%{
         "slug" => slug,
         "name" => name,
         "schema_definition" => schema_def
       })
       when is_binary(slug) and is_binary(name) and is_map(schema_def) do
    true
  end

  defp valid_model?(_), do: false

  defp valid_entry?(%{
         "model_slug" => model_slug,
         "slug" => slug,
         "data" => data
       })
       when is_binary(model_slug) and is_binary(slug) and is_map(data) do
    true
  end

  defp valid_entry?(_), do: false

  defp valid_media?(%{
         "id" => id,
         "file_name" => file_name,
         "url" => url
       })
       when is_binary(id) and is_binary(file_name) and is_binary(url) do
    true
  end

  defp valid_media?(_), do: false
end
