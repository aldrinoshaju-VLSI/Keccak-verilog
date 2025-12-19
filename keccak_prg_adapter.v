module keccak_prg_adapter (
    input  wire        clk,
    input  wire        rst,

    // From Keccak
    input  wire        keccak_ready,
    input  wire [255:0] keccak_out,

    // To SampleInBall FSM
    input  wire        prg_ready,        // FSM requests next 9 bits
    output reg         prg_valid,
    output reg  [8:0]  prg_bits,
	 output reg         prg_done
);

    reg [255:0] buff;        // holds the squeezed block
    reg [5:0]   idx;        // index for 9-bit slices (0..28)
    reg         loaded;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buff <= 0;
            idx <= 0;
            prg_valid <= 0;
            prg_bits <= 0;
            loaded <= 0;
				prg_done <= 0;
        end else begin
            prg_valid <= 0;

            // Load a new 256-bit block from Keccak
            if (keccak_ready) begin
                buff <= keccak_out;
                idx <= 0;
                loaded <= 1;
					 prg_done <= 0;
            end

            // FSM asks for a new 9-bit PRG word
            if (prg_ready && loaded) begin
                prg_bits <= buff[idx*9 +: 9];
                prg_valid <= 1;
                idx <= idx + 1;

                // When we exhaust buffer, wait for next Keccak block
                if ((idx+1) * 9 >= 256)begin
                    loaded <= 0;
						  prg_done <= 1;
						  end
            end
        end
    end
endmodule
