`timescale 1 ns / 1 ps

module keccak_test_shake256_512_xof_2;
    reg clk;
    reg reset;
    reg [63:0] in;
    reg in_ready, is_last;
    reg [2:0] byte_num;
    wire buffer_full;
	 
	 integer k;
    reg [511:0] out_block;

    // NEW: squeeze request
    reg  squeeze_next;

    wire out_ready;

    // ---------------------- SHAKE hooks ----------------------
    localparam integer RATE_BITS    = 1088;   // SHAKE256 rate
    localparam [7:0]   SUFFIX       = 8'h1F;  // SHAKE suffix
    localparam integer DO_COMPARE   = 1'b1;   // compares ONLY first block unless you add more vectors
    localparam integer OUTPUT_SIZE  = 512;    // 512-bit block per out_valid
    // --------------------------------------------------------

    localparam CLK_PER = 4;
    wire [OUTPUT_SIZE-1:0] out;

    // DUT
    keccak_xof #(
        .RATE_BITS   (RATE_BITS),
        .SUFFIX      (SUFFIX),
        .OUTPUT_SIZE (OUTPUT_SIZE)
    ) sha3core (
        .clk        (clk),
        .reset      (reset),
        .in         (in),
        .in_ready   (in_ready),
        .is_last    (is_last),
        .byte_num   (byte_num),
        .buffer_full(buffer_full),

        // NEW: squeeze hook
        .squeeze_next(squeeze_next),

        .out        (out),
        .out_valid  (out_ready)
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

        // NEW
        squeeze_next = 0;

        @(posedge clk)
        reset = 1;
        #0 @(posedge clk)
        reset = 0;
        #1;
    end
    endtask

    // UPDATED:
    // - Adds 'squeeze_blocks' to request additional blocks after the first one.
    // - If squeeze_blocks=1 -> same as your old behavior (only first output).
    // - If squeeze_blocks=2 -> prints (or optionally compares) first + second output blocks.
    task check_hash_xof;
        input [16*512-1 : 0] input_data;
        input [9:0]           bytes_count;
        input [511:0]         correct_hash_first; // compares ONLY first block
        input integer         squeeze_blocks;      // 1 = only first block, 2 = first+second, ...

        integer block_index;
        integer blocks_count;
        integer byte_index;
        integer block_byte_index;

        reg [511:0] out_block1;
        reg [511:0] out_block2;
    begin
        sync_reset();

        // ---------------- Absorb message into keccak_xof ----------------
        blocks_count = bytes_count/8 + 1;
        byte_index = bytes_count - 1;

        for (block_index = blocks_count - 1; block_index >= 0; block_index = block_index - 1) begin
            wait(buffer_full == 0);

            for (block_byte_index = 7; block_byte_index >= 0; block_byte_index = block_byte_index - 1) begin
                if (byte_index >= 0)
                    #0 in[block_byte_index*8 +: 8] = input_data[byte_index*8 +: 8];
                else
                    #0 in[block_byte_index*8 +: 8] = 0;
                byte_index = byte_index - 1;
            end

            in_ready = 1;
            if (byte_index < -1) begin
                #0 is_last = 1;
                #0 byte_num = 9 + byte_index;
            end else begin
                #0 is_last = 0;
            end
            @(posedge clk);
        end

        #0 is_last = 0;
        #0 in_ready = 0;
        #0 byte_num = 0;

        // ---------------- Get first output block ----------------
        wait(out_ready == 1'b1);
        @(posedge clk);
        out_block1 = out;

        if (DO_COMPARE) begin
            if (out_block1 != correct_hash_first) begin
                $display("ERROR! first block mismatch  expected=%h  got=%h",
                         correct_hash_first, out_block1);
            end else begin
                $display("OK   : first block matches  %h", out_block1);
            end
        end else begin
            $display("XOF first block:  %h", out_block1);
        end

        // ---------------- Request additional squeeze blocks ----------------
                // ---------------- Request additional squeeze blocks ----------------
        if (squeeze_blocks > 1) begin
            for (k = 2; k <= squeeze_blocks; k = k + 1) begin
                // Pulse squeeze_next (request next block)
                @(posedge clk);
                squeeze_next = 1'b1;
                @(posedge clk);
                squeeze_next = 1'b0;

                // Wait for core to leave HAVE_OUT and come back with next block
                wait(out_ready == 1'b0);
                wait(out_ready == 1'b1);

                // Sample output block
                @(posedge clk);
                out_block = out;

                $display("XOF block %0d: %h", k, out_block);
            end
        end


        // If you want more than 2 blocks, repeat the above pattern in a for-loop:
        // pulse squeeze_next -> wait out_ready 0 -> wait out_ready 1 -> sample out

        #15;
    end
    endtask

    initial begin
        #1;
        sync_reset();
        wait (buffer_full == 0 && out == 0 && out_ready == 0)
        $display("%d# Reset correct", $time);

        // IMPORTANT:
        // Your 'correct_hash' constants below are SHA3-512 KATs (not SHAKE).
        // If you are truly running SHAKE256 (RATE_BITS=1088, SUFFIX=8'h1F),
        // set DO_COMPARE=0 OR replace expected values with SHAKE KATs.
        //
        // For squeeze testing, DO_COMPARE=0 is usually easiest initially.

        // Example: request 2 blocks (first + second)
        check_hash_xof("a", 1,
            512'h867e2cb04f5a04dcbd592501a5e8fe9ceaafca50255626ca736c138042530ba436b7b1ec0e06a279bc790733bb0aee6fa802683c7b355063c434e91189b0c651,
            5
        );

        // You can run more cases similarly:
        check_hash_xof("abcdefg", 7,
            512'hc0a95607e693d05606ed30edf19ede82f9b1840e8324956b981e038aa1d3f3d3678a9e8a87d773755e41ff335adbed72cf097e50e28d933cbfc37cd889253e6b,
            2
        );

        $display("Simulation end (squeeze tested if second block printed).");
        $finish;
    end

endmodule
