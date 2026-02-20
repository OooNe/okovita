defmodule Okovita.Workers.PipelineExecutor do
  @moduledoc """
  Oban worker that executes async pipelines on content entries.

  ## Job Args

      %{
        "entry_id" => uuid,
        "model_id" => uuid,
        "prefix" => "tenant_<slug>",
        "pipeline" => "slugify",
        "field" => "title",
        "options" => %{}
      }

  Loads the entry, applies the pipeline to the specified field, and updates the entry.
  If the entry no longer exists, discards the job.
  """
  use Oban.Worker, queue: :pipeline, max_attempts: 3

  alias Okovita.Repo
  alias Okovita.Content.Entry

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "entry_id" => entry_id,
      "prefix" => prefix,
      "pipeline" => pipeline_name,
      "field" => field
    } = args

    options = Map.get(args, "options", %{})

    case Repo.get(Entry, entry_id, prefix: prefix) do
      nil ->
        # Entry was deleted, discard the job
        :discard

      entry ->
        pipeline_module = resolve_pipeline(pipeline_name)
        field_value = Map.get(entry.data, field)

        case pipeline_module.apply(field_value, options) do
          {:ok, new_value} ->
            new_data = Map.put(entry.data, field, new_value)

            entry
            |> Ecto.Changeset.change(%{data: new_data})
            |> Repo.update(prefix: prefix)

            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp resolve_pipeline(name) do
    pipelines =
      Application.get_env(:okovita, :async_pipelines, %{})
      |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)

    # Also check sync pipelines as fallback
    sync_pipelines =
      Application.get_env(:okovita, :sync_pipelines, [])
      |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)

    Map.get(pipelines, name) ||
      Map.get(sync_pipelines, name) ||
      raise ArgumentError, "Unknown pipeline: #{name}"
  end
end
