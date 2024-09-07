`default_nettype none
`timescale 1ns / 1ps

module axis_debug_decoder #(
        parameter logic [7:0] AXIS_DEVICE_TYPE      = 8'h00,
        parameter logic [7:0] AXIS_DEVICE_ID        = 8'h00,
        parameter int         ADDRESS_WIDTH         = 8,
        parameter int         RW_DATA_WIDTH         = 8
    ) (
        input wire                                  i_clk,
        input wire                                  i_rst_n,

        //Slave debug interface
        input  wire                                 i_s_axis_tvalid,
        output wire                                 o_s_axis_tready,
        input  wire  [7:0]                          i_s_axis_tdata,
        input  wire                                 i_s_axis_tlast,
       
        //Master debug interface
        output wire                                 o_m_axis_tvalid,
        input  wire                                 i_m_axis_tready,
        output wire  [7:0]                          o_m_axis_tdata,
        output wire                                 o_m_axis_tlast,
    
        //Interface to module
        //Set address, set 'read_request' or 'write_request' high
        //wait for i_output_valid -> set 'read_request' and 'write_request'
        //low (or change address and read again)
        output wire  [ADDRESS_WIDTH-1:0]            o_rw_address,
        input  wire  [RW_DATA_WIDTH-1:0]            i_read_data,
        output wire  [RW_DATA_WIDTH-1:0]            o_write_data,

        output wire                                 o_read_request,
        output wire                                 o_write_request,
        input  wire                                 i_output_valid
    );

    typedef enum logic [2:0] {
        PACKET_TYPE        = 0,
        RW_DEVICE_TYPE     = 1,
        RW_DEVICE_ID       = 2,
        RW_ADDRESS         = 3,
        R_RESPONSE         = 4,
        W_DATA             = 5,
        RESPONSE_START     = 6,
        RESPONDING         = 7
    } pkt_parser_state_t;
    
    typedef enum logic [1:0] {
        IDENTIFY,
        READ,
        WRITE
    } pkt_type_t;

    pkt_parser_state_t pkt_parser_state;
    pkt_type_t         pkt_type;

    logic [ADDRESS_WIDTH-1:0]            rw_address_q;
    logic [RW_DATA_WIDTH-1:0]            rw_data_q;
    logic                                read_request_q;
    logic                                write_request_q;
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            pkt_parser_state <= PACKET_TYPE;
            internal_packet_valid <= 1'b0;
        end else begin
            case (pkt_parser_state)
                PACKET_TYPE: begin
                    if(start_packet_parser && i_s_axis_tvalid && o_s_axis_tready) begin
                        case (i_s_axis_tdata)
                            8'h00: begin    //IDENITFY
                                pkt_parser_state <= RESPONSE_START; 
                                pkt_type <= IDENTIFY;
                            end
                          //8'h01:          //IDENTIFY RESPONSE
                            8'h02: begin    //READ
                                pkt_parser_state <= RW_DEVICE_TYPE;
                                pkt_type <= READ;
                            end
                          //8'h03:          //READ RESPONSE 
                            8'h04: begin    //WRITE
                                pkt_parser_state <= RW_DEVICE_TYPE;
                                pkt_type <= WRITE;    
                            end
                          //8'h04:          //WRITE RESPONSE 
                            default: begin
                                //We abort parsing the packet if the type is
                                //not something we can serve
                                pkt_parser_state <= PACKET_TYPE;
                            end
                        endcase
                    end
                end
                RW_DEVICE_TYPE: begin
                    if(i_s_axis_tvalid && o_s_axis_tready) begin
                        if (i_s_axis_tdata == AXIS_DEVICE_TYPE) begin
                            pkt_parser_state <= RW_DEVICE_ID;
                        end else begin
                            pkt_parser_state <= PACKET_TYPE;
                        end
                    end
                end
                RW_DEVICE_ID: begin
                    if(i_s_axis_tvalid && o_s_axis_tready) begin
                        if (i_s_axis_tdata == AXIS_DEVICE_ID) begin
                            pkt_parser_state <= RW_ADDRESS;
                        end else begin
                            pkt_parser_state <= PACKET_TYPE;
                        end
                    end
                end
                RW_ADDRESS: begin
                    if(i_s_axis_tvalid && o_s_axis_tready) begin
                        rw_address_q <= i_s_axis_tdata;
                        case (pkt_type)
                            READ: begin
                                read_request_q <= 1'b1;
                                pkt_parser_state <= R_RESPONSE;
                            end
                            WRITE: begin
                                pkt_parser_state <= W_DATA;
                            end
                            default: $error("Unreachable");
                        endcase
                    end
                end
                R_RESPONSE: begin
                    if(i_output_valid) begin
                        rw_data_q <= i_read_data;
                        read_request_q <= 1'b0;
                        pkt_parser_state <= RESPONSE_START;  
                    end
                end
                W_DATA: begin
                    if(i_s_axis_tvalid && o_s_axis_tready && !write_request_q) begin
                        rw_data_q <= i_s_axis_tdata;
                        write_request_q <= 1'b1;
                    end
                    //On the next cycle (or a couple of cycles down the line)
                    //We may be here a while if the device we're debugging is
                    //slow. In this case, we just simply have to wait,
                    //dropping any packets that come in. (but still forwarding
                    //packets on) This is deemed not a problem, as with a uart
                    //debugger, we have many cycles between packets on the bus
                    if(write_request_q && i_output_valid) begin
                        write_request_q <= 1'b0;
                        pkt_parser_state <= PACKET_TYPE;
                    end
                end
                RESPONSE_START: begin
                end
                RESPONDING: begin
                    //set 'internal packet valid' and wait for 'internal
                    //packet ready'
                end
                default: $error("Unreachable");
            endcase
        end
    end

    //Packet parsing state machine




    //Packet forwarding state machine

    //Denotes which field we're expecting in the packet
    typedef enum logic [1:0] {
        IDLE = 0,
        FORWARD_PKT = 1, 
        FORWARD_PKT_TLAST = 2,
        INTERNAL_PACKET_START = 3
    } pkt_forwarder_state_t;
    
    pkt_forwarder_state_t pkt_forwarder_state;

    logic [7:0] axis_tdata_q;
    logic       axis_tlast_q;

    logic s_axis_tready_q;
    assign o_s_axis_tready = s_axis_tready_q;

    logic start_packet_parser;
    logic m_axis_tvalid_q;
    assign o_m_axis_tvalid = m_axis_tvalid_q;

    assign o_m_axis_tdata = axis_tdata_q;
    assign o_m_axis_tlast = axis_tlast_q;
   
    logic internal_packet_ready;
    logic internal_packet_valid;

    //Forwards packets from slave to master interface. Accepts an interrupt
    //signal to accept packet transmission from this module
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            pkt_forwarder_state <= IDLE;  
            start_packet_parser <= 1'b0;
            m_axis_tvalid_q <= 1'b0;
            s_axis_tready_q <= 1'b0;
            internal_packet_ready <= 1'b1;
        end else begin 
            //Have to wait for tready. When we parse a packet, we also send it
            //along the wire
            case (pkt_forwarder_state) 
                IDLE: begin
                    internal_packet_ready <= 1'b0;
                    //In order to give the internal packet path a chance, we
                    //need to enter this state with s_axis_tready_q <= 1'b0;
                    if (i_s_axis_tvalid && o_s_axis_tready) begin
                        axis_tdata_q <= i_s_axis_tdata;
                        axis_tlast_q <= i_s_axis_tlast; 
                        m_axis_tvalid_q <= 1'b1;
                        pkt_forwarder_state <= FORWARD_PKT;
                        //Also, check i_s_axis_tdata for a protocol version.
                        //If the version is 0x01, also at the same time start
                        //parsing the packet. This means, next clock cycle at
                        //the earliest we will have the next byte of the
                        //packet
                        if (i_s_axis_tdata == 8'h01) begin
                            start_packet_parser <= 1'b1; 
                        end
                    end else begin
                        if (internal_packet_valid) begin
                            s_axis_tready_q <= 1'b0;
                            internal_packet_ready <= 1'b1;
                            pkt_forwarder_state <= INTERNAL_PACKET_START;
                            //TODO make transition in internal packet loading
                        end else begin
                            s_axis_tready_q <= 1'b1;
                        end    
                    end
                end
                FORWARD_PKT: begin
                    //Clear the packet parser signal, as it may have been set
                    start_packet_parser <= 1'b0; 
                    if (i_s_axis_tvalid && o_s_axis_tready && i_m_axis_tready && o_m_axis_tvalid) begin
                        axis_tdata_q <= i_s_axis_tdata;
                        axis_tlast_q <= i_s_axis_tlast; 
                        m_axis_tvalid_q <= 1'b1;
                        if (i_s_axis_tlast) begin
                            pkt_forwarder_state <= FORWARD_PKT_TLAST;
                        end
                    end
                end
                FORWARD_PKT_TLAST: begin
                    if (i_m_axis_tready && o_m_axis_tvalid) begin
                        m_axis_tvalid_q <= 1'b0;
                        pkt_forwarder_state <= IDLE;
                    end 
                end
                INTERNAL_PACKET_START: begin
                    internal_packet_ready <= 1'b0;
                    s_axis_tready_q <= 1'b0;
                    //We only need to wait until the packet is finished
                    if (i_m_axis_tready && o_m_axis_tvalid && o_m_axis_tlast) begin
                        pkt_forwarder_state <= IDLE;                    
                    end
                end
                default: $error("Unreachable");   
            endcase
        end
        
    end
    
endmodule
