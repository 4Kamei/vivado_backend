`default_nettype none
`timescale 1ns / 1ps

module eth_block_alignment (
        input wire i_clk,
        input wire [1:0] i_header,
        input wire i_rst_n,
        output wire o_block_lock,
        output wire o_rxslip
    );

    typedef enum logic [1:0] {
        LOCK_INIT,
        RESET_CNT,
        TEST_SH,
        SLIP
    } bl_fsm_t;
    
    bl_fsm_t bl_state;

    logic [6:0] sh_total_count;
    logic [6:0] sh_invalid_count; 
    logic [1:0] slip_counter;

    logic slip;
    logic block_lock;
    assign o_rxslip = slip;
    assign o_block_lock = block_lock;

    logic sh_valid;
    always_comb sh_valid = i_header == 2'b10 || i_header == 2'b01;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            bl_state <= LOCK_INIT;
        end else begin
            case (bl_state)
                LOCK_INIT: begin
                    block_lock <= 1'b0;
                    bl_state <= RESET_CNT;
                end
                RESET_CNT: begin
                    sh_total_count <= 0;
                    sh_invalid_count <= 0;
                    bl_state <= TEST_SH;
                    slip <= 1'b0;
                end
                TEST_SH: begin
                    sh_total_count <= sh_total_count + 1'b1;
                    if (sh_total_count == 7'd64 || sh_invalid_count == 7'd16) begin
                        bl_state <= RESET_CNT;
                        if(sh_invalid_count == 0) begin
                            block_lock <= 1'b1;
                        end
                        if (sh_invalid_count == 7'd16 || ~sh_valid) begin
                            block_lock <= 1'b0;
                            bl_state <= SLIP;
                            slip <= 1'b1;
                            slip_counter <= 2'd3;
                        end
                    end else begin
                        if(~sh_valid) begin
                            sh_invalid_count <= sh_invalid_count + 1'b1;
                        end
                    end
                end
                SLIP: begin
                    slip <= 1'b0;
                    slip_counter <= slip_counter - 1'b1;
                    if (slip_counter == 0) begin
                        bl_state <= RESET_CNT;
                    end
                end
                default: $error("Unreachable");
            endcase
        end
    end


endmodule
`resetall
