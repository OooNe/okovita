# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :okovita,
  ecto_repos: [Okovita.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :okovita, OkovitaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: OkovitaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Okovita.PubSub,
  live_view: [signing_salt: "DPMRwiGN"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  okovita: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  okovita: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Field types registry — string name → module mapping
config :okovita, :field_types, %{
  "text" => Okovita.FieldTypes.Text,
  "textarea" => Okovita.FieldTypes.Textarea,
  "number" => Okovita.FieldTypes.Number,
  "integer" => Okovita.FieldTypes.Integer,
  "boolean" => Okovita.FieldTypes.Boolean,
  "enum" => Okovita.FieldTypes.Enum,
  "date" => Okovita.FieldTypes.Date,
  "datetime" => Okovita.FieldTypes.Datetime,
  "relation" => Okovita.FieldTypes.Relation,
  "relation_many" => Okovita.FieldTypes.RelationMany,
  "image" => Okovita.FieldTypes.Image,
  "image_gallery" => Okovita.FieldTypes.ImageGallery,
  "rich_text" => Okovita.FieldTypes.RichText
}

# Global sync pipelines — applied to all string values in entry data
config :okovita, :sync_pipelines, trim: Okovita.Pipeline.Sync.Trim
# Active transports
config :okovita, :transports, [
  Okovita.Transports.REST
]

# Oban job processing
config :okovita, Oban,
  repo: Okovita.Repo,
  queues: [pipeline: 10]

# ExAws Configuration
config :ex_aws,
  json_codec: Jason,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

config :okovita, :s3_bucket, System.get_env("S3_BUCKET_NAME", "okovita-content")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
