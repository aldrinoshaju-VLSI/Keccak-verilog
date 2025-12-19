//testbench

`timescale 1ns / 1ps
module sampleinball_top_tb;
    parameter N = 256;
    parameter TAU = 60;
    parameter DATA_WIDTH = 24;
    parameter Q = 8380417;

    reg clk = 0;
    reg rst = 0;
    reg start = 0;
	 reg [63:0] in;

    wire done;
    wire [5:0] i;  // TAU=60 fits in 6 bits
	 wire [DATA_WIDTH * TAU -1 : 0] ram_b_mem_out_flat;
	 
	 reg in_ready, is_last;
    reg [2:0] byte_num;
	 

    integer zero_count;
    reg [DATA_WIDTH-1:0] coeffs [0:TAU-1];
    integer k;
	 
	 // ---------------------- NEW: minimal SHAKE hooks ----------------------
    // Keep defaults for SHA3-512. For SHAKE, set as below:
    //   SHAKE256: RATE_BITS=1088, SUFFIX=8'h1F, DO_COMPARE=0 (unless you change vectors)
    //   SHAKE128: RATE_BITS=1344, SUFFIX=8'h1F, DO_COMPARE=0 (unless you change vectors)
    localparam integer RATE_BITS  = 1088;   // 576 (SHA3-512), 1088 (SHAKE256), 1344 (SHAKE128)
    localparam [7:0]   SUFFIX     = 8'h1F; // 8'h06 (SHA3), 8'h1F (SHAKE)
    localparam integer DO_COMPARE = 1'b1;  // set 0 for SHAKE unless you replace expected digests
	 localparam integer OUTPUT_SIZE = 1088;  // set 256 for 32 byte, or 512 for 64 byte
    // ---------------------------------------------------------------------

    sampleinball_top #(
        .N(N),
        .TAU(TAU),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(8),
        .OUT_ADDR_WIDTH(6),
		  .RATE_BITS(RATE_BITS),
        .SUFFIX   (SUFFIX),
		  .OUTPUT_SIZE(OUTPUT_SIZE)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .i(i),
		  .in(in),
		  .in_ready(in_ready),
        .is_last(is_last),
        .byte_num(byte_num),
		  .ram_b_mem_out_flat(ram_b_mem_out_flat)
    );

    always #5 clk = ~clk;  // 100 MHz clock

    initial begin
        $display("SampleInBall testbench starting...");
        $dumpfile("sampleinball_top_tb.vcd");
        $dumpvars(0, sampleinball_top_tb);
        rst = 0;
        start = 0;
        #700 
		  //rst = 1;
        #20 start = 1;
        #10 start = 0;
    end

    initial begin
		  #1;
        sync_reset(); 

        input_val("a", 1);
		  
		  $display("Simulation end, correct if no errors (or compare disabled for SHAKE).");
		  
        wait(done);
        #20;  // Allow memory to settle

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

    initial begin
        #2000000 $display("Timeout reached, stopping simulation."); $finish;
    end
	 
	 
	 
	 
	 task sync_reset;
    begin
        in = 0;
        in_ready = 0;
        is_last = 0;
        byte_num = 0;

        @(posedge clk)
        rst = 1;
        #0 @(posedge clk)
        rst = 0;
        #1;
    end
    endtask

    task input_val;
        input [16*512-1 : 0] input_data;
        input [9:0] bytes_count;

        integer block_index;
        integer blocks_count;
        integer byte_index;
        integer block_byte_index;
        reg [511:0] out_buffer;
    begin
        sync_reset();

        blocks_count = bytes_count/8 + 1;
        byte_index = bytes_count - 1;
        for(block_index = blocks_count - 1; block_index >= 0; block_index = block_index - 1) begin
            //wait(buffer_full == 0);            
            
            for(block_byte_index = 7; block_byte_index >= 0; block_byte_index = block_byte_index - 1) begin
                if(byte_index >= 0)
                    #0 in[block_byte_index*8 +: 8] = input_data[byte_index*8 +: 8];
                else
                    #0 in[block_byte_index*8 +: 8] = 0;
                byte_index = byte_index - 1;
            end

            in_ready = 1;
            if(byte_index < -1) begin
                #0 is_last = 1;
                #0 byte_num = 9 + byte_index;
            end 
            else begin
                #0 is_last = 0;
            end
            @(posedge clk);
        end
        #0 is_last = 0;
        #0 in_ready = 0;
        #0 byte_num = 0;
    end
    endtask

endmodule
