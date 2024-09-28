`timescale 1ns / 1ps
`default_nettype none

module eth_descrambler #(
        parameter int DATA_WIDTH = 16
    ) (
        input wire                      i_clk, 
        input wire                      i_rst_n,
        
        input  wire                     i_data_valid,
        output wire                     o_data_valid,

        input  wire [DATA_WIDTH-1:0]    i_data,
        output wire [DATA_WIDTH-1:0]    o_data,

        input   wire [1:0]              i_header,
        output  wire [1:0]              o_header,

        input   wire                    i_headervalid,
        output  wire                    o_headervalid
    );

    logic [57:0]            descrambler;
    logic [DATA_WIDTH-1:0]  output_data;
    logic                   output_data_valid;

    assign o_data       = output_data;
    assign o_data_valid = output_data_valid;

    logic [57:0]            new_descrambler_state;
    logic [DATA_WIDTH-1:0]  output_data_comb;
    
    logic [1:0]             header;
    logic                   headervalid;

    assign o_header = header;
    assign o_headervalid = headervalid;


    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            descrambler <= 58'h03FF_FFFF_FFFF_FFFF;    //2 ^ 58 - 1. Initalise to all ones 
        end else begin
            output_data_valid <= i_data_valid; 
            if (i_data_valid) begin
                descrambler <= new_descrambler_state;        
                output_data <= output_data_comb;
                if (i_headervalid) begin
                    //To stop needless toggling on the header pin
                    header <= i_header;
                end
                headervalid <= i_headervalid;
            end
        end
    end
    
    //The optimistic approach
    generate
        always_comb begin
            new_descrambler_state = descrambler;
            for (int i = 0; i < DATA_WIDTH; i++) begin
                output_data_comb[DATA_WIDTH-i-1] = i_data[DATA_WIDTH-i-1] ^ new_descrambler_state[38] ^ new_descrambler_state[57]; 
                new_descrambler_state = {new_descrambler_state[56:0], i_data[DATA_WIDTH-i-1]};
            end
        end
    endgenerate

endmodule

`resetall
