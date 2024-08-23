`default_nettype none
`timescale 1ns/1ps

//Receives bytes on UART, and translates them into AXI-4 stream packets
//Each packet received will always look like:
//      1-byte : packet length
//      n-bytes: packet data
// ???  1-byte : packet data checksum
//


module uart_packet_rx #(
        parameter CLOCK_FREQUENCY = 1_000_000,
        parameter UART_BAUD_RATE = 115_200,
        parameter MAX_PACKET_LENGTH_BYTES = 16
        //Put something in here     
    ) (
        input wire i_clk,
        input wire i_uart_rx,
        input wire i_rst_n,

        output wire       o_m_axis_tvalid,
        input wire        i_m_axis_tready,
        output wire [7:0] o_m_axis_tdata,
        output wire       o_m_axis_tlast,
        output wire       o_m_axis_tstrb,
        output wire       o_m_axis_tkeep,
        output wire       o_m_axis_tid,
        output wire       o_m_axis_tdest,
        output wire       o_m_axis_tuser
    );

    //We don't use the full axis interface as we're only 1-byte wide, so set
    //sane defaults
    assign o_m_axis_tuser = 1'b0;
    assign o_m_axis_tdest = 1'b0;
    assign o_m_axis_tid   = 1'b0;
    assign o_m_axis_tstrb = 1'b0;
    assign o_m_axis_tkeep = 1'b1;

    //States:
    //  IDLE:       Waiting for a byte to come in on the UART. This is the start of
    //              a packet. Read it's length. If length == 0, ignore it.
    //  RECEIVING:  Read N bytes into packet_data from the UART
    //  WRITING:    Write the packet over AXI
    localparam PACKET_LENGTH_BYTES_WIDTH = $clog2(MAX_PACKET_LENGTH_BYTES);

    logic uart_rx_enable;
    logic [7:0] uart_rx_data;

    uart_rx #(   
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(UART_BAUD_RATE))
    uart_rx_inst (
        .i_clk(i_clk),
        .i_uart_rx(i_uart_rx),
        .i_rst_n(i_rst_n),

        .o_rx_data(uart_rx_data),
        .o_rx_en(uart_rx_enable));

    
    logic [MAX_PACKET_LENGTH_BYTES-1:0][7:0] packet_data;

    logic [PACKET_LENGTH_BYTES_WIDTH:0] current_packet_length;
    logic [PACKET_LENGTH_BYTES_WIDTH:0] max_packet_length;


    logic [7:0] m_axis_tdata_q;
    logic       m_axis_tlast_q;
    logic       m_axis_tvalid_q;

    assign o_m_axis_tdata = m_axis_tdata_q;
    assign o_m_axis_tlast = m_axis_tlast_q;
    assign o_m_axis_tvalid = m_axis_tvalid_q;

    typedef enum {IDLE, RECV, WRITE, WRITE_TLAST} t_state;

    t_state current_state_q;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        m_axis_tvalid_q <= 1'b0;
        m_axis_tlast_q <= 1'b0;

        if (!i_rst_n) begin
            //Reset values
            current_state_q <= IDLE;
        end else begin
            case (current_state_q)
                IDLE: begin: state_idle_logic
                    if (uart_rx_enable) begin
                        current_state_q <= RECV;
                        if (uart_rx_data > MAX_PACKET_LENGTH_BYTES) begin
                            $error("Received packet has length longer than MAX_PACKET_LENGTH_BYTES");
                        end
                        max_packet_length <= uart_rx_data[PACKET_LENGTH_BYTES_WIDTH:0];
                        current_packet_length <= 0;
                    end
                end
                RECV: begin: state_recv_logic
                    if (uart_rx_enable) begin
                        packet_data[current_packet_length] = uart_rx_data;
                        
                        //Change to 'writing' state and write out
                        //packet on AXI-S
                        if (current_packet_length == max_packet_length-1) begin
                            current_packet_length <= 1;
                            current_state_q <= WRITE;
                            //Register the packet data, so on next clock cycle
                            //it is already valid to be read
                            m_axis_tdata_q <= packet_data[0];
                        end else begin
                            current_packet_length <= current_packet_length + 1'b1;
                        end
                    end
                end
                WRITE: begin
                    m_axis_tvalid_q <= 1'b1;
                    m_axis_tlast_q <= 1'b0; 
                    //If we're transmitting, and the receiver is ready,
                    //then that's a valid write.
                    if (i_m_axis_tready && m_axis_tvalid_q) begin
                        m_axis_tdata_q <= packet_data[current_packet_length];
                        current_packet_length <= current_packet_length + 1'b1;
                        if (current_packet_length == max_packet_length - 1) begin
                            current_state_q <= WRITE_TLAST;
                            m_axis_tlast_q <= 1'b1;
                        end
                    end
                end
                WRITE_TLAST: begin
                    m_axis_tvalid_q <= 1'b1;       
                    m_axis_tlast_q <= 1'b1; 
                    //If we're transmitting, and the receiver is ready,
                    //then that's a valid write.
                    if (i_m_axis_tready && m_axis_tvalid_q) begin
                        current_state_q <= IDLE;
                        m_axis_tlast_q <= 1'b0;
                        m_axis_tvalid_q <= 1'b0;       
                    end
                end
                
                default: $error("Unreachable state");
            endcase
        end
    end

endmodule
