`default_nettype none
`timescale 1ns / 1ps


//The address here is 2 bytes, and is structured as: {0, 7'(slave_address),8'(register_address)}
module i2c_master_ad #(
        parameter logic [7:0] AXIS_DEVICE_ID        = 8'h01,
        parameter int         CLOCK_SPEED           = 20_000_000,
        parameter int         I2C_SPEED_BPS         = 100_000
    ) (
        input wire                                  i_clk,
        input wire                                  i_rst_n,

        input  wire                                 i_sda,
        input  wire                                 i_scl,
        
        output wire                                 o_sda,
        output wire                                 o_scl,

        //Slave debug interface
        input  wire                                 i_s_axis_tvalid,
        output wire                                 o_s_axis_tready,
        input  wire  [7:0]                          i_s_axis_tdata,
        input  wire                                 i_s_axis_tlast,
       
        //Master debug interface
        output wire                                 o_m_axis_tvalid,
        input  wire                                 i_m_axis_tready,
        output wire  [7:0]                          o_m_axis_tdata,
        output wire                                 o_m_axis_tlast
    );

//Defines *_DEVICE_TYPE variables 
`include "axis_debug_device_types.sv"
    localparam AXIS_DEVICE_TYPE = I2C_MASTER_DEVICE_TYPE;
    
    axis_debug_decoder #(
        .AXIS_DEVICE_TYPE(AXIS_DEVICE_TYPE),
        .AXIS_DEVICE_ID(AXIS_DEVICE_ID),
        .ADDR_WIDTH_BYTES(2),
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
    
    logic [15:0] ad_rw_address;
    logic [7:0]  ad_read_data;
    logic [7:0]  ad_write_data;
    logic        ad_read_request;
    logic        ad_write_request;
    logic        ad_output_valid;


    logic       i2c_we;
    logic       i2c_re;
    logic [7:0] i2c_rw_address;
    logic [7:0] i2c_write_data;
    logic [6:0] i2c_slave_address;
    logic [7:0] i2c_read_data;
    logic       i2c_ready;
    logic       i2c_ready_q;

    always_comb ad_read_data = i2c_read_data;
    
    logic       can_read;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            i2c_ready_q <= 1'b0;
            can_read <= 1'b0;
        end else begin
            i2c_ready_q <= i2c_ready;
            ad_output_valid <= {i2c_ready, i2c_ready_q} == 2'b10;
            if (ad_output_valid) begin
                can_read <= 1'b1;
            end
            i2c_we <= 1'b0;
            i2c_re <= 1'b0;
            if (ad_write_request && can_read) begin
                i2c_slave_address <= ad_rw_address[14:8];
                i2c_rw_address    <= ad_rw_address[7 :0];
                i2c_write_data    <= ad_write_data;
                i2c_we            <= 1'b1;
                can_read          <= 1'b0;
            end
            if (ad_read_request && can_read) begin
                i2c_slave_address <= ad_rw_address[14:8];
                i2c_rw_address    <= ad_rw_address[7 :0];
                i2c_re            <= 1'b1;
                can_read          <= 1'b0;
            end
        end
    end

    i2c_master #(
        .I2C_SPEED_BPS(I2C_SPEED_BPS),
        .CLOCK_SPEED(CLOCK_SPEED))
    i2c_master_u (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_write_enable(i2c_we),
        .i_read_enable(i2c_re),

        .i_rw_address(i2c_rw_address),
        .i_write_data(i2c_write_data),
        .i_slave_address(i2c_slave_address),
        .o_read_data(i2c_read_data),

        .o_ready(i2c_ready),

        .i_sda(i_sda),
        .i_scl(i_scl),

        .o_sda(o_sda),
        .o_scl(o_scl)
    );

endmodule
