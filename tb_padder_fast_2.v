`timescale 1ns/1ps

module tb_padder_fast_2;

  // Parameters
  parameter integer RATE_BITS = 1088;   // Use SHAKE256 rate
  parameter [7:0]   SUFFIX    = 8'h1F;  // SHAKE domain separation

  // DUT I/O
  reg               clk;
  reg               reset;
  reg  [63:0]       in;
  reg               in_ready;
  reg               is_last;
  reg  [2:0]        byte_num;
  wire              buffer_full;
  wire [RATE_BITS-1:0] out;
  wire              out_ready;
  reg               f_ack;

  // Instantiate DUT
  padder_fast_2 #(
      .RATE_BITS(RATE_BITS),
      .SUFFIX(SUFFIX)
  ) uut (
      .clk(clk),
      .reset(reset),
      .in(in),
      .in_ready(in_ready),
      .is_last(is_last),
      .byte_num(byte_num),
      .buffer_full(buffer_full),
      .out(out),
      .out_ready(out_ready),
      .f_ack(f_ack)
  );

  // Clock generation: 10 ns period
  always #5 clk = ~clk;

  // Stimulus
  initial begin
    $dumpfile("padder_fast_2_wave.vcd");   // for GTKWave
    $dumpvars(0, tb_padder_fast_2);

    clk = 0;
    reset = 1;
    in = 64'd0;
    in_ready = 0;
    is_last = 0;
    byte_num = 3'd0;
    f_ack = 0;

    // Hold reset
    #20;
    reset = 0;

    // === Feed one character 'a' ===
    @(posedge clk);
    in = 64'h0000000000000061;  // ASCII 'a'
    in_ready = 1;
    is_last = 1;
    byte_num = 3'd1;            // 1 byte valid
    @(posedge clk);
    in_ready = 0;
    is_last = 0;
    byte_num = 3'd0;

    // Let padder run for some cycles to fill output
    repeat (25) @(posedge clk);

    // When block full, send ack to clear
    if (out_ready) begin
      $display(">> Padder output ready!");
      $display("out[63:0] = %h", out[63:0]);
      $display("out[1071:1008] (top bits) = %h", out[RATE_BITS-1 -: 64]);
    end
    @(posedge clk);
    f_ack = 1;
    @(posedge clk);
    f_ack = 0;

    #20;
    $finish;
  end

endmodule
