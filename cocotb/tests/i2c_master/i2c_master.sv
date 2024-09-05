`default_nettype none
`timescale 1ns / 1ps

//Usage:
//
//
module i2c_master #(
    ) (
        input wire i_clk,
        input wire i_rst_n,

        input  wire i_sda1,
        output wire o_sda1,  //o_sda == 1 means we set tristate to 'Z'
        input  wire i_scl1,   
        output wire o_scl1,   

        input  wire i_sda2,
        output wire o_sda2,  //o_sda == 1 means we set tristate to 'Z'
        input  wire i_scl2,   
        output wire o_scl2   
    );
    

    assign o_sda2 = i_sda2 & i_sda1;
    assign o_scl2 = i_scl1 & i_scl2;
    
    assign o_sda1 = i_sda2 & i_sda1;
    assign o_scl1 = i_scl2 & i_scl1;

endmodule
