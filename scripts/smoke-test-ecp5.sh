#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: smoke-test-ecp5.sh /path/to/ecp5-toolchain" >&2
  exit 2
fi

TOOLCHAIN_ROOT=$(realpath -m "$1")
# shellcheck disable=SC1091
source "$TOOLCHAIN_ROOT/setup-env.sh"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/blinky.v" <<'EOF'
module blinky(
    input wire clk,
    output wire led
);
    reg [23:0] counter = 24'd0;

    always @(posedge clk)
        counter <= counter + 24'd1;

    assign led = counter[23];
endmodule
EOF

cat > "$TEST_DIR/blinky_tb.v" <<'EOF'
module blinky_tb;
    reg clk = 1'b0;
    wire led;

    blinky dut(.clk(clk), .led(led));

    initial begin
        repeat (8) #1 clk = ~clk;
        $finish;
    end
endmodule
EOF

pushd "$TEST_DIR" >/dev/null
yosys -q -p "synth_ecp5 -top blinky -json blinky.json" blinky.v
nextpnr-ecp5 --25k --package CABGA256 --json blinky.json --textcfg blinky.config --lpf-allow-unconstrained --quiet
ecppack blinky.config blinky.bit
iverilog -o blinky_sim.vvp blinky.v blinky_tb.v
vvp blinky_sim.vvp
test -s blinky.bit
popd >/dev/null

echo "ECP5 smoke test passed: yosys -> nextpnr-ecp5 -> ecppack, plus iverilog/vvp."
