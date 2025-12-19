// for random number generator
`timescale 1ns / 1ps
module prg_stub (
    input clk,
    input rst_n,
    input start,
    input ready,
    output reg valid,
    output reg [8:0] prg_bits   // [8]=sign, [7:0]=index
);

    reg [15:0] lfsr;
    reg running;
    wire feedback;

    assign feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1;
            running <= 0;
            valid <= 0;
            prg_bits <= 9'b0;
        end else begin
            if (start)
                running <= 1;
            if (running && ready) begin
                lfsr <= {lfsr[14:0], feedback};
                prg_bits <= {lfsr[15], lfsr[7:0]};
                valid <= 1;
            end else begin
                valid <= 0;
            end
        end
    end
endmodule
