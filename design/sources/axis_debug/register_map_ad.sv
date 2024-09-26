`default_nettype none
`timescale 1ns / 1ps

module register_map_ad #(
        //Default to 'ff' as we treat this as 'unset'
        parameter logic [7:0] AXIS_DEVICE_ID                = 8'hff,
        parameter int         NUM_REGS                      = 256    
    ) (
        input wire                                  i_clk,
        input wire                                  i_rst_n,

        //Slave debug interface
        input  wire                                 i_s_axis_tvalid,
        output wire                                 o_s_axis_tready,
        input  wire  [7:0]                          i_s_axis_tdata,
        input  wire                                 i_s_axis_tlast,
       
        //Master debug interface
        output wire                                 o_m_axis_tvalid,
        input  wire                                 i_m_axis_tready,
        output wire  [7:0]                          o_m_axis_tdata,
        output wire                                 o_m_axis_tlast,

        output wire  [NUM_REGS-1:0] [7:0]           o_registers
    );

//Defines *_DEVICE_TYPE variables 
`include "axis_debug_device_types.sv"
    localparam AXIS_DEVICE_TYPE = REGISTER_MAP_DEVICE_TYPE;
    
    axis_debug_decoder #(
        .AXIS_DEVICE_TYPE(AXIS_DEVICE_TYPE),
        .AXIS_DEVICE_ID(AXIS_DEVICE_ID),
        .ADDR_WIDTH_BYTES(1),
        .DATA_WIDTH_BYTES(1)) 
    axis_debug_decoder_u (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),

        //Slave debug interface
        .i_s_axis_tvalid(i_s_axis_tvalid),
        .o_s_axis_tready(o_s_axis_tready),
        .i_s_axis_tdata(i_s_axis_tdata),
        .i_s_axis_tlast(i_s_axis_tlast),
       
        //Master debug interface
        .o_m_axis_tvalid(o_m_axis_tvalid),
        .i_m_axis_tready(i_m_axis_tready),
        .o_m_axis_tdata(o_m_axis_tdata),
        .o_m_axis_tlast(o_m_axis_tlast),
    
        //Interface to module
        //Set address, set 'read_request' or 'write_request' high
        //wait for i_output_valid -> set 'read_request' and 'write_request'
        //low (or change address and read again)
        .o_rw_address(ad_rw_address),
        .i_read_data(ad_read_data),
        .o_write_data(ad_write_data),

        .o_read_request(ad_read_request),
        .o_write_request(ad_write_request),
        .i_output_valid(ad_output_valid));
    
    logic [7:0] ad_rw_address;
    logic [7:0]  ad_read_data;
    logic [7:0]  ad_write_data;
    logic        ad_read_request;
    logic        ad_write_request;
    logic        ad_output_valid;

    logic [NUM_REGS-1:0] [7:0] memory;

    assign o_registers = memory;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
        end else begin
            if (ad_read_request && !ad_output_valid) begin
                ad_output_valid <= 1'b1;
                if (ad_rw_address < NUM_REGS) begin
                    ad_read_data <= memory[ad_rw_address];
                end else begin
                    ad_read_data <= 8'h00;
                    ad_output_valid <= 1'b1; 
                end
            end
            if (ad_write_request && !ad_output_valid) begin
                ad_output_valid <= 1'b1;
                if (ad_rw_address < NUM_REGS) begin
                    memory[ad_rw_address] <= ad_write_data;
                end
            end
            //Reset once we have ad_output_vaild AND a read/write request
            if (ad_output_valid && (ad_read_request || ad_write_request)) begin
                ad_output_valid <= 1'b0;
            end
        end
    end

endmodule
