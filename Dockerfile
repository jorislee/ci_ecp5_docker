FROM ubuntu:24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    file \
    flex \
    gawk \
    git \
    gperf \
    graphviz \
    libboost-all-dev \
    libeigen3-dev \
    libffi-dev \
    libreadline-dev \
    libtommath-dev \
    libusb-1.0-0-dev \
    lld \
    ninja-build \
    pkg-config \
    python3 \
    python3-dev \
    tcl-dev \
    xz-utils \
    zlib1g-dev \
    zstd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY scripts ./scripts

RUN python3 scripts/resolve_tool_versions.py \
      --env-file build/tool-versions.env \
      --json-file build/tool-versions.json \
      --markdown-file build/tool-versions.md \
    && bash scripts/build-ecp5-toolchain.sh \
      --versions build/tool-versions.env \
      --prefix /opt/ecp5-toolchain \
      --work-dir /src/build/source \
    && bash scripts/smoke-test-ecp5.sh /opt/ecp5-toolchain

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libboost-filesystem1.83.0 \
    libboost-iostreams1.83.0 \
    libboost-program-options1.83.0 \
    libboost-thread1.83.0 \
    libffi8 \
    libreadline8t64 \
    libtcl8.6 \
    libtommath1 \
    libusb-1.0-0 \
    python3 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/ecp5-toolchain /opt/ecp5-toolchain

ENV ECP5_TOOLCHAIN_ROOT=/opt/ecp5-toolchain
ENV PATH=/opt/ecp5-toolchain/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/ecp5-toolchain/lib:/opt/ecp5-toolchain/lib/trellis
ENV CMAKE_PREFIX_PATH=/opt/ecp5-toolchain
ENV TRELLIS=/opt/ecp5-toolchain/share/trellis

CMD ["/bin/bash"]
