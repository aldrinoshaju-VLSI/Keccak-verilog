// Updated testbench for NEW sampleinball_top (Keccak adapter integrated)
// --------------------------------------------------------------------
// Changes vs your original TB:
// 1) sampleinball_top now has extra ports to feed Keccak through adapter:
//      keccak_in, keccak_in_ready, keccak_is_last, keccak_byte_num,
//      keccak_buffer_full
// 2) TB now drives a small message ("a") into Keccak through these ports
//    while start=1.
// 3) Rest of TB (wait done, dump TAU coeffs) is same as before.
//
// NOTE on byte_num:
// - This TB uses byte_num=3'd1 for message length 1 byte ("a").
// - If your padder expects a different encoding, adjust byte_num accordingly.

`timescale 1ns / 1ps
module sampleinball_top_tb;

    parameter N          = 256;
    parameter TAU        = 60;
    parameter DATA_WIDTH = 24;
    parameter Q          = 8380417;

    reg clk   = 0;
    reg rst_n = 0;
    reg start = 0;

    // NEW: Keccak input ports (through adapter)
    reg  [63:0] keccak_in;
    reg         keccak_in_ready;
    reg         keccak_is_last;
    reg  [2:0]  keccak_byte_num;
    wire        keccak_buffer_full;

    wire done;
    wire [5:0] i;  // TAU=60 fits in 6 bits

    // Exposed flattened RAM_B from top
    wire [DATA_WIDTH*TAU-1:0] ram_b_mem_out_flat;

    integer zero_count;
    reg [DATA_WIDTH-1:0] coeffs [0:TAU-1];
    integer k;

    // DUT (UPDATED port list)
    sampleinball_top #(
        .N(N),
        .TAU(TAU),
        .Q(Q),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(8),
        .OUT_ADDR_WIDTH(6)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        // NEW keccak ports
        .keccak_in(keccak_in),
        .keccak_in_ready(keccak_in_ready),
        .keccak_is_last(keccak_is_last),
        .keccak_byte_num(keccak_byte_num),
        .keccak_buffer_full(keccak_buffer_full),

        .done(done),
        .i(i),
        .ram_b_mem_out_flat(ram_b_mem_out_flat)
    );

    always #5 clk = ~clk;  // 100 MHz clock

    // ------------------------------------------------------------
    // Reset / start + feed keccak input via adapter
    // ------------------------------------------------------------
    initial begin
        $display("SampleInBall (Keccak-adapter) testbench starting...");
        $dumpfile("sampleinball_top_tb.vcd");
        $dumpvars(0, sampleinball_top_tb);

        // init
        keccak_in        = 64'd0;
        keccak_in_ready  = 1'b0;
        keccak_is_last   = 1'b0;
        keccak_byte_num  = 3'd0;

        rst_n = 0;
        start = 0;

        // reset
        #100 rst_n = 1;

        // start
        #20  start = 1;

        // --------------------------------------------------------
        // Feed a 1-byte message "a" into keccak through adapter.
        // We pack 'a' into keccak_in[63:56], rest 0, like your keccak TB.
        // Wait until buffer is free, then pulse in_ready for 1 clock.
        // --------------------------------------------------------

        // Wait (bounded) until keccak_buffer_full deasserts
        // (avoid wait() if your simulator is strict)
		  /*
        begin : BF_WAIT
            integer t;
            reg ok;
            ok = 0;
            for (t = 0; t < 5000; t = t + 1) begin
                @(posedge clk);
                if (!keccak_buffer_full) ok = 1;
            end
            if (!ok) begin
                $display("ERROR: timeout waiting keccak_buffer_full=0");
                $finish;
            end
        end
		  */

        // Drive the last input word
        keccak_in       = {8'h61, 56'h0}; // "a"
        keccak_in_ready = 1'b1;
        keccak_is_last  = 1'b1;
        keccak_byte_num = 3'd1;          // 1 valid byte in the last word

        @(posedge clk);

        // Deassert
        keccak_in_ready = 1'b0;
        keccak_is_last  = 1'b0;
        keccak_byte_num = 3'd0;
        keccak_in       = 64'd0;

        // stop start pulse
        //#100 start = 0;
    end

    // ------------------------------------------------------------
    // Wait for done then dump TAU coefficients (same as before)
    // ------------------------------------------------------------
    initial begin
        // If your simulator dislikes wait(done), replace with a bounded loop
        wait(done);
        #20;  // allow memory to settle

        zero_count = 0;
        $display("--- Final Polynomial Coefficients (TAU = %0d) ---", TAU);

        for (k = 0; k < TAU; k = k + 1) begin
            coeffs[k] = ram_b_mem_out_flat[DATA_WIDTH*(k+1)-1 -: DATA_WIDTH];

            if (^coeffs[k] === 1'bx)
                $display("Coeff[%0d] = X (uninitialized)", k);
            else if (coeffs[k] == Q - 1)
                $display("Coeff[%0d] = -1", k);
            else if (coeffs[k] == 1)
                $display("Coeff[%0d] = 1", k);
            else if (coeffs[k] == 0) begin
                zero_count = zero_count + 1;
                $display("Coeff[%0d] = 0", k);
            end else
                $display("Coeff[%0d] = %0d", k, coeffs[k]);
        end

        $display("Zero coefficients count = %0d", zero_count);
        #10 $finish;
    end

    // Timeout
    initial begin
        #2000000;
        $display("Timeout reached, stopping simulation.");
        $finish;
    end

endmodule
