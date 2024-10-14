
`default_nettype none
`timescale 1ns / 1ps
//synthesis translate_off
`define SIMULATION
//synthesis translate_on

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

    typedef struct packed {
       logic [31:0] data;  
       logic [1:0]  keep;  
       logic        last;  
    } comb_fifo_data_t;
    
    typedef struct packed {
        comb_fifo_data_t [3:0]  inner_data;
        logic                   is_aborted;
        logic [1:0]             write_ptr;
    } comb_fifo_state_t;

`ifdef SIMULATION
    
    logic [31:0]    comb_fifo_data_0;
    logic [31:0]    comb_fifo_data_1;
    logic [31:0]    comb_fifo_data_2;
    logic [31:0]    comb_fifo_data_3;

    always_comb comb_fifo_data_0 = comb_fifo.inner_data[0].data;
    always_comb comb_fifo_data_1 = comb_fifo.inner_data[1].data;
    always_comb comb_fifo_data_2 = comb_fifo.inner_data[2].data;
    always_comb comb_fifo_data_3 = comb_fifo.inner_data[3].data;

`endif

    typedef logic [1:0] comb_fifo_read_ptr_t;

    comb_fifo_read_ptr_t comb_fifo_read_ptr;

    function static logic is_empty(
        input comb_fifo_state_t input_fifo_state, 
        input comb_fifo_read_ptr_t comb_fifo_read_ptr);
        return comb_fifo_read_ptr == input_fifo_state.write_ptr;
    endfunction

    function static comb_fifo_data_t poll(
        input comb_fifo_state_t input_fifo_state, 
        input comb_fifo_read_ptr_t read_ptr);
        return input_fifo_state.inner_data[read_ptr];
    endfunction

    function static comb_fifo_state_t clean_fifo();
        comb_fifo_state_t output_state;
        output_state.write_ptr  = 2'b0;
        output_state.is_aborted = 1'b0;
    endfunction

    function comb_fifo_state_t push_data(
        input comb_fifo_state_t input_fifo, 
        input logic [31:0] data, 
        input logic [1:0] keep, 
        input logic last);
        comb_fifo_data_t input_data;
        $display("Push data single %h, %h, %d", data, keep, last);
        input_data.keep = keep;
        input_data.last = last;
        input_data.data = data;
        input_fifo.inner_data[input_fifo.write_ptr] = input_data;
        input_fifo.write_ptr += 1'b1;
        return input_fifo;
    endfunction;
    
    function comb_fifo_state_t push_data_partial_single(
        input comb_fifo_state_t input_fifo, 
        input logic [23:0] data);
        //Add the new byte and set the last flac
        comb_fifo_data_t input_data;
        $display("Push data partial single %h", data);
        input_data.keep = 2'b11;
        input_data.last = 1'b0;
        input_data.data = {8'h0, data};
        input_fifo.inner_data[input_fifo.write_ptr] = input_data;
        return input_fifo;
    endfunction

    //Push a single byte into the msb position
    function comb_fifo_state_t push_data_partial_byte(
        input comb_fifo_state_t input_fifo, 
        input logic [7:0] data_previous,
        input logic last);
        comb_fifo_data_t input_data;
        $display("Push data partial byte %h, %d, (%h)", data_previous, last, input_fifo.inner_data[input_fifo.write_ptr].data);
        //Here, just add the next byte, increment the pointer and fill in with
        //nthe new data
        input_data.data = {data_previous, input_fifo.inner_data[input_fifo.write_ptr].data[23:0]};
        input_data.keep = 2'b11;
        input_data.last = last;
        input_fifo.inner_data[input_fifo.write_ptr] = input_data;
        input_fifo.write_ptr += 1'b1;
        return input_fifo;
    endfunction;
    
    //Push a single byte into the msb position, then push the data into the
    //next position
    function comb_fifo_state_t push_data_partial_remaining(
        input comb_fifo_state_t input_fifo, 
        input logic [7:0] data_previous,
        input logic [31:0] data, 
        input logic [1:0] keep, 
        input logic last);
        $display("Push data partial remaining %h, %h, %h, %d", data_previous, data, keep, last);
        input_fifo = push_data_partial_byte(input_fifo, data_previous, 1'b0);
        input_fifo = push_data(input_fifo, data, keep, last);
        return input_fifo;
    endfunction;

    comb_fifo_state_t comb_fifo;
    logic             valid;

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
    
    ////////////////////////////////
    //  Fifo for the output eth stream
    //  Fifo is modified only through the associated functions
    ////////////////////////////////

    logic comb_fifo_empty;
    always_comb comb_fifo_empty = is_empty(comb_fifo, comb_fifo_read_ptr);

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            eths_valid <= 1'b0;
        end else begin
            //Not empty AND eths_valid means we sent data.
            if (eths_valid) begin
                if (comb_fifo_empty || eths_last_prev) begin
                    eths_valid <= 1'b0;
                    eths_last <= 1'b0;
                    if (eths_last_prev) begin
                        //In the 'TERM_0' case, eths_last_prev is
                        //a combinational path. The write pointer in that case
                        //is incremented once spuriously, hence need to ignore
                        //the next beat here.
                        comb_fifo_read_ptr <= comb_fifo_read_ptr + 1'd1;
                    end
                end else begin
                    eths_valid <= 1'b1;
                    {eths_data, eths_keep, eths_last} <= poll(comb_fifo, comb_fifo_read_ptr);
                    eths_abort <= comb_fifo.is_aborted;
                    comb_fifo_read_ptr <= comb_fifo_read_ptr + 1'd1;
                end
            end else begin
                if (!comb_fifo_empty) begin
                    eths_valid <= 1'b1;
                    {eths_data, eths_keep, eths_last} <= poll(comb_fifo, comb_fifo_read_ptr);
                    eths_abort <= comb_fifo.is_aborted;
                    comb_fifo_read_ptr <= comb_fifo_read_ptr + 1'b1;
                end
            end
        end
    end



    
    logic [1:0]                 i_header_q;
    logic                       i_header_valid_q;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            i_header_q <= 2'b00;
            i_header_valid_q <= 1'b0;
        end else begin
            if (i_data_valid) begin
                i_header_q <= i_header;
                i_header_valid_q <= i_header_valid;
            end
        end
    end
   


    packet_block_type   block_type;
    packet_block_type   prev_block_type;

    logic [23:0]        partial_data;
    logic               partial_data_valid;

    always_ff @(posedge i_clk) prev_block_type <= block_type;

    always_comb block_type = packet_block_type'(i_data[31:24]);

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            comb_fifo <= clean_fifo();
            sending <= 1'b0;
            skip_next <= 2'b0;
            partial_data_valid <= 1'b0;
        end else begin
            if (i_data_valid) begin
                if (sending) begin
                    if (skip_next != 0) begin
                        skip_next <= skip_next - 1'b1;
                    end else begin
                        if ((i_header_valid   && (i_header   == 2'b01)) || 
                            (i_header_valid_q && (i_header_q == 2'b01))) begin
                            comb_fifo <= push_data(comb_fifo, input_data_rev, 2'b11, 1'b0);
                        end else if (i_header_valid) begin
                            $display("Block type %h, Data %h AT %0t", block_type, input_data_rev,  $time);
                            case (block_type)
                                TERM_0: begin
                                    sending <= 1'b0;
                                end
                                TERM_1: begin
                                    comb_fifo <= push_data(comb_fifo, {8'h00, input_data_rev[31:8]}, 2'b00, 1'b1);
                                    sending <= 1'b0;
                                end
                                TERM_2: begin
                                    comb_fifo <= push_data(comb_fifo, {8'h00, input_data_rev[31:8]}, 2'b01, 1'b1);
                                    sending <= 1'b0;
                                end
                                TERM_3: begin
                                    comb_fifo <= push_data(comb_fifo, {8'h00, input_data_rev[31:8]}, 2'b10, 1'b1);
                                    sending <= 1'b0;
                                end
                                //These end on the next beat, but need to
                                //delay the current beat by 1, as keep = 2'b11,
                                //but only have 3 bytes of data atm
                                TERM_4, TERM_5, TERM_6, TERM_7: begin
                                    comb_fifo <= push_data_partial_single(comb_fifo, input_data_rev[31:8]);
                                end
                                default: begin
                                    sending <= 1'b0;
                                    comb_fifo.is_aborted <= 1'b1;
                                end
                            endcase
                        end else begin
                            $display("Block type %h", prev_block_type);
                            sending <= 1'b0; 
                            case (prev_block_type)
                                TERM_4: begin
                                    comb_fifo <= push_data_partial_byte(
                                        comb_fifo, 
                                        input_data_rev[7:0],
                                        1'b1
                                    );
                                end
                                TERM_5: begin
                                    comb_fifo <= push_data_partial_remaining(
                                        comb_fifo,
                                        input_data_rev[7:0],
                                        {24'h0, input_data_rev[15:8]},
                                        2'b00,
                                        1'b1);
                                end
                                TERM_6: begin
                                    comb_fifo <= push_data_partial_remaining(
                                        comb_fifo,
                                        input_data_rev[7:0],
                                        {16'h0, input_data_rev[23:8]},
                                        2'b01,
                                        1'b1);
                                end
                                TERM_7: begin
                                    comb_fifo <= push_data_partial_remaining(
                                        comb_fifo,
                                        input_data_rev[7:0],
                                        { 8'h0, input_data_rev[31:8]},
                                        2'b10,
                                        1'b1);
                                end
                                default: begin
                                    comb_fifo.is_aborted <= 1'b1;
                                end
                            endcase
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
    end

endmodule

`resetall
