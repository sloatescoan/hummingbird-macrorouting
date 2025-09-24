FROM swift:6.2-noble

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get install -y libssl-dev curl \
    && rm -rf /var/lib/apt/lists/*
