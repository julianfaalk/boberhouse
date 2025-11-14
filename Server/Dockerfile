### Multi-stage build for the Vapor Server
# Build stage – compile the app with Swift toolchain
FROM swift:5.10-jammy AS build

WORKDIR /build

# Copy only the manifest files first to leverage Docker layer caching
COPY Package.swift Package.resolved ./

# Copy the rest of the sources
COPY Sources ./Sources

# Build the Run executable in release mode
RUN swift build --configuration release --product Run


# Runtime stage – minimal image with only the compiled binary
FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libssl3 \
        libsqlite3-0 \
        ca-certificates \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# Copy Swift runtime libraries from the build stage so the binary can run on plain Ubuntu
COPY --from=build /usr/lib/swift/linux /usr/lib/swift/linux
ENV LD_LIBRARY_PATH=/usr/lib/swift/linux:$LD_LIBRARY_PATH

WORKDIR /app

# Copy the compiled binary from the build stage
COPY --from=build /build/.build/release/Run /app/Run

# Ensure the entrypoint script has execute permissions
RUN chmod +x /app/Run

# Create writable directories for runtime state (e.g. SQLite DB, Logs, Secrets)
RUN mkdir -p /data /secrets

ENV SQLITE_PATH=/data/boberhouse.sqlite

EXPOSE 8080

CMD ["/app/Run", "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
