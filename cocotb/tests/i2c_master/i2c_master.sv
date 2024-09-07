`default_nettype none
`timescale 1ns / 1ps

//Usage:
//
//  inout io_sda
//      .I(1'b0),
//      .O(i_sda),
//      .E(o_sda)
//  


//Description:
//  - Does not support burst read
//  - 
module i2c_master #(
    ) (
        input wire i_clk,
        input wire i_rst_n,

        input  wire i_sda1,
        output wire o_sda1,  //o_sda == 1 means we set tristate to 'Z'
        input  wire i_scl1,   
        output wire o_scl1,  //o_scl1 == 1 means we set tristate to 'Z'  
    );

    

endmodule
