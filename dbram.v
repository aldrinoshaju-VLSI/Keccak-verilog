// dual port RAM module
`timescale 1ns / 1ps
module dbram #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 8,
    parameter DEPTH = (1 << ADDR_WIDTH)
)(
    input clk,
    input rst,
    input ena,
    input wea,
    input [ADDR_WIDTH-1:0] addra,
    input [DATA_WIDTH-1:0] dina,
    output reg [DATA_WIDTH-1:0] douta,
    input enb,
    input web,
    input [ADDR_WIDTH-1:0] addrb,
    input [DATA_WIDTH-1:0] dinb,
    output reg [DATA_WIDTH-1:0] doutb
`ifndef SYNTHESIS
    , output wire [DATA_WIDTH * DEPTH - 1 : 0] mem_out_flat
`endif
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 0;
            douta <= 0;
            doutb <= 0;
        end else begin
            if (ena) begin
                douta <= mem[addra];
                if (wea)
                    mem[addra] <= dina;
            end else
                douta <= 0;

            if (enb) begin
                doutb <= mem[addrb];
                if (web)
                    mem[addrb] <= dinb;
            end else
                doutb <= 0;
        end
    end

`ifndef SYNTHESIS
    genvar gi;
    generate
        for (gi = 0; gi < DEPTH; gi = gi + 1) begin : mem_expose
            assign mem_out_flat[(gi + 1) * DATA_WIDTH - 1 -: DATA_WIDTH] = mem[gi];
        end
    endgenerate
`endif
endmodule
