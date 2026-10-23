# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=gitea/runner-images:ubuntu-24.04
FROM ${BASE_IMAGE}

ARG GCLOUD_VERSION=581.0.0
ARG KUBECTL_VERSION=1.36.2
ARG BUN_VERSION=1.3.14
ARG NODE_MAJOR_VERSION=26
ARG NODE_VERSION=26.9.0-1nodesource1
ARG PNPM_VERSION=12.5.1
ARG TERRAFORM_VERSION=1.13.5

ENV DEBIAN_FRONTEND=noninteractive \
    BUN_INSTALL=/opt/bun \
    PATH=/opt/bun/bin:/usr/bin:${PATH}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y ca-certificates curl gnupg unzip; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor --batch --yes -o /etc/apt/keyrings/nodesource.gpg; \
    chmod a+r /etc/apt/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR_VERSION}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list; \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor --batch --yes -o /etc/apt/keyrings/cloud.google.gpg; \
    chmod a+r /etc/apt/keyrings/cloud.google.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list; \
    apt-get update; \
    CLOUDSDK_SKIP_PY_COMPILATION=1 apt-get install --no-install-recommends -y \
      "google-cloud-cli=${GCLOUD_VERSION}-0" \
      "google-cloud-cli-gke-gcloud-auth-plugin=${GCLOUD_VERSION}-0" \
      "nodejs=${NODE_VERSION}"; \
    npm install --global --no-audit --no-fund "pnpm@${PNPM_VERSION}"; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    kubectl_version="v${KUBECTL_VERSION}"; \
    curl -fsSL "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl" -o /tmp/kubectl; \
    curl -fsSL "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl.sha256" -o /tmp/kubectl.sha256; \
    echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check --strict; \
    install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
    rm -f /tmp/kubectl /tmp/kubectl.sha256

RUN set -eux; \
    curl -fsSL https://bun.sh/install | bash -s -- "bun-v${BUN_VERSION}"; \
    ln -sf /opt/bun/bin/bun /usr/local/bin/bun; \
    ln -sf /opt/bun/bin/bunx /usr/local/bin/bunx

RUN set -eux; \
    workdir="$(mktemp -d)"; \
    cd "$workdir"; \
    archive="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"; \
    curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${archive}"; \
    unzip "$archive" terraform; \
    install -o root -g root -m 0755 terraform /usr/local/bin/terraform; \
    cd /; \
    rm -rf "$workdir"

LABEL org.opencontainers.image.title="Gitea Ubuntu 24.04 job image" \
      org.opencontainers.image.description="Ubuntu 24.04 Gitea job image with Google Cloud CLI, GKE auth plugin, kubectl, Node.js, pnpm, Bun, and Terraform" \
      org.opencontainers.image.source="https://github.com/palamccc/gitea-runner-ubuntu"

RUN set -eux; \
    test "$(. /etc/os-release && echo "${VERSION_ID}")" = "24.04"; \
    gcloud --version; \
    command -v gke-gcloud-auth-plugin; \
    kubectl version --client; \
    node_version="$(node --version)"; \
    [[ "$node_version" == v26.* ]]; \
    echo "$node_version"; \
    pnpm --version; \
    bun --version; \
    terraform version
