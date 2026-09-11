# Dashboard exports

These JSON files were exported from OpenObserve Cloud after creation through its API. Import each file using Dashboards > Import.

- `logs.dashboard.json`: log volume per minute, log level distribution, and top services.
- `metrics.dashboard.json`: synthetic latency by service, accepted synthetic samples per second, and Vector sender bytes per second by sink.

All eight queries returned live data during validation. Each dashboard also includes an accepted JSON-equivalent GB/hour panel for the measured load-test run. The initial three-panel versions were visually checked in the supplied screenshots (see [screenshots](../docs/screenshots/README.md)). The added rate panels have been checked through their API queries; their UI rendering remains unverified. The default time range is the last 30 minutes; select the recorded test window after teardown.

Sample rate uses stored records in one-minute buckets, so partial boundary buckets undercount. Sender bytes include protocol/compression effects and are not the accepted ingestion byte rate. The measurement method and limitations are documented in [throughput report](../docs/throughput.md).

The JSON structure follows the version 5 examples in the OpenObserve dashboards repository: [OpenObserve dashboards repository](https://github.com/openobserve/dashboards). Panel queries and titles are specific to this assignment.
