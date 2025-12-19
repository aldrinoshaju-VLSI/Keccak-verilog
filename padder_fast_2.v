// ============================================================================
// padder (Verilog-2001, no variable part-selects)
// • MSB-first lane placement; no extra cycles for short messages
// • Uses a 64-bit lane array + constant slice wiring via generate
// • SUFFIX injection on last beat; pad10*1 final bit asserted immediately
// ============================================================================
module padder_fast_2 #(
    parameter integer RATE_BITS = 576,      // 576, 1088, 1344
    parameter [7:0]   SUFFIX    = 8'h01     // 8'h01 Keccak, 8'h06 SHA-3, 8'h1F SHAKE
)(
    input              clk,
    input              reset,
    input      [63:0]  in,
    input              in_ready,
    input              is_last,
    input      [2:0]   byte_num,
    output             buffer_full,
    output     [RATE_BITS-1:0] out,
    output             out_ready,
    input              f_ack
);
    localparam integer NUM_WORDS = RATE_BITS/64;   // 9, 17, 21
    localparam [RATE_BITS-1:0] PAD_MASK = {{RATE_BITS-1{1'b0}}, 8'h80}; // MSB of rate {{RATE_BITS-1{1'b0}}, 8'h80}

    // One-hot write pointer: bit 0 -> MSB lane (lane index 0), bit NUM_WORDS-1 -> LSB lane
    reg [NUM_WORDS-1:0] wptr;

    // Lane storage (legal Verilog-2001 memory)
    reg [63:0] lanes [0:NUM_WORDS-1];

    // Hold a complete block?
    reg full;

    // Final pad bit latch (set when we accept a last beat)
    reg pad_bit;

    // Accept a beat when producer is ready and we’re not holding a full block
    wire accept = in_ready & ~full;

    // Suffix injector for the *current* input word when is_last=1
    wire [63:0] in_suffix;
    padder1 #(.SUFFIX(SUFFIX)) p_suf (
        .in(in),
        .byte_num(byte_num),
        .out(in_suffix)
    );

    // Public flags
    assign buffer_full = full;
    assign out_ready   = full;

    // Stitch the output bus with constant slice bounds (no variable part-selects)
    // lane 0 is MSB slice, lane NUM_WORDS-1 is LSB slice
    genvar g;
    wire [RATE_BITS-1:0] pack;
    generate
      for (g = 0; g < NUM_WORDS; g = g + 1) begin : PACK
        localparam integer HI = RATE_BITS-1 - 64*g;
        localparam integer LO = RATE_BITS-64 - 64*g;
        assign pack[HI:LO] = lanes[g];
      end
    endgenerate

    // Final output: packed lanes OR final pad bit
    assign out = pack | (pad_bit ? PAD_MASK : {RATE_BITS{1'b0}});

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // clear state
            for (i = 0; i < NUM_WORDS; i = i + 1) lanes[i] <= 64'd0;
            wptr     <= {{(NUM_WORDS-1){1'b0}}, 1'b1}; // start at lane 0 (MSB)
            full     <= 1'b0;
            pad_bit  <= 1'b0;
        end else begin
            // permutation consumed the block -> clear for next
            if (f_ack) begin
                for (i = 0; i < NUM_WORDS; i = i + 1) lanes[i] <= 64'd0;
                wptr    <= {{(NUM_WORDS-1){1'b0}}, 1'b1};
                full    <= 1'b0;
                pad_bit <= 1'b0;
            end

            // accept a lane?
            if (accept) begin
                // write only the selected lane (no variable part-select: memory index is fine)
                for (i = 0; i < NUM_WORDS; i = i + 1)
                    if (wptr[i])
                        lanes[i] <= is_last ? in_suffix : in;

                if (is_last) begin
                    // complete now: set final pad bit and mark full
                    pad_bit <= 1'b1;
                    full    <= 1'b1;
                    // pointer will reset on f_ack
                end else begin
                    // advance pointer towards LSB lanes
                    wptr <= {wptr[NUM_WORDS-2:0], 1'b0};
                    // if we just wrote the last lane, block is full (no padding)
                    if (wptr[NUM_WORDS-1]) begin
                        full    <= 1'b1;
                        pad_bit <= 1'b0; // exact-fit case: no pad bit here
                    end
                end
            end
        end
    end
endmodule
