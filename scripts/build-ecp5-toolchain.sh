#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-ecp5-toolchain.sh --versions FILE --prefix DIR --work-dir DIR [--only TOOL] [--no-clean]

Builds Yosys, Project Trellis, nextpnr-ecp5, and Icarus Verilog from the
resolved upstream tags written by scripts/resolve_tool_versions.py.

TOOL may be one of: all, yosys, prjtrellis, nextpnr, iverilog.
EOF
}

VERSIONS_FILE=
PREFIX=
WORK_DIR=
ONLY=all
CLEAN=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --versions)
      VERSIONS_FILE=$2
      shift 2
      ;;
    --prefix)
      PREFIX=$2
      shift 2
      ;;
    --work-dir)
      WORK_DIR=$2
      shift 2
      ;;
    --only)
      ONLY=$2
      shift 2
      ;;
    --no-clean)
      CLEAN=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$VERSIONS_FILE" || -z "$PREFIX" || -z "$WORK_DIR" ]]; then
  usage >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$VERSIONS_FILE"

PREFIX=$(realpath -m "$PREFIX")
WORK_DIR=$(realpath -m "$WORK_DIR")
JOBS=${JOBS:-$(nproc)}

if [[ "$CLEAN" == "1" ]]; then
  rm -rf "$PREFIX" "$WORK_DIR"
fi
mkdir -p "$PREFIX" "$WORK_DIR"

export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib/trellis:${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="$PREFIX:${CMAKE_PREFIX_PATH:-}"

clone_tag() {
  local repo=$1
  local tag=$2
  local dest=$3

  echo "::group::Clone $repo @ $tag"
  git clone --depth 1 --branch "$tag" --recurse-submodules --shallow-submodules "$repo" "$dest"
  git -C "$dest" submodule update --init --recursive --depth 1 || \
    git -C "$dest" submodule update --init --recursive
  echo "::endgroup::"
}

build_yosys() {
  local src="$WORK_DIR/yosys"
  clone_tag "$YOSYS_REPO" "$YOSYS_TAG" "$src"

  echo "::group::Build Yosys"
  cmake -S "$src" -B "$src/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_SHARED_LIBS=OFF
  cmake --build "$src/build" --parallel "$JOBS"
  cmake --install "$src/build" --strip
  echo "::endgroup::"
}

build_prjtrellis() {
  local src="$WORK_DIR/prjtrellis"
  clone_tag "$PRJTRELLIS_REPO" "$PRJTRELLIS_TAG" "$src"

  echo "::group::Build Project Trellis"
  pushd "$src/libtrellis" >/dev/null
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    .
  cmake --build . --parallel "$JOBS"
  cmake --install . --strip
  popd >/dev/null
  echo "::endgroup::"
}

build_nextpnr() {
  local src="$WORK_DIR/nextpnr"
  clone_tag "$NEXTPNR_REPO" "$NEXTPNR_TAG" "$src"

  echo "::group::Build nextpnr-ecp5"
  cmake -S "$src" -B "$src/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DARCH=ecp5 \
    -DTRELLIS_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_GUI=OFF \
    -DBUILD_PYTHON=ON \
    -DUSE_IPO=OFF
  cmake --build "$src/build" --parallel "$JOBS"
  cmake --install "$src/build" --strip
  echo "::endgroup::"
}

build_iverilog() {
  local src="$WORK_DIR/iverilog"
  clone_tag "$IVERILOG_REPO" "$IVERILOG_TAG" "$src"

  echo "::group::Build Icarus Verilog"
  pushd "$src" >/dev/null
  sh autoconf.sh
  ./configure --prefix="$PREFIX"
  make -j"$JOBS"
  make install
  popd >/dev/null
  echo "::endgroup::"
}

write_setup_env() {
  cat > "$PREFIX/setup-env.sh" <<'EOF'
#!/usr/bin/env bash
_ecp5_toolchain_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ECP5_TOOLCHAIN_ROOT="$_ecp5_toolchain_root"
export PATH="$_ecp5_toolchain_root/bin:$PATH"
export LD_LIBRARY_PATH="$_ecp5_toolchain_root/lib:$_ecp5_toolchain_root/lib/trellis:${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="$_ecp5_toolchain_root:${CMAKE_PREFIX_PATH:-}"
export TRELLIS="$_ecp5_toolchain_root/share/trellis"
EOF
  chmod +x "$PREFIX/setup-env.sh"
}

case "$ONLY" in
  all)
    build_yosys
    build_prjtrellis
    build_nextpnr
    build_iverilog
    write_setup_env
    ;;
  yosys)
    build_yosys
    ;;
  prjtrellis)
    build_prjtrellis
    ;;
  nextpnr)
    build_nextpnr
    ;;
  iverilog)
    build_iverilog
    write_setup_env
    ;;
  *)
    echo "Unknown tool for --only: $ONLY" >&2
    exit 2
    ;;
esac
