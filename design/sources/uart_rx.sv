`timescale 1ns / 1ps
`default_nettype none

module uart_rx
    #(   parameter CLOCK_FREQUENCY = 10_000_000,
         parameter BAUD_RATE = 115200,
         parameter PARITY_BIT = 0
     )(
        input wire i_clk,
        input wire i_uart_rx,
        input wire i_rst_n,

        output reg [7:0] o_rx_data,
        output reg o_rx_en
    );
    
    localparam CLOCKS_PER_BAUD = CLOCK_FREQUENCY/BAUD_RATE;

    localparam DELAY_WIDTH = $clog2(CLOCK_FREQUENCY * 3/2);

    reg receive_state;
    reg [3:0] byte_counter;
    reg [7:0] data_reg;
    reg uart_in_sync, uart_in_sync1;
    
    always_ff @(posedge i_clk) begin : proc_uart_in_sync
        uart_in_sync <= uart_in_sync1;
        uart_in_sync <= i_uart_rx;
    end
    
    //detects 1-0 edge 
    reg past_value;
    reg edge_strobe;
    reg has_bits;

    always_comb edge_strobe = {past_value, uart_in_sync} == 2'b10;
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin : proc_edge_detector
        if (!i_rst_n) begin
            past_value <= 1'b1;
        end else begin
            past_value <= uart_in_sync;
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin : proc_receive_state
        if (!i_rst_n) begin
           has_bits <= 0;
           receive_state <= 0;
        end else begin
            o_rx_en <= 0;
            if (edge_strobe & !receive_state) begin
                receive_state <= 1'b1;
                has_bits <= 1'b1;
            end
            if (receive_state & byte_counter == 4'b1000) begin
                if (has_bits) begin
                    o_rx_data <= data_reg;
                    has_bits <= 0;
                    receive_state <= 0;                
                    o_rx_en <= 1'b1;
                end
            end
        end
    end

    //strobes every time we should read a bit
    reg uart_clk_strobe;

    reg [DELAY_WIDTH:0] uart_clk_div_counter;
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin : proc_uart_clk_strobe
        if (!i_rst_n) begin
            //Reset nothing in this block, but needs to have a reset to
            //prevent tools from 
        end else begin
            if (edge_strobe & !receive_state) begin    
                uart_clk_div_counter <= (CLOCKS_PER_BAUD + CLOCKS_PER_BAUD/2);
                byte_counter <= 4'b1111;
            end
            uart_clk_strobe <= 0;
            if (receive_state) begin
                if (uart_clk_div_counter == 0) begin
                    uart_clk_div_counter <= CLOCKS_PER_BAUD - 1;
                    byte_counter <= byte_counter + 1;
                    uart_clk_strobe <= 1;
                end else begin
                    uart_clk_div_counter <= uart_clk_div_counter - 1;
                end
            end
        end
    end

    always_ff @(posedge i_clk) begin : proc_data_save
        if (uart_clk_strobe & has_bits) begin
            data_reg[byte_counter[2:0]] <= uart_in_sync;
        end
    end

    
endmodule
