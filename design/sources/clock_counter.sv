`default_nettype none
`timescale 1ns / 1ps

//  counters are latchend and reset on i_latch_counters
//  counters presented are valid if o_counter_valid
//  EXTERNAL_FREQUENCY = (LOCAL_FREQUENCY) * EXTERNAL_COUNTER / LOCAL_COUNTER
module clock_counter #(
        //Devices are uniquely defined by AXI_BUS_TYPE_ID and
        //AXI_BUS_DEVICE_ID
        parameter AXI_BUS_DEVICE_ID = 8'h01,
        parameter CLOCK_COUNTER_WIDTH = 64
    ) (
        input wire i_clk_local,
        input wire i_rst_n,
        
        input wire i_clk_extern,
        
        input wire i_latch_counters,
        //Cleared on 'i_latch_counters', set when new values are valid and
        //loaded
        output wire o_counter_valid,
        output wire [CLOCK_COUNTER_WIDTH-1:0] o_clk_local_counter,
        output wire [CLOCK_COUNTER_WIDTH-1:0] o_clk_extern_counter
    );
    typedef enum logic [1:0] {RUNNING, LOAD_EXTERN, LOAD_DEASSERT, RESET_DEASSERT} state_t;

    state_t fsm_state_local;
    
    //If there has been at least one clock pulse on the external clock domain
    //since we reset the counters. If false, we don't even bother reading the
    //register, as we could not resync into that domain (due to no clock
    //present)
    logic clock_present_extern;

    //The registered versions by i_clk of the two clock counters
    logic [CLOCK_COUNTER_WIDTH-1:0] clk_local_counter_local_q;
    logic [CLOCK_COUNTER_WIDTH-1:0] clk_extern_counter_local_q;

    logic counter_valid_local_q;

    assign o_counter_valid = counter_valid_local_q;

    assign o_clk_local_counter = clk_local_counter_local_q;
    assign o_clk_extern_counter = clk_extern_counter_local_q;

    always_ff @(posedge i_clk_local or negedge i_rst_n) begin
        if (!i_rst_n) begin
            clk_counter_reset_local <= 1'b1;
            fsm_state_local <= RESET_DEASSERT;
        end else begin
            case (fsm_state_local)
                RUNNING: begin
                    if (i_latch_counters) begin
                        fsm_state_local <= LOAD_EXTERN;
                        clk_local_counter_local_q <= clk_counter_local;
                        clk_counter_latch_local <= 1'b1;
                        counter_valid_local_q <= 1'b0;
                    end
                end
                LOAD_EXTERN: begin
                    if (!clock_present_extern) begin
                        //$error("We don't have an external clock present to monitor. Need to reset the counters to 0");
                        clk_extern_counter_local_q <= 64'b0;
                        clk_counter_latch_local <= 1'b0;
                        fsm_state_local <= LOAD_DEASSERT;
                    end else begin
                        if (clk_counter_latch_ack_local) begin
                            //We are guaranteed to have stopped the clock at
                            //this point, as it's gated by
                            //clk_counter_latch_extern, that's been resync'd here. 
                            clk_extern_counter_local_q <= clk_counter_extern_handshake_out;
                            clk_counter_latch_local <= 1'b0;
                            fsm_state_local <= LOAD_DEASSERT;
                        end
                    end
                end
                LOAD_DEASSERT: begin
                    if (!clk_counter_latch_ack_local) begin
                        clk_counter_reset_local <= 1'b1;
                        fsm_state_local <= RESET_DEASSERT;
                    end
                end
                RESET_DEASSERT: begin
                    if (!clk_counter_reset_ack_local) begin
                        clk_counter_reset_local <= 1'b0;
                        counter_valid_local_q <= 1'b1;
                        fsm_state_local <= RUNNING;
                    end
                end
                default: $error("Unreachable");   
            endcase
        end
    end
    
    //TODO FIXME
    always_comb clock_present_extern = 1'b1;
    
    //TODO with a slow ext clock, the ext counter isn't reset????
    

    //Resync back and forward for reset
    logic clk_counter_reset_ack_local;
    handshake_resync
    handshake_resync_counter_reset_u (
        .i_send_clk(i_clk_local),
        .i_recv_clk(i_clk_extern),
        .i_rst_n(i_rst_n),
        .i_valid(clk_counter_reset_local),
        .o_valid(clk_counter_reset_extern),

        .i_ack(clk_counter_reset_extern),
        .o_ack(clk_counter_reset_ack_local)
    );

    //Resync back and forward for counter latch
    logic clk_counter_latch_ack_local;
    logic [CLOCK_COUNTER_WIDTH-1:0] clk_counter_extern_handshake_out;
    handshake_data_resync #(.DATA_WIDTH(CLOCK_COUNTER_WIDTH)) 
    handshake_data_resync_counter_latch_u (
        .i_send_clk(i_clk_local),
        .i_recv_clk(i_clk_extern),
        .i_rst_n(i_rst_n),
        .i_valid(clk_counter_latch_local),
        .o_valid(clk_counter_latch_extern),

        .i_ack(clk_counter_latch_extern),
        .o_ack(clk_counter_latch_ack_local),

        .i_data(clk_counter_extern),
        .o_data(clk_counter_extern_handshake_out)
    );
    


    //local domain
    logic [CLOCK_COUNTER_WIDTH-1:0] clk_counter_local;
    logic clk_counter_latch_local;
    logic clk_counter_reset_local;
    logic clk_counter_reset_local_q;

    always_ff @(posedge i_clk_local) begin
        clk_counter_reset_local_q <= clk_counter_reset_local;
        if (clk_counter_reset_local & !clk_counter_reset_local_q) begin
            clk_counter_local <= 0;
        end else begin
            if (!clk_counter_latch_local) begin
                //Not in reset AND not 'latch' -> operate normally
                clk_counter_local <= clk_counter_local + 1'b1;
            end
        end
    end

    //extern domain
    logic [CLOCK_COUNTER_WIDTH-1:0] clk_counter_extern;
    logic clk_counter_latch_extern;
    logic clk_counter_reset_extern;
    logic clk_counter_reset_extern_q;
   
    always_ff @(posedge i_clk_extern) begin
        clk_counter_reset_extern_q <= clk_counter_reset_extern;
        if (clk_counter_reset_extern & !clk_counter_reset_extern_q) begin
            clk_counter_extern <= 0;
        end else begin
            if (!clk_counter_latch_extern) begin
                //Not in reset AND not 'latch' -> operate normally
                clk_counter_extern <= clk_counter_extern + 1'b1;
            end
        end
    end

endmodule
