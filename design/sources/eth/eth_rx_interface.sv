
`default_nettype none
`timescale 1ns / 1ps

module eth_rx_interface #(
        parameter int DATAPATH_WIDTH = 32
    ) (
       
        input  wire                                 i_clk,
        input  wire                                 i_rst_n, 

        /* Eth stream interface */
        output wire [DATAPATH_WIDTH-1:0]            o_eths_master_data,
        output wire [$clog2(DATAPATH_WIDTH/8)-1:0]  o_eths_master_keep,
        output wire                                 o_eths_master_valid, 
        output wire                                 o_eths_master_abort,
        output wire                                 o_eths_master_last,


        input  wire [DATAPATH_WIDTH-1:0]            i_data,
        input  wire                                 i_data_valid,
        input  wire [1:0]                           i_header,
        input  wire                                 i_header_valid

    ); 
    
 
    //These are bit-reversed
    typedef enum logic [7:0] {
        CTRL_ONLY  = 8'h78,
        CTRL_ORD   = 8'hb4,
        CTRL_START = 8'hcc,
        ORD_START  = 8'h66,
        ORD_ORD    = 8'haa,
        START      = 8'h1e,
        ORD_CTRL   = 8'hd2,
        TERM_0     = 8'he1,
        TERM_1     = 8'h99,
        TERM_2     = 8'h55,
        TERM_3     = 8'h2d,
        TERM_4     = 8'h33,
        TERM_5     = 8'h4b,
        TERM_6     = 8'h87,
        TERM_7     = 8'hff
    } packet_block_type; 
    
    union packed {
        struct packed {
            union packed {
                struct packed {
                    logic [7:0] [6:0]   ctrl;
                } ctrl_only;
                struct packed {
                    logic [2:0] [7:0]   ordered_set_data;
                    logic [3:0]         ordered_set_type;
                    logic [3:0] [6:0]   ctrl;    
                } ctrl_ord;
                struct packed {
                    logic [2:0] [7:0]   data;
                    logic [3:0]         blank;
                    logic [3:0] [6:0]   ctrl;    
                } ctrl_start;
                struct packed {
                    logic [2:0] [7:0]   data;
                    logic [3:0]         blank;
                    logic [3:0]         ordered_set_type;
                    logic [2:0] [7:0]   ordered_set_data;
                } ord_start;
                struct packed {
                    logic [2:0] [7:0]   ordered_set1_data;
                    logic [3:0]         ordered_set1_type;
                    logic [3:0]         ordered_set0_type;
                    logic [2:0] [7:0]   ordered_set0_data;
                } ord_ord;
                struct packed {
                    logic [6:0] [7:0]   data;
                } start;
                struct packed {
                    logic [3:0] [6:0]   ctrl;    
                    logic [3:0]         ordered_set;
                    logic [2:0] [7:0]   ordered_set_data;
                } ord_ctrl;
                struct packed {
                    logic [6:0] [6:0]   ctrl;    
                    logic [6:0]         blank;
                } term_0;
                struct packed {
                    logic [5:0] [6:0]   ctrl;    
                    logic [5:0]         blank;
                    logic [7:0]         data;
                } term_1;
                struct packed {
                    logic [4:0] [6:0]   ctrl;    
                    logic [4:0]         blank;
                    logic [1:0] [7:0]   data;
                } term_2;
                struct packed {
                    logic [3:0] [6:0]   ctrl;    
                    logic [3:0]         blank;
                    logic [2:0] [7:0]   data;
                } term_3;
                struct packed {
                    logic [2:0] [6:0]   ctrl;    
                    logic [2:0]         blank;
                    logic [3:0] [7:0]   data;
                } term_4;
                struct packed {
                    logic [1:0] [6:0]   ctrl;    
                    logic [1:0]         blank;
                    logic [4:0] [7:0]   data;
                } term_5;
                struct packed {
                    logic [6:0]         ctrl;    
                    logic               blank;
                    logic [5:0] [7:0]   data;
                } term_6;
                struct packed {
                    logic [6:0] [7:0]   data;
                } term_7;
            } body;
            packet_block_type pkt_type;
        } ctrl;
        logic [7:0] [7:0]   data;    
    } packet;
    
    typedef struct packed {
        logic [7:0] [7:0] data_register;
        logic [3:0]       stop_byte;
    } data_buffer_t;
    
    //Updated in a separate always_ff, so needs to be outside of the struct
    logic [3:0] data_buffer_start_byte;

    function data_buffer_t put_data_in_buffer(
            input  data_buffer_t      buffer,
            input  logic [63:0]     data,  
            input  logic [3:0]      num_bytes
        );

        data_buffer_t out;
        out.data_register = buffer.data_register;
        out.stop_byte  = buffer.stop_byte + 4'(num_bytes);

        for (int data_index = 0; data_index < num_bytes; data_index++) begin
            out.data_register[buffer.stop_byte[2:0] + 3'(data_index)] = data[(8 * data_index)+:8];                           
        end
        
        return out;    

    endfunction

    logic recv_packet;
    logic packet_corrupted;

    logic valid_block;
    
    logic [1:0]         previous_header;

    (* MARK_DEBUG = "TRUE" *) data_buffer_t data_buffer;

    logic [31:0]        previous_block_reg;

    logic [31:0]        input_data_rev;
    always_comb input_data_rev = {i_data[7:0], i_data[15:8], i_data[23:16], i_data[31:24]};

    logic               started;

    always_comb packet = {input_data_rev, previous_block_reg};
    //      Packet types:
    //      CTRL_ONLY   CTRL_ORD    CTRL_START  ORD_START 
    //      ORD_ORD     START       ORD_CTRL 
    //      TERM_0      TERM_1      TERM_2      TERM_3        
    //      TERM_4      TERM_5      TERM_6      TERM_7
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            data_buffer.stop_byte  <= 4'b0;
            started <= 1'b0;
        end else begin
            if (i_header_valid) begin
                previous_block_reg <= input_data_rev;
                previous_header <= i_header;
                started <= 1'b1;
            end else if (!started) begin
                //We have not started packet reception yet
                
            end else begin
                if (previous_header == 2'b10) begin
                    //That means 'packet' is valid:
                    case (packet.ctrl.pkt_type)
                        CTRL_ONLY   : begin /* Do nothing */ end
                        CTRL_ORD    : begin /* Do nothing */ end
                        CTRL_START  : begin
                            $error("CTRL_START unimplemented");
                        end 
                        ORD_START   : begin
                            $error("ORD_START unimplemented");
                        end
                        ORD_ORD     : begin /* We don't care */ end
                        START       : begin
                            //Check if the starting sequence is aa aa aa aa aa aa ab
                            //as if this is the case, this is an ethernet
                            //packet
                            if (packet.ctrl.body.start.data == 56'haa_aa_aa_aa_aa_aa_ab) begin
                                recv_packet <= 1'b1;
                                packet_corrupted <= 1'b0;
                            end else begin
                                recv_packet <= 1'b1;
                                packet_corrupted <= 1'b1;
                            end
                        end
                        TERM_0      : begin
                            recv_packet <= 1'b0;
                        end
                        TERM_1      : begin
                            data_buffer <= put_data_in_buffer(data_buffer, 64'(packet.ctrl.body.term_1.data),'d1);
                            recv_packet <= 1'b0;
                        end
                        TERM_2      : begin
                            data_buffer <= put_data_in_buffer(data_buffer, 64'(packet.ctrl.body.term_2.data),'d2);
                            recv_packet <= 1'b0;
                        end
                        TERM_3      : begin
                            data_buffer <= put_data_in_buffer(data_buffer, 64'(packet.ctrl.body.term_3.data),'d3);
                            recv_packet <= 1'b0;
                        end
                        TERM_4      : begin
                            data_buffer <= put_data_in_buffer(data_buffer, 64'(packet.ctrl.body.term_4.data),'d4);
                            recv_packet <= 1'b0;
                        end
                        TERM_5      : begin
                            data_buffer <= put_data_in_buffer(data_buffer, 64'(packet.ctrl.body.term_5.data),'d5);
                            recv_packet <= 1'b0;
                        end
                        TERM_6      : begin
                            data_buffer <= put_data_in_buffer(data_buffer, 64'(packet.ctrl.body.term_6.data),'d6);
                            recv_packet <= 1'b0;
                        end
                        TERM_7      : begin
                            data_buffer <= put_data_in_buffer(data_buffer, 64'(packet.ctrl.body.term_7.data),'d7);
                            recv_packet <= 1'b0;
                        end
                        default: $display(packet.ctrl.pkt_type);
                    endcase  
                end else if (previous_header == 2'b01 & recv_packet) begin
                    //Need to put the data into the data register, somehow?
                    //TODO write a systemverilog function for this
                    data_buffer <= put_data_in_buffer(data_buffer, packet.data,'d8);  
                end else begin
                    //Some sort of error state
                    $error("BAD HEADER");
                end
            end
        end
    end
    
    logic transmission_started;

    logic [3:0] [7:0]   output_data;
    logic               output_last;
    logic               output_abort;
    logic [1:0]         output_keep;
    logic               output_valid;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            data_buffer_start_byte <= 4'b0;
            transmission_started <= 1'b0;
        end else begin
            if (i_data_valid & recv_packet) begin
                if (transmission_started || data_buffer.stop_byte - data_buffer_start_byte > 0) begin
                    transmission_started <= 1'b1;
                    for (logic [3:0] i = 0; i < 4; i++) begin
                        output_data[i] <= data_buffer.data_register[i + data_buffer_start_byte];
                    end
                    output_keep <= data_buffer.stop_byte - data_buffer_start_byte >= 4 
                        ? 2'b11 
                        : 2'(data_buffer.stop_byte - data_buffer_start_byte - 1'b1);
                    if (data_buffer.stop_byte - data_buffer_start_byte >= 4) begin
                        data_buffer_start_byte <= data_buffer_start_byte + 3'h4;
                    end else begin
                        data_buffer_start_byte <= data_buffer.stop_byte;
                        transmission_started <= 1'b0;
                    end
                end 
            end else begin
               //something 
            end
        end
    end
    



endmodule

`resetall
