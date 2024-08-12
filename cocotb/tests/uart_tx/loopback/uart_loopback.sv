`timescale 1ns/1ps
`default_nettype none

module uart_loopback #(
        parameter CLOCK_FREQUENCY = 12_000_000,
        parameter BAUD_RATE = 115200
    ) (
        //Transmit side connections
        input logic i_clk,
        input logic i_rst_n,
        input logic i_tx_en,
        input logic [7:0] i_tx_data,
        output logic o_uart_busy,
    
        //Receive side connections
        output logic [7:0] o_rx_data,
        output logic o_rx_en
    );

    logic o_uart_tx;

    uart_tx #(
            .CLOCK_FREQUENCY(CLOCK_FREQUENCY), 
            .BAUD_RATE(BAUD_RATE))
    uart_tx_inst (
            .i_clk(i_clk), 
            .i_rst_n(i_rst_n),
            .i_tx_en(i_tx_en), 
            .i_tx_data(i_tx_data), 
            .o_uart_tx(o_uart_tx),
            .o_uart_busy(o_uart_busy));

    logic i_uart_rx;
    //Loopback the tx into the rx
    always_comb i_uart_rx = o_uart_tx;

    uart_rx #(
            .CLOCK_FREQUENCY(CLOCK_FREQUENCY), 
            .BAUD_RATE(BAUD_RATE))
    uart_rx_inst (
            .i_clk(i_clk), 
            .i_rst_n(i_rst_n), 
            .i_uart_rx(i_uart_rx), 
            .o_rx_data(o_rx_data), 
            .o_rx_en(o_rx_en));


endmodule
