// ============================================================================
// padder_fast_lr  (Left-to-right packing, fast tail)
// ----------------------------------------------------------------------------
// • 64-bit input words are written MSB→LSB into 'out':
//     word_cnt=0 -> out[RATE_BITS-64 +: 64]   (top slice)
//     word_cnt=1 -> out[RATE_BITS-128 +: 64]
//     ...
// • On is_last:
//     - if byte_num!=0: suffix injected in that word, final '1' set at
//       out[RATE_BITS-1], block presented immediately (no extra zero cycles).
//     - if byte_num==0: current block is pure message; after f_ack a
//       padding-only block is generated (suffix at first word's byte0, and
//       final '1' at out[RATE_BITS-1]).
// ============================================================================

module padder_fast #(
    parameter integer RATE_BITS = 1088,   // 576/1088/1344
    parameter [7:0]   SUFFIX    = 8'h1F   // 01=Keccak, 06=SHA-3, 1F=SHAKE
)(
    input              clk,
    input              reset,

    input      [63:0]  in,
    input              in_ready,
    input              is_last,
    input      [2:0]   byte_num,          // first UNUSED byte index in 'in' (0..7)

    output             buffer_full,       // to user
    output reg [RATE_BITS-1:0] out,       // to permutation (rate block)
    output             out_ready,         // to permutation
    input              f_ack              // from permutation (took the block)
);
    localparam integer NUM_WORDS = RATE_BITS/64;

    // count accepted 64b words in current block
    reg  [7:0] word_cnt;                  // enough for up to 255 words
    wire at_last_word_pos = (word_cnt == (NUM_WORDS-1));

    // block control
    reg have_block;                       // we currently hold a complete block in 'out'
    reg need_extra_pad;                   // exact-boundary case -> emit padding-only block after f_ack

    // suffix injector for the *incoming* last word
    wire [63:0] in_with_suffix;
    padder1 #(.SUFFIX(SUFFIX)) p1 (
        .in(in),
        .byte_num(byte_num),
        .out(in_with_suffix)
    );

    // Present when block is ready
    assign buffer_full = have_block;
    assign out_ready   = have_block;

    // Accept only if we don't already hold a block
    wire accept = in_ready & ~have_block;

    // Helper: write a 64b word into the *left-to-right* slot for 'word_cnt'
    //   slot_base = RATE_BITS - (word_cnt+1)*64
    //   out[slot_base +: 64] <= data;
    task write_lr;
        input [7:0]  wc;
        input [63:0] data;
        integer base;
    begin
        base = RATE_BITS - (wc+1)*64;
        out[base +: 64] = data;
    end
    endtask

    // Build a padding-only block (suffix at first byte of the *first* word;
    // final '1' at MSB of rate area).
    task build_padding_block_lr;
        integer base_first;
    begin
        out = {RATE_BITS{1'b0}};
        // first word sits at the MSB side
        base_first = RATE_BITS - 64;
        // put SUFFIX into byte0 (bits [base_first+7 : base_first])
        out[base_first + 7 -: 8] = SUFFIX;     // same as out[base_first +: 8] but explicit dir
        // final pad '1' at the very end of the rate area
        out[RATE_BITS-1] = 1'b1;
    end
    endtask

    integer base_idx;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            out            <= {RATE_BITS{1'b0}};
            word_cnt       <= 8'd0;
            have_block     <= 1'b0;
            need_extra_pad <= 1'b0;
        end else begin
            // When permutation consumes our block, either emit the queued
            // padding-only block (boundary case) or go back to collecting.
            if (f_ack) begin
                have_block <= 1'b0;
                if (need_extra_pad) begin
                    build_padding_block_lr();
                    need_extra_pad <= 1'b0;
                    have_block     <= 1'b1;   // present immediately
                    word_cnt       <= 8'd0;   // next block starts fresh after this
                end else begin
                    out      <= {RATE_BITS{1'b0}};
                    word_cnt <= 8'd0;
                end
            end

            // Normal streaming + fast-tail padding
            if (accept) begin
                // compute base index for this slot (left-to-right)
                base_idx = (RATE_BITS - (word_cnt+1)*64)-1;

                if (is_last) begin
                    // We're writing the last input beat of this message.
                    if (byte_num != 3'd0) begin
                        // (A) There is room in this block: pad in-place, finish now.
                        // write the last word with suffix
                        out[base_idx +: 64] <= in_with_suffix;
                        // everything else in 'out' above this is still zero (from f_ack reset)
                        // set the final pad '1' at end of rate area
                        out[RATE_BITS-1]    <= 1'b1;
                        // present the complete block immediately
                        have_block          <= 1'b1;
                        // do not increment word_cnt; next block will reset on f_ack
                    end else begin
                        // (B) Exact boundary: no room for suffix here.
                        // write the pure message word
                        out[base_idx +: 64] <= in;
                        if (at_last_word_pos) begin
                            // current block just became full -> present it
                            have_block     <= 1'b1;
                            need_extra_pad <= 1'b1;  // after f_ack, emit padding-only block
                        end else begin
                            // byte_num==0 implies full-word messages; practically this path
                            // hits only when this word fills the block.
                            word_cnt <= word_cnt + 8'd1;
                        end
                    end
                end else begin
                    // Not last: just store the word.
                    out[base_idx +: 64] <= in;
                    if (at_last_word_pos) begin
                        // block is full (more input expected in next block)
                        have_block <= 1'b1;
                    end else begin
                        word_cnt <= word_cnt + 8'd1;
                    end
                end
            end
        end
    end
endmodule
