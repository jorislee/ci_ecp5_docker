FROM ubuntu:18.04

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
    && rm -rf /var/lib/apt/lists/*
    
    # prjtrellis
    RUN git clone --recursive https://github.com/SymbiFlow/prjtrellis.git prjtrellis \
    && cd prjtrellis/libtrellis && cmake -DCMAKE_INSTALL_PREFIX=/usr/local . \
    && make -j$(nproc) && make clean && make install && cd - && rm -r prjtrellis
    # yosys
    RUN git clone --recursive https://github.com/cliffordwolf/yosys.git yosys \
    && cd yosys && make clean && make yosys-abc \
    && make -j$(nproc) && make install && cd - && rm -r yosys
    # nextpnr
    RUN git clone --recursive https://github.com/YosysHQ/nextpnr.git nextpnr \
    && cd nextpnr && cmake -DARCH=ice40 -DBUILD_GUI=OFF -DCMAKE_INSTALL_PREFIX=/usr/local . \
    && make -j$(nproc) && make install && cd - && rm -r nextpnr
    # iverilog
    RUN git clone --recursive https://github.com/steveicarus/iverilog.git iverilog \
    && cd iverilog && autoconf && ./configure && make clean \
    && make -j$(nproc) && make install && cd - && rm -r iverilog
    # verilator
    RUN git clone --recursive https://github.com/ddm/verilator.git verilator \
    && cd verilator && autoconf && ./configure && make clean \
    && make -j$(nproc) && make install && cd - && rm -r verilator
 
CMD [ "/bin/bash" ]
