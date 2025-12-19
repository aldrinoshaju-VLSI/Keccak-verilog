module f_permutation #(
    parameter integer RATE_BITS = 576  // 576 (SHA3-512), 1088 (SHAKE256), 1344 (SHAKE128)
)(
    input               clk, reset,
    input  [RATE_BITS-1:0] in,
    input               in_ready,
    output              ack,
    output reg [1599:0] out,
    output reg          out_ready
);
    reg        [10:0]   i; /* select round constant */
    wire       [1599:0] round_in, round_out;
    wire       [63:0]   rc1, rc2;
    wire                update;
    wire                accept;
    reg                 calc; /* == 1: calculating rounds */

    assign accept = in_ready & (~calc); // in_ready & (i == 0)
    
    always @ (posedge clk)
      if (reset) i <= 11'd0;
      else       i <= {i[9:0], accept};
    
    always @ (posedge clk)
      if (reset) calc <= 1'b0;
      else       calc <= (calc & (~i[10])) | accept;
    
    assign update = calc | accept;
    assign ack    = accept;

    always @ (posedge clk)
      if (reset)
        out_ready <= 1'b0;
      else if (accept)
        out_ready <= 1'b0;
      else if (i[10]) // only change at the last (12th) two-round step
        out_ready <= 1'b1;

    // ********** ONLY CHANGE FOR SHAKE: parameterized absorb splice **********
    // XOR 'in' into the top RATE_BITS of the state on accept
    assign round_in = accept
                      ? { (in ^ out[1599:1600-RATE_BITS]), out[1599-RATE_BITS:0] }
                      : out;

    rconst2in1 rconst_ ({i, accept}, rc1, rc2);
    round2in1  round_  (round_in, rc1, rc2, round_out);
	 //round2in1_pipelined  round_  (clk, 1'b1, round_in, rc1, rc2, round_out);
	 
    always @ (posedge clk)
      if (reset)
        out <= 1600'd0;
      else if (update)
        out <= round_out;
endmodule
