# Kubernetes observability pipeline

A small GKE Standard cluster runs Vector and sends synthetic logs and Prometheus metrics over HTTPS to OpenObserve Cloud. Terraform manages the infrastructure; plain Kubernetes manifests configure the workload.

The deployment and load test are complete, and the GKE infrastructure has been destroyed. Over a four-minute measurement window, accepted records represented **5.004 GB/hour of logs** and **4.995 GB/hour of metrics**. These rates use reconstructed, uncompressed JSON size, including returned metadata—not a verified provider billing counter. See [measurement details and limitations](docs/throughput.md).

## Repository layout

```text
terraform/              GKE, networking, IAM, variables and outputs
kubernetes/             Development and finite load-test manifests
dashboards/             Two OpenObserve dashboard exports
docs/
   throughput.md        Test method, results and reproduction steps
   evidence/            Query responses and Kubernetes validation output
   screenshots/         Selected deployment and dashboard screenshots
```

Credentials, Terraform state and saved plans stay local. The provider lock file is committed for repeatable installs.

## Architecture

```text
Terraform → GKE Standard (one node)
                └─ Vector → synthetic logs ────────┐
                          → Prometheus metrics ────┤ HTTPS
                                                  ▼
                                          OpenObserve Cloud
                                          ├─ Logs dashboard
                                          └─ Metrics dashboard
```

Development uses one Vector pod at low rates. The finite load test uses two pods sharing the target rate for five minutes each. The reported rates cover the four-minute window when both pods were running.

## Prerequisites

- Terraform >= 1.6, Google Cloud CLI, kubectl and the GKE authentication plugin.
- A GCP project with billing, sufficient quota, and permission to create the resources.
- Application Default Credentials: `gcloud auth application-default login`.
- An OpenObserve Cloud organization and ingestion credentials.

The recorded deployment used `personal-500014`, `asia-south1-a`, and one `n2-standard-2` node. N2 was selected because the project's E2 quota was zero. Review the defaults in `terraform/variables.tf` before using another project.

## Create the cluster

Run from the repository root:

```bash
printf 'admin_cidr = "YOUR_PUBLIC_IP/32"\n' > terraform/terraform.tfvars
```

Set `admin_cidr` to your public IPv4 address with `/32`, then run:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=assignment.tfplan
terraform -chdir=terraform apply assignment.tfplan
terraform -chdir=terraform output -raw get_credentials
```

Run the printed credentials command, then confirm the cluster:

```bash
kubectl config current-context
kubectl get nodes -o wide
```

## Deploy Vector

Update the OpenObserve API host and organization in the chosen ConfigMap for your account. `kubernetes/secret.yaml` contains base64-encoded dummy credentials. Replace its username and password with your own values before applying it.

If OpenObserve provides a Basic access key, its decoded form is `username:password`. Split at the first colon and encode each part separately for the Secret. Base64 is encoding, not encryption. Keep real credential changes local; never commit them. The repository contains dummy values only.

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secret.yaml
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl -n observability rollout status deployment/vector --timeout=180s
kubectl -n observability get pods
kubectl -n observability logs deployment/vector --tail=50
```

After editing the ConfigMap, apply it and run `kubectl -n observability rollout restart deployment/vector`. Do not apply the entire directory: development and load-test files manage the same objects with different settings.

## Validate ingestion and run the load test

Check that `assignment_logs` and `synthetic_latency_ms` contain recent data in OpenObserve. Read Vector logs for rejected requests or dropped events. To inspect Vector's internal metrics:

```bash
kubectl -n observability port-forward deployment/vector 9598:9598
```

Open `http://localhost:9598/metrics`. Pod readiness only checks the metrics listener; successful ingestion must be checked separately. Sink health checks are disabled, so clean startup alone does not prove delivery.

Follow [the finite load-test procedure](docs/throughput.md) for the two-pod run, measurement SQL and recorded results. The development configuration does not generate the target throughput.

## Dashboards and evidence

Import both JSON files from [dashboards](dashboards/README.md) into OpenObserve. The logs dashboard shows volume, levels, top services and accepted JSON-equivalent rate. The metrics dashboard shows latency, accepted samples, sender bytes and accepted JSON-equivalent rate.

For the recorded load test, select **September 11, 2026, 21:00–21:04 UTC** (**September 12, 02:30–02:34 IST**). The default relative time range will show no new data after teardown. Dashboard data remains subject to OpenObserve retention.

[Selected screenshots](docs/screenshots/README.md) show the initial deployment and earlier low-rate dashboards. [Raw evidence](docs/evidence/) supports the later throughput calculation. The added rate panels returned data through the API, but still need a visual check in OpenObserve.

## Design and cost choices

A dedicated VPC, one zonal node pool and a dedicated node service account keep the setup small. The control-plane endpoint accepts the developer's `/32`. Workload Identity, shielded nodes, non-root containers, read-only root filesystems and resource limits provide basic isolation. Vector does not mount a Kubernetes API token.

The node's external IP provides outbound HTTPS without Cloud NAT. No application LoadBalancer or NodePort is created. This single-node demo uses memory buffers and temporary storage; restarts can lose queued data, and it is not highly available.

The working budget was ₹500 total. Potential charges include cluster management, compute, disk, external IPv4, egress and OpenObserve usage outside its allowance. The final settled bill has not been verified. A budget alert is not a spending cap; stop generation and destroy the infrastructure promptly after validation.

## Teardown

The recorded deployment is already destroyed; see [cleanup evidence](docs/evidence/teardown.txt). For a future run, export dashboards and save evidence, then stop traffic:

```bash
kubectl -n observability scale deployment/vector --replicas=0
terraform -chdir=terraform destroy
```

Review the plan and enter `yes`. If already inside `terraform/`, use `terraform destroy` without `-chdir`. Afterwards, `terraform state list` should be empty and the cluster, node disks and dedicated network should be absent in GCP.

A state-lock error means another Terraform operation may be running. Wait for that operation and inspect its output. Do not bypass locking with `-lock=false` or force-unlock an active operation. A saved destroy plan executed with `terraform apply` can legitimately report `OperationTypeApply` in its lock.

Terraform preserves enabled project APIs on destroy. OpenObserve data and the account have a separate lifecycle.
