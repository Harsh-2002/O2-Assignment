# Assignment review

Compared with the supplied Kubernetes Observability Pipeline assignment PDF.

| Requirement | Repository evidence | Status |
| --- | --- | --- |
| Managed Kubernetes through Terraform | `terraform/` provisions GKE Standard | Implemented and tested |
| Security best practices | Restricted API CIDR, dedicated node IAM, non-root pods, no API token mount | Implemented; demo tradeoffs documented |
| Vector dummy logs and metrics | Development and finite load-test manifests in `kubernetes/` | Implemented and tested |
| Approximately 5 GB/hour per signal | `docs/throughput.md` and query evidence | Approximately met on reconstructed accepted-record JSON size; provider ingestion-byte counter not verified |
| OpenObserve ingestion | Accepted-record query responses in `docs/evidence/` | Verified during the recorded run |
| Logs dashboard: volume, levels, services | `dashboards/logs.dashboard.json` | Export present |
| Metrics dashboard: key metrics and ingestion rate | `dashboards/metrics.dashboard.json` | Export present |
| Deployment instructions and design decisions | Root `README.md` | Present |
| Tear down after testing | `docs/evidence/teardown.txt` | Completed and verified |
| GitHub repository with final files | Terraform, manifests, exports and documentation | Included in the submission |

The PDF does not prescribe folder names, require screenshots, or specify a minimum test duration. The recorded four-minute measurement is not an hour-long endurance test.

The selected screenshots show the earlier low-rate dashboards. Final rate-panel queries returned data, but their UI rendering has not yet been verified. Capture the recorded absolute time window if adding final dashboard screenshots.
