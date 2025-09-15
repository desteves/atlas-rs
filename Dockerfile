# Tools image: Terraform + MongoDB Atlas CLI + providers pre-fetched
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

# Install essentials, HashiCorp repo, and Terraform (>= 1.6)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        jq \
        gnupg \
        software-properties-common \
        apt-transport-https \
        zip \
        bash; \
    rm -rf /var/lib/apt/lists/*; \
    # HashiCorp APT repo
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" > /etc/apt/sources.list.d/hashicorp.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends terraform; \
    terraform -version; \
    rm -rf /var/lib/apt/lists/*

# Install MongoDB Atlas CLI (atlas) from the latest GitHub release
# Resolves the correct linux asset for the current architecture via GitHub API
RUN set -eux; \
    tmpdir="$(mktemp -d)"; \
    arch="$(dpkg --print-architecture)"; \
    # Fetch latest release asset URL for linux + current arch + .tar.gz
    url="$( \
      curl -s https://api.github.com/repos/mongodb/mongodb-atlas-cli/releases/latest \
      | jq -r --arg arch "$arch" '[.assets[]
          | select((.name | test("linux"; "i"))
                   and (.name | test($arch; "i"))
                   and (.name | test("\\.tar\\.gz$"; "i"))
          )][0].browser_download_url' \
    )"; \
    echo "Downloading Atlas CLI from: ${url}"; \
    curl -fsSL "$url" -o "$tmpdir/atlas.tgz"; \
    tar -xzf "$tmpdir/atlas.tgz" -C "$tmpdir"; \
    # Find the extracted binary (atlas or atlascli) and install as /usr/local/bin/atlas
    binpath="$(find "$tmpdir" -maxdepth 3 -type f -perm -u+x \( -name atlas -o -name atlascli \) | head -n1 || true)"; \
    if [ -z "$binpath" ]; then \
      echo "ERROR: Could not locate atlas binary in archive"; \
      ls -laR "$tmpdir"; \
      exit 1; \
    fi; \
    install -m 0755 "$binpath" /usr/local/bin/atlas; \
    /usr/local/bin/atlas --version || true; \
    rm -rf "$tmpdir"

# Set up Terraform plugin cache to prefetch providers
ENV TF_PLUGIN_CACHE_DIR=/root/.terraform.d/plugin-cache
RUN mkdir -p "$TF_PLUGIN_CACHE_DIR"

# Default GCP ADC credentials path. Mount your SA JSON to this path.
ENV GOOGLE_APPLICATION_CREDENTIALS=/creds/gcp.json
RUN mkdir -p /creds

# Copy Terraform project into the image
WORKDIR /workspace
COPY terraform/ /workspace/terraform/

# Pre-download providers (no backend init to avoid creds during build)
RUN terraform -chdir=/workspace/terraform init -backend=false -upgrade

# Default working directory for users
WORKDIR /workspace/terraform

# Default shell
CMD ["bash"]
