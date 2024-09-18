`default_nettype none
`timescale 1ns / 1ps

module eth_10g_pkt_receive #(
        parameter CLOCK_FREQUENCY = 200_000_000,
        parameter UART_BAUD_RATE = 115_200,
        parameter UART_FIFO_LENGTH = 256,
        parameter UART_MAX_PACKET_LENGTH = 16,
        parameter UART_DEBUG_BUS_AXIS_WIDTH = 8
    ) (
        input  wire i_sys_clk_p,
        input  wire i_sys_clk_n,

        input  wire i_rst_n,
        input  wire i_uart_rx,
        output wire o_uart_tx,

        output wire o_gtx_sfp1_tx_disable,
        input  wire i_gtx_sfp1_rx_p,
        input  wire i_gtx_sfp1_rx_n,
        
        output wire o_debug_right,
        output wire o_debug_left,
        
        output wire [3:0] o_eth_led
    );

    assign o_debug_left = 1'b0;
    assign o_debug_right = i_uart_rx;

    assign o_gtx_sfp1_tx_disable = 1'b0;

    logic i_clk;
    logic clk_78_mhz;
    logic clk_gtx;
    logic pll_locked_2;
    logic pll_locked_1;

    logic PLLE2_BASE_u_feedback_1;
    //F_OUT = F_IN * M / (D * O)
    //VCO should be in the range of (800 - 1600)
    PLLE2_BASE #(
        .CLKIN1_PERIOD(5),       // 5ns period
        .BANDWIDTH("OPTIMIZED"),
        .DIVCLK_DIVIDE(4),
        .CLKOUT0_DIVIDE(16),    //800Mhz / 128 = 6.25Mhz
        .CLKFBOUT_MULT(25)        //VCO Frequency of 200 * 4 =  800Mhz 
    )
    PLLE2_BASE_1_u (
        .CLKIN1(i_clk),
        .RST(!i_rst_n),
        .PWRDWN(1'b0),
        .CLKOUT0(clk_78_mhz),
        .LOCKED(pll_locked_1),
        .CLKFBOUT(PLLE2_BASE_u_feedback_1),
        .CLKFBIN(PLLE2_BASE_u_feedback_1)
    );
    logic PLLE2_BASE_u_feedback_2;
    //F_OUT = F_IN * M / (D * O)
    //VCO should be in the range of (800 - 1600)
    PLLE2_BASE #(
        .CLKIN1_PERIOD(12.8),       // 5ns period
        .BANDWIDTH("OPTIMIZED"),
        .DIVCLK_DIVIDE(2),
        .CLKOUT0_DIVIDE(4),    //800Mhz / 128 = 6.25Mhz
        .CLKFBOUT_MULT(33)        //VCO Frequency of 200 * 4 =  800Mhz 
    )
    PLLE2_BASE_2_u (
        .CLKIN1(clk_78_mhz),
        .RST(!i_rst_n),
        .PWRDWN(1'b0),
        .CLKOUT0(clk_gtx),
        .LOCKED(pll_locked_2),
        .CLKFBOUT(PLLE2_BASE_u_feedback_2),
        .CLKFBIN(PLLE2_BASE_u_feedback_2)
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
    clock_counter_ad_ref_u (
        .i_clk(i_clk),
        .i_clk_extern(clk_78_mhz),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_s_axis_tready),
        .i_s_axis_tdata(clock_counter_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(clock_counter_2_s_axis_tvalid),
        .i_m_axis_tready(clock_counter_2_s_axis_tready),
        .o_m_axis_tdata(clock_counter_2_s_axis_tdata),
        .o_m_axis_tlast(clock_counter_2_s_axis_tlast)
    );
    
    logic clock_counter_2_s_axis_tvalid;
    logic clock_counter_2_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] clock_counter_2_s_axis_tdata;
    logic clock_counter_2_s_axis_tlast;
    
    clock_counter_ad #(
        .AXIS_DEVICE_TYPE(8'h01),
        .AXIS_DEVICE_ID(8'h01)) 
    clock_counter_ad_rx_u (
        .i_clk(i_clk),
        .i_clk_extern(clk_gtx_out),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_2_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_2_s_axis_tready),
        .i_s_axis_tdata(clock_counter_2_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_2_s_axis_tlast),  
       
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
        
    localparam int RX_DATA_WIDTH = 64;

    logic           clk_gtx_out; 
    logic [31:0]    gtx_sfp1_rx_data;
    logic [1:0]     gtx_sfp1_rx_header;
    logic           gtx_sfp1_rx_datavalid;
    logic           gtx_sfp1_rx_headervalid;
    logic [2:0]     gtx_sfp1_rx_status;
    logic           gtx_sfp1_rx_reset_done;
    
    (*MARK_DEBUG="TRUE"*) logic [RX_DATA_WIDTH-1:0]    gtx_sfp1_rx_data_q;
    (*MARK_DEBUG="TRUE"*) logic [1:0]     gtx_sfp1_rx_header_q;
    (*MARK_DEBUG="TRUE"*) logic           gtx_sfp1_rx_datavalid_q;
    (*MARK_DEBUG="TRUE"*) logic           gtx_sfp1_rx_headervalid_q;
    (*MARK_DEBUG="TRUE"*) logic [2:0]     gtx_sfp1_rx_status_q;
    (*MARK_DEBUG="TRUE"*) logic           gtx_sfp1_rx_reset_done_q;
   
    //For debug purposes
    always_ff @(posedge clk_gtx) begin    
        gtx_sfp1_rx_data_q <= gtx_sfp1_rx_data;
        gtx_sfp1_rx_header_q <= gtx_sfp1_rx_header;
        gtx_sfp1_rx_datavalid_q <= gtx_sfp1_rx_datavalid;
        gtx_sfp1_rx_headervalid_q <= gtx_sfp1_rx_headervalid;
        gtx_sfp1_rx_status_q <= gtx_sfp1_rx_status;
        gtx_sfp1_rx_reset_done_q <= gtx_sfp1_rx_reset_done;
    end
   
    
    //FIXME refclk needs to be clocked by the external clock, which comes from the clock generator chip thing


    gt_wrapper #(
        .RX_DATA_WIDTH(RX_DATA_WIDTH))
    gtx_lane_0_u (    
        .i_refclk(/* FIXME */),
        .i_rx_usrclk(1'b0),
        .i_rx_usrclk2(1'b0),
        .o_rxout_clk(clk_gtx_out),
        //Resets
        .i_lpm_reset(!i_rst_n),
        .i_gtx_rx_reset(!i_rst_n),
        .i_gtx_tx_reset(!i_rst_n),
        //Lanes
        .i_rx_p(i_gtx_sfp1_rx_p),
        .i_rx_n(i_gtx_sfp1_rx_n),

        .i_rxslip(1'b0),
        .i_rx_polarity(1'b0),

        .o_rxdata(gtx_sfp1_rx_data),
        .o_rxdatavaild(gtx_sfp1_rx_datavalid),
        .o_rxheader(gtx_sfp1_rx_header),
        .o_rxheader_valid(gtx_sfp1_rx_headervalid),
        .o_rxstartofseq(/* Unused */),
        .o_rx_status(gtx_sfp1_rx_status),
        .o_rx_reset_done(gtx_sfp1_rx_reset_done)
    );
 
    assign o_eth_led[3] = gtx_sfp1_rx_reset_done;
    assign o_eth_led[2:0] = gtx_sfp1_rx_status;

endmodule
