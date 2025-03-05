`default_nettype none
`timescale 1ns / 1ps

module lfsr_1bit #(
        parameter logic [31:0] POLYNOMIAL = 32'h4c11db7
        //parameter logic [4:0] POLYNOMIAL = 5'b10101
    )
    (
        input  wire         i_clk,
        input  wire         i_rst_n,

        input  wire         i_bit,
        input  wire         i_bit_en,

        output wire [31:0]  o_state

    );

    logic [31:0]     state;
    logic           top_bit;

    assign o_state = {top_bit, state[30:0]};

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= 0;
        end else begin
            if (i_bit_en) begin
                if (state[31]) begin
                    {top_bit, state} <= {state, i_bit}  ^ (state[31] ? {1'b0, POLYNOMIAL} : '0);
                end else begin  
                    {top_bit, state} <= {state, i_bit};
                end
            end
        end
    end



endmodule
