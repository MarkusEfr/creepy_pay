FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8

# Install deps
RUN apt-get update && apt-get install -y \
    curl git wget unzip gnupg ca-certificates \
    build-essential libssl-dev libncurses5-dev libwxgtk3.0-gtk3-dev libgl1-mesa-dev libqt5webkit5-dev libssh-dev \
    libxml2-dev libxslt1-dev libffi-dev libreadline-dev libz-dev libyaml-dev libsqlite3-dev sqlite3 \
    inotify-tools postgresql-client sudo

# Install ASDF
ENV ASDF_DIR=/root/.asdf
RUN git clone https://github.com/asdf-vm/asdf.git $ASDF_DIR --branch v0.13.1
RUN echo '. $ASDF_DIR/asdf.sh' >> /root/.bashrc

# Install Elixir & Erlang via ASDF
RUN bash -c ". $ASDF_DIR/asdf.sh && \
    asdf plugin add erlang && \
    asdf install erlang 26.2 && \
    asdf global erlang 26.2 && \
    asdf plugin add elixir && \
    asdf install elixir 1.16.2 && \
    asdf global elixir 1.16.2"

# Install GPG deps before nodejs plugin
RUN apt-get update && apt-get install -y dirmngr gpg curl

# Install Node.js safely via asdf
RUN bash -c ". $ASDF_DIR/asdf.sh && \
    asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git && \
    bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring || true && \
    asdf install nodejs 20.11.1 && \
    asdf global nodejs 20.11.1"


# Set working dir
WORKDIR /workspace

CMD [ "bash" ]
