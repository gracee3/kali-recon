FROM kalilinux/kali-rolling

ARG DEBIAN_FRONTEND=noninteractive
# Optional install of lightweight screenshot tooling (e.g. wkhtmltoimage) to keep default image lean.
# Build with --build-arg ENABLE_SCREENSHOT_TOOL=1 to include it.
ARG ENABLE_SCREENSHOT_TOOL=0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      git \
      jq \
      yq \
      ripgrep \
      fd-find \
      less \
      tree \
      dnsutils \
      whois \
      python3 \
      python3-pip \
      subfinder \
      amass \
      httpx-toolkit \
      wpscan; \
    if [ "$ENABLE_SCREENSHOT_TOOL" = "1" ]; then \
      apt-get install -y --no-install-recommends wkhtmltopdf; \
    fi; \
    ln -s /usr/bin/fdfind /usr/local/bin/fd || true; \
    ln -s /usr/bin/httpx-toolkit /usr/local/bin/httpx || true; \
    if [ ! -f /usr/local/bin/tini ]; then \
      TINI_ARCH="$(dpkg --print-architecture)"; \
      case "$TINI_ARCH" in \
        amd64) TINI_RELEASE_ARCH=amd64 ;; \
        arm64) TINI_RELEASE_ARCH=arm64 ;; \
        armhf) TINI_RELEASE_ARCH=armhf ;; \
        *) echo "Unsupported architecture for tini: $TINI_ARCH"; exit 1 ;; \
      esac; \
      curl -fsSL "https://github.com/krallin/tini/releases/latest/download/tini-${TINI_RELEASE_ARCH}" -o /usr/local/bin/tini; \
      chmod +x /usr/local/bin/tini; \
    fi; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash recon \
 && mkdir -p /workspace/input /workspace/output /workspace/config /workspace/tmp \
 && chown -R recon:recon /workspace /home/recon

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY shell-init.sh /home/recon/.bashrc
COPY recon-env.sh /usr/local/bin/recon-env

RUN chmod +x /usr/local/bin/docker-entrypoint /usr/local/bin/recon-env \
 && chown recon:recon /home/recon/.bashrc \
 && chmod 755 /usr/local/bin/tini

USER recon

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["bash"]
