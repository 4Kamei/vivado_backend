`default_nettype none
`timescale 1ns / 1ps
//synthesis translate_off
`define SIMULATION
//synthesis translate_on

module eth_10g_pkt_receive #(
        parameter CLOCK_FREQUENCY = 200_000_000,
        parameter UART_BAUD_RATE = 115_200,
        parameter UART_FIFO_LENGTH = 256,
        parameter UART_MAX_PACKET_LENGTH = 16,
        parameter UART_DEBUG_BUS_AXIS_WIDTH = 8
    ) (
`ifdef SIMULATION
        output wire o_scl,
        input  wire i_scl,
        output wire o_sda,
        input  wire i_sda,
`else   
        inout  wire b_sda,
        inout  wire b_scl,
`endif

        input  wire i_sys_clk_p,
        input  wire i_sys_clk_n,

        input  wire i_gtx_clk_p,
        input  wire i_gtx_clk_n,

        input  wire i_gtx_qsfp_clk_p,
        input  wire i_gtx_qsfp_clk_n,

        input  wire i_pcie_clk_p,
        input  wire i_pcie_clk_n,
        
        input  wire i_rst_n,

        input  wire i_key2,

        input  wire i_uart_rx,
        output wire o_uart_tx,

        output wire o_gtx_sfp1_tx_disable,
        input  wire i_gtx_sfp1_loss,
        input  wire i_gtx_sfp1_rx_p,
        input  wire i_gtx_sfp1_rx_n,
        output wire o_gtx_sfp1_tx_p,
        output wire o_gtx_sfp1_tx_n,

        output wire [3:0] o_debug,
 
        output wire [3:0] o_eth_led
    );

//We need to define a 'debug_parameters' file, which holds the addresses of
//each of the devices on the debug bus so that we can map ID -> device 
`include "axis_debug_device_ids.sv"

    assign o_debug[0] = i2c_i_sda;
    assign o_debug[1] = i2c_i_scl;
    assign o_debug[2] = clk_gtx;
    assign o_debug[3] = clk_logic;

    assign o_gtx_sfp1_tx_disable = 1'b0;

    logic clk_logic;

    IBUFGDS IBUFGDS_u (
        .I(i_sys_clk_p),
        .IB(i_sys_clk_n),
        .O(clk_logic)
    );

    logic clk_pcie;

    IBUFDS_GTE2 #(
        .CLKCM_CFG("TRUE"), // Refer to Transceiver User Guide
        .CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
        .CLKSWING_CFG(2'b11))
    IBUFDS_GTE2_pcie_u (
        .I(i_pcie_clk_p),
        .IB(i_pcie_clk_n),
        .CEB(1'b0),
        .ODIV2(/* Unconnected */),
        .O(clk_pcie)
    );

    logic clk_gtx_qsfp;
    IBUFDS_GTE2 #(
        .CLKCM_CFG("TRUE"), // Refer to Transceiver User Guide
        .CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
        .CLKSWING_CFG(2'b11))
    IBUFDS_GTE2_gtx_qsfp_u (
        .I(i_gtx_qsfp_clk_p),
        .IB(i_gtx_qsfp_clk_n),
        .CEB(1'b0),
        .ODIV2(/* Unconnected */),
        .O(clk_gtx_qsfp)
    );
    
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
        .i_clk(clk_logic),
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
        .i_clk(clk_logic),
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
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_CLK_LOGIC)) 
    clock_counter_ad_logic_u (
        .i_clk(clk_logic),
        .i_clk_extern(clk_logic),
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
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_CLK_QSFP)) 
    clock_counter_ad_gtx_qsfp_u (
        .i_clk(clk_logic),
        .i_clk_extern(clk_gtx_qsfp),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_2_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_2_s_axis_tready),
        .i_s_axis_tdata(clock_counter_2_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_2_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(clock_counter_3_s_axis_tvalid),
        .i_m_axis_tready(clock_counter_3_s_axis_tready),
        .o_m_axis_tdata(clock_counter_3_s_axis_tdata),
        .o_m_axis_tlast(clock_counter_3_s_axis_tlast)
    );
    
    logic clock_counter_3_s_axis_tvalid;
    logic clock_counter_3_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] clock_counter_3_s_axis_tdata;
    logic clock_counter_3_s_axis_tlast;
    
    clock_counter_ad #(
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_CLK_GTX_REF)) 
    clock_counter_ad_gtx_u (
        .i_clk(clk_logic),
        .i_clk_extern(clk_gtx),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_3_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_3_s_axis_tready),
        .i_s_axis_tdata(clock_counter_3_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_3_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(clock_counter_4_s_axis_tvalid),
        .i_m_axis_tready(clock_counter_4_s_axis_tready),
        .o_m_axis_tdata(clock_counter_4_s_axis_tdata),
        .o_m_axis_tlast(clock_counter_4_s_axis_tlast)
    );
    
    logic clock_counter_4_s_axis_tvalid;
    logic clock_counter_4_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] clock_counter_4_s_axis_tdata;
    logic clock_counter_4_s_axis_tlast;
    
    clock_counter_ad #(
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_CLK_GTX_TX)) 
    clock_counter_ad_gtx_tx_u (
        .i_clk(clk_logic),
        .i_clk_extern(clk_gtx_tx),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_4_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_4_s_axis_tready),
        .i_s_axis_tdata(clock_counter_4_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_4_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(clock_counter_5_s_axis_tvalid),
        .i_m_axis_tready(clock_counter_5_s_axis_tready),
        .o_m_axis_tdata(clock_counter_5_s_axis_tdata),
        .o_m_axis_tlast(clock_counter_5_s_axis_tlast)
    );
    
    logic clock_counter_5_s_axis_tvalid;
    logic clock_counter_5_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] clock_counter_5_s_axis_tdata;
    logic clock_counter_5_s_axis_tlast;
    
    clock_counter_ad #(
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_CLK_PCS_TX)) 
    clock_counter_ad_gtx_tx_pcs_u (
        .i_clk(clk_logic),
        .i_clk_extern(clk_gtx_pcs_tx),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_5_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_5_s_axis_tready),
        .i_s_axis_tdata(clock_counter_5_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_5_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(clock_counter_6_s_axis_tvalid),
        .i_m_axis_tready(clock_counter_6_s_axis_tready),
        .o_m_axis_tdata(clock_counter_6_s_axis_tdata),
        .o_m_axis_tlast(clock_counter_6_s_axis_tlast)
    );
    
    logic clock_counter_6_s_axis_tvalid;
    logic clock_counter_6_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] clock_counter_6_s_axis_tdata;
    logic clock_counter_6_s_axis_tlast;
    
    clock_counter_ad #(
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_CLK_FABRIC_TX)) 
    clock_counter_ad_gtx_tx_fabric_u (
        .i_clk(clk_logic),
        .i_clk_extern(clk_gtx_fabric_tx),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_6_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_6_s_axis_tready),
        .i_s_axis_tdata(clock_counter_6_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_6_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(clock_counter_7_s_axis_tvalid),
        .i_m_axis_tready(clock_counter_7_s_axis_tready),
        .o_m_axis_tdata(clock_counter_7_s_axis_tdata),
        .o_m_axis_tlast(clock_counter_7_s_axis_tlast)
    );
    
    logic clock_counter_7_s_axis_tvalid;
    logic clock_counter_7_s_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] clock_counter_7_s_axis_tdata;
    logic clock_counter_7_s_axis_tlast;

    clock_counter_ad #(
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_CLK_GTX_RX)) 
    clock_counter_ad_gtx_rx_u (
        .i_clk(clk_logic),
        .i_clk_extern(clk_gtx_rx),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(clock_counter_7_s_axis_tvalid),
        .o_s_axis_tready(clock_counter_7_s_axis_tready),
        .i_s_axis_tdata(clock_counter_7_s_axis_tdata),  
        .i_s_axis_tlast(clock_counter_7_s_axis_tlast),  
       
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
    
    logic i2c_o_scl;
    logic i2c_o_sda;
    logic i2c_i_scl;
    logic i2c_i_sda;
    
`ifdef SIMULATION
    assign o_scl = i2c_o_scl;
    assign o_sda = i2c_o_sda;
    always_comb i2c_i_scl = i_scl;
    always_comb i2c_i_sda = i_sda;
`endif

`ifndef SIMULATION
    IOBUF IOBUF_sda_u (
        .I(i2c_o_sda),
        .T(i2c_o_sda),
        .O(i2c_i_sda),
        .IO(b_sda)
    );
`endif

    //T I IO O
    //1 X Z  IO
    //0 1 1  1
    //0 0 0  0
`ifndef SIMULATION
    IOBUF IOBUF_scl_u (
        .I(i2c_o_scl),
        .T(i2c_o_scl),
        .O(i2c_i_scl),
        .IO(b_scl)
    );
`endif

    i2c_master_ad #(
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_I2C_TEMP),
        .CLOCK_SPEED(CLOCK_FREQUENCY),
        .I2C_SPEED_BPS(400_000))
    i2c_master_ad_u (
        .i_clk(clk_logic),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(i2c_master_s_axis_tvalid),
        .o_s_axis_tready(i2c_master_s_axis_tready),
        .i_s_axis_tdata(i2c_master_s_axis_tdata),  
        .i_s_axis_tlast(i2c_master_s_axis_tlast),  
       
        //Master debug interface
        .o_m_axis_tvalid(stream_mon_rx_0_axis_tvalid),
        .i_m_axis_tready(stream_mon_rx_0_axis_tready),
        .o_m_axis_tdata(stream_mon_rx_0_axis_tdata),
        .o_m_axis_tlast(stream_mon_rx_0_axis_tlast),

        
        .i_sda(i2c_i_sda),
        .i_scl(i2c_i_scl),

        .o_sda(i2c_o_sda),
        .o_scl(i2c_o_scl)
    );

    logic stream_mon_rx_0_axis_tvalid;
    logic stream_mon_rx_0_axis_tready;
    logic [UART_DEBUG_BUS_AXIS_WIDTH-1:0] stream_mon_rx_0_axis_tdata;
    logic stream_mon_rx_0_axis_tlast; 

    eth_stream_monitor_ad #(
        .AXIS_DEVICE_ID(AXIS_DEBUG_IDS_MON_RX_0),
        .DATAPATH_WIDTH(32))
    eth_stream_monitor_ad_rx_0_u (
        .i_clk_dbg(clk_logic),
        .i_clk_stream(clk_gtx_rx),
        .i_rst_n(i_rst_n),
        //Eth stream master
        .o_eths_master_data(/* Unconnected */),
        .o_eths_master_keep(/* Unconnected */),
        .o_eths_master_valid(/* Unconnected */),
        .o_eths_master_abort(/* Unconnected */),
        .o_eths_master_last(/* Unconnected */),

        /* Eth stream master interface */
        .i_eths_slave_data(eths_rx_out.data),
        .i_eths_slave_keep(eths_rx_out.keep),
        .i_eths_slave_valid(eths_rx_out.valid),
        .i_eths_slave_abort(eths_rx_out.abort),
        .i_eths_slave_last(eths_rx_out.last),

        //Slave debug interface 
        .i_s_axis_tvalid(stream_mon_rx_0_axis_tvalid),
        .o_s_axis_tready(stream_mon_rx_0_axis_tready),
        .i_s_axis_tdata(stream_mon_rx_0_axis_tdata),
        .i_s_axis_tlast(stream_mon_rx_0_axis_tlast),

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
        .i_clk(clk_logic),
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
        
    localparam int RX_DATA_WIDTH = 32;
    localparam int TX_DATA_WIDTH = 32;

    typedef struct {
        logic [RX_DATA_WIDTH-1:0]   data;
        logic [1:0]                 keep;
        logic                       valid;
        logic                       abort;
        logic                       last;
    } eth_stream_if_t;
    
    (* MARK_DEBUG = "TRUE" , MARK_DEBUG_CLOCK = "clk_gtx_rx" *) eth_stream_if_t eths_rx_out;

    eth_rx_interface #( .DATAPATH_WIDTH(RX_DATA_WIDTH))
    eth_rx_interface_u (
        .i_clk(clk_gtx_rx),
        .i_rst_n(i_rst_n),

        /* Eth stream interface */
        .o_eths_master_data(eths_rx_out.data),
        .o_eths_master_keep(eths_rx_out.keep),
        .o_eths_master_valid(eths_rx_out.valid),
        .o_eths_master_abort(eths_rx_out.abort),
        .o_eths_master_last(eths_rx_out.last),

        .i_data(gtx_sfp1_rx_data),
        .i_data_valid(gtx_sfp1_rx_datavalid),
        .i_header(gtx_sfp1_rx_header),
        .i_header_valid(gtx_sfp1_rx_headervalid)
    );
    
    logic           clk_gtx_rx; 
    logic           clk_gtx_tx; 
    
    (* MARK_DEBUG = "TRUE" , MARK_DEBUG_CLOCK = "clk_gtx_rx" *) logic [RX_DATA_WIDTH-1:0]    gtx_sfp1_rx_data;
    (* MARK_DEBUG = "TRUE" , MARK_DEBUG_CLOCK = "clk_gtx_rx" *) logic [1:0]     gtx_sfp1_rx_header;
    (* MARK_DEBUG = "TRUE" , MARK_DEBUG_CLOCK = "clk_gtx_rx" *) logic           gtx_sfp1_rx_datavalid;
    (* MARK_DEBUG = "TRUE" , MARK_DEBUG_CLOCK = "clk_gtx_rx" *) logic           gtx_sfp1_rx_headervalid;
    logic           gtx_sfp1_rx_startofseq;
    logic           gtx_sfp1_rx_reset_done;
    //FIXME refclk needs to be clocked by the external clock, which comes from the clock generator chip thing

    logic clk_qpll;
    logic clk_qpll_ref;
    logic qpll_lock;
    logic gtx_sfp1_tx_gearbox_ready;
    logic gtx_sfp1_tx_reset_done;

    logic gtx_sfp1_tx_startofseq;

    assign o_eth_led[3] = gtx_sfp1_rx_reset_done;
    assign o_eth_led[2] = gtx_sfp1_block_lock;

    //assign o_eth_led[2] = i_gtx_sfp1_loss;
    //assign o_eth_led[1] = gtx_sfp1_block_lock;
    //assign o_eth_led[0] = gtx_sfp1_tx_gearbox_ready;
    //assign {o_eth_led[1], o_eth_led[0]} = reset_fsm_state;

    //RESET FSM. //TODO REFACTOR
    typedef enum logic [2:0] {PLL_RESET, GTX_RESET, USR_RDY, DONE} reset_fsm_t;
    reset_fsm_t reset_fsm_state;
    
    logic reset_fsm_qpll_reset;
    logic reset_fsm_gtx_reset;
    logic reset_fsm_userrdy;
    logic reset_fsm_gtx_seqstart;

    logic tx_pcs_reset;
    logic tx_pma_reset;

    always_comb tx_pma_reset = 1'b0;
    always_comb tx_pcs_reset = 1'b0;

    always_ff @(posedge clk_logic or negedge i_rst_n) begin
        if (!i_rst_n) begin
            reset_fsm_state <= PLL_RESET;
            reset_fsm_qpll_reset <= 1'b1;
            reset_fsm_gtx_reset <= 1'b1;
            reset_fsm_userrdy <= 1'b0;
            reset_fsm_gtx_seqstart <= 1'b0;
        end else begin
            case (reset_fsm_state)
                PLL_RESET: begin
                    reset_fsm_state <= GTX_RESET;
                    reset_fsm_qpll_reset <= 1'b1;
                    reset_fsm_gtx_reset <= 1'b1;
                end
                GTX_RESET: begin
                    reset_fsm_qpll_reset <= 1'b0;
                    if (qpll_lock) begin
                        reset_fsm_state <= USR_RDY;
                        reset_fsm_gtx_reset <= 1'b0;
                    end
                end
                USR_RDY: begin
                    reset_fsm_userrdy <= 1'b1;
                    if (gtx_sfp1_rx_reset_done & gtx_sfp1_tx_reset_done) begin
                        reset_fsm_state <= DONE;
                        reset_fsm_gtx_seqstart <= 1'b1;
                    end
                end
                DONE: begin /* Do nothing */ end
                default: $error("Unreachable");
            endcase
        end
    end

    GTXE2_COMMON #(
        //Set the PLL to multiply by 66, to get 156.25 to 10.3125
        .QPLL_REFCLK_DIV(1),
        .QPLL_FBDIV_RATIO(1'b0),
        .QPLL_FBDIV(9'b0101000000),
        .BIAS_CFG                               (64'h0000040000001000),
        .COMMON_CFG                             (32'h00000000),
        .QPLL_CFG                               (27'h0680181),          //Reserved
        .QPLL_CLKOUT_CFG                        (4'b0000),              //Reserved
        .QPLL_COARSE_FREQ_OVRD                  (6'b010000),            //Reserved
        .QPLL_COARSE_FREQ_OVRD_EN               (1'b0),                 //Reserved  
        .QPLL_CP                                (10'b0000011111),       //Reserved
        .QPLL_CP_MONITOR_EN                     (1'b0),                 //Reserved
        .QPLL_DMONITOR_SEL                      (1'b0),                 //Reserved
        .QPLL_FBDIV_MONITOR_EN                  (1'b0),                 //Reserved
        .QPLL_INIT_CFG                          (24'h000006),           //Reserved
        .QPLL_LOCK_CFG                          (16'h21E8),             //Reserved
        .QPLL_LPF                               (4'b1111))              //Reserved
    GTX2E_COMMON_sfp_u (
        .GTGREFCLK(/* Unconnected*/),
        .GTNORTHREFCLK0(/* Unconnected */),
        .GTNORTHREFCLK1(/* Unconnected */),
        .GTREFCLK0(clk_gtx), 
        .GTREFCLK1(/* Unconnected */), 
        .GTSOUTHREFCLK0(/* Unconnected */), 
        .GTSOUTHREFCLK1(/* Unconnected */), 
        .QPLLOUTCLK(clk_qpll), 
        .QPLLOUTREFCLK(clk_qpll_ref), 
        .QPLLREFCLKSEL(3'b001), 
        .REFCLKOUTMONITOR(/* Unconnected */), 
        .QPLLDMONITOR(/* Unconnected */),
        .QPLLFBCLKLOST(/* Unconnected */),
        .QPLLLOCK(qpll_lock),
        .QPLLLOCKDETCLK(/* Floating */),
        .QPLLLOCKEN(1'b1),
        .QPLLOUTRESET(1'b0),
        .QPLLPD(1'b0),
        .QPLLREFCLKLOST(/* Unused */),
        .QPLLRESET(reset_fsm_qpll_reset),
        .BGBYPASSB(1'b1),
        .BGMONITORENB(1'b1),
        .BGPDB(1'b1),
        .BGRCALOVRD(5'b11111),
        .RCALENB(1'b1)
    );    

    logic clk_gtx_pcs_tx;
    logic clk_gtx_fabric_tx;

    gt_wrapper #(
        .RX_DATA_WIDTH(RX_DATA_WIDTH),
        .TX_DATA_WIDTH(TX_DATA_WIDTH))
    gtx_lane_0_u (    
        .i_qpll_clk(clk_qpll),
        .i_qpll_refclk(clk_qpll_ref),
        .o_rxout_clk(clk_gtx_rx),
        .o_txout_clk(clk_gtx_tx),
        .o_txout_pcs_clk(clk_gtx_pcs_tx),
        .o_txout_fabric_clk(clk_gtx_fabric_tx),
        //Resets
        .i_lpm_reset(1'b0),
        .i_gtx_rx_reset(reset_fsm_gtx_reset),
        .i_gtx_rx_userrdy(reset_fsm_userrdy),
        .i_gtx_tx_reset(reset_fsm_gtx_reset),
        .i_gtx_tx_userrdy(reset_fsm_userrdy),
        //Lanes
        .i_rx_p(i_gtx_sfp1_rx_p),
        .i_rx_n(i_gtx_sfp1_rx_n),
        .o_tx_p(o_gtx_sfp1_tx_p),
        .o_tx_n(o_gtx_sfp1_tx_n),

        .i_tx_pcs_reset(tx_pcs_reset),
        .i_tx_pma_reset(tx_pma_reset),

        .i_rxslip(gtx_sfp1_rxslip),
        .i_rx_polarity(1'b0),

        .o_rxdata(gtx_sfp1_rx_data_scrambled),
        .o_rxdata_valid(gtx_sfp1_rx_datavalid_scrambled),
        .o_rxheader(gtx_sfp1_rx_header_scrambled),
        .o_rxheader_valid(gtx_sfp1_rx_headervalid_scrambled),
        .o_rxstartofseq(gtx_sfp1_rx_startofseq),
        .o_rx_status(/* Unused */),
        .o_rx_reset_done(gtx_sfp1_rx_reset_done),
        
        .i_txdata(gtx_sfp1_tx_data_scrambled),
        .i_txheader(2'b10),
        .i_tx_start_seq(reset_fsm_gtx_seqstart),

        .o_tx_gearbox_ready(gtx_sfp1_tx_gearbox_ready),
        .o_tx_reset_done(gtx_sfp1_tx_reset_done)
    );
   
    logic gtx_sfp1_tx_gearbox_ready_qq;

    always_ff @(posedge clk_gtx_tx) begin
        gtx_sfp1_tx_gearbox_ready_qq <= gtx_sfp1_tx_gearbox_ready;
    end
    
    eth_scrambler #(
        .DATA_WIDTH(TX_DATA_WIDTH))
    eth_scrambler_u (
        .i_clk(clk_gtx_tx),
        .i_rst_n(i_rst_n),
        .i_scrambler_bypass(1'b0),

        .i_ready((gtx_sfp1_tx_gearbox_ready | gtx_sfp1_tx_gearbox_ready_qq) & reset_fsm_gtx_seqstart),
        .o_ready(scrambler_ready),
        .i_valid(1'b1),
        .o_valid(/* Unused */),

        .i_data(scrambler_in_data),
        .o_data(gtx_sfp1_tx_data_scrambled)
    );
    
    

    assign o_eth_led[1] = 1'b0;
    assign o_eth_led[0] = 1'b0;
    
    logic [TX_DATA_WIDTH-1:0] gtx_sfp1_tx_data_scrambled;
    logic [TX_DATA_WIDTH-1:0] scrambler_in_data;
    
    //always_comb scrambler_in_data = scrambler_data_toggle ? 32'h1e000000 : 32'h00000000;

    logic scrambler_data_toggle;
    logic scrambler_ready;

    always_ff @(posedge clk_gtx_tx or negedge i_rst_n) begin
        if (!i_rst_n) begin
            scrambler_in_data <= 32'h0;
            scrambler_data_toggle <= 1'b0; 
        end else begin
            if (scrambler_ready) begin
                scrambler_data_toggle <= ~scrambler_data_toggle;
                if (scrambler_data_toggle) begin
                    scrambler_in_data <= 32'h00000000;
                end else begin              //10 _ 00011110 _ 00000000 _ ...   
                    scrambler_in_data <= 32'h78000000;
                end
            end
        end
    end
    
    logic [2:0]               gtx_sfp1_tx_header;
    logic [TX_DATA_WIDTH-1:0] gtx_sfp1_tx_data;
    
    
    logic [RX_DATA_WIDTH-1:0]    gtx_sfp1_rx_data_scrambled;
    logic [1:0]     gtx_sfp1_rx_header_scrambled;
    logic           gtx_sfp1_rx_datavalid_scrambled;
    logic           gtx_sfp1_rx_headervalid_scrambled;
  
    eth_descrambler #(.DATA_WIDTH(TX_DATA_WIDTH))
    eth_descrambler_u (
        .i_clk(clk_gtx_rx),
        .i_rst_n(i_rst_n),
        .i_descrambler_bypass(1'b0),
        .i_data(gtx_sfp1_rx_data_scrambled),
        .i_valid(gtx_sfp1_rx_datavalid_scrambled),
        .i_ready(1'b1),
        .o_ready(/* Unconnected */),
        .o_data(gtx_sfp1_rx_data),
        .o_valid(gtx_sfp1_rx_datavalid),
        //Header passthrough
        .i_header(gtx_sfp1_rx_header_scrambled),
        .o_header(gtx_sfp1_rx_header),
        .i_headervalid(gtx_sfp1_rx_headervalid_scrambled),
        .o_headervalid(gtx_sfp1_rx_headervalid)
    );

    logic gtx_sfp1_block_lock;
    logic gtx_sfp1_rxslip;

    eth_block_alignment eth_block_lock_sfp1_u (
        .i_clk(clk_gtx_rx),
        .i_header(gtx_sfp1_rx_header_scrambled),
        .i_header_valid(gtx_sfp1_rx_headervalid_scrambled),
        .i_rst_n(i_rst_n),
        .o_block_lock(gtx_sfp1_block_lock),
        .o_rxslip(gtx_sfp1_rxslip)
    );

    

endmodule
