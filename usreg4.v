// 4-bit universal shift register
module usreg4 (
    input        clk,
    input        rst_n,        // active low reset
    input  [1:0] sel,          // S1S0: 00 hold, 01 shiftR, 10 shiftL, 11 parallel load
    input  [3:0] data_in,      // parallel input
    input        serial_in_l,  // enters from leftmost for shift-right
    input        serial_in_r,  // enters from rightmost for shift-left
    output reg [3:0] q
);

    wire [3:0] d; // next data to each FF

    // Build the combinational MUX logic for each bit
    // sel == 2'b00: hold (q)
    // sel == 2'b01: shift right (from higher index)
    // sel == 2'b10: shift left  (from lower index)
    // sel == 2'b11: parallel load (data_in)

    // bit 3 (leftmost)
    assign d[3] = (sel == 2'b00) ? q[3] :
                  (sel == 2'b01) ? q[2] :    // shift right: take from q[2]
                  (sel == 2'b10) ? serial_in_l : // shift left: serial_in_l enters MSB
                  data_in[3];

    // bit 2
    assign d[2] = (sel == 2'b00) ? q[2] :
                  (sel == 2'b01) ? q[1] :
                  (sel == 2'b10) ? q[3] :
                  data_in[2];

    // bit 1
    assign d[1] = (sel == 2'b00) ? q[1] :
                  (sel == 2'b01) ? q[0] :
                  (sel == 2'b10) ? q[2] :
                  data_in[1];

    // bit 0 (rightmost)
    assign d[0] = (sel == 2'b00) ? q[0] :
                  (sel == 2'b01) ? serial_in_r : // shift right: serial_in_r enters LSB
                  (sel == 2'b10) ? q[1] :
                  data_in[0];

    // Synchronous update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 4'b0;
        else
            q <= d;
    end

endmodule