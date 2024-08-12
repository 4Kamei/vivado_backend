`timescale 1ns/1ps

`default_nettype none

module uart_tx #(
        parameter CLOCK_FREQUENCY = 12_000_000,
        parameter BAUD_RATE = 115200
    ) (
        input wire i_clk,
        input wire i_rst_n,
        
        input wire i_tx_en,
        input wire [7:0] i_tx_data,

        output wire o_uart_tx,
        output wire o_uart_busy
    );

    //TODO can rewrite without the weird indexing into an array, but with
    //a bit-shift instead.... still need the counter though, but it probably
    //simplifies the decoding logic a bit

    localparam CLOCKS_PER_BAUD_ = CLOCK_FREQUENCY/BAUD_RATE;
    localparam UART_TX_CLK_COUNTER_SIZE = $clog2(CLOCKS_PER_BAUD_);
    //TODO can probably take a bit off this counter?
    //but on the other hand, what really is a single bit between friends
    localparam CLOCKS_PER_BAUD  = CLOCKS_PER_BAUD_[UART_TX_CLK_COUNTER_SIZE:0]; 

    localparam NUM_STOP_BIT = 3;
    localparam DATA_LEN = 8;

    localparam TRANSMIT_PATTERN_LEN = NUM_STOP_BIT + DATA_LEN + 1;

    logic [11:0] transmit_pattern;
    always_comb transmit_pattern = {{NUM_STOP_BIT{1'b1}}, {i_tx_data}, 1'b0};
    logic [11:0] transmit_pattern_q;
    logic transmitting;


    //Transmit state and setup
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            //If reset, we reset the 'output_pattern_index' to 0, which
            //indexes into the msb of this -> Idle UART state is 1 hence leave
            //the reset value
            transmit_pattern_q <= {1'b1, {DATA_LEN{1'b0}}, {NUM_STOP_BIT{1'b1}}};
            transmitting <= 1'b0;
        end else begin
            if (i_tx_en && !transmitting) begin
                transmit_pattern_q <= transmit_pattern;
                transmitting <= 1'b1;
            end
            if (output_pattern_index == TRANSMIT_PATTERN_LEN - 1 && uart_tx_clk_enable) begin
                transmitting <= 1'b0;
            end
        end
    end
    
    logic [3:0] output_pattern_index;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || !transmitting) begin
           output_pattern_index <= 4'b0000;
        end else begin
            if (transmitting && uart_tx_clk_enable && output_pattern_index < TRANSMIT_PATTERN_LEN - 1) begin
                output_pattern_index <= output_pattern_index + 1'b1;
            end
        end
    end

    logic [UART_TX_CLK_COUNTER_SIZE:0] uart_tx_clk_enable_counter;
    logic uart_tx_clk_enable;
    //Generate the 'uart clk' that's responsible for
    always @(posedge i_clk) begin
        uart_tx_clk_enable <= 0;
        if (transmitting) begin
            //TODO count down 'CLOCKS PER BAUD'
            if (uart_tx_clk_enable_counter == CLOCKS_PER_BAUD) begin
                uart_tx_clk_enable_counter <= 0;
                uart_tx_clk_enable <= 1;
            end else begin
                uart_tx_clk_enable_counter <= uart_tx_clk_enable_counter + 1'b1;
            end
        end else begin      
            uart_tx_clk_enable_counter <= 0;
        end
    end
    
    assign o_uart_tx = transmit_pattern_q[output_pattern_index];
    assign o_uart_busy = transmitting;

endmodule // uart_tx
