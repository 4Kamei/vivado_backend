
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
    

    logic [31:0]        input_data_rev;
    always_comb input_data_rev = {i_data[7:0], i_data[15:8], i_data[23:16], i_data[31:24]};

    logic               sending;
    logic [1:0]         skip_next;

    logic [31:0]        eths_data;
    logic [1:0]         eths_keep;
    logic               eths_valid;
    logic               eths_abort;
    logic               eths_last;
    
    //If it's the start of a new packet, AND the packet is a terminate in
    //position-0 packet, that means the current beat will need to have
    //'o_eths_master_last' asserted.
    logic               eths_last_prev;
    always_comb eths_last_prev = i_header_valid && block_type == TERM_0;

    assign o_eths_master_data   = eths_data;
    assign o_eths_master_keep   = eths_keep;
    assign o_eths_master_valid  = eths_valid;
    assign o_eths_master_abort  = eths_abort;
    assign o_eths_master_last   = eths_last_prev ? 1'b1 : eths_last;    //Need a combinatorial path here

    logic [1:0]                 i_header_q;
    
    always_ff @(posedge i_clk) i_header_q <= i_header;


    packet_block_type   block_type;
    always_comb block_type = packet_block_type'(i_data[31:24]);

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            sending <= 1'b0;
            skip_next <= 2'b0;
            eths_valid <= 1'b0;
        end else begin
            if (sending) begin
                if (skip_next != 0) begin
                    skip_next <= skip_next - 1'b1;
                end else begin
                    if ((i_header_valid && i_header == 2'b01) || (!i_header_valid && i_header_q == 2'b01)) begin
                        eths_valid <= i_data_valid;
                        eths_data  <= input_data_rev;
                        eths_keep  <= 2'b11;
                        eths_last  <= 1'b0;
                        eths_abort <= 1'b0;
                    end else begin
                        if (i_header_valid) begin
                            eths_data <= {8'h00, input_data_rev[31:8]};
                            case (block_type)
                                TERM_0: begin
                                    sending <= 1'b0;
                                    $display("%h", block_type);
                                    $display(block_type == TERM_0);
                                    $display(i_header_valid);
                                end
                                TERM_1: begin
                                    eths_keep <= 2'b00;
                                    eths_last <= 1'b1;
                                end
                                TERM_2: begin
                                    eths_keep <= 2'b01;
                                    eths_last <= 1'b1;
                                end
                                TERM_3: begin
                                    eths_keep <= 2'b10;
                                    eths_last <= 1'b1;
                                end
                                TERM_4: begin
                                    eths_keep <= 2'b11;
                                    eths_last <= 1'b1;
                                end
                                TERM_5, TERM_6, TERM_7: begin
                                    eths_keep <= 2'b11;
                                    eths_last <= 1'b0;
                                end
                                default: $error("Unexpected block type %s", block_type);
                            endcase
                        end else begin
                            eths_data <= input_data_rev;
                            $display("Unimplemented");
                        end
                        //eths_valid <= i_data_valid;
                        //eths_data  <= input_data_rev;
                        //eths_keep  <= 2'b11;
                        //eths_last  <= 1'b0;
                        //eths_abort <= 1'b0;
                    end
                end
            end else begin
                //We have the start of a new block
                if (i_header_valid && i_header == 2'b10) begin
                    case (block_type)
                        CTRL_START: begin
                            //TODO check that there are no error chars or
                            //somtehing
                            skip_next <= 2'd2;
                            sending <= 1'b1;
                        end
                        ORD_START: begin
                            skip_next <= 2'd2;
                            sending <= 1'b1;
                        end
                        START: begin
                            skip_next <= 2'd1;
                            sending <= 1'b1;
                        end
                        default: $display("Unimplemented packet %s", block_type);
                    endcase
                end
            end
        end
    end

endmodule

`resetall
