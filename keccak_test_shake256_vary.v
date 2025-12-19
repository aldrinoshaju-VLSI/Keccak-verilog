`timescale 1 ns / 1 ps

module keccak_test_shake256_vary;
    reg clk;
    reg reset;
    reg [63:0] in;
    reg in_ready, is_last;
    reg [2:0] byte_num;
    wire buffer_full;

    // ----- Set your SHAKE / output params here -----
    localparam integer RATE_BITS   = 1088;    // 576=SHA3-512, 1088=SHAKE256, 1344=SHAKE128
    localparam [7:0]   SUFFIX      = 8'h1F;   // 0x06=SHA3, 0x1F=SHAKE
    localparam integer OUTPUT_BIT  = 600;     // any byte-multiple <= RATE_BITS
    localparam integer DO_COMPARE  = 0;       // 1 to compare against provided vectors
    // ------------------------------------------------

    // DUT I/O (variable-width out)
    wire [OUTPUT_BIT-1:0] out;
    wire out_ready;

    // If your keccak RTL has squeeze_more input (for extra chunks), tie it low here.
    reg squeeze_more;

    localparam CLK_PER = 4;

    // DUT: pass the new parameters (rate, suffix, out width)
    keccak #(
        .RATE_BITS(RATE_BITS),
        .SUFFIX   (SUFFIX),
        .OUT_BITS (OUTPUT_BIT)
    ) sha3core (
        .clk(clk), .reset(reset),
        .in(in),
        .in_ready(in_ready),
        .is_last(is_last),
        .byte_num(byte_num),
        .squeeze_more(squeeze_more),          // tie low for single chunk
        .buffer_full(buffer_full),
        .out(out),
        .out_ready(out_ready)
    );

    initial begin
        clk = 0;
        reset = 0;
        squeeze_more = 1'b0;
    end
    always begin
        #(CLK_PER/2) clk = ~clk;
    end

    task sync_reset;
    begin
        in = 64'd0;
        in_ready = 1'b0;
        is_last = 1'b0;
        byte_num = 3'd0;
        squeeze_more = 1'b0;

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
        input [OUTPUT_BIT-1:0] correct_hash;   // match OUTPUT_BIT

        integer block_index;
        integer blocks_count;
        integer byte_index;
        integer block_byte_index;
        reg [OUTPUT_BIT-1:0] out_buffer;
        integer k;
    begin
        sync_reset();

        // show input string for convenience
        $write("MSG (%0d bytes): \"", bytes_count);
        for (k = bytes_count-1; k >= 0; k = k-1) $write("%c", input_data[k*8 +: 8]);
        $display("\"");

        // feed message as 64-bit words, MSB-first per your original TB
        blocks_count = bytes_count/8 + 1;
        byte_index = bytes_count - 1;
        for(block_index = blocks_count - 1; block_index >= 0; block_index = block_index - 1) begin
            wait(buffer_full == 0);

            for(block_byte_index = 7; block_byte_index >= 0; block_byte_index = block_byte_index - 1) begin
                if(byte_index >= 0)
                    #0 in[block_byte_index*8 +: 8] = input_data[byte_index*8 +: 8];
                else
                    #0 in[block_byte_index*8 +: 8] = 8'h00;
                byte_index = byte_index - 1;
            end

            in_ready = 1;
            if(byte_index < -1) begin
                #0 is_last = 1;
                #0 byte_num = 9 + byte_index; // 0..7
            end else begin
                #0 is_last = 0;
            end
            @(posedge clk);
        end
        #0 is_last = 0;
        #0 in_ready = 0;
        #0 byte_num = 0;

        // First chunk (<= RATE_BITS) arrives here
        wait(out_ready);
        @(posedge clk);

        if (DO_COMPARE) begin
            if(out != correct_hash) begin
                $display("ERROR! hash incorrect - (correct != out) %0d'h%0h != %0d'h%0h",
                         OUTPUT_BIT, correct_hash, OUTPUT_BIT, out);
            end else begin
                $display("OK   : hash matches %0d'h%0h", OUTPUT_BIT, out);
            end
        end else begin
            $display("SHAKE output (first %0d bits): %0d'h%0h", OUTPUT_BIT, OUTPUT_BIT, out);
        end

        // Example: if you wanted the NEXT chunk, uncomment:
        // squeeze_more = 1'b1; @(posedge clk); squeeze_more = 1'b0;
        // wait(out_ready); @(posedge clk);
        // $display("Next %0d bits: %0d'h%0h", OUTPUT_BIT, OUTPUT_BIT, out);

        #15;
    end
    endtask

    initial begin
        #1;
        sync_reset();
        wait (buffer_full == 0 && out == {OUTPUT_BIT{1'b0}} && out_ready == 0);
        $display("Reset correct (RATE=%0d, OUT=%0d, SUFFIX=0x%02x)", RATE_BITS, OUTPUT_BIT, SUFFIX);

        // For SHAKE runs, DO_COMPARE should usually be 0 unless you supply matching SHAKE KATs of width OUTPUT_BIT.
        // The 'correct_hash' args below are 512-bit constants; they are ignored when DO_COMPARE=0.

        check_hash("a", 1, {OUTPUT_BIT{1'b0}});
        check_hash("abcdefg", 7, {OUTPUT_BIT{1'b0}});
        check_hash("abcdefgh", 8, {OUTPUT_BIT{1'b0}});
        check_hash("abcdefgha", 9, {OUTPUT_BIT{1'b0}});
        check_hash("abcdefghijklm", 13, {OUTPUT_BIT{1'b0}});
        check_hash("Lorem ipsum dolor sit amet amet.", 32, {OUTPUT_BIT{1'b0}});
        check_hash("Lorem ipsum dolor sit amet emat.", 32, {OUTPUT_BIT{1'b0}});
        check_hash("Nunc tempor lectus posuere.", 27, {OUTPUT_BIT{1'b0}});
        check_hash("Cras tristique, felis non auctor dapibus, metus libero fermentum magna.", 71, {OUTPUT_BIT{1'b0}});
        check_hash("Nulla consectetur libero in tortor.", 35, {OUTPUT_BIT{1'b0}});
        check_hash("Nulla consectetur libero in tortor!", 35, {OUTPUT_BIT{1'b0}});
        check_hash("Litwo ojczyzno moja", 19, {OUTPUT_BIT{1'b0}});
        check_hash("Praesent magna metus, lacinia id tellus vel, pellentesque metus.", 64, {OUTPUT_BIT{1'b0}});
        check_hash("facebook", 8, {OUTPUT_BIT{1'b0}});
        check_hash("faecbook", 8, {OUTPUT_BIT{1'b0}});
        check_hash("faceb00k", 8, {OUTPUT_BIT{1'b0}});
        check_hash("3,141592653589793238", 20, {OUTPUT_BIT{1'b0}});
        check_hash("3.141592653589793238", 20, {OUTPUT_BIT{1'b0}});
        check_hash("O", 1, {OUTPUT_BIT{1'b0}});
        check_hash("0", 1, {OUTPUT_BIT{1'b0}});
        check_hash("o", 1, {OUTPUT_BIT{1'b0}});
        check_hash("I", 1, {OUTPUT_BIT{1'b0}});
        check_hash("l", 1, {OUTPUT_BIT{1'b0}});
        check_hash("1", 1, {OUTPUT_BIT{1'b0}});
        check_hash("c", 1, {OUTPUT_BIT{1'b0}});

        $display("Simulation end, correct if no errors (or compare disabled for SHAKE).");
        $finish;
    end

endmodule
