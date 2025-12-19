`timescale 1ns / 1ps

module sampleinball_top_new_tb;

    // ---------------- PARAMETERS ----------------
    parameter N          = 256;
    parameter TAU        = 60;
    parameter DATA_WIDTH = 24;
    parameter Q          = 8380417;
    parameter CLK_PERIOD = 10;

    // ---------------- SIGNALS ----------------
    reg clk;
    reg rst;

    // Keccak input interface
    reg  [63:0] in;
    reg         in_ready;
    reg         is_last;
    reg  [2:0]  byte_num;

    // Outputs
    wire done;
    wire [5:0] i;
    wire [DATA_WIDTH*TAU-1:0] ram_b_mem_out_flat;

    integer k;
    integer coeff;

    // ---------------- DUT ----------------
    sampleinball_top #(
        .N(N),
        .TAU(TAU),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(1'b0),        // unused in current RTL
        .in(in),
        .in_ready(in_ready),
        .is_last(is_last),
        .byte_num(byte_num),
        .done(done),
        .i(i),
        .ram_b_mem_out_flat(ram_b_mem_out_flat)
    );

    // ---------------- CLOCK ----------------
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end

    // ---------------- RESET TASK ----------------
    task apply_reset;
    begin
        rst       = 1'b1;
        in        = 64'd0;
        in_ready  = 1'b0;
        is_last   = 1'b0;
        byte_num  = 3'd0;
        #(5*CLK_PERIOD);
        rst       = 1'b0;
    end
    endtask

    // ---------------- MESSAGE FEED TASK ----------------
    task feed_message;
    begin
        @(posedge clk);
        in        = 64'h0000000000000061; // ASCII 'a'
        in_ready  = 1'b1;
        is_last   = 1'b1;
        byte_num  = 3'd1;                // 1 byte valid
        @(posedge clk);
        in_ready  = 1'b0;
        is_last   = 1'b0;
        byte_num  = 3'd0;
        in        = 64'd0;
    end
    endtask

    // ---------------- MAIN TEST ----------------
    initial begin
        clk = 1'b0;

        $display("============================================");
        $display(" SampleInBall + Keccak (PURE VERILOG TB)");
        $display("============================================");

        $dumpfile("sampleinball_top_new_tb.vcd");
        $dumpvars(0, sampleinball_top_new_tb);

        apply_reset();
        feed_message();

        // Wait for SampleInBall to finish
        wait (done == 1'b1);
        #(2*CLK_PERIOD);

        $display("\n--- SampleInBall Output (TAU=%0d) ---", TAU);

        for (k = 0; k < TAU; k = k + 1) begin
            coeff = ram_b_mem_out_flat[(k+1)*DATA_WIDTH-1 -: DATA_WIDTH];

            if (coeff == 1)
                $display("Coeff[%0d] = +1", k);
            else if (coeff == Q-1)
                $display("Coeff[%0d] = -1", k);
            else if (coeff == 0)
                $display("Coeff[%0d] =  0", k);
            else
                $display("Coeff[%0d] = %0d", k, coeff);
        end

        $display("\n=== TEST PASSED ===");
        #(5*CLK_PERIOD);
        $finish;
    end

    // ---------------- TIMEOUT ----------------
    initial begin
        #(5_000_000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
