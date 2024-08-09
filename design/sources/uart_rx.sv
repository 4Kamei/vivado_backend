`timescale 1ns / 1ps
`default_nettype none

module uart_rx
    #(   parameter CLOCK_FREQUENCY = 10_000_00,
         parameter BAUD_RATE = 12_000,
         parameter PARITY_BIT = 0
     )(
        input wire i_uart_clk,
        input wire i_uart_in,
        input wire i_reset,

        output reg [7:0] o_data,
        output reg o_data_out_strobe
    );
    
    localparam CLOCKS_PER_BAUD = CLOCK_FREQUENCY/BAUD_RATE;

    localparam DELAY_WIDTH = $clog2(CLOCK_FREQUENCY * 3/2);

    reg receive_state = 0;
    reg [3:0] byte_counter = 0;
    reg [7:0] data_reg = 0;
    reg uart_in_sync, uart_in_sync1;
    
    always_ff @(posedge i_uart_clk) begin : proc_uart_in_sync
        uart_in_sync <= uart_in_sync1;
        uart_in_sync1 <= i_uart_in;
    end
    
    //detects 1-0 edge 
    reg past_value = 0;
    reg edge_strobe = 0;
    reg has_bits = 0;

    always_ff @(posedge i_uart_clk) begin : proc_edge_detector
        edge_strobe = {past_value, uart_in_sync} == 2'b10;
        past_value <= uart_in_sync;
    end
    
    always_ff @(posedge i_uart_clk) begin : proc_receive_state
        o_data_out_strobe <= 0;

        if (edge_strobe & !receive_state) begin
            receive_state <= 1;
            has_bits <= 1;
            uart_clk_div_counter <= (CLOCKS_PER_BAUD + CLOCKS_PER_BAUD/2);
            byte_counter <= 4'b1111;
        end
        if (receive_state & byte_counter == 4'b1000) begin
            if (has_bits) begin
                o_data <= data_reg;
                has_bits <= 0;
            end else begin
                if (uart_in_sync) begin
                    receive_state <= 0;                
                    o_data_out_strobe <= 1;
                end
            end
            byte_counter <= 4'b1000;
        end
    end
    

    //strobes every time we should read a bit
    reg uart_clk_strobe;

    reg [DELAY_WIDTH:0] uart_clk_div_counter;

    always_ff @(posedge i_uart_clk) begin : proc_uart_clk_strobe
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
    
    always_ff @(posedge i_uart_clk) begin : proc_data_save
        if (uart_clk_strobe & has_bits) begin
            data_reg[byte_counter[2:0]] <= uart_in_sync;
        end
    end

    
endmodule
