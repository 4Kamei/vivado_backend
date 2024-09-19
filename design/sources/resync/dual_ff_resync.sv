`default_nettype none
`timescale 1ns / 1ps

module dual_ff_resync #(
        parameter RESET_VALUE = 1'b0
    ) (
        input wire i_clk,
        input wire i_rst_n,
        
        input wire i_signal,
        output wire o_signal
    );

    logic flop_q;
    logic flop_q_q;
        
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            flop_q <= RESET_VALUE;
            flop_q_q <= RESET_VALUE;
        end else begin
            flop_q <= i_signal;
            flop_q_q <= flop_q;
        end
    end

    assign o_signal = flop_q_q;

endmodule
