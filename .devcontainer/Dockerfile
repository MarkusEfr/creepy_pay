# Use base Ubuntu image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl gnupg apt-transport-https \
    git build-essential \
    inotify-tools \
    wget \
    libssl-dev \
    libncurses5-dev \
    libwxgtk3.0-gtk3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libpng-dev \
    libssh-dev \
    unixodbc-dev \
    xsltproc \
    fop \
    libxml2-utils \
    libncurses-dev \
    libffi-dev \
    liblzma-dev \
    zlib1g-dev \
    libgmp-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install ASDF version manager
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
ENV PATH="/root/.asdf/bin:/root/.asdf/shims:$PATH"
RUN echo ". $HOME/.asdf/asdf.sh" >> ~/.bashrc

# Install Erlang and Elixir via ASDF
RUN bash -c ". $HOME/.asdf/asdf.sh && \
    asdf plugin add erlang && \
    asdf plugin add elixir && \
    asdf install erlang 26.2 && \
    asdf install elixir 1.16.2 && \
    asdf global erlang 26.2 && \
    asdf global elixir 1.16.2"

# Install Node.js (Phoenix needs it for assets)
RUN bash -c ". $HOME/.asdf/asdf.sh && \
    asdf plugin add nodejs && \
    bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring && \
    asdf install nodejs 20.11.1 && \
    asdf global nodejs 20.11.1"

# Install Hex & Rebar
RUN mix local.hex --force && mix local.rebar --force

# Set workdir
WORKDIR /workspace

EXPOSE 4000
