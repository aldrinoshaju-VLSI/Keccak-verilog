/*
`define low_pos(w,b)      ((w)*64 + (b)*8)
`define low_pos2(w,b)     `low_pos(w,7-b)
`define high_pos(w,b)     (`low_pos(w,b) + 7)
`define high_pos2(w,b)    (`low_pos2(w,b) + 7)

module keccak_out_vary #(
    // Defaults keep SHA3-512 behavior; override for SHAKE.
    // SHA3-512: RATE_BITS=576,  SUFFIX=8'h06
    // SHAKE256: RATE_BITS=1088, SUFFIX=8'h1F
    // SHAKE128: RATE_BITS=1344, SUFFIX=8'h1F
    parameter integer RATE_BITS = 576,
    parameter [7:0]   SUFFIX    = 8'h01,
	 parameter integer OUTPUT_BITS = 1032
)(
    input              clk, reset,
    input      [63:0]  in,
    input              in_ready, is_last,
    input      [2:0]   byte_num,
    output             buffer_full,
    output     [OUTPUT_BITS:0] out,
    output reg         out_ready
);

    reg                state;     
    wire [RATE_BITS-1:0] padder_out,
                         padder_out_1; 
    wire               padder_out_ready;
    wire               f_ack;
    wire      [1599:0] f_out;
    wire               f_out_ready;
    wire      [OUTPUT_BITS:0]  out1;      
    reg       [10:0]   i;         
    genvar w, b;

	 if(OUTPUT_BITS/RATE_BITS<=1)
		assign out1 = f_out[1599:1599-OUTPUT_BITS];
	 else 
		assign out1 = f_out[1599:1599-RATE_BITS];

    always @ (posedge clk)
      if (reset)
        i <= 11'd0;
      else
        i <= {i[9:0], state & f_ack};

    always @ (posedge clk)
      if (reset)
        state <= 1'b0;
      else if (is_last)
        state <= 1'b1;

    
    generate
      for(w=0; w<8; w=w+1) begin : L0
        for(b=0; b<8; b=b+1) begin : L1
          assign out[`high_pos(w,b):`low_pos(w,b)] =
                 out1[`high_pos2(w,b):`low_pos2(w,b)];
        end
      end
    endgenerate

    
    generate
      for(w=0; w<(RATE_BITS/64); w=w+1) begin : L2
        for(b=0; b<8; b=b+1) begin : L3
          assign padder_out[`high_pos(w,b):`low_pos(w,b)] =
                 padder_out_1[`high_pos2(w,b):`low_pos2(w,b)];
        end
      end
    endgenerate

    always @ (posedge clk)
      if (reset)
        out_ready <= 1'b0;
      else if (i[10])               // last (12th) two-round step done
        out_ready <= 1'b1;

    
    padder #(
      .RATE_BITS(RATE_BITS),
      .SUFFIX   (SUFFIX)
    ) padder_ (
      .clk(clk), .reset(reset),
      .in(in), .in_ready(in_ready), .is_last(is_last), .byte_num(byte_num),
      .buffer_full(buffer_full),
      .out(padder_out_1), .out_ready(padder_out_ready),
      .f_ack(f_ack)
    );

    
    f_permutation #(
      .RATE_BITS(RATE_BITS)
    ) f_permutation_ (
      .clk(clk), .reset(reset),
      .in(padder_out), .in_ready(padder_out_ready),
      .ack(f_ack),
      .out(f_out), .out_ready(f_out_ready)
    );
endmodule

`undef low_pos
`undef low_pos2
`undef high_pos
`undef high_pos2
*/