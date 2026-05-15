# Stage 1: build unison with OCaml 5.x to match brew's version on macOS
FROM ocaml/opam:ubuntu-24.04-ocaml-5.2 AS unison-builder

ENV UNISON_VERSION=2.54.0

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
USER opam

# Build from GitHub source using the opam-managed OCaml 5.2 compiler
RUN curl -fsSL https://github.com/bcpierce00/unison/archive/refs/tags/v${UNISON_VERSION}.tar.gz \
    | tar xz -C /tmp \
    && cd /tmp/unison-${UNISON_VERSION} \
    && eval $(opam env) && make \
    && cp src/unison /tmp/unison

# Stage 2: runtime image
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy unison binary built with matching OCaml version
COPY --from=unison-builder /tmp/unison /usr/local/bin/unison

# Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Non-root sandbox user
RUN useradd -m -s /bin/bash sandbox \
    && mkdir -p /workspace \
    && chown sandbox:sandbox /workspace

RUN mkdir -p /home/sandbox/.unison /home/sandbox/.claude \
    && chown -R sandbox:sandbox /home/sandbox/.unison /home/sandbox/.claude

WORKDIR /workspace
USER sandbox

CMD ["sleep", "infinity"]
