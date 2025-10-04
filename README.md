# atlas-rs
Deploys a 5-node distributed Replica Set plus a regional read-only node in MongoDB Atlas (AWS).

## Terraform Infrastructure

This repository now contains a Terraform project (in `terraform/`) that provisions:

* A MongoDB Atlas cluster in an existing Atlas Project
* A two-region (US-EAST-1 + US-EAST-2) advanced replica set cluster (5 electable nodes by default: 3 in US-EAST-1, 2 in US-EAST-2), plus an additional read-only node in AP-SOUTHEAST-2 (Sydney, Australia), running MongoDB 7.0. Note: Multi-region requires at least M30 instance size.

### 1. Prerequisites

* Terraform >= 1.6
* MongoDB Atlas API Key with access to the target project
* Existing Atlas Project ID (set `atlas_project_id`)
* (Optional) Remote state: you can configure a backend later (S3, GCS, etc.). By default this project uses local state.

#### Atlas

The MongoDB Atlas provider requires credentials. Export the following environment variables before `terraform init/plan/apply`:

```bash
export MONGODB_ATLAS_PUBLIC_KEY=
export MONGODB_ATLAS_PRIVATE_KEY=
export TF_VAR_atlas_project_id=
```

### 2. Deploy Resources

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

## Docker Tools Image (Atlas CLI + Terraform)

- Build a local image that includes Terraform, the MongoDB Atlas CLI, copies this repo’s `terraform/` folder, and pre-downloads required providers.

```bash
docker build -t atlas-tf-tools .
```

- Run it with your Atlas and GCP credentials (example):

```bash
docker run -it --rm \
  -e MONGODB_ATLAS_PUBLIC_KEY=$MONGODB_ATLAS_PUBLIC_KEY \
  -e MONGODB_ATLAS_PRIVATE_KEY=$MONGODB_ATLAS_PRIVATE_KEY \
  -e TF_VAR_atlas_project_id=$TF_VAR_atlas_project_id \
  atlas-tf-tools

# inside the container
terraform validate
terraform plan
terraform apply
```

Notes:
- Providers are pre-fetched during the image build (via `terraform init -backend=false`).
- The Atlas CLI (`atlas`) and Terraform (>= 1.6) are installed in the image.

## Backend (State)

- By default, Terraform uses local state in the `terraform/` directory. If you want remote state (e.g., GCS or S3), add a backend block in `terraform/versions.tf` and run `terraform init` to configure/migrate state.

### 3. Run Demos

There are demo apps available to show the impact of read preference and write times to sharded clusters at:

https://us.mdb-architect-day.net:3000

and

https://au.mdb-architect-day.net:3000

One instance is deployed on an AWS EC2 node in US-EAST-1, the other in AP-SOUTHEAST-2. 

#### Localized Reads vs not so

The AU demo instance, in particualr, will show a significant drop in latency when switching from default 'PRIMARY' read preference, to 'NEAREST' read preference.

#### Upgrade to MongoDB 8.0 while application is running.

See the step-by-step Terraform demo: `demos/upgrade-mongodb-7-to-8/README.md:1`


#### Convert Replica Set to One-Shard Cluster

See the sharding upgrade demo: `demos/replicaset-to-one-shard/README.md:1`


