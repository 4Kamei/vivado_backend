`resetall
`default_nettype none
`timescale 1ns / 1ps

//There are only two resyncs in this module (and hopefully assertions in the
//future). The purpose is to be easily found in the design and constrained
//correctly
//
(* DONT_TOUCH = "yes" *)
module handshake_resync (
        input  wire                     i_send_clk,
        input  wire                     i_recv_clk,

        input  wire                     i_rst_n,

        input  wire                     i_valid,
        output wire                     o_valid,

        input  wire                     i_ack,
        output wire                     o_ack
    );

    //set i_valid -> don't change i_data
    //wait for o_valid -> read o_data + set i_ack
    //wait for o_ack -> lower i_valid, can change data


    dual_ff_resync #(.RESET_VALUE(1'b0))
    dual_ff_resync_valid_u (
        .i_clk(i_recv_clk),
        .i_rst_n(i_rst_n),
        .i_signal(i_valid),
        .o_signal(o_valid)
    );

    dual_ff_resync #(.RESET_VALUE(1'b0))
    dual_ff_resync_ack_u (
        .i_clk(i_send_clk),
        .i_rst_n(i_rst_n),
        .i_signal(i_ack),
        .o_signal(o_ack)
    );

endmodule

`resetall
