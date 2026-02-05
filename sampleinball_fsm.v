// sampleinball_fsm module with case handling
`timescale 1ns / 1ps
module sampleinball_fsm #(
    parameter N = 256,
    parameter TAU = 60,
    parameter Q = 8380417,
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 8,
    parameter OUT_ADDR_WIDTH = 6
)(
    input clk,
    input rst_n,
    input start,
    input prg_valid,
    input [ADDR_WIDTH:0] prg_bits,  // [8]=sign, [7:0]=index
    output reg prg_ready,
    output reg [ADDR_WIDTH-1:0] bram_addr_A,
    output reg [DATA_WIDTH-1:0] bram_din_A,
    output reg bram_en_A,
    output reg bram_we_A,
    input [DATA_WIDTH-1:0] bram_dout_A,
    output reg [OUT_ADDR_WIDTH-1:0] bram_addr_B,
    output reg [DATA_WIDTH-1:0] bram_din_B,
    output reg bram_en_B,
    output reg bram_we_B,
    input [DATA_WIDTH-1:0] bram_dout_B,
    output reg done,
    output reg [OUT_ADDR_WIDTH-1:0] i
);

    localparam IDLE        = 4'd0,
               INIT        = 4'd1,
               PULL_RANDOM = 4'd2,
               WRITE_A     = 4'd3,
               WAIT_READ   = 4'd4,
               WAIT_READ2  = 4'd5,
               WAIT_READ3  = 4'd6,
               WRITE_B     = 4'd7,
               DONE_STATE  = 4'd8;

    reg [3:0] state_internal;
    reg [ADDR_WIDTH-1:0] r;
    reg s;
    reg [N-1:0] sampled_flags;
    reg prev_sampled;
    reg [ADDR_WIDTH-1:0] prev_r;
    reg prev_write_success;
    reg prev_sampling_success;

    function [DATA_WIDTH-1:0] mod_q;
        input integer val;
        begin
            if (val < 0)
                mod_q = val + Q;
            else if (val >= Q)
                mod_q = val - Q;
            else
                mod_q = val;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_internal <= IDLE;
            done <= 0;
            sampled_flags <= 0;
            r <= 0;
            s <= 0;
            prg_ready <= 0;
            bram_addr_A <= 0;
            bram_din_A <= 0;
            bram_en_A <= 0;
            bram_we_A <= 0;
            bram_addr_B <= 0;
            bram_din_B <= 0;
            bram_en_B <= 0;
            bram_we_B <= 0;
            i <= 0;
            prev_sampled <= 0;
            prev_r <= 0;
            prev_write_success <= 0;
            prev_sampling_success <= 0;
            $display("RESET: FSM cleared at time %t", $time);
        end else begin
            prg_ready <= 0;
            bram_en_A <= 0; bram_we_A <= 0;
            bram_en_B <= 0; bram_we_B <= 0;

            case(state_internal)
                IDLE: begin
                    done <= 0;
                    sampled_flags <= 0;
                    i <= 0;
                    prev_sampled <= 0;
                    prev_write_success <= 0;
                    prev_sampling_success <= 0;
                    if (start) begin
                        state_internal <= INIT;
                        $display("IDLE: Starting FSM at time %t", $time);
                    end
                end

                INIT: begin
                    prg_ready <= 1;
                    state_internal <= PULL_RANDOM;
                    $display("INIT: Requesting PRG at time %t", $time);
                end

                PULL_RANDOM: begin
                    prg_ready <= 1;
                    if (prg_valid) begin
                        r <= prg_bits[ADDR_WIDTH-1:0];
                        s <= prg_bits[ADDR_WIDTH];
                        if (sampled_flags[r]) begin
                            prg_ready <= 1;  // keep requesting new random
                            $display("PULL_RANDOM: Duplicate sample %d rejected at time %t", r, $time);
                        end else begin
                            state_internal <= WRITE_A;
                            $display("PULL_RANDOM: Accepted sample %d with sign %b at time %t", r, s, $time);
                        end
                    end else begin
                        $display("PULL_RANDOM: Waiting for PRG valid at time %t", $time);
                    end
                end

                WRITE_A: begin
                    bram_addr_A <= r;
                    bram_din_A <= s ? Q-1 : 1;
                    bram_en_A <= 1;
                    bram_we_A <= 1;
                    state_internal <= WAIT_READ;
                    $display("WRITE_A: Writing %d at addr %d at time %t", bram_din_A, r, $time);
                end

                WAIT_READ: state_internal <= WAIT_READ2;
                WAIT_READ2: state_internal <= WAIT_READ3;

                WAIT_READ3: begin
                    bram_addr_A <= r;
                    bram_en_A <= 1;
                    bram_we_A <= 0;
                    state_internal <= WRITE_B;
                    $display("WAIT_READ3: Read done addr %d at time %t", r, $time);
                end

                WRITE_B: begin
                    bram_addr_B <= i;
                    bram_din_B <= bram_din_A;
                    bram_en_B <= 1;

                    if (i == r && !prev_sampled) begin
                        bram_we_B <= 0;
                        prev_sampled <= 1;
                        prev_write_success <= 0;
                        $display("WRITE_B: Disabled write at addr %d (Conflict 1) at time %t", i, $time);
                    end else if ((i > 0) && (r == (i - 1)) && prev_sampling_success) begin
                        bram_we_B <= 0;
                        prev_write_success <= 0;
                        $display("WRITE_B: Disabled write at addr %d (Conflict 2) at time %t", i, $time);
                    end else begin
                        bram_we_B <= 1;
                        prev_sampled <= 0;
                        prev_write_success <= 1;
                        sampled_flags[r] <= 1'b1;
                        $display("WRITE_B: Writing %d to addr %d at time %t", bram_din_B, i, $time);
                        i <= i + 1;
                    end

                    prev_r <= r;
                    prev_sampling_success <= bram_we_B;

                    if (i < TAU)
                        state_internal <= PULL_RANDOM;
                    else begin
                        done <= 1;
                        state_internal <= DONE_STATE;
                        $display("WRITE_B: TAU reached, done asserted at time %t", $time);
                    end
                end

                DONE_STATE: begin
                    if (!start) begin
                        state_internal <= IDLE;
                        done <= 0;
                        $display("DONE_STATE: FSM reset at time %t", $time);
                    end
                end

                default: begin
                    state_internal <= IDLE;
                    $display("DEFAULT: Unknown state, resetting at time %t", $time);
                end
            endcase
        end
    end
endmodule
