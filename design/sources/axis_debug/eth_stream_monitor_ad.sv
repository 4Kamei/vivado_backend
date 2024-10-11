
`default_nettype none
`timescale 1ns / 1ps

module eth_stream_monitor_ad #(
        parameter int DATAPATH_WIDTH = 32,
        parameter logic [7:0] AXIS_DEVICE_ID = 0
    ) (
       
        input  wire                                 i_clk_dbg,
        input  wire                                 i_clk_stream,
        input  wire                                 i_rst_n, 

        /* Eth stream master interface */
        output wire [DATAPATH_WIDTH-1:0]            o_eths_master_data,
        output wire [$clog2(DATAPATH_WIDTH/8)-1:0]  o_eths_master_keep,
        output wire                                 o_eths_master_valid, 
        output wire                                 o_eths_master_abort,
        output wire                                 o_eths_master_last,

        /* Eth stream master interface */
        input  wire [DATAPATH_WIDTH-1:0]            i_eths_slave_data,
        input  wire [$clog2(DATAPATH_WIDTH/8)-1:0]  i_eths_slave_keep,
        input  wire                                 i_eths_slave_valid, 
        input  wire                                 i_eths_slave_abort,
        input  wire                                 i_eths_slave_last,

        //Slave debug interface
        input  wire                                 i_s_axis_tvalid,
        output wire                                 o_s_axis_tready,
        input  wire  [7:0]                          i_s_axis_tdata,
        input  wire                                 i_s_axis_tlast,
       
        //Master debug interface
        output wire                                 o_m_axis_tvalid,
        input  wire                                 i_m_axis_tready,
        output wire  [7:0]                          o_m_axis_tdata,
        output wire                                 o_m_axis_tlast
    );
`include "axis_debug_device_types.sv"
    localparam AXIS_DEVICE_TYPE = ETH_STREAM_MONITOR_DEVICE_TYPE;

    localparam ADDR_WIDTH_BYTES = 2;
    localparam DATA_WIDTH_BYTES = 5;
     
    axis_debug_decoder #(
        .AXIS_DEVICE_TYPE(AXIS_DEVICE_TYPE),
        .AXIS_DEVICE_ID(AXIS_DEVICE_ID),
        .ADDR_WIDTH_BYTES(ADDR_WIDTH_BYTES),
        .DATA_WIDTH_BYTES(DATA_WIDTH_BYTES)) 
    axis_debug_decoder_u (
        .i_clk(i_clk_dbg),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(i_s_axis_tvalid),
        .o_s_axis_tready(o_s_axis_tready),
        .i_s_axis_tdata(i_s_axis_tdata),
        .i_s_axis_tlast(i_s_axis_tlast),
       
        //Master debug interface
        .o_m_axis_tvalid(o_m_axis_tvalid),
        .i_m_axis_tready(i_m_axis_tready),
        .o_m_axis_tdata(o_m_axis_tdata),
        .o_m_axis_tlast(o_m_axis_tlast),
    
        //Interf Operator CASE expects 24 bits on the Case Itemace to module
        //Set address, set 'read_request' or 'write_request' high
        //wait for i_output_valid -> set 'read_request' and 'write_request'
        //low (or change address and read again)
        .o_rw_address(rw_address),
        .i_read_data(read_data),
        .o_write_data(write_data),

        .o_read_request(read_request),
        .o_write_request(write_request),
        .i_output_valid(output_valid_q));
    
    typedef logic [DATA_WIDTH_BYTES*8-1:0] data_t;
    typedef logic [ADDR_WIDTH_BYTES*8-1:0] addr_t;

    addr_t      rw_address;
    data_t      read_data;
    data_t      write_data;

    logic           read_request;
    logic           write_request;
    logic           output_valid_q;

    struct packed {
        logic [2:0]     padding;
        logic           abort;
        logic           valid;
        logic           last;
        logic [1:0]     keep;
        logic [31:0]    data;
    } eth_stream_packet;

    //Need to use a BRAM for this, but can't store the entire
    //eth_stream_packet struct in that bram -> 
    //can store 4 extra bits along with data, but have:
    //      keep    2
    //      valid   1
    //      abort   1
    //      last    1   ==  5       Maybe remove 'last', as it's going to be
    //                              implied by the packet length?
    //
    //
    //      Each BRAM can store 36k => 1024 entries
    //                              => Need to use 2 brams to be able to store
    //                              a max-length packet.
    //



    typedef logic [9:0] memory_read_addr_t;
    typedef enum logic          {MEM_IDLE, MEM_DONE} memory_read_state_t;
    memory_read_state_t memory_read_state;
    

    memory_read_addr_t memory_read_addr;
    logic   memory_read_en;

    typedef struct packed {
        logic [31:0]    data;
        logic [1:0]     keep;
        logic           abort;
        logic           valid;
    } memory_row_t;
    
    memory_row_t memory_read_data;
    
    logic [9:0] memory [35:0];

    always_ff @(posedge i_clk_dbg or negedge i_rst_n) begin : memory_read_fsm_b
        if (!i_rst_n) begin
            memory_read_state <= MEM_IDLE;
        end else begin
            case (memory_read_state)
                MEM_IDLE: begin : memory_read_idle_case
                
                end
                MEM_DONE: begin : memory_read_done_case
                
                end
            endcase
        end
    end
    
    //0000 0011   READ RESPONSE       [0x01, TYPE, DEV_TYPE, DEV_ID, READ_DATAM, ..., READ_DATA0]
    
    //Format for the read payload is this:  
    //  |   byte 0  |   byte 1  |   byte 2  |    ...    |   byte 5  |   byte  6  |
    //  [   sequence counter   ][       32 bits stream data        ][    info    ]
    //
    //  where `info` is formatted as
    //
    //  |       7       6       5       4       3       2       1       0
    //  [         unused       ][ abort][ valid][  last ][      keep    ]
    //
    //Internal register map:
    //
    //  0:          total packet counter
    //  1:          trigger active                  
    //      ->  writes back
    //          with length of captured packet
    //  2:          local packet counter            //TODO
    //  3:          local packet counter reset?     //TODO
    //
    //  //Packet filters?
    //  0x8000 reserved for reading the saved packet
    //  0xffff

    

    typedef enum logic [1:0]    {PKT_IDLE, PKT_CAPTURING, PKT_DONE} pkt_capture_state_t;
    data_t pkt_capture_length;
    pkt_capture_state_t pkt_capture_state;

    always_ff @(posedge i_clk_dbg or negedge i_rst_n) begin : pkt_capture_fsm_b
        if (!i_rst_n) begin
            pkt_capture_state <= PKT_IDLE;
        end else begin
            case (pkt_capture_state)
                PKT_IDLE: begin : pkt_capture_idle_case
                    if (write_request && rw_address == 16'd1 && write_data == 40'b1) begin
                        pkt_capture_state <= PKT_CAPTURING;
                        pkt_capture_length <= 0;
                    end
                end
                PKT_CAPTURING: begin : pkt_capture_capturing_case
                     
                end
                PKT_DONE: begin : pkt_capture_done_case

                end
                default: $error("Unreachable");
            endcase
        end
    end

    always_ff @(posedge i_clk_dbg or negedge i_rst_n) begin : axis_debug_reply_b
        if (!i_rst_n) begin
            output_valid_q <= 1'b0;
        end else begin
            if (read_request) begin
                case (rw_address) inside
                    addr_t'(0) : begin : total_packet_counter_case
                        output_valid_q <= 1'b1;
                        read_data <= total_packet_counter;
                    end
                    addr_t'(1) : begin : trigger_active_case    
                        //Always reads as '0', as when written '1', we block
                        //by sending write reply only when we capture a packet
                        output_valid_q <= 1'b1;
                        read_data <= 0;
                    end
                    16'b1???????????????: begin : read_saved_packet_case
                        //Need to send a memory read request, wait for the
                        //memory to come back,  
                        memory_read_addr <= rw_address[9:0];
                        if (memory_read_state == MEM_IDLE) begin
                            memory_read_en <= 1'b1;
                        end else begin
                            memory_read_en <= 1'b0;
                        end
                        if (memory_read_state == MEM_DONE) begin
                            output_valid_q <= 1'b1;
                            read_data <= {4'h0, memory_read_data};
                        end
                    end
                    default: begin : output_default_value
                        output_valid_q <= 1'b1;
                        read_data <= 0;
                    end
                endcase
            end
            if (write_request) begin
                case (rw_address)
                    addr_t'(1) : begin : write_trigger_active_case
                        //This condition is also checked inside of the other
                        //always_ff, we only detect the end condition here
                        if (pkt_capture_state == PKT_DONE) begin
                            output_valid_q <= 1'b1;
                            read_data <= {pkt_capture_length};
                        end
                    end
                    default: begin : rw_address_invalid_case
                        read_data <= 0;
                        output_valid_q <= 1'b1;
                    end
                endcase
            end
            if (output_valid_q) begin
                output_valid_q <= 1'b0;
            end
        end
    end

    //Total packet counter
    data_t  total_packet_counter;

    always_ff @(posedge i_clk_stream or negedge i_rst_n) begin : total_packet_counter_b
        if (!i_rst_n) begin
            total_packet_counter <= 0;
        end else begin
            if (total_packet_counter != {(DATA_WIDTH_BYTES * 8){1'b1}}) begin
                if (eths_slave_valid && eths_slave_last) begin
                    total_packet_counter <= total_packet_counter + 1'b1;
                end
            end
        end
    end
    
    //Passthrough for the eth stream
    logic       [DATAPATH_WIDTH-1:0]            eths_slave_data;
    logic       [$clog2(DATAPATH_WIDTH/8)-1:0]  eths_slave_keep;
    logic                                       eths_slave_valid;
    logic                                       eths_slave_abort;
    logic                                       eths_slave_last;
    
    assign o_eths_master_data = eths_slave_data;
    assign o_eths_master_keep = eths_slave_keep;
    assign o_eths_master_valid = eths_slave_valid; 
    assign o_eths_master_abort = eths_slave_abort;
    assign o_eths_master_last = eths_slave_last;
    
    always_ff @(posedge i_clk_stream or negedge i_rst_n) begin : eth_stream_passthrough_b
        if (!i_rst_n) begin
            eths_slave_valid <= 1'b0;
            eths_slave_last <= 1'b0;
            eths_slave_abort <= 1'b0;
        end else begin     
            eths_slave_data     <= i_eths_slave_data;
            eths_slave_keep     <= i_eths_slave_keep;
            eths_slave_valid    <= i_eths_slave_valid;
            eths_slave_abort    <= i_eths_slave_abort;
            eths_slave_last     <= i_eths_slave_last;
        end
    end

endmodule
