module padder1 #(
    parameter [7:0] SUFFIX = 8'h01  // use 8'h1F for SHAKE (0x1F)
)(
    input      [63:0] in,        // last 64-bit word (or any word when is_last=1)
    input      [2:0]  byte_num,  // index of FIRST UNUSED byte in 'in' (0..7)
    output reg [63:0] out        // same word with SUFFIX OR'ed at that byte
);
    
    always @ (*)
      case (byte_num)
        0: out =             {SUFFIX,56'h0}; 
        1: out = {in[63:56], {SUFFIX,48'h0}};
        2: out = {in[63:48], {SUFFIX,40'h0}};
        3: out = {in[63:40], {SUFFIX,32'h0}};
        4: out = {in[63:32], {SUFFIX,24'h0}};
        5: out = {in[63:24], {SUFFIX,16'h0}};
        6: out = {in[63:16], {SUFFIX,8'h0}};
        7: out = {in[63:8],   SUFFIX};
      endcase
endmodule
