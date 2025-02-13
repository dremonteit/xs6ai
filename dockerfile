# XS6 Dockerfile
# Note: Ensure you have cloned the git repository and submodules before running this file.
# This is used for active development while building for different architectures.

FROM docker.io/library/node:20.18.0-bookworm AS builder

# Set environment variables
ENV PATH="/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/usr/local/lib:/usr/include:/usr/share"

ARG DEBIAN_FRONTEND=noninteractive
ARG USE_SYSTEM_FPM=true
ARG PREVAL_BUILD_INFO_PLACEHOLDERS=true

# Install dependencies required for building on ARM architectures
RUN apt-get update -y \
  && apt-get install --no-install-recommends -y rpm ruby gem \
  && gem install dotenv -v 2.8.1 --no-document \
  && gem install fpm --no-document

WORKDIR /usr/src/xs6

# Copy package files
COPY package*.json ./
COPY .npmrc ./

# Install pnpm and dependencies
RUN npm i -gf "pnpm@$(node -p 'require("./package.json").engines.pnpm')" && pnpm -v
RUN pnpm i

# Copy source code
COPY . .

WORKDIR /usr/src/xs6/modules
RUN pnpm i && pnpm lint && pnpm reformat-files && pnpm package

WORKDIR /usr/src/xs6

# Build XS6 based on system architecture
RUN arch="$(dpkg --print-architecture)"; \
        case "$arch" in \
            *arm*) TARGET_ARCH=arm64 ;; \
            *)     TARGET_ARCH=x64 ;; \
        esac; \
        pnpm build --$TARGET_ARCH --dir

# --------------------------------------------------------------------------------------------

# Use a lightweight image for the final build
FROM docker.io/library/busybox:latest

WORKDIR /xs6

# Copy the built output from the builder stage
COPY --from=builder /usr/src/xs6/out/* /xs6/

VOLUME [ "/xs6-out" ]
