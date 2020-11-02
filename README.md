LoggerHumioBackend
=======================

## About

A backend for the [Elixir Logger](http://elixir-lang.org/docs/v1.0/logger/Logger.html)
that will send logs to [Humio](https://www.humio.com/).

## Supported options

### Required
* **host**: `String.t`. The hostname of the Humio ingest API endpoint.
* **token**: `String.t`. The unique Humio ingest token for the log destination.

### Optional
* **format**: `String.t`. The logging format of the message. [default: `$datetime $hostname[$pid]: [$level] $message $metadata`].
* **level**: `atom`. Minimum level for this backend. [default: `:debug`]
* **metadata**: `Keyword.t`. Extra fields to be added when sending the logs. These will
be merged with the metadata sent in every log message.  [default: `[]`]
* **client**: `Logger.Humio.Backend.Client`.  Client used to send messages to Humio.  [default: `Logger.Humio.Backend.Client.Tesla`]
* **ingest_api**: `Logger.Humio.Backend.IngestApi`.  Humio API endpoint to which to send the logs.  [default: `Logger.Humio.Backend.IngestApi.Unstructured`]
* **max_batch_size**: `pos_integer`. Maximum number of logs that the library will batch before sending them to Humio.  [default: `20`]
* **flush_interval_ms**: `pos_integer`.  Maximum number of milliseconds that ellapses between flushes to Humio. [default: `10_000`]
* **debug_io_device**: `PID`, `:stdio`, or `:stderr`. The IO device to which error messages are sent if sending logs to Humio fails for any reason. [default: `::stdio`]

### Ingest API-specifc

These configuration options only have an effect if the corresponding Ingest API is specified.

#### Unstructured
* **fields**: `map`. Can be used to specify fields that will be added to each request. Useful for setting service name, for example, without needing to add it to every log line. [default: `%{}`]
* **tags**: `map`. Can be used to specify [tags](https://docs.humio.com/ingesting-data/parsers/tagging/) that will be added to each request. Only use if you understand the difference between fields and tags in the context of Humio. [default: `%{}`]

## Using it with Mix

To use it in your Mix projects, first add it as a dependency:

```elixir
def deps do
  [{:logger_humio_backend, git: "https://github.com/akasprzok/logger_humio_backend/", tag: "v0.0.6"}]
end
```
Then run mix deps.get to install it.

## Configuration Examples

### Runtime

```elixir
Logger.add_backend {Logger.Backend.Humio, :debug}
Logger.configure {Logger.Backend.Humio, :debug},
  format: "[$level] $message\n"
  host: "https://humio-ingest.bigcorp.com:443",
  level: :debug,
  token: "ingest-token-goes-here",
```

### Application config

#### Minimal

```elixir
config :logger,
  utc_log: true #recommended
  backends: [{Logger.Backend.Humio, :humio_log}, :console]

config :logger, :humio_log,
  host: "https://humio-ingest.bigcorp.com:443/",
  token: "ingest-token-goes-here",
```

#### With All Options
```elixir
config :logger,
  utc_log: true #recommended
  backends: [{Logger.Backend.Humio, :humio_log}, :console]

config :logger, :humio_log,
  host: "https://humio-ingest.bigcorp.com:443/",
  token: "ingest-token-goes-here",
  format: "[$level] $message\n",
  level: :debug,
  metadata: [:request_id, :customer_id],
  client: Logger.Backend.Humio.Client.Tesla,
  ingest_api: Logger.Backend.Humio.IngestApi.Unstructured,
  max_batch_size: 50,
  flush_interval_ms: 5_000,
  debug_io_device: :stderr,
  fields: %{
    "service" => "my_service"
  },
  tags: %{
    "env" => "dev"
  }
```

## Ingest APIs

Ingest APIs are configured using the `ingest_api` config option.  They are prefixed with `Logger.Backend.Humio.IngestApi`.  They format logs according to Humio's ingest APIs and then pass the formatted logs to the `Logger.Backend.Humio.Client` to send to Humio.

### Unstructured

Uses Humio's [unstructured ingest API](https://docs.humio.com/api/ingest/#parser).  It functions very closely to the default console backend.  `fields` can be added to every request using the `fields` config option.

### Structured

Uses Humio's [structured ingest API](https://docs.humio.com/api/ingest/#structured-data). Logs are formatted as `events`.

Metadata is omitted when formatting the message according to the `format` specified, and instead added as `attributes` key-value pairs.  
The timestamp is added in the `event`'s `timestamp` field, and can be omitted in the `format` config.

## Clients

A Client sends logs formatted by an Ingest API to Humio.  Clients are prefixed with `Logger.Backend.Humio.Client`.

### Tesla

The default (and currently only) client.  Compresses payload using `gzip` and contains sensible retry defaults.

## Batching

The library will batch requests until either
1. the buffer of logs has reached the `max_batch_size` or
2. an amount of time equal to `flush_interval_ms` has passed.

At this point the logger backend will send all accrued log events to Humio, and reset the flush interval timer.

The logger can be flushed manually by calling `Logger.flush()`.  Note this will flush _all_ registered logger backends.

## Formatter

This logging backend implements its own formatter. It supports all the options present in Elixir's `Logger.Formatter`, plus these additiona options:

* `$datetime`, which formats the time stamp as an ISO8601 timestamp.
* `$hostname`, which prints the current hostname retrieved via `:inet.gethostname/0`.
* `$pid`, which prints the PID of the process from which the log was sent. This works even when `:pid` is excluded from the `metadata` config.