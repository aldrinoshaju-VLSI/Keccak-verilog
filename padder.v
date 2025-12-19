/* "is_last" == 0 means byte number is 8, no matter what value "byte_num" is. */
/* if "in_ready" == 0, then "is_last" should be 0. */
/* the user switch to next "in" only if "ack" == 1. */

module padder #(
    parameter integer RATE_BITS = 576,   // 576(SHA3-512/Keccak-512), 1088(SHAKE256), 1344(SHAKE128)
    parameter [7:0]   SUFFIX    = 8'h01  // 8'h01 Keccak, 8'h06 SHA-3, 8'h1F SHAKE
)(
    input              clk, reset,
    input      [63:0]  in,
    input              in_ready, is_last,
    input      [2:0]   byte_num,
    output             buffer_full,      /* to user */
    output reg [RATE_BITS-1:0] out,      /* to f_permutation */
    output             out_ready,        /* to f_permutation */
    input              f_ack             /* from f_permutation */
);
    localparam integer NUM_WORDS = RATE_BITS/64;   // 9, 17, 21

    reg                state;     /* 0: more input expected, 1: last seen -> tail zeros */
    reg                done;      /* 1: hold off filling (mirrors your gating) */
    reg  [NUM_WORDS-1:0] i;       /* shift register counting loaded 64b words */
    wire [63:0]        v0;        /* output of padder1 (suffix injected) */
    reg  [63:0]        v1;        /* word to shift into 'out' */
    wire               accept;    /* accept user input? */
    wire               update;

	 
    // Handshake identical to your original (generalized)
    assign buffer_full = i[NUM_WORDS-1];
    assign out_ready   = buffer_full;
    assign accept      = (~state) & in_ready & (~buffer_full);        // if state==1, don't eat input
    assign update      = (accept | (state & (~buffer_full))) & (~done); // don't fill if done

    // Build output block (shift left, append next 64-bit word)
    always @ (posedge clk)
      if (reset)
        out <= {RATE_BITS{1'b0}};
      else if (update)
        out <= {out[RATE_BITS-65:0], v1};

    // Word counter (shift-in ones; clear when f_ack)
    always @ (posedge clk)
      if (reset)
        i <= {NUM_WORDS{1'b0}};
      else if (f_ack | update)
        i <= ({i[NUM_WORDS-2:0], 1'b1}) & {NUM_WORDS{~f_ack}};

    // 'done' follows your original intent: assert once block is full while tailing
    always @ (posedge clk)
      if (reset)
        done <= 1'b0;
      else
        done <= state & buffer_full;

    // Latch 'state' to indicate we've seen the last user word
    always @ (posedge clk)
      if (reset)
        state <= 1'b0;
      else if (f_ack)
        state <= 1'b0;
      else if (accept && is_last)
        state <= 1'b1;

    // Suffix injector (parameterized). If your padder1 has no parameter,
    // hardcode SUFFIX inside padder1 instead.
    padder1 #(.SUFFIX(SUFFIX)) p1 (
        .in(in),
        .byte_num(byte_num),
        .out(v0)
    );

    // Choose the next 64-bit word to shift in (same semantics as your code)
    // - while tailing (state=1): push zeros, but set the final pad10*1 MSB when
    //   we're about to append the last 64b word (i[NUM_WORDS-2]==1).
    // - if not last yet: pass-through 'in'
    // - if this is the last input word: use v0 (suffix inserted), also OR the final MSB as above
    always @ (*) begin
        if (state) begin
            v1 = 64'd0;
            v1[7] = v1[7] | i[NUM_WORDS-2];          // final '1' of pad10*1
        end else if (is_last == 1'b0) begin
            v1 = in;
        end else begin
            v1 = v0;
            v1[7] = v1[7] | i[NUM_WORDS-2];          // final '1' of pad10*1
        end
    end
endmodule