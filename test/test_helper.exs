ExUnit.start()

Mox.defmock(Logger.Backend.Humio.Client.Mock, for: Logger.Backend.Humio.Client)
Mox.defmock(Logger.Backend.Humio.IngestApi.Mock, for: Logger.Backend.Humio.IngestApi)
