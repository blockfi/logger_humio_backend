LoggerHumioBackend
=======================

## About

A [Elixir Logger](http://elixir-lang.org/docs/v1.0/logger/Logger.html) backend for [Humio](https://www.humio.com/).

## Supported options

### Required
* **host**: `String.t()`. The hostname of the Humio ingest API endpoint.
* **token**: `String.t()`. The unique Humio ingest token for the log destination.

### Optional
* **format**: `String.t()`. The logging format of the message. [default: `$hostname[$pid]: [$level]$levelpad $message`].
* **level**: `atom()`. Minimum level for this backend. [default: `:debug`]
* **metadata**: `list() | :all | {:except, list()}`. Specifies the metadata to be sent to Humio. If a list, sends all the metadata with keys in the list. `:all` sends all metadata. The tuple of `:except` and a list specifies that all metadata except for the keys in the list should be sent. [default: `[]`]
* **client**: `Logger.Humio.Backend.Client`.  Client used to send messages to Humio.  [default: `Logger.Humio.Backend.Client.Tesla`]
* **max_batch_size**: `pos_integer()`. Maximum number of logs that the library will batch before sending them to Humio.  [default: `20`]
* **flush_interval_ms**: `pos_integer()`.  Maximum number of milliseconds that ellapses between flushes to Humio. [default: `2_000`]
* **debug_io_device**: `pid()`, `:stdio`, or `:stderr`. The IO device to which error messages are sent if sending logs to Humio fails for any reason. [default: `:stdio`]
* **fields**: `map()`. Can be used to specify fields that will be added to each request. Useful for setting service name, for example, without needing to add it to every log line. [default: `%{}`]
* **tags**: `map()`. Can be used to specify [tags](https://docs.humio.com/ingesting-data/parsers/tagging/) that will be added to each request. Only use if you understand the difference between fields and tags in the context of Humio. [default: `%{}`]

## Using it with Mix

To use it in your Mix projects, first add it as a dependency:

```elixir
def deps do
  [{:logger_humio_backend, "~> 0.1.0"}]
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
  print_config?: true,
  level: :debug,
  metadata: [:request_id, :customer_id],
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

### Tesla

The default (and currently only) client.  Compresses payload using `gzip` and contains sensible retry defaults.

## Batching

The library will batch requests until either
1. the buffer of logs has reached the `max_batch_size` or
2. an amount of time equal to `flush_interval_ms` has passed.

At this point the logger backend will send all accrued log events to Humio, and reset the flush interval timer.

The logger can be flushed manually by calling `Logger.flush()`.  Note this will flush _all_ registered logger backends.

## Metadata

Metadata is sent to Humio as `attributes` using the `Structured` Ingest API. This means any metadata you set will be ingested as `fields` in Humio, and, unlike the `:console` logger, metadata can not be appended in the Formatter. This is much more powerful than the `:console` logger, as it enables the ingestion of nested maps, lists, and generally more complex metadata than just string values.

## Formatter

This logging backend implements its own formatter, similar to Elixir's [Logger.Formatter](https://hexdocs.pm/logger/Logger.Formatter.html).

It allows developers to specify a string that serves as template for log messages, for example:

```
$hostname[$pid]: [$level]$levelpad $message
```

Will print error messages as:

```
localhost[<0.349.0>]: [error] Hello
```

The valid parameters you can use are: 

* `$application` - the name of the application from which the log was sent.
* `$hostname` - the hostname retrieved via `:inet.gethostname/0`.
* `$level` - the log level
* `$levelpad` - sets to a single space if level is 4 characters long, otherwise set to the empty space. Used to align the message after level.
* `$message` - the log message
* `$node` - the node that prints the message
* `$pid` - the PID of the process from which the log was sent. This works even when `:pid` is excluded from the `metadata` config.