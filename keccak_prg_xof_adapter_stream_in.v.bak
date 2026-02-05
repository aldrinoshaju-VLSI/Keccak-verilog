`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// keccak_prg_xof_adapter_stream_in
// -----------------------------------------------------------------------------
// - Absorb interface is PROVIDED BY USER/TB and forwarded to keccak_xof:
//     in[63:0], in_ready, is_last, byte_num
// - Output to sampleinball_fsm:
//     prg_valid, prg_bits[8:0] where prg_bits[8]=sign, prg_bits[7:0]=index
// - Auto-squeeze:
//     When bit buffer has < 9 bits and FSM requests (ready=1), pulse squeeze_next
//     and wait for next out_valid block.
//
// Assumptions:
// 1) keccak_xof out_valid behaves as "block valid level" (stays 1 in HAVE_OUT).
// 2) keccak_xof accepts squeeze_next when out_valid==1 (in HAVE_OUT).
// 3) Consuming bits LSB-first from out_block. If your bit order differs, invert slicing.
// -----------------------------------------------------------------------------

module keccak_prg_xof_adapter_stream_in #(
    parameter integer RATE_BITS          = 1088,
    parameter [7:0]   SUFFIX             = 8'h1F,

    // This must match keccak_xof OUTPUT_SIZE you configured (512 or 1088, etc.)
    parameter integer KECCAK_BLOCK_BITS  = 1088,

    // Optional safety limit (0 = unlimited)
    parameter integer MAX_SQUEEZE_BLOCKS = 0
)(
    input  wire        clk,
    input  wire        rst_n,

    // Control
    input  wire        start,

    // ---------------- Keccak absorb interface (FROM USER/TB) ----------------
    input  wire [63:0] in,
    input  wire        in_ready,
    input  wire        is_last,
    input  wire [2:0]  byte_num,
    output wire        buffer_full,

    // ---------------- PRG interface (TO sampleinball_fsm) -------------------
    input  wire        ready,        // prg_ready
    output reg         valid,        // prg_valid
    output reg  [8:0]  prg_bits,     // {sign,index}

    // Status
    output reg         exhausted,
    output reg  [15:0] sample_count
);

    // ---------------- Keccak XOF instance ----------------
    reg  squeeze_next;
    wire [KECCAK_BLOCK_BITS-1:0] out_block;
    wire out_valid;

    keccak_xof #(
        .RATE_BITS   (RATE_BITS),
        .SUFFIX      (SUFFIX),
        .OUTPUT_SIZE (KECCAK_BLOCK_BITS)
    ) u_keccak (
        .clk         (clk),
        .reset       (~rst_n),

        .in          (in),
        .in_ready    (in_ready),
        .is_last     (is_last),
        .byte_num    (byte_num),
        .buffer_full (buffer_full),

        .squeeze_next(squeeze_next),

        .out         (out_block),
        .out_valid   (out_valid)
    );

    // ---------------- Bit buffer ----------------
    reg [KECCAK_BLOCK_BITS-1:0] bitbuf;
    reg [15:0] bitcount; // enough for up to 1088/1344

    localparam integer NEED_BITS = 9;

    wire have_sample = (bitcount >= NEED_BITS);

    // Track how many blocks we have pulled (optional safety)
    reg [15:0] squeeze_blocks_used;

    // Latch that we've seen end of absorb
    reg last_seen;

    // Adapter FSM
    localparam [2:0]
        S_IDLE      = 3'd0,
        S_ABSORB    = 3'd1,
        S_WAIT_OUT  = 3'd2,
        S_RUN       = 3'd3,
        S_REQ_SQ    = 3'd4,
        S_WAIT_SQ   = 3'd5,
        S_EXHAUSTED = 3'd6;

    reg [2:0] st;

    // ---------------- Sequential control ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE;

            valid <= 1'b0;
            prg_bits <= 9'd0;

            squeeze_next <= 1'b0;

            bitbuf <= {KECCAK_BLOCK_BITS{1'b0}};
            bitcount <= 16'd0;

            exhausted <= 1'b0;
            sample_count <= 16'd0;
            squeeze_blocks_used <= 16'd0;

            last_seen <= 1'b0;

        end else begin
            // defaults each cycle
            valid <= 1'b0;
            squeeze_next <= 1'b0;

            // Track last absorb event
            if (start && in_ready && is_last)
                last_seen <= 1'b1;
            if (!start)
                last_seen <= 1'b0;

            case (st)
                S_IDLE: begin
                    exhausted <= 1'b0;
                    sample_count <= 16'd0;
                    squeeze_blocks_used <= 16'd0;
                    bitcount <= 16'd0;
                    bitbuf <= {KECCAK_BLOCK_BITS{1'b0}};

                    if (start) begin
                        st <= S_ABSORB;
                    end
                end

                // During absorb we just wait until last_seen is asserted
                S_ABSORB: begin
                    if (!start) begin
                        st <= S_IDLE;
                    end else if (last_seen) begin
                        st <= S_WAIT_OUT;
                    end
                end

                // Wait for first output block
                S_WAIT_OUT: begin
                    if (!start) begin
                        st <= S_IDLE;
                    end else if (out_valid) begin
                        bitbuf <= out_block;                 // load full block
                        bitcount <= KECCAK_BLOCK_BITS[15:0]; // bits available
                        squeeze_blocks_used <= squeeze_blocks_used + 1'b1;
                        st <= S_RUN;
                    end
                end

                // Serve 9-bit samples when requested
                S_RUN: begin
                    if (!start) begin
                        st <= S_IDLE;
                    end else if (ready) begin
                        if (have_sample) begin
                            // LSB-first: next 9 bits are at [8:0]
                            prg_bits <= bitbuf[8:0];
                            valid    <= 1'b1;

                            // consume 9 bits
                            bitbuf   <= {9'b0, bitbuf[KECCAK_BLOCK_BITS-1:9]};
                            bitcount <= bitcount - NEED_BITS[15:0];
                            sample_count <= sample_count + 1'b1;
                        end else begin
                            st <= S_REQ_SQ;
                        end
                    end
                end

                // Request squeeze (one-cycle pulse) while out_valid is still high (HAVE_OUT)
                S_REQ_SQ: begin
                    if (!start) begin
                        st <= S_IDLE;
                    end else begin
                        if (MAX_SQUEEZE_BLOCKS != 0 && squeeze_blocks_used >= MAX_SQUEEZE_BLOCKS) begin
                            exhausted <= 1'b1;
                            st <= S_EXHAUSTED;
                        end else begin
                            // IMPORTANT: squeeze_next must be asserted when out_valid==1
                            // If out_valid is not currently high, wait until it is.
                            if (out_valid) begin
                                squeeze_next <= 1'b1;  // 1-cycle request
                                st <= S_WAIT_SQ;
                            end
                        end
                    end
                end

                // Wait for next output block after squeeze
                S_WAIT_SQ: begin
                    if (!start) begin
                        st <= S_IDLE;
                    end else if (out_valid) begin
                        // After squeeze, out_valid will go low then high with new block.
                        // Some implementations may keep it high briefly; this is still OK:
                        // the new block becomes stable when out_valid reasserts after busy.
                        bitbuf <= out_block;
                        bitcount <= KECCAK_BLOCK_BITS[15:0];
                        squeeze_blocks_used <= squeeze_blocks_used + 1'b1;
                        st <= S_RUN;
                    end
                end

                S_EXHAUSTED: begin
                    exhausted <= 1'b1;
                    if (!start) st <= S_IDLE;
                end

                default: st <= S_IDLE;
            endcase
        end
    end

endmodule
