`default_nettype none
`timescale 1ns/1ps

//Loopback uart on the FPGA as a basic test of both modules in hardware
module uart_fpga_loopback(
        input wire i_sys_clk_p,
        input wire i_sys_clk_n,

        input wire i_rst_n,
        input wire i_uart_rx,

        output wire o_uart_tx,

        output reg [3:0] o_eth_led 
    );   

    (* keep= "true", mark_debug = "true" *) logic o_uart_tx_dbg;
    
    assign o_uart_tx = o_uart_tx_dbg;

    localparam CLOCK_FREQUENCY = 200_000_000;
    localparam UART_BAUD_RATE = 115200;
    //Differential buffer for sysclk
    logic i_sys_clk;
    IBUFGDS u_sys_clk_buf (
        .I(i_sys_clk_p),
        .IB(i_sys_clk_n),
        .O(i_sys_clk));

    logic [7:0] uart_rx_data;
    logic uart_rx_en;
    
    uart_rx #(   
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(UART_BAUD_RATE),
        .PARITY_BIT(0))
    uart_rx_inst_u (
        .i_clk(i_sys_clk),
        .i_uart_rx(i_uart_rx),
        .i_rst_n(i_rst_n),
        .o_rx_data(uart_rx_data),
        .o_rx_en(uart_rx_en));

    uart_tx #(
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(UART_BAUD_RATE)) 
    uart_tx_inst_u (
        .i_clk(i_sys_clk),
        .i_rst_n(i_rst_n),
        .i_tx_en(uart_rx_en),
        .i_tx_data(uart_rx_data),
        .o_uart_tx(o_uart_tx_dbg),
        .o_uart_busy(/* Unconnected */)    );    

    always @(posedge i_sys_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_eth_led <= 4'h0000; 
        end else begin
            o_eth_led <= uart_rx_data[3:0];
        end
    end

endmodule
