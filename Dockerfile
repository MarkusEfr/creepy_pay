# ---- 📦 Builder Stage ----
ARG ELIXIR_VERSION=1.18.2
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bullseye-20250224-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS builder

ENV MIX_ENV=prod
WORKDIR /app

# Install build tools
RUN apt-get update -y && \
  apt-get install -y build-essential git npm curl && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Install Elixir deps
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy config before full source for cache efficiency
RUN mkdir -p config
COPY config/config.exs config/prod.exs config/

# Compile deps
RUN mix deps.compile

# Copy full app source
COPY lib lib
COPY priv priv

# ---- 📁 Assets Build ----
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets install
COPY assets assets
RUN mix assets.deploy

# Compile & Release
RUN mix compile
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ---- 🚀 Runner Stage ----
FROM debian:${DEBIAN_VERSION} AS runner

# Install runtime deps
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en \
  LC_ALL=en_US.UTF-8

WORKDIR /app
RUN useradd -ms /bin/bash appuser
ENV MIX_ENV=prod

# Copy release from builder
COPY --from=builder --chown=appuser:appuser /app/_build/prod/rel/creepy_pay ./

USER appuser

CMD ["/app/bin/creepy_pay", "start"]
