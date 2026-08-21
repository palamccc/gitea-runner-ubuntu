# Gitea Ubuntu 24.04 Job Image

An Ubuntu 24.04 job image for Gitea Actions, based on the official
`gitea/runner-images:ubuntu-24.04` image.

It adds these pinned tools:

| Tool | Version |
| --- | --- |
| Google Cloud CLI | 581.0.0 |
| GKE gcloud auth plugin | 581.0.0 |
| kubectl | 1.36.2 |
| Bun | 1.3.14 |

The image is published for `linux/amd64` as:

```text
ghcr.io/palamccc/gitea-runner-ubuntu:latest
```

## Configure Gitea

This is a job image, not an `act_runner` daemon image. Configure the Gitea
runner's Docker label to use it:

```text
ubuntu-24.04:docker://ghcr.io/palamccc/gitea-runner-ubuntu:latest
```

For example, the equivalent environment variable when starting `act_runner`
is:

```bash
GITEA_RUNNER_LABELS='ubuntu-24.04:docker://ghcr.io/palamccc/gitea-runner-ubuntu:latest'
```

The runner must be configured in Docker mode. The image is public, so the job
container does not need GHCR credentials to pull it.

## Use it in a Gitea workflow

```yaml
name: Build and deploy

on:
  push:

jobs:
  build-and-deploy:
    runs-on: ubuntu-24.04
    steps:
      - name: Check out source
        uses: actions/checkout@v4

      - name: Install dependencies
        run: bun install --frozen-lockfile

      - name: Build
        run: bun run build

      # Authenticate gcloud using your Gitea secret or workload identity.
      - name: Deploy
        run: |
          gcloud container clusters get-credentials "$GKE_CLUSTER" \
            --location "$GKE_LOCATION" \
            --project "$GCP_PROJECT"
          kubectl apply -f k8s/
```

The `gke-gcloud-auth-plugin` is included so `kubectl` can authenticate to GKE
clusters using the active Google Cloud credentials.

Provide `GKE_CLUSTER`, `GKE_LOCATION`, and `GCP_PROJECT` through Gitea
secrets or environment configuration. Never bake cloud credentials into this
image.

If a build itself needs to build and publish container images, configure the
Gitea runner's Docker access separately. This image provides the job tools; it
does not run a Docker daemon.

## Local build

```bash
docker build --platform linux/amd64 -t gitea-runner-ubuntu:latest .
docker run --rm --platform linux/amd64 gitea-runner-ubuntu:latest bash -lc '
  . /etc/os-release && test "$VERSION_ID" = "24.04"
  gcloud --version
  kubectl version --client
  bun --version
'
```

## Publishing

The GitHub Actions workflow runs on every push and publishes only the
`latest` tag to GHCR. It uses the repository `GITHUB_TOKEN`; no personal
access token is stored in the repository.
