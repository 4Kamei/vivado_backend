`default_nettype none
`timescale 1ns / 1ps

module eth_10g_pkt_receive #(
        parameter CLOCK_FREQUENCY = 200_000_000,
        parameter UART_BAUD_RATE = 115_200,
        parameter UART_FIFO_LENGTH = 256,
        parameter UART_MAX_PACKET_LENGTH = 16,
        parameter UART_DEBUG_BUS_AXIS_WIDTH = 8
    ) (
        inout  wire b_sdl,
        inout  wire b_scl,

        input  wire i_sys_clk_p,
        input  wire i_sys_clk_n,

        input  wire i_gtx_clk_p,
        input  wire i_gtx_clk_n,

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

    assign o_debug_left = i2c_i_scl;
    assign o_debug_right = i2c_i_sda;

    assign o_gtx_sfp1_tx_disable = 1'b0;

    IBUFGDS IBUFGDS_u (
        .I(i_sys_clk_p),
        .IB(i_sys_clk_n),
        .O(i_clk));

    logic clk_gtx;

    IBUFDS_GTE2 #(
        .CLKCM_CFG("TRUE"), // Refer to Transceiver User Guide
        .CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
        .CLKSWING_CFG(2'b11))
    IBUFDS_GTE2_u (
        .I(i_gtx_clk_p),
        .IB(i_gtx_clk_n),
        .CEB(1'b0),
        .ODIV2(/* Unconnected */),
        .O(clk_gtx)
    );

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
        .i_clk_extern(clk_gtx),
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
        .o_m_axis_tvalid(i2c_master_s_axis_tvalid),
        .i_m_axis_tready(i2c_master_s_axis_tready),
        .o_m_axis_tdata(i2c_master_s_axis_tdata),
        .o_m_axis_tlast(i2c_master_s_axis_tlast)
    );
    
    logic i2c_master_s_axis_tvalid;
    logic i2c_master_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] i2c_master_s_axis_tdata;
    logic i2c_master_s_axis_tlast;
//  OBUFT OBUFT_u
//  (
//      .I(1'b0),
//      .T(~o_sda),  //T is active-low
//      .O(i_sda)
//      .IO(PAD)
//  );

    IOBUF IOBUF_sda_u (
        I(1'b0),
        IO(~i2c_o_sda),
        O(i2c_i_sda),
        T(b_sda)
    );
    
    IOBUF IOBUF_scl_u (
        I(1'b0),
        IO(~i2c_o_scl),
        O(i2c_i_scl),
        T(b_scl)
    );

    i2c_master_ad #(
        .AXIS_DEVICE_TYPE(8'h02),
        .AXIS_DEVICE_ID(8'h01),
        .CLOCK_FREQUENCY(200_000_000),
        .I2C_SPEED_BPS(400_000))
    i2c_master_ad_u (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(i2c_master_s_axis_tvalid),
        .o_s_axis_tready(i2c_master_s_axis_tready),
        .i_s_axis_tdata(i2c_master_s_axis_tdata),  
        .i_s_axis_tlast(i2c_master_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(uart_tx_s_axis_tvalid),
        .i_m_axis_tready(uart_tx_s_axis_tready),
        .o_m_axis_tdata(uart_tx_s_axis_tdata),
        .o_m_axis_tlast(uart_tx_s_axis_tlast),

        
        .i_sda(i2c_i_sda),
        .i_scl(i2c_i_scl),

        .o_sda(i2c_o_sda),
        .o_scl(i2c_o_scl)
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
        .i_refclk(clk_gtx),
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
