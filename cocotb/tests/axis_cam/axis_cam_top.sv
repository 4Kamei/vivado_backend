`default_nettype none
`timescale 1ns / 1ps


//Need to create a wrapper and pass the signals through, as verilator doesn't
//support interfaces at top level
module axis_cam_top #(
        parameter int DATA_WIDTH_BYTES = 1,
        parameter int KEY_WIDTH_BYTES = 6
    ) (
        input   wire                            i_clk,
        input   wire                            i_rst_n,


        //Input stream
        output  wire                            o_s_tready,
        input   wire                            i_s_tvalid,
        input   wire                            i_s_tlast,
        input   wire [
            DATA_WIDTH_BYTES*8
          + KEY_WIDTH_BYTES*8 - 1:0]            i_s_tdata,
        input   wire [2:0]                      i_s_tuser,
        input   wire [7:0]                      i_s_tid,
        
        //Output stream
        input   wire                            i_m_tready,
        output  wire                            o_m_tvalid,
        output  wire                            o_m_tlast,
        output  wire [
            DATA_WIDTH_BYTES*8
          + KEY_WIDTH_BYTES*8 - 1:0]            o_m_tdata,
        output  wire [2:0]                      o_m_tuser,
        output  wire [7:0]                      o_m_tid
        
        //Rest of the DUT signals, passed through

    );

    axis_cam_if #(
        .DATA_WIDTH(DATA_WIDTH_BYTES),
        .KEY_WIDTH(KEY_WIDTH_BYTES),
        .TID_WIDTH(8)) input_if();
    axis_cam_if #(
        .DATA_WIDTH(DATA_WIDTH_BYTES),
        .KEY_WIDTH(KEY_WIDTH_BYTES),
        .TID_WIDTH(8)) output_if();
    
    assign o_s_tready = input_if.ready;
    always_comb input_if.valid = i_s_tvalid;
    always_comb input_if.last = i_s_tlast;
    always_comb input_if.data = i_s_tdata;
    always_comb input_if.id = i_s_tid;
    always_comb input_if.user = i_s_tuser;
    
    always_comb output_if.ready = i_m_tready;
    assign o_m_tvalid = output_if.valid;
    assign o_m_tuser = output_if.user;
    assign o_m_tdata = output_if.data;
    assign o_m_tid = output_if.id;
    assign o_m_tlast = output_if.last;

    axis_cam #() axis_cam_u (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_slave_ready(1'b1),
        .slave_axis(input_if),
        .master_axis(output_if)
    );

endmodule

`resetall
