FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
    
RUN apt-get update && apt-get install -y \
    # IceStorm and friends
    bison \
    build-essential \
    clang \
    cmake \
    flex \
    gawk \
    git \
    graphviz \
    libboost-all-dev \
    libeigen3-dev \
    libffi-dev \
    libftdi-dev \
    libreadline-dev \
    mercurial \
    pkg-config \
    python \
    python3 \
    python3-dev \
    qt5-default \
    tcl-dev \
    xdot \
    # Icarus Verilog and friends
    autoconf \
    bison \
    flex \
    g++ \
    gcc \
    git \
    gperf \
    gtkwave \
    make \
    libhidapi-dev \
    libusb-dev \
    libusb-1.0 \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
    
    # yosys
    RUN git clone --recursive https://github.com/cliffordwolf/yosys.git yosys \
    && cd yosys && make clean && make config-clang \
    && make -j$(nproc) && make install && cd - && rm -r yosys
    # prjtrellis
    RUN git clone --recursive https://github.com/YosysHQ/prjtrellis.git prjtrellis \
    && cd prjtrellis/libtrellis && cmake -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX=/usr/local . \
    && make -j$(nproc) && make install && cd - && rm -r prjtrellis
    # nextpnr
    RUN git clone --recursive https://github.com/YosysHQ/nextpnr.git nextpnr \
    && cd nextpnr && cmake . -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX=/usr/local \
    && make -j$(nproc) && make install && cd - && rm -r nextpnr
    # iverilog
    RUN git clone --recursive https://github.com/steveicarus/iverilog.git iverilog \
    && cd iverilog && sh autoconf.sh && ./configure \
    && make -j$(nproc) && make install && cd - && rm -r iverilog

CMD [ "/bin/bash" ]
