`default_nettype none
`timescale 1ns / 1ps

module clock_counter_test #(
        parameter CLOCK_FREQUENCY = 200_000_000,
        parameter UART_BAUD_RATE = 115_200,
        parameter UART_FIFO_LENGTH = 256,
        parameter UART_MAX_PACKET_LENGTH = 16,
        parameter UART_DEBUG_BUS_AXIS_WIDTH = 8
    ) (
        input wire i_sys_clk_p,
        input wire i_sys_clk_n,

        input wire i_rst_n,
        input wire i_uart_rx,
        output wire o_uart_tx,

        output wire o_debug_right,
        output wire o_debug_left,
        
        output wire [3:0] o_eth_led
    );

    assign o_debug_left = clk_extern;
    assign o_debug_right = i_uart_rx;

    logic i_clk;
    logic clk_extern;
    logic pll_locked;
    
    assign o_eth_led[3] = !i_rst_n;
    assign o_eth_led[2] = 1'b1;
    assign o_eth_led[1] = 1'b0;
    assign o_eth_led[0] = !pll_locked;

    logic PLLE2_BASE_u_feedback;
    //F_OUT = F_IN * M / (D * O)
    //VCO should be in the range of (800 - 1600)
    PLLE2_BASE #(
        .CLKIN1_PERIOD(5),       // 5ns period
        .BANDWIDTH("OPTIMIZED"),
        .CLKOUT0_DIVIDE(12),    //800Mhz / 128 = 6.25Mhz
        .CLKFBOUT_MULT(4)        //VCO Frequency of 200 * 4 =  800Mhz 
    )
    PLLE2_BASE_u (
        .CLKIN1(i_clk),
        .RST(!i_rst_n),
        .PWRDWN(1'b0),
        .CLKOUT0(clk_extern),
        .LOCKED(pll_locked),
        .CLKFBOUT(PLLE2_BASE_u_feedback),
        .CLKFBIN(PLLE2_BASE_u_feedback)
    );

    IBUFGDS IBUFGDS_u (
        .I(i_sys_clk_p),
        .IB(i_sys_clk_n),
        .O(i_clk));

    uart_packet_rx #(
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .UART_BAUD_RATE(UART_BAUD_RATE),
        .MAX_PACKET_LENGTH_BYTES(UART_MAX_PACKET_LENGTH)) 
    uart_packet_rx_u (
        .i_clk(i_clk),
        .i_uart_rx(i_uart_rx),
        .i_rst_n(i_rst_n),

        .o_m_axis_tvalid(uart_rx_m_axis_tvalid),
        .i_m_axis_tready(uart_rx_m_axis_tready),
        .o_m_axis_tdata(uart_rx_m_axis_tdata),
        .o_m_axis_tlast(uart_rx_m_axis_tlast),
        .o_m_axis_tstrb(/* Unconnected */),
        .o_m_axis_tkeep(/* Unconnected */),
        .o_m_axis_tid(/* Unconnected */),
        .o_m_axis_tdest(/* Unconnected */),
        .o_m_axis_tuser(/* Unconnected */)
    );
     
    logic uart_rx_m_axis_tvalid;
    logic uart_rx_m_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] uart_rx_m_axis_tdata;
    logic uart_rx_m_axis_tlast;
   
    axis_sync_fifo #(
        .AXIS_TDATA_WIDTH(UART_DEBUG_BUS_AXIS_WIDTH),
        .AXIS_FIFO_DEPTH(UART_FIFO_LENGTH)
    )
    axis_sync_fifo_u (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),

        //Slave interface, into the fifo
        .i_s_axis_tvalid(uart_rx_m_axis_tvalid),
        .o_s_axis_tready(uart_rx_m_axis_tready),
        .i_s_axis_tdata(uart_rx_m_axis_tdata),
        .i_s_axis_tlast(uart_rx_m_axis_tlast),
        .i_s_axis_tkeep(1'b1),
        .i_s_axis_tstrb(1'b0),
        .i_s_axis_tid(1'b0),
        .i_s_axis_tdest(1'b0),
        .i_s_axis_tuser(1'b0),

        //Master interface, out of the fifo
        .o_m_axis_tvalid(clock_counter_s_axis_tvalid),
        .i_m_axis_tready(clock_counter_s_axis_tready),
        .o_m_axis_tdata(clock_counter_s_axis_tdata),
        .o_m_axis_tlast(clock_counter_s_axis_tlast),
        .o_m_axis_tstrb(/* Unconnected */),
        .o_m_axis_tkeep(/* Unconnected */),
        .o_m_axis_tid(/* Unconnected */),
        .o_m_axis_tdest(/* Unconnected */),
        .o_m_axis_tuser(/* Unconnected */)
    ); 
    
    logic clock_counter_s_axis_tvalid;
    logic clock_counter_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] clock_counter_s_axis_tdata;
    logic clock_counter_s_axis_tlast;

    clock_counter_ad #(
        .AXIS_DEVICE_TYPE(8'h01),
        .AXIS_DEVICE_ID(8'h00)) 
    clock_counter_ad_u (
        .i_clk(i_clk),
        .i_clk_extern(clk_extern),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_s_axis_tready),
        .i_s_axis_tdata(clock_counter_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(uart_tx_s_axis_tvalid),
        .i_m_axis_tready(uart_tx_s_axis_tready),
        .o_m_axis_tdata(uart_tx_s_axis_tdata),
        .o_m_axis_tlast(uart_tx_s_axis_tlast)
    );

    logic uart_tx_s_axis_tvalid;
    logic uart_tx_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] uart_tx_s_axis_tdata;
    logic uart_tx_s_axis_tlast;
    
    
    uart_packet_tx #(
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(UART_BAUD_RATE),
        .MAXIMUM_PACKET_LEN(UART_MAX_PACKET_LENGTH),
        .AXIS_TDATA_WIDTH(UART_DEBUG_BUS_AXIS_WIDTH)) 
    uart_packet_tx_u (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .o_uart_tx(o_uart_tx),
        //Axis interface
        .i_s_axis_tvalid(uart_tx_s_axis_tvalid),
        .o_s_axis_tready(uart_tx_s_axis_tready),
        .i_s_axis_tdata(uart_tx_s_axis_tdata),  
        .i_s_axis_tlast(uart_tx_s_axis_tlast),  
        .i_s_axis_tkeep(1'b1),
        .i_s_axis_tstrb(1'b0),  //Ignored
        .i_s_axis_tid(1'b0),    //Ignored
        .i_s_axis_tdest(1'b0),  //Ignored
        .i_s_axis_tuser(1'b0)   //Ignored
    );

    
endmodule
