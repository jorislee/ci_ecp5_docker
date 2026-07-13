# ECP5 toolchain release builder

This repository builds an Ubuntu 24.04 Linux x86_64 ECP5 FPGA toolchain in
GitHub Actions and publishes the compiled binaries to GitHub Releases. It no
longer publishes a DockerHub image.

The release package is built from the latest upstream tags for:

- [Yosys](https://github.com/YosysHQ/yosys)
- [Project Trellis](https://github.com/YosysHQ/prjtrellis), including `ecppack`
- [nextpnr](https://github.com/YosysHQ/nextpnr), built for `ecp5`
- [Icarus Verilog](https://github.com/steveicarus/iverilog), including `iverilog` and `vvp`

## Release workflow

The workflow in `.github/workflows/toolchain-release.yml` runs on:

- manual `workflow_dispatch`
- pushes to `master`
- a weekly schedule

Each run resolves the newest version-like tag from the four upstream projects,
builds the tools from source, smoke-tests a small ECP5 bitstream flow, and
uploads these Release assets:

- `ecp5-toolchain-linux-x86_64.tar.zst`
- `ecp5-toolchain-linux-x86_64.env`
- `ecp5-toolchain-linux-x86_64.json`
- `SHA256SUMS`

The Release tag is derived from the resolved upstream tags, for example:

```text
ecp5-toolchain-yosys-v0.67-prjtrellis-1.4-nextpnr-nextpnr-0.10-iverilog-v13_0
```

The release is marked as the latest release, so downstream workflows can use a
stable `releases/latest/download/...` URL.

## Use from another GitHub Actions workflow

Use an `ubuntu-24.04` runner, matching the release build host.

```yaml
jobs:
  fpga:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      - name: Download ECP5 toolchain
        run: |
          curl -L -o ecp5-toolchain-linux-x86_64.tar.zst \
            https://github.com/jorislee/ci_ecp5_docker/releases/latest/download/ecp5-toolchain-linux-x86_64.tar.zst
          tar --use-compress-program=unzstd -xf ecp5-toolchain-linux-x86_64.tar.zst
          echo "$PWD/ecp5-toolchain/bin" >> "$GITHUB_PATH"
          echo "LD_LIBRARY_PATH=$PWD/ecp5-toolchain/lib:$PWD/ecp5-toolchain/lib/trellis:${LD_LIBRARY_PATH:-}" >> "$GITHUB_ENV"
          echo "TRELLIS=$PWD/ecp5-toolchain/share/trellis" >> "$GITHUB_ENV"

      - name: Check toolchain
        run: |
          yosys -V
          nextpnr-ecp5 --help >/dev/null
          ecppack --help >/dev/null
          iverilog -V
```

For shell scripts, source the generated environment file after extraction:

```sh
. ./ecp5-toolchain/setup-env.sh
```

## Build locally on Ubuntu

Install the same dependencies as the workflow, then run:

```sh
python3 scripts/resolve_tool_versions.py \
  --env-file build/tool-versions.env \
  --json-file build/tool-versions.json \
  --markdown-file build/tool-versions.md

bash scripts/build-ecp5-toolchain.sh \
  --versions build/tool-versions.env \
  --prefix "$PWD/dist/ecp5-toolchain" \
  --work-dir "$PWD/build/source"

bash scripts/smoke-test-ecp5.sh "$PWD/dist/ecp5-toolchain"
```

## License

MIT License.
