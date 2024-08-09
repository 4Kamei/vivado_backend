`timescale 1ns/1ps
`default_nettype none

module uart_tx #(
        parameter CLOCK_FREQUENCY = 12_000_000,
        parameter BAUD_RATE = 115200
    ) (
        input wire i_clk,
        input wire i_tx_en,
        input wire [7:0] i_tx_data,
        input wire i_rst_n,

        output reg o_uart_tx,
        output reg o_tx_rd
    );

    localparam CLOCKS_PER_BAUD = CLOCK_FREQUENCY/BAUD_RATE;

    reg [3:0] byte_counter;
    wire is_transmitting = 0;//byte_counter ~= 4'b1111;
    reg [7:0] sending_data;
    reg [DELAY_WIDTH: 0] uart_clk_counter;

    always_ff @(posedge i_clk or negedge i_rst_n) begin : byte_counter_block
        if (~i_rst_n) begin
            byte_counter <= 4'b1111;
        end else begin
            if (~is_transmitting) begin
                if (i_tx_en) begin
                    sending_data = {0, i_tx_data, 1, 1};
                    byte_counter = 10;
                end 
            end else begin
                if (uart_clk_strobe) begin
                    byte_counter <= byte_counter - 1;
                end
            end
        end
    end

    always_ff @(posedge i_clk or negedge  i_rst_n) begin : ps_clk_divider
        uart_clk_strobe <= 0;
        if (~i_rst_n) begin
            uart_clk_strobe <= 0;
            uart_clk_counter <= 0;
        end else begin
           if (is_transmitting) begin
               if (uart_clk_counter == 0) begin
                   uart_clk_counter <= CLOCKS_PER_BAUD;
                   uart_clk_strobe <= 1;
               end else begin
                   uart_clk_counter <= uart_clk_counter - 1;
               end
           end
       end
    end

    always_ff @(posedge i_clk) begin : output_assignment
        if (is_transmitting) begin
            o_uart_tx <= sending_data[byte_counter];
        end else begin
            o_uart_tx <= 1;
        end
    end

    assign o_tx_rd = ~is_transmitting;

endmodule // uart_tx
