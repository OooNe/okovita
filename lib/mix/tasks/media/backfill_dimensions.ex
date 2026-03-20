defmodule Mix.Tasks.Media.BackfillDimensions do
  use Mix.Task
  require Logger
  import Ecto.Query

  alias Okovita.Content.Media
  alias Okovita.Repo
  alias Okovita.Tenants

  @shortdoc "Backfills width/height for existing media records that have no dimensions"

  def run(_) do
    Mix.Task.run("app.start")

    tenants = Repo.all(Tenants.Tenant)
    Logger.info("Backfilling media dimensions for #{length(tenants)} tenant(s)...")

    totals =
      Enum.reduce(tenants, %{found: 0, updated: 0, failed: 0}, fn tenant, acc ->
        prefix = Tenants.tenant_prefix(tenant)
        Logger.info("Processing tenant: #{prefix}")

        records =
          Repo.all(from(m in Media, where: is_nil(m.width) or is_nil(m.height)), prefix: prefix)

        Logger.info("  Found #{length(records)} media record(s) without dimensions")

        results =
          Enum.map(records, fn media ->
            case fetch_and_extract(media) do
              {:ok, width, height} ->
                media
                |> Media.changeset(%{width: width, height: height})
                |> Repo.update(prefix: prefix)
                |> case do
                  {:ok, _} ->
                    Logger.info("  [OK] #{media.file_name} → #{width}x#{height}")
                    :updated

                  {:error, reason} ->
                    Logger.warning("  [FAIL] #{media.file_name} DB update failed: #{inspect(reason)}")
                    :failed
                end

              {:error, reason} ->
                Logger.warning("  [SKIP] #{media.file_name} — #{reason}")
                :failed
            end
          end)

        updated = Enum.count(results, &(&1 == :updated))
        failed = Enum.count(results, &(&1 == :failed))

        %{
          found: acc.found + length(records),
          updated: acc.updated + updated,
          failed: acc.failed + failed
        }
      end)

    Logger.info(
      "Done. found=#{totals.found} updated=#{totals.updated} failed=#{totals.failed}"
    )
  end

  defp fetch_and_extract(%Media{file_name: file_name, mime_type: mime_type}) do
    unless String.starts_with?(mime_type || "", "image/") do
      {:error, "not an image (#{mime_type})"}
    else
      bucket = Application.get_env(:okovita, :s3_bucket, "okovita-content")

      case ExAws.S3.get_object(bucket, file_name) |> ExAws.request() do
        {:ok, %{body: body}} when is_binary(body) ->
          extract_from_binary(body)

        _ ->
          extract_from_cache(file_name)
      end
    end
  end

  defp extract_from_binary(body) do
    case Image.from_binary(body) do
      {:ok, img} ->
        {width, height, _bands} = Image.shape(img)
        {:ok, width, height}

      _ ->
        {:error, "Image.from_binary failed"}
    end
  end

  defp extract_from_cache(file_name) do
    uuid = Path.rootname(file_name)
    cache_dir = "priv/static/cache/media"

    # Prefer w1600 contain (closest to original), then any hnil contain, then any cached file
    candidates =
      Path.wildcard("#{cache_dir}/#{uuid}_w1600_hnil_*.webp") ++
        Path.wildcard("#{cache_dir}/#{uuid}_w*_hnil_*.webp") ++
        Path.wildcard("#{cache_dir}/#{uuid}_*.webp")

    case Enum.uniq(candidates) do
      [] ->
        {:error, "no cached file found"}

      [path | _] ->
        case Image.open(path) do
          {:ok, img} ->
            {width, height, _bands} = Image.shape(img)
            {:ok, width, height}

          _ ->
            {:error, "Image.open failed for #{path}"}
        end
    end
  end
end
