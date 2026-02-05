`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// SIMPLE TESTBENCH (pure Verilog style) for your:
//   keccak_prg_xof_adapter_stream_in  +  keccak_xof
// -----------------------------------------------------------------------------
// What it does:
// 1) Reset
// 2) start=1
// 3) Send ONE 64-bit word message "a" through the adapter into keccak_xof
//    - 'a' is placed at in[63:56] (same packing as your original keccak TB)
//    - is_last=1
//    - byte_num=1 (one valid byte in last word, matches your TB behavior)
// 4) ready=1 and prints 9-bit output every cycle when valid=1
// 5) Collects 200 samples (forces auto-squeeze: 1088/9=120 samples per block)
// -----------------------------------------------------------------------------
// Notes:
// - No while loops, no wait(), no disable labels.
// - Uses only bounded for loops.
// -----------------------------------------------------------------------------

module tb_keccak_prg_xof_adapter_stream_in;

  localparam integer RATE_BITS         = 1088;
  localparam [7:0]   SUFFIX            = 8'h1F;
  localparam integer KECCAK_BLOCK_BITS = 1088;

  localparam integer CLK_HALF          = 5;       // 100 MHz
  localparam integer SAMPLES_TO_GET    = 200;     // >120 => auto-squeeze must happen
  localparam integer MAX_CYCLES        = 500;  // safety cap

  reg clk;
  reg rst_n;
  reg start;

  // Keccak absorb interface (through adapter)
  reg  [63:0] in;
  reg         in_ready;
  reg         is_last;
  reg  [2:0]  byte_num;
  wire        buffer_full;

  // PRG interface (to sampleinball_fsm style consumer)
  reg         ready;
  wire        valid;
  wire [8:0]  prg_bits;

  wire        exhausted;
  wire [15:0] sample_count;

  // DUT: your adapter (it instantiates keccak_xof internally)
  keccak_prg_xof_adapter_stream_in #(
    .RATE_BITS(RATE_BITS),
    .SUFFIX(SUFFIX),
    .KECCAK_BLOCK_BITS(KECCAK_BLOCK_BITS),
    .MAX_SQUEEZE_BLOCKS(0)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),

    .in(in),
    .in_ready(in_ready),
    .is_last(is_last),
    .byte_num(byte_num),
    .buffer_full(buffer_full),

    .ready(ready),
    .valid(valid),
    .prg_bits(prg_bits),

    .exhausted(exhausted),
    .sample_count(sample_count)
  );

  // Clock
  initial clk = 1'b0;
  always #CLK_HALF clk = ~clk;

  integer cyc;
  integer got;

  initial begin
    // init
    rst_n    = 1'b0;
    start    = 1'b0;

    in       = 64'd0;
    in_ready = 1'b0;
    is_last  = 1'b0;
    byte_num = 3'd0;

    ready    = 1'b0;
    got      = 0;

    // reset for a few cycles
    for (cyc = 0; cyc < 10; cyc = cyc + 1) @(posedge clk);
    rst_n = 1'b1;

    // start
    for (cyc = 0; cyc < 2; cyc = cyc + 1) @(posedge clk);
    start = 1'b1;

    // -----------------------------------------------------------------------
    // Feed input message "a" (1 byte) exactly like your keccak TB packing:
    // - 'a' placed at in[63:56] (block_byte_index = 7 in your TB)
    // - is_last = 1
    // - byte_num = 1 (because last word has only 1 valid byte)
    // -----------------------------------------------------------------------
    // give a few cycles for buffer_full to settle low after reset
    for (cyc = 0; cyc < 20; cyc = cyc + 1) @(posedge clk);

    in       = {8'h61, 56'h0};  // "a" = 0x61 at MSB byte
    in_ready = 1'b1;
    is_last  = 1'b1;
    byte_num = 3'd1;

    @(posedge clk);
    in_ready = 1'b0;
    is_last  = 1'b0;
    byte_num = 3'd0;
    in       = 64'd0;

    // start consuming PRG samples
    ready = 1'b1;

    $display("==================================================");
    $display("Simple TB: collecting %0d samples (9-bit each)", SAMPLES_TO_GET);
    $display("Expect auto-squeeze after ~120 samples for 1088-bit blocks.");
    $display("Format: sample#, sign, index, raw, sample_count");
    $display("==================================================");

    for (cyc = 0; cyc < MAX_CYCLES; cyc = cyc + 1) begin
      @(posedge clk);

      if (exhausted) begin
        $display("ERROR: adapter exhausted early, got=%0d, sample_count=%0d",
                 got, sample_count);
        $finish;
      end

      if (valid) begin
        $display("sample=%0d  sign=%0d  index=%0d (0x%02h)  raw=%b  sample_count=%0d",
                 got, prg_bits[8], prg_bits[7:0], prg_bits[7:0], prg_bits, sample_count);
        got = got + 1;
      end

      if (got >= SAMPLES_TO_GET) begin
        $display("--------------------------------------------------");
        $display("PASS: collected %0d samples; sample_count=%0d", got, sample_count);
        $display("If got > 120, auto-squeeze was exercised.");
        $display("--------------------------------------------------");
        start = 1'b0;
        #50;
        $finish;
      end
    end

    $display("ERROR: timeout, only got %0d samples", got);
    $finish;
  end

endmodule
