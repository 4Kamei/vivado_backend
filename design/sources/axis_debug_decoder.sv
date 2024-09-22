`default_nettype none
`timescale 1ns / 1ps



//TODO handling malformed packets (with tlast asserted during packet parsing)
module axis_debug_decoder #(
        parameter logic [7:0] AXIS_DEVICE_TYPE      = 8'haa,
        parameter logic [7:0] AXIS_DEVICE_ID        = 8'h55,
        parameter integer     ADDR_WIDTH_BYTES      = 2,
        parameter integer     DATA_WIDTH_BYTES      = 3
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
        output wire  [ADDR_WIDTH_BYTES*8-1:0]       o_rw_address,
        input  wire  [DATA_WIDTH_BYTES*8-1:0]       i_read_data,
        output wire  [DATA_WIDTH_BYTES*8-1:0]       o_write_data,

        output wire                                 o_read_request,
        output wire                                 o_write_request,
        input  wire                                 i_output_valid
    );
    
    typedef enum logic [3:0] {
        PACKET_TYPE,
        RW_DEVICE_TYPE,
        RW_DEVICE_ID,
        RW_ADDRESS,
        R_RESPONSE,
        W_DATA,
        W_DATA_WAIT,
        RESPONSE_START,
        RESPONDING
    } pkt_parser_state_t ;
    
    typedef enum logic [1:0] {
        IDENTIFY,
        READ,
        WRITE
    } pkt_type_t ;

    typedef enum logic [2:0] {
        PKT_TYPE,
        PKT_DEV_TYPE,
        PKT_DEV_ID, 
        PKT_IDENTIFY_ADDR_WIDTH,
        PKT_IDENTIFY_DATA_WIDTH,
        PKT_END,
        PKT_READ_DATA,
        PKT_READ_ADDR
    } pkt_transmission_state_t ;

    pkt_parser_state_t          pkt_parser_state;
    pkt_type_t                  pkt_type;
    pkt_transmission_state_t    pkt_transmission_state;

    logic [ADDR_WIDTH_BYTES*8-1:0] rw_address_q;
    logic [DATA_WIDTH_BYTES*8-1:0] rw_data_q;
    logic                          read_request_q;
    logic                          write_request_q;
    logic [7:0]                    packet_data_q;
    logic                          packet_data_last_q;
    
    assign o_read_request = read_request_q;
    assign o_write_request = write_request_q;
    assign o_rw_address = rw_address_q;
    assign o_write_data = rw_data_q;

    localparam int ADDR_WIDTH_BYTES_LOG2 = $clog2(ADDR_WIDTH_BYTES) + 1;
    localparam int DATA_WIDTH_BYTES_LOG2 = $clog2(DATA_WIDTH_BYTES) + 1;

    localparam logic [ADDR_WIDTH_BYTES_LOG2-1:0] _ADDR_WIDTH_BYTES = ADDR_WIDTH_BYTES[ADDR_WIDTH_BYTES_LOG2-1:0];    
    localparam logic [DATA_WIDTH_BYTES_LOG2-1:0] _DATA_WIDTH_BYTES = DATA_WIDTH_BYTES[DATA_WIDTH_BYTES_LOG2-1:0];    

    logic [ADDR_WIDTH_BYTES_LOG2-1:0] addr_byte_counter;                         
    logic [DATA_WIDTH_BYTES_LOG2-1:0] data_byte_counter;                         

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
                            8'h02: begin    //READ
                                pkt_parser_state <= RW_DEVICE_TYPE;
                                pkt_type <= READ;
                            end
                            8'h04: begin    //WRITE
                                pkt_parser_state <= RW_DEVICE_TYPE;
                                pkt_type <= WRITE;    
                            end
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
                            addr_byte_counter <= _ADDR_WIDTH_BYTES - 1;
                        end else begin
                            pkt_parser_state <= PACKET_TYPE;
                        end
                    end
                end
                RW_ADDRESS: begin
                    if(i_s_axis_tvalid && o_s_axis_tready) begin
                        rw_address_q[(addr_byte_counter*8+7)-:8] <= i_s_axis_tdata;
                        if (addr_byte_counter == 0) begin
                            case (pkt_type)
                                READ: begin
                                    read_request_q <= 1'b1;
                                    pkt_parser_state <= R_RESPONSE;
                                end
                                WRITE: begin
                                    data_byte_counter <= _DATA_WIDTH_BYTES - 1;
                                    pkt_parser_state <= W_DATA;
                                end
                                default: $error("Unreachable");
                            endcase
                        end else begin
                            addr_byte_counter <= addr_byte_counter - 1'b1;
                        end
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
                        rw_data_q[(data_byte_counter*8+7)-:8] <= i_s_axis_tdata;
                        if (data_byte_counter == 0) begin
                            write_request_q <= 1'b1;
                            pkt_parser_state <= W_DATA_WAIT;    
                        end
                        data_byte_counter <= data_byte_counter - 1'b1;
                    end
                end
                W_DATA_WAIT: begin
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
                    if (!internal_packet_valid) begin
                        internal_packet_valid <= 1'b1;
                        packet_data_q <= 8'h01; //Protocol version header to 0x01
                        pkt_transmission_state <= PKT_TYPE; 
                    end else begin
                        if (internal_packet_ready) begin
                            //We have the channel free here until we send
                            //a 'tlast'
                            internal_packet_valid <= 1'b0;
                            pkt_parser_state <= RESPONDING;
                        end
                    end
                end
                RESPONDING: begin
                    //We have sent the packet version in RESPONSE_START, now
                    //send the remainder of the packet
                    if (i_m_axis_tready && o_m_axis_tvalid) begin
                        case (pkt_transmission_state)
                            PKT_TYPE: begin
                                pkt_transmission_state <= PKT_DEV_TYPE;
                                if (pkt_type == IDENTIFY) begin
                                    packet_data_q <= 8'h01;
                                end
                                if (pkt_type == READ) begin
                                    packet_data_q <= 8'h03;
                                end
                            end
                            PKT_DEV_TYPE: begin
                                packet_data_q <= AXIS_DEVICE_TYPE;
                                pkt_transmission_state <= PKT_DEV_ID;
                            end
                            PKT_DEV_ID: begin
                                packet_data_q <= AXIS_DEVICE_ID;
                                if (pkt_type == IDENTIFY) begin
                                    pkt_transmission_state <= PKT_IDENTIFY_ADDR_WIDTH;
                                end
                                if (pkt_type == READ) begin
                                    pkt_transmission_state <= PKT_READ_ADDR;
                                    addr_byte_counter <= _ADDR_WIDTH_BYTES - 1;
                                end
                            end
                            PKT_IDENTIFY_ADDR_WIDTH: begin
                                packet_data_q <= 8'(_ADDR_WIDTH_BYTES);    
                                pkt_transmission_state <= PKT_IDENTIFY_DATA_WIDTH;
                            end
                            PKT_IDENTIFY_DATA_WIDTH: begin
                                packet_data_q <= 8'(_DATA_WIDTH_BYTES);    
                                pkt_transmission_state <= PKT_END;
                                packet_data_last_q <= 1'b1;
                            end
                            PKT_READ_ADDR: begin
                                packet_data_q <= rw_address_q[(addr_byte_counter * 8 + 7)-:8];
                                addr_byte_counter <= addr_byte_counter - 1'b1;
                                if (addr_byte_counter == 0) begin
                                    data_byte_counter <= _DATA_WIDTH_BYTES - 1;
                                    pkt_transmission_state <= PKT_READ_DATA;     
                                end
                            end
                            PKT_READ_DATA: begin
                                packet_data_q <= i_read_data[(data_byte_counter * 8 + 7)-:8];
                                data_byte_counter <= data_byte_counter - 1'b1;
                                if (data_byte_counter == 0) begin
                                    packet_data_last_q <= 1'b1;
                                    pkt_transmission_state <= PKT_END;     
                                end
                            end
                            PKT_END: begin
                                pkt_parser_state <= PACKET_TYPE;
                                packet_data_last_q <= 1'b0;
                            end
                            default: $error("Unreachable");
                        endcase
                    end
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
        IDLE,
        FORWARD_PKT, 
        FORWARD_PKT_TLAST,
        INTERNAL_PACKET_START
    } pkt_forwarder_state_t ;
    
    pkt_forwarder_state_t pkt_forwarder_state;

    logic [7:0] axis_tdata_q;
    logic       axis_tlast_q;

    logic [7:0] axis_tdata_qq;
    logic       axis_tlast_qq;
    logic       m_axis_tvalid_qq;

    logic s_axis_tready_q;
    assign o_s_axis_tready = s_axis_tready_q;

    logic start_packet_parser;
    logic m_axis_tvalid_q;
    assign o_m_axis_tvalid = m_axis_tvalid_q;

    assign o_m_axis_tdata = pkt_forwarder_state == INTERNAL_PACKET_START ? packet_data_q : axis_tdata_q;
    assign o_m_axis_tlast = pkt_forwarder_state == INTERNAL_PACKET_START ? packet_data_last_q : axis_tlast_q;
   
    logic internal_packet_ready;
    logic internal_packet_valid;

    //Forwards packets from slave to master interface. Accepts an interrupt
    //signal to accept packet transmission from this module
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            pkt_forwarder_state <= IDLE;  
            start_packet_parser <= 1'b0;
            m_axis_tvalid_q <= 1'b0;
            m_axis_tvalid_qq <= 1'b0;
            s_axis_tready_q <= 1'b0;
            internal_packet_ready <= 1'b1;
        end else begin 
            //Have to wait for tready. When we parse a packet, we also send it
            //along the wire
            case (pkt_forwarder_state) 
                IDLE: begin
                    internal_packet_ready <= 1'b0;
                    start_packet_parser <= 1'b0;
                    //In order to give the internal packet path a chance, we
                    //need to enter this state with s_axis_tready_q <= 1'b0;
                    if (i_s_axis_tvalid && o_s_axis_tready) begin
                        axis_tdata_q <= i_s_axis_tdata;
                        axis_tlast_q <= i_s_axis_tlast; 
                        m_axis_tvalid_q <= 1'b1;

                        //Need to reset this, as they are the condition
                        //for finishing a packet
                        axis_tlast_qq <= 1'b0;

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
                            m_axis_tvalid_q <= 1'b0;

                            pkt_forwarder_state <= INTERNAL_PACKET_START;
                            //TODO make transition in internal packet loading
                        end else begin
                            s_axis_tready_q <= 1'b1;
                        end    
                    end
                end
                FORWARD_PKT: begin
                    if (start_packet_parser && i_s_axis_tvalid && o_s_axis_tready) begin
                        start_packet_parser <= 1'b0;
                    end
                    casez ({i_m_axis_tready, i_s_axis_tvalid, m_axis_tvalid_qq, m_axis_tvalid_q})
                        4'b0011,
                        4'b000?: ;
                        4'b??10: $error("m_axis_tvalid is 0, but m_axis_tvalid_qq.");
                        4'b0100: begin
                            if (s_axis_tready_q) begin
                                axis_tdata_q <= i_s_axis_tdata;
                                axis_tlast_q <= i_s_axis_tlast;
                                m_axis_tvalid_q <= 1'b1;
                                s_axis_tready_q <= 1'b0;
                            end else begin
                                s_axis_tready_q <= 1'b1;
                            end
                        end
                        4'b0101: begin
                            if (s_axis_tready_q) begin
                                axis_tdata_qq <= i_s_axis_tdata;
                                axis_tlast_qq <= i_s_axis_tlast;
                                m_axis_tvalid_qq <= 1'b1;
                                s_axis_tready_q <= 1'b0;
                            end else begin
                                s_axis_tready_q <= 1'b1;
                            end 
                        end
                        4'b0111: assert(!o_s_axis_tready); //Otherwise, we deleted data
                        4'b1000: ;
                        4'b1001: begin //Send over what is in the buffer, but the 2buffer not valid -
                            m_axis_tvalid_q <= 1'b0;
                            s_axis_tready_q <= 1'b1;
                        end
                        4'b1011: begin
                            m_axis_tvalid_qq <= 1'b0;
                            axis_tdata_q <= axis_tdata_qq;
                            axis_tlast_q <= axis_tlast_qq;
                            s_axis_tready_q <= 1'b1;
                        end
                        4'b1100: begin
                            if(s_axis_tready_q) begin
                                axis_tdata_q <= i_s_axis_tdata;
                                axis_tlast_q <= i_s_axis_tlast;
                                m_axis_tvalid_q <= 1'b1;
                            end else begin
                                s_axis_tready_q <= 1'b1;
                            end
                        end
                        4'b1101: begin
                            m_axis_tvalid_q <= 1'b0;
                            if(s_axis_tready_q) begin
                                axis_tdata_q <= i_s_axis_tdata;
                                axis_tlast_q <= i_s_axis_tlast;
                                m_axis_tvalid_q <= 1'b1;
                            end else begin
                                s_axis_tready_q <= 1'b1;
                            end
                        end
                        4'b1111: begin
                            //Advance the packet into the output buffer
                            m_axis_tvalid_q <= m_axis_tvalid_qq;
                            axis_tdata_q <= axis_tdata_qq;
                            axis_tlast_q <= axis_tlast_qq;
                            m_axis_tvalid_qq <= 1'b0;
                        end
                        default: $error("Error %04b o_s_axis_tready=%01b", 
                            {i_m_axis_tready, i_s_axis_tvalid, m_axis_tvalid_qq, m_axis_tvalid_q}, 
                            o_s_axis_tready);
                    endcase
                    //If there are any tlasts, we don't want to accept any new
                    //packets - force tvalid to 0
                    if (axis_tlast_q || axis_tlast_qq) begin
                        s_axis_tready_q <= 1'b0;

                        if (i_m_axis_tready && o_m_axis_tvalid && o_m_axis_tlast) begin
                            pkt_forwarder_state <= IDLE;
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
                    //Delays sending the packet until the clock cycle after 
                    if (!internal_packet_ready) begin
                        m_axis_tvalid_q <= 1'b1;
                    end
                    //We only need to wait until the packet is finished
                    if (i_m_axis_tready && o_m_axis_tvalid && o_m_axis_tlast) begin
                        pkt_forwarder_state <= IDLE;         
                        m_axis_tvalid_q <= 1'b0;
                    end
                end
                default: $error("Unreachable");   
            endcase
        end 
    end
    
endmodule
