FROM kalilinux/kali-rolling

ARG DEBIAN_FRONTEND=noninteractive
ARG ENABLE_SCREENSHOT_TOOL=0

ENV HOME=/home/recon \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -euxo pipefail; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      openssl \
      git \
      jq \
      yq \
      ripgrep \
      fd-find \
      less \
      netcat-openbsd \
      tree \
      nmap \
      dnsutils \
      whois \
      tcpdump \
      python3 \
      python3-pip \
      subfinder \
      amass \
      httpx-toolkit \
      wpscan \
      tini; \
    if [ "$ENABLE_SCREENSHOT_TOOL" = "1" ]; then \
      if apt-cache search '^wkhtmltopdf$' | grep -qx 'wkhtmltopdf'; then \
        apt-get install -y --no-install-recommends wkhtmltopdf; \
      else \
        echo "WARN: ENABLE_SCREENSHOT_TOOL=1 but wkhtmltopdf is unavailable on this Kali snapshot. Skipping screenshot package."; \
      fi; \
    fi; \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd; \
    ln -sf /usr/bin/httpx-toolkit /usr/local/bin/httpx; \
    mkdir -p /var/lib/libpostal; \
    touch /var/lib/libpostal/transliteration; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN useradd --system --create-home --shell /bin/bash --home-dir /home/recon recon \
 && install -d -m 0750 \
      /home/recon \
      /workspace/input \
      /workspace/output \
      /workspace/config \
      /workspace/tmp \
 && chown -R recon:recon /home/recon /workspace

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --chown=recon:recon shell-init.sh /home/recon/.bashrc
COPY recon-env.sh /usr/local/bin/recon-env

RUN chmod +x /usr/local/bin/docker-entrypoint /usr/local/bin/recon-env \
 && chmod 755 /usr/bin/tini \
 && chmod 644 /home/recon/.bashrc \
 && chmod 700 /workspace /home/recon

USER recon

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["bash"]
