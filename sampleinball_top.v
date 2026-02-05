`timescale 1ns / 1ps
module sampleinball_top #(
    parameter N = 256,
    parameter Q = 8380417,
    parameter TAU = 60,
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 8,
    parameter OUT_ADDR_WIDTH = 6,

    // Keccak adapter params
    parameter integer RATE_BITS         = 1088,
    parameter [7:0]   SUFFIX            = 8'h1F,
    parameter integer KECCAK_BLOCK_BITS = 1088,
    parameter integer MAX_SQUEEZE_BLOCKS= 0
)(
    input wire clk,
    input wire rst_n,
    input wire start,

    // NEW: Keccak absorb input ports (driven by TB/user)
    input  wire [63:0] keccak_in,
    input  wire        keccak_in_ready,
    input  wire        keccak_is_last,
    input  wire [2:0]  keccak_byte_num,
    output wire        keccak_buffer_full,

    output wire done,
    output wire [OUT_ADDR_WIDTH-1:0] i,
    output wire [DATA_WIDTH * TAU -1 : 0] ram_b_mem_out_flat
);

    // PRG interface to sampleinball_fsm
    wire prg_valid;
    wire [8:0] prg_bits;   // {sign,index} => [8]=sign, [7:0]=index
    wire prg_ready;

    // Optional adapter status
    wire exhausted;
    wire [15:0] sample_count;

    // BRAM A
    wire [ADDR_WIDTH-1:0] bram_addr_A;
    wire [DATA_WIDTH-1:0] bram_din_A;
    wire bram_en_A;
    wire bram_we_A;
    wire [DATA_WIDTH-1:0] bram_dout_A;

    // BRAM B
    wire [OUT_ADDR_WIDTH-1:0] bram_addr_B;
    wire [DATA_WIDTH-1:0] bram_din_B;
    wire bram_en_B;
    wire bram_we_B;
    wire [DATA_WIDTH-1:0] bram_dout_B;

    wire [DATA_WIDTH * N -1 : 0] ram_a_mem_out_flat;

    // ------------------------------------------------------------
    // REPLACEMENT: Keccak PRG Adapter (instead of prg_stub)
    // ------------------------------------------------------------
    keccak_prg_xof_adapter_stream_in #(
        .RATE_BITS(RATE_BITS),
        .SUFFIX(SUFFIX),
        .KECCAK_BLOCK_BITS(KECCAK_BLOCK_BITS),
        .MAX_SQUEEZE_BLOCKS(MAX_SQUEEZE_BLOCKS)
    ) prg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        // Keccak absorb interface from top ports
        .in       (keccak_in),
        .in_ready (keccak_in_ready),
        .is_last  (keccak_is_last),
        .byte_num (keccak_byte_num),
        .buffer_full(keccak_buffer_full),

        // PRG handshake to FSM
        .ready    (prg_ready),
        .valid    (prg_valid),
        .prg_bits (prg_bits),

        .exhausted   (exhausted),
        .sample_count(sample_count)
    );

    // ------------------------------------------------------------
    // SampleInBall FSM (unchanged)
    // ------------------------------------------------------------
    sampleinball_fsm #(
        .N(N),
        .TAU(TAU),
        .Q(Q),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .OUT_ADDR_WIDTH(OUT_ADDR_WIDTH)
    ) sib_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        .prg_valid(prg_valid),
        .prg_bits(prg_bits),

        .prg_ready(prg_ready),

        .bram_addr_A(bram_addr_A),
        .bram_din_A (bram_din_A),
        .bram_en_A  (bram_en_A),
        .bram_we_A  (bram_we_A),
        .bram_dout_A(bram_dout_A),

        .bram_addr_B(bram_addr_B),
        .bram_din_B (bram_din_B),
        .bram_en_B  (bram_en_B),
        .bram_we_B  (bram_we_B),
        .bram_dout_B(bram_dout_B),

        .done(done),
        .i(i)
    );

    // RAM A
    dbram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH(N)
    ) ram_a (
        .clk(clk),
        .rst_n(rst_n),
        .ena(bram_en_A),
        .wea(bram_we_A),
        .addra(bram_addr_A),
        .dina(bram_din_A),
        .douta(bram_dout_A),
        .enb(1'b0),
        .web(1'b0),
        .addrb({ADDR_WIDTH{1'b0}}),
        .dinb({DATA_WIDTH{1'b0}}),
        .doutb(),
        .mem_out_flat(ram_a_mem_out_flat)
    );

    // RAM B
    dbram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(OUT_ADDR_WIDTH),
        .DEPTH(TAU)
    ) ram_b (
        .clk(clk),
        .rst_n(rst_n),
        .ena(bram_en_B),
        .wea(bram_we_B),
        .addra(bram_addr_B),
        .dina(bram_din_B),
        .douta(bram_dout_B),
        .enb(1'b0),
        .web(1'b0),
        .addrb({OUT_ADDR_WIDTH{1'b0}}),
        .dinb({DATA_WIDTH{1'b0}}),
        .doutb(),
        .mem_out_flat(ram_b_mem_out_flat)
    );

endmodule
