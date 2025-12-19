`timescale 1 ns / 1 ps

module tb_keccak_prg_adapter;
    reg clk;
    reg reset;
    reg [63:0] in;
    reg in_ready, is_last;
    reg [2:0] byte_num;
    wire buffer_full;
    
    wire out_ready;
	 
	 reg prg_ready;
	 wire prg_valid, prg_done;
	 wire [8:0] prg_bits;


    // ---------------------- NEW: minimal SHAKE hooks ----------------------
    // Keep defaults for SHA3-512. For SHAKE, set as below:
    //   SHAKE256: RATE_BITS=1088, SUFFIX=8'h1F, DO_COMPARE=0 (unless you change vectors)
    //   SHAKE128: RATE_BITS=1344, SUFFIX=8'h1F, DO_COMPARE=0 (unless you change vectors)
    localparam integer RATE_BITS  = 1088;   // 576 (SHA3-512), 1088 (SHAKE256), 1344 (SHAKE128)
    localparam [7:0]   SUFFIX     = 8'h1F; // 8'h06 (SHA3), 8'h1F (SHAKE)
    localparam integer DO_COMPARE = 1'b0;  // set 0 for SHAKE unless you replace expected digests
	 localparam integer OUTPUT_SIZE = 1088;  // set 256 for 32 byte, or 512 for 64 byte
    // ---------------------------------------------------------------------

    localparam CLK_PER = 4;
	 wire [OUTPUT_SIZE-1:0] out;

    // DUT: pass the new parameters (rate width + suffix)
    keccak #(
        .RATE_BITS(RATE_BITS),
        .SUFFIX   (SUFFIX),
		  .OUTPUT_SIZE(OUTPUT_SIZE)
    ) sha3core (
        .clk(clk), 
		  .reset(reset),
        .in(in),
        .in_ready(in_ready),
        .is_last(is_last),
        .byte_num(byte_num),
        .buffer_full(buffer_full),
        .out(out),
        .out_ready(out_ready)
    );
	 
	 keccak_prg_adapter prg_adapter (
		 .clk(clk),
		 .rst(reset),
		 .keccak_ready(out_ready),
		 .keccak_out(out),
		 .prg_ready(out_ready),
		 .prg_valid(prg_valid),
		 .prg_bits(prg_bits),
		 .prg_done(prg_done)
	);

    initial begin
        clk = 0;
        reset = 0;
    end
    always begin
        #(CLK_PER/2) clk = ~clk;
    end

    task sync_reset;
    begin
        in = 0;
        in_ready = 0;
        is_last = 0;
        byte_num = 0;

        @(posedge clk)
        reset = 1;
        #0 @(posedge clk)
        reset = 0;
        #1;
    end
    endtask

    task check_hash;
        input [16*512-1 : 0] input_data;
        input [9:0] bytes_count;
        input [511:0] correct_hash;

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
            wait(buffer_full == 0);            
            
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
        
        wait(out_ready);
        @(posedge clk)

        // ---------------------- NEW: conditional compare/print ----------------------
        if (DO_COMPARE) begin
            if(out != correct_hash) begin
                $display("ERROR! hash incorrect - (correct != out) 512'h%h != 512'h%h", correct_hash, out);
            end else begin
                $display("OK   : hash matches 512'h%h", out);
            end
        end else begin
            $display("Input: 0x%016h, SHAKE output (first 512 bits): 512'h%h", in, out);
        end
        // ---------------------------------------------------------------------------

        #15;
    end
    endtask

    initial begin
        #1;
        sync_reset();           
        wait (buffer_full == 0 && out == 0 && out_ready == 0) 
        $display("%d# Reset correct", $time);
        
        // NOTE:
        // - Keep these for SHA3-512 (DO_COMPARE=1).
        // - For SHAKE, either:
        //     (a) set DO_COMPARE=0 and this will print outputs, or
        //     (b) replace 'correct_hash' values with SHAKE KATs and keep DO_COMPARE=1.

        check_hash("a", 1, 512'h867e2cb04f5a04dcbd592501a5e8fe9ceaafca50255626ca736c138042530ba436b7b1ec0e06a279bc790733bb0aee6fa802683c7b355063c434e91189b0c651);
        
        $display("Simulation end, correct if no errors (or compare disabled for SHAKE).");
		  wait(prg_done)
        $finish;
    end
	 
	 initial begin
		 #300;  // timeout value (adjust as needed)
		 $display("ERROR: Simulation timeout – DUT did not finish");
		 $finish;
	 end

endmodule
