`timescale 1ns/1ps
`default_nettype none

//Reads in packets as AXIS, counts the number of items in the packet.
//Transmits the packet length, then transmits the actual packet
module uart_packet_tx #(
        parameter AXIS_TDATA_WIDTH = 8,
        parameter MAXIMUM_PACKET_LEN = 16,
        parameter CLOCK_FREQUENCY = 20_000_000,
        parameter BAUD_RATE = 1_000_000
    ) (
        input wire i_clk,
        input wire i_rst_n,
        output wire o_uart_tx,
    
        input  wire                         i_s_axis_tvalid,
        output wire                         o_s_axis_tready,
        input  wire [AXIS_TDATA_WIDTH-1:0]  i_s_axis_tdata,  
        input  wire                         i_s_axis_tlast,  
        input  wire                         i_s_axis_tstrb,  //Ignored
        input  wire                         i_s_axis_tkeep,
        input  wire                         i_s_axis_tid,    //Ignored
        input  wire                         i_s_axis_tdest,  //Ignored
        input  wire                         i_s_axis_tuser   //Ignored
    );
    
    //IDLE    : ?
    //RECV    : o_s_axis_tready-> we're collecting packets waiting for tlast
    //TX_LEN  : we've received tlast, transmit the length of the packet
    //TX      : we've transmitted the len, now transmit the rest of the packet
    uart_tx #(
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(BAUD_RATE))
    uart_tx_inst (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_tx_en(uart_tx_en),
        .i_tx_data(uart_tx_data),
        .o_uart_tx(o_uart_tx),
        .o_uart_busy(uart_tx_busy));

    logic uart_tx_en;
    logic uart_tx_busy;
    logic [7:0] uart_tx_data;

    typedef enum [1:0] {RECV, TX_LEN, TX_LEN_FIN, TX} state_t;  

    assign o_s_axis_tready = o_s_axis_tready_q;
    state_t state;

    logic [$clog2(MAXIMUM_PACKET_LEN)-1:0] packet_rw_ptr;
    logic [$clog2(MAXIMUM_PACKET_LEN)-1:0] packet_len;
    //Implement as distributed ram?
    logic [MAXIMUM_PACKET_LEN-1:0] [AXIS_TDATA_WIDTH-1:0] packet_memory;
    logic o_s_axis_tready_q;   

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= RECV;
            o_s_axis_tready_q <= 1'b0;
            packet_rw_ptr <= 0;
            packet_len <= 0;
        end else begin
            case (state)
                RECV: begin
                    o_s_axis_tready_q <= 1'b1;
                    if (i_s_axis_tvalid && i_s_axis_tkeep && o_s_axis_tready_q) begin
                        packet_memory[packet_rw_ptr] = i_s_axis_tdata;  
                        if (i_s_axis_tlast) begin
                            packet_len <= packet_rw_ptr + 1'b1;
                            packet_rw_ptr <= 0;
                            state <= TX_LEN;
                            o_s_axis_tready_q <= 1'b0;
                        end else begin
                            packet_rw_ptr <= packet_rw_ptr + 1'b1;
                        end
                    end
                end
                TX_LEN: begin
                    if (!uart_tx_busy) begin
                        uart_tx_data <= {{8-$clog2(MAXIMUM_PACKET_LEN){1'b0}}, packet_len};
                        uart_tx_en <= 1'b1;
                    end else begin
                        state <= TX_LEN_FIN;
                        uart_tx_en <= 1'b0;
                    end
                end
                TX_LEN_FIN: begin
                    if (!uart_tx_busy) begin
                        state <= TX;
                    end
                end
                TX: begin
                    if (!uart_tx_busy & !uart_tx_en) begin
                        if (packet_rw_ptr == packet_len) begin
                            state <= RECV;
                            packet_rw_ptr <= 0;
                            packet_len <= 0;
                            uart_tx_en <= 1'b0;
                        end else begin
                            uart_tx_data <= packet_memory[packet_rw_ptr];
                            packet_rw_ptr <= packet_rw_ptr + 1'b1;
                            uart_tx_en <= 1'b1;
                        end
                    end else begin
                        uart_tx_en <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
