import Config

target = System.get_env("EXLA_TARGET", "host")

config :exla, :clients, default: [platform: :cuda]

config :logger, :console,
  format: "\n$time [$level] $metadata $levelpad$message\n",
  metadata: [:domain, :file, :line]
