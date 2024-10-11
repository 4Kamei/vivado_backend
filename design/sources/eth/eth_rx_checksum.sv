`default_nettype none
`timescale 1ns / 1ps

module eth_rx_checksum #(
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
        
        /* Eth stream output */
        input  wire [DATAPATH_WIDTH-1:0]            i_eths_slave_data,
        input  wire [$clog2(DATAPATH_WIDTH/8)-1:0]  i_eths_slave_keep,
        input  wire                                 i_eths_slave_valid, 
        input  wire                                 i_eths_slave_abort,
        input  wire                                 i_eths_slave_last

    ); 
    
    logic is_aborted;

    logic [DATAPATH_WIDTH-1:0]            data;
    logic [$clog2(DATAPATH_WIDTH/8)-1:0]  keep;
    logic                                 valid;
    logic                                 abort;
    logic                                 last;

    assign o_eths_master_data = data;
    assign o_eths_master_keep = keep;
    assign o_eths_master_valid = valid;
    assign o_eths_master_abort = abort;
    assign o_eths_master_last = last;

    //*CRC is the last 32 bits of the packet*

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
           valid <= 1'b0;
           abort <= 1'b0;
           last <= 1'b0;
        end else begin
            data <= i_eths_slave_data;
            keep <= i_eths_slave_keep;
            valid <= i_eths_slave_valid; 
            abort <= i_eths_slave_abort;
            last <= i_eths_slave_last;
        end
    end

endmodule

`resetall
