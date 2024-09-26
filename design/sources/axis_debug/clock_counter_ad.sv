`default_nettype none
`timescale 1ns / 1ps

module clock_counter_ad #(
        parameter logic [7:0] AXIS_DEVICE_TYPE      = 8'haa,
        parameter logic [7:0] AXIS_DEVICE_ID        = 8'h55
    ) (
        input wire                                  i_clk,
        input wire                                  i_clk_extern,
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
        output wire                                 o_m_axis_tlast
    );


    
    axis_debug_decoder #(
        .AXIS_DEVICE_TYPE(AXIS_DEVICE_TYPE),
        .AXIS_DEVICE_ID(AXIS_DEVICE_ID),
        .ADDR_WIDTH_BYTES(1),
        .DATA_WIDTH_BYTES(8)) 
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
        .o_rw_address(rw_address),
        .i_read_data(read_data),
        .o_write_data(write_data),

        .o_read_request(read_request),
        .o_write_request(write_request),
        .i_output_valid(output_valid_q));
    

    logic [7:0]     rw_address;
    logic [63:0]    read_data;
    logic [63:0]    write_data;

    logic           read_request;
    logic           write_request;
    logic           output_valid_q;
    
    logic           latch_counters;
    logic           counter_valid;

    logic [63:0]    clk_local_counter;
    logic [63:0]    clk_extern_counter;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            output_valid_q <= 1'b0;
            latch_counters <= 1'b0;
        end else begin
            output_valid_q <= 1'b0;
            //Release the latch signal, so that we may start the counters
            //again
            latch_counters <= 1'b0;
            case (rw_address)
                0: begin
                    if (write_request) begin
                        latch_counters <= 1'b1;
                        output_valid_q <= 1'b1;
                    end
                    if (read_request) begin
                        read_data <= 64'(counter_valid);
                        output_valid_q <= 1'b1;
                    end
                end
                1: begin
                    if (write_request) begin
                        output_valid_q <= 1'b1;
                    end
                    if (read_request) begin
                        read_data <= clk_local_counter;
                        output_valid_q <= 1'b1;
                    end
                end
                2: begin
                    if (write_request) begin
                        output_valid_q <= 1'b1;
                    end
                    if (read_request) begin
                        read_data <= clk_extern_counter;
                        output_valid_q <= 1'b1;
                    end
                end
                default: begin 
                    output_valid_q <= 1'b1;
                    read_data <= 64'd0;
                end
            endcase
        end
    end

    clock_counter #(
        .CLOCK_COUNTER_WIDTH(64))
    clock_counter_u (
        .i_clk_local(i_clk),
        .i_rst_n(i_rst_n),
        .i_clk_extern(i_clk_extern),
        
        .i_latch_counters(latch_counters),
        //Cleared on 'i_latch_counters', set when new values are valid and
        //loaded
        .o_counter_valid(counter_valid),

        .o_clk_local_counter(clk_local_counter),
        .o_clk_extern_counter(clk_extern_counter)
    );

endmodule
