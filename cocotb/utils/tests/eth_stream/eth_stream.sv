`default_nettype none
`timescale 1ns / 1ps

module eth_stream #(
        parameter int DATA_WIDTH = 32
    ) (
        input  wire i_clk,
        input  wire i_rst_n,

        input  wire [DATA_WIDTH-1:0]            i_eth_slave_data,
        input  wire [$clog2(DATA_WIDTH/8)-1:0]  i_eth_slave_keep,
        input  wire                             i_eth_slave_valid,
        input  wire                             i_eth_slave_abort,
        input  wire                             i_eth_slave_last,

        output wire [DATA_WIDTH-1:0]            o_eth_master_data,
        output wire [$clog2(DATA_WIDTH/8)-1:0]  o_eth_master_keep,
        output wire                             o_eth_master_valid,
        output wire                             o_eth_master_abort,
        output wire                             o_eth_master_last
    );

    assign o_eth_master_data = i_eth_slave_data;
    assign o_eth_master_keep = i_eth_slave_keep;
    assign o_eth_master_valid = i_eth_slave_valid;
    assign o_eth_master_abort = i_eth_slave_abort;
    assign o_eth_master_last  = i_eth_slave_last;

endmodule
