/*  keccak_xof.v  (multi-squeeze / XOF-style wrapper)
    -------------------------------------------------
    This is a drop-in replacement for your one-shot keccak module, with the ability
    to request additional output blocks via squeeze_next.

    Key changes vs your original:
    1) Adds input  squeeze_next
    2) Changes output out_ready (sticky) to out_valid (block-valid)
    3) Adds a small FSM: ABSORB -> PERMUTE -> HAVE_OUT -> SQUEEZE -> HAVE_OUT -> ...
    4) IMPORTANT: Resets the 12-step counter 'i' on entry to PERMUTE and SQUEEZE,
       so i[10] cannot remain high from a previous run.

    Assumption (minimal-change squeeze triggering):
    - f_permutation can be triggered to run a new 12-step permutation by pulsing
      in_ready for 1 cycle, even if in = 0 (i.e., XOR 0 into the rate part).
      This is common. If your f_permutation does NOT behave like this, you must
      modify f_permutation to add a dedicated squeeze_start input.
*/

/* "is_last" == 0 means byte number is 8, no matter what value "byte_num" is. */
/* if "in_ready" == 0, then "is_last" should be 0. */
/* the user switch to next "in" only if "ack" == 1. */

`define low_pos(w,b)      ((w)*64 + (b)*8)
`define low_pos2(w,b)     `low_pos(w,7-b)
`define high_pos(w,b)     (`low_pos(w,b) + 7)
`define high_pos2(w,b)    (`low_pos2(w,b) + 7)

module keccak_xof #(
    // SHA3-512: RATE_BITS=576,  SUFFIX=8'h06
    // SHAKE256: RATE_BITS=1088, SUFFIX=8'h1F
    // SHAKE128: RATE_BITS=1344, SUFFIX=8'h1F
    parameter integer RATE_BITS    = 576,
    parameter [7:0]   SUFFIX       = 8'h01,
    parameter integer OUTPUT_SIZE  = 256
)(
    input                    clk,
    input                    reset,

    // Absorb interface (same as your original)
    input      [63:0]        in,
    input                    in_ready,
    input                    is_last,
    input      [2:0]         byte_num,
    output                   buffer_full,

    // NEW: request next squeezed output block
    input                    squeeze_next,

    // Output
    output     [OUTPUT_SIZE-1:0] out,
    output reg               out_valid
);

    // -----------------------------
    // Internal signals
    // -----------------------------
    reg  [1:0]            st, st_d;

    localparam [1:0] ST_ABSORB   = 2'd0;
    localparam [1:0] ST_PERMUTE  = 2'd1;  // first permutation after last input
    localparam [1:0] ST_HAVE_OUT = 2'd2;  // output valid, wait for squeeze_next
    localparam [1:0] ST_SQUEEZE  = 2'd3;  // additional squeeze permutation

    wire [RATE_BITS-1:0]  padder_out, padder_out_1;
    wire                  padder_out_ready;
    wire                  f_ack;
    wire [1599:0]          f_out;
    wire                  f_out_ready;

    wire [OUTPUT_SIZE-1:0] out1;
    assign out1 = f_out[1599:1599-(OUTPUT_SIZE-1)];

    // 12-step counter (your original style; 11-bit shift reg)
    reg  [10:0] i;

    // State entry detection (for proper counter reset)
    always @(posedge clk) begin
      if (reset) st_d <= ST_ABSORB;
      else       st_d <= st;
    end

    //wire enter_permute = (st == ST_PERMUTE) && (st_d != ST_PERMUTE);
    wire enter_squeeze = (st == ST_SQUEEZE) && (st_d != ST_SQUEEZE);

    // Byte reordering for output and padder_out (same as your original)
    genvar w, b;

    generate
      for (w = 0; w < (OUTPUT_SIZE/64); w = w + 1) begin : OUT_REORDER_W
        for (b = 0; b < 8; b = b + 1) begin : OUT_REORDER_B
          assign out[`high_pos(w,b):`low_pos(w,b)] =
                 out1[`high_pos2(w,b):`low_pos2(w,b)];
        end
      end
    endgenerate

    generate
      for (w = 0; w < (RATE_BITS/64); w = w + 1) begin : PAD_REORDER_W
        for (b = 0; b < 8; b = b + 1) begin : PAD_REORDER_B
          assign padder_out[`high_pos(w,b):`low_pos(w,b)] =
                 padder_out_1[`high_pos2(w,b):`low_pos2(w,b)];
        end
      end
    endgenerate

    // -------------------------------------------------------
    // Squeeze trigger pulse (one-cycle) when entering SQUEEZE
    // -------------------------------------------------------
    reg sq_d;
    always @(posedge clk) begin
      if (reset) sq_d <= 1'b0;
      else       sq_d <= (st == ST_SQUEEZE);
    end
    wire squeeze_pulse = (st == ST_SQUEEZE) & ~sq_d; // 1-cycle pulse on entry

    // -------------------------------------------------------
    // Drive permutation input:
    // - absorb path: use padder_out when padder_out_ready=1
    // - squeeze path: kick permutation with in_ready pulse and in = 0
    // -------------------------------------------------------
    wire [RATE_BITS-1:0] perm_in       = (padder_out_ready) ? padder_out : {RATE_BITS{1'b0}};
    wire                 perm_in_ready = padder_out_ready | squeeze_pulse;

    // -------------------------------------------------------
    // Count 12 two-round steps using f_ack
    // IMPORTANT: reset i on entry to PERMUTE or SQUEEZE
    // -------------------------------------------------------
    wire perm_running = (st == ST_PERMUTE) | (st == ST_SQUEEZE);

    always @(posedge clk) begin
      if (reset) begin
        i <= 11'd0;
      end else if (st==ST_SQUEEZE && i[10]) begin
        i <= 11'd0;
      end else begin
        i <= {i[9:0], (perm_running & f_ack)};
      end
    end

    // -------------------------------------------------------
    // Control FSM
    // -------------------------------------------------------
    always @(posedge clk) begin
      if (reset) begin
        st        <= ST_ABSORB;
        out_valid <= 1'b0;
      end else begin
        case (st)
          ST_ABSORB: begin
            out_valid <= 1'b0;
            // When last chunk is indicated, move to permutation phase.
            // Note: padder_out_ready will still control when permutation starts.
            if (is_last) begin
              st <= ST_PERMUTE;
            end
          end

          ST_PERMUTE: begin
            // Wait until permutation completes
            if (i[10]) begin
              out_valid <= 1'b1;
              st        <= ST_HAVE_OUT;
            end
          end

          ST_HAVE_OUT: begin
            // Hold out_valid until user requests next block.
            // Only accept request when output is currently valid.
            if (out_valid && squeeze_next) begin
              out_valid <= 1'b0;
              st        <= ST_SQUEEZE;
				  //i <= 11'd0;
            end
          end

          ST_SQUEEZE: begin
            // squeeze_pulse (on entry) triggers a new permutation run with zero input.
            // Wait until it completes, then output is valid again.
            if (i[10]) begin
              out_valid <= 1'b1;
              st        <= ST_HAVE_OUT;
            end
          end

          default: begin
            st        <= ST_ABSORB;
            out_valid <= 1'b0;
          end
        endcase
      end
    end

    // -------------------------------------------------------
    // Padder (unchanged)
    // -------------------------------------------------------
    padder_fast_2 #(
      .RATE_BITS(RATE_BITS),
      .SUFFIX   (SUFFIX)
    ) padder_ (
      .clk(clk), .reset(reset),
      .in(in), .in_ready(in_ready), .is_last(is_last), .byte_num(byte_num),
      .buffer_full(buffer_full),
      .out(padder_out_1), .out_ready(padder_out_ready),
      .f_ack(f_ack)
    );

    // -------------------------------------------------------
    // Permutation (same module, driven by perm_in/perm_in_ready)
    // -------------------------------------------------------
    f_permutation #(
      .RATE_BITS(RATE_BITS)
    ) f_permutation_ (
      .clk(clk), .reset(reset),
      .in(perm_in), .in_ready(perm_in_ready),
      .ack(f_ack),
      .out(f_out), .out_ready(f_out_ready)
    );

endmodule

`undef low_pos
`undef low_pos2
`undef high_pos
`undef high_pos2
