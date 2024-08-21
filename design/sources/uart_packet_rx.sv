`default_nettype none
`timescale 1ns/1ps

module uart_packet_rx #(
        parameter CLOCK_FREQUENCY = 10_000_000,
        parameter UART_BAUD_RATE = 115200
        //Put something in here     
    ) (
        input wire i_clk,
        input wire i_uart_rx,
        input wire i_rst_n
        //Put something in here
    );


    logic [7:0] uart_rx_data;
    logic uart_rx_enable;

    uart_rx #(   
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(UART_BAUD_RATE))
    uart_rx_inst (
        .i_clk(i_clk),
        .i_uart_rx(i_uart_rx),
        .i_rst_n(i_rst_n),

        .o_rx_data(uart_rx_data),
        .o_rx_en(uart_rx_enable));


endmodule
