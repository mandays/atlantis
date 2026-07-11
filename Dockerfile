# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Build args (override at build time or via docker-compose "args:", which in
# turn can be sourced from .env)
# ---------------------------------------------------------------------------
ARG ATLANTIS_VERSION=v0.42.0
ARG TERRAGRUNT_VERSION=1.1.0

# ---------------------------------------------------------------------------
# Stage 1: fetch and checksum-verify the Terragrunt binary
# The official Atlantis image already bundles OpenTofu (see
# DEFAULT_OPENTOFU_VERSION in the upstream Dockerfile), so we only need to
# add Terragrunt ourselves.
# ---------------------------------------------------------------------------
FROM alpine:3.20 AS terragrunt-fetcher

ARG TERRAGRUNT_VERSION
ARG TARGETARCH

RUN apk add --no-cache curl ca-certificates

WORKDIR /tmp

RUN BINARY="terragrunt_linux_${TARGETARCH}" \
 && curl -fsSL -o "${BINARY}" \
      "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/${BINARY}" \
 && curl -fsSL -o SHA256SUMS \
      "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/SHA256SUMS" \
 && grep "${BINARY}\$" SHA256SUMS | sha256sum -c - \
 && mv "${BINARY}" terragrunt \
 && chmod +x terragrunt

# ---------------------------------------------------------------------------
# Stage 2: final image
# ---------------------------------------------------------------------------
FROM ghcr.io/runatlantis/atlantis:${ATLANTIS_VERSION}

ARG TERRAGRUNT_VERSION
LABEL org.opencontainers.image.description="Atlantis with OpenTofu (bundled) + Terragrunt ${TERRAGRUNT_VERSION}"

USER root

COPY --from=terragrunt-fetcher /tmp/terragrunt /usr/local/bin/terragrunt

# Sanity check at build time: both binaries must resolve and run.
RUN terragrunt --version \
 && tofu version

# Drop back to the non-root user the base image already creates.
USER atlantis

# Pre-create directories Atlantis needs at runtime to avoid permission issues.
RUN mkdir -p /home/atlantis/.atlantis/bin && chmod 755 /home/atlantis/.atlantis/bin

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]
