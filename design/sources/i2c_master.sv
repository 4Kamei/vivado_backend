`resetall
`timescale 1ns/1ps
`default_nettype none

//o_sda should be connected to the enable of a tristate buffer that as input
//XILINX:
//  
//  OBUFT OBUFT_u 
//  (
//      .I(1'b0),
//      .T(~o_sda),  //T is active-low
//      .O(i_sda)
//      .IO(PAD)
//  );
//
//  To drive a 1, we actually drive 'Z'
//  To drive a 0, we drive '0'
//
//

//Does not support address auto increment
module i2c_master #(
        parameter int I2C_SPEED_BPS = 100_000,
        parameter int CLOCK_SPEED   = 20_000_000
    ) (
        input  wire         i_clk,
        input  wire         i_rst_n,

        input  wire         i_write_enable,
        input  wire         i_read_enable,
        
        input  wire [7:0]   i_rw_address,
        input  wire [7:0]   i_write_data,
        input  wire [6:0]   i_slave_address,

        output wire [7:0]   o_read_data,

        output wire         o_ready,
        
        input  wire         i_sda,
        input  wire         i_scl,

        output wire         o_sda,
        output wire         o_scl
    );

    

    typedef enum logic [4:0] {
        IDLE,
        
        //Sending a write packet
        WRITE_START, 
        WRITE_SLV_ADDR,
        WRITE_BIT,
        WRITE_SLV_ADDR_ACK,         //Slave to master
        WRITE_REG_ADDR,
        WRITE_REG_ADDR_ACK,         //Slave to master
        WRITE_DATA,
        WRITE_DATA_ACK,             //Slave to master
        WRITE_STOP_CONDITION_PRE,
        WRITE_STOP_CONDITION,

        //Sending a read packet
        READ_OUT_START,             
        READ_OUT_SLV_ADDR,
        READ_OUT_BIT,               
        READ_OUT_SLV_ADDR_ACK,      //Slave to master
        READ_OUT_REG_ADDR,       
        READ_OUT_REG_ADDR_ACK,      //Slave to master
        READ_OUT_STOP_CONDITION_PRE,
        READ_OUT_STOP_CONDITION,
        
        //Read packet reply receive
        READ_IN_START, 
        READ_IN_SLV_ADDR,
        READ_IN_BIT,
        READ_IN_SLV_ADDR_ACK,       //Slave to master
        READ_IN_DATA,               //Slave to master
        READ_IN_DATA_NACK,
        READ_IN_STOP_CONDITION_PRE,
        READ_IN_STOP_CONDITION
    } fsm_state_t /*verilator public */;

    localparam int CLK_COUNTER_WIDTH = 25;

    logic   [CLK_COUNTER_WIDTH-1:0]  i2c_clk_counter;

    localparam real  COUNTER_MAX_VALUE = $pow(2, CLK_COUNTER_WIDTH) - 1;
    localparam int   CLOCKS_PER_BAUD   = CLOCK_SPEED / I2C_SPEED_BPS; 
    localparam int   COUNTER_INCREMENT_VALUE = $rtoi((COUNTER_MAX_VALUE * I2C_SPEED_BPS) / CLOCK_SPEED);
    localparam logic [CLK_COUNTER_WIDTH-1:0] COUNTER_INCR = COUNTER_INCREMENT_VALUE[CLK_COUNTER_WIDTH-1:0];

    if (COUNTER_INCREMENT_VALUE[31:CLK_COUNTER_WIDTH-2] != 0) begin
        $error("COUNTER_INCREMENT_VALUE is too large. Need to edit COUNTER_MAX_VALUE and i2c_clk_counter width to accurately represent this");
    
    end

    logic [1:0] counter_top_bits_prev;
    logic [1:0] counter_top_bits;

    always_comb counter_top_bits = i2c_clk_counter[CLK_COUNTER_WIDTH-1-:2];
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            i2c_clk_counter <= 0;
            counter_top_bits_prev <= 2'b00;
        end else begin
            if (fsm_state == IDLE && (i_write_enable || i_read_enable)) begin
                i2c_clk_counter <= 0;
            end else if (fsm_state != IDLE) begin
                counter_top_bits_prev <= counter_top_bits;
                i2c_clk_counter <= i2c_clk_counter + COUNTER_INCR; 
            end
        end
    end

    logic           state_advance_en;
    logic           scl_high_en;
    logic           scl_low_en;
    
    //Enables for various things - Use the msb 2 bits to create enables,
    //because we want to things at 4X the clock of the I2C. These are
    //  scl_high_en     : setting SCL high
    //  scl_low_en      : setting SCL low
    //  state_advance_en: In the middle, between SCL low and SCL high, setting the next SDA data
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state_advance_en <= 1'b0;
            scl_high_en      <= 1'b0;
            scl_low_en       <= 1'b0;
        end else begin
            state_advance_en <= {counter_top_bits_prev, counter_top_bits} == 4'b1100;
            scl_high_en      <= {counter_top_bits_prev, counter_top_bits} == 4'b0001;
            scl_low_en       <= {counter_top_bits_prev, counter_top_bits} == 4'b1011;
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            scl_q <= 1'b1;
        end else begin
            if (fsm_state != WRITE_STOP_CONDITION && 
                fsm_state != READ_IN_STOP_CONDITION && 
                fsm_state != READ_OUT_STOP_CONDITION &&
                fsm_state != WRITE_START &&
                fsm_state != READ_IN_START &&
                fsm_state != READ_OUT_START) begin
                if (scl_low_en) begin
                    scl_q <= 1'b0;
                end
             end
             if (scl_high_en) begin
                scl_q <= 1'b1;
             end
        end
    end

    fsm_state_t fsm_state;
    logic   [4:0]   fsm_counter;

    logic   [6:0]   slave_address_q;
    logic   [7:0]   rw_address_q;
    logic   [7:0]   data_q;
    logic           ready_q;

    logic           sda_q;
    logic           scl_q;
    logic           sda_q_set;

    assign o_ready = ready_q;
    assign o_sda   = sda_q;
    assign o_scl   = scl_q;
    
    
    //Have 2 paths through the FSM, these are:
    //  
    //  IDLE -> WRITE_* -> IDLE
    //  IDLE -> READ_OUT_* -> READ_IN_* -> IDLE
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            fsm_state <= IDLE;
            ready_q <= 1'b0;
            sda_q <= 1'b1;
            sda_q_set <= 1'b0;
        end else begin
            case (fsm_state)
                IDLE: begin
                    sda_q <= 1'b1;
                    ready_q <= 1'b1;
                    if (i_write_enable) begin
                        slave_address_q <= i_slave_address;
                        rw_address_q <= i_rw_address;
                        data_q <= i_write_data;
                        ready_q <= 1'b0;
                        fsm_state <= WRITE_START;
                    end
                    if (i_read_enable) begin
                        slave_address_q <= i_slave_address;
                        rw_address_q <= i_rw_address;
                        ready_q <= 1'b0;
                        fsm_state <= READ_OUT_START;
                    end
                end
                WRITE_START: begin
                    if (state_advance_en) begin
                        fsm_state <= WRITE_SLV_ADDR;
                        fsm_counter <= 5'd6;
                        sda_q <= 1'b0;
                    end
                end 
                WRITE_SLV_ADDR: begin
                    if (state_advance_en) begin
                        sda_q <= slave_address_q[fsm_counter[2:0]];
                        fsm_counter <= fsm_counter - 1'b1;
                        if (fsm_counter == 0) begin
                            fsm_state <= WRITE_BIT;
                        end
                    end
                end
                WRITE_BIT: begin
                    if (state_advance_en) begin
                        sda_q <= 1'b0;
                        fsm_state <= WRITE_SLV_ADDR_ACK;
                    end
                end
                WRITE_SLV_ADDR_ACK: begin                //Slave to master
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        sda_q_set <= 1'b1;
                    end
                    if (scl_high_en && sda_q_set) begin
                        if (i_sda == 1'b0) begin
                            sda_q_set <= 1'b0;
                            fsm_state <= WRITE_REG_ADDR;
                            fsm_counter <= 5'd7;
                        end else begin
                            //SDA is high, we did not get an ACK
                            //TODO!! 
                            //FIXME!!
                            $error("Unimplemented WRITE_SLV_ADDR_ACK");
                        end
                    end
                end         
                WRITE_REG_ADDR: begin
                    if (state_advance_en) begin
                        sda_q <= rw_address_q[fsm_counter[2:0]];
                        fsm_counter <= fsm_counter - 1'b1;
                        if (fsm_counter == 0) begin
                            fsm_state <= WRITE_REG_ADDR_ACK;
                        end
                    end
                end
                WRITE_REG_ADDR_ACK: begin       //Slave to master
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        sda_q_set <= 1'b1;
                    end
                    if (scl_high_en && sda_q_set) begin
                        if (i_sda == 1'b0) begin
                            fsm_state <= WRITE_DATA;
                            fsm_counter <= 5'd7;
                            sda_q_set <= 1'b0;
                        end else begin
                            //SDA is high, we did not get an ACK
                            //TODO!! 
                            //FIXME!!
                            $error("Unimplemented WRITE_REG_ADDR_ACK");
                        end
                    end
                end
                WRITE_DATA: begin	
                    if (state_advance_en) begin
                        sda_q <= data_q[fsm_counter[2:0]];
                        fsm_counter <= fsm_counter - 1'b1;
                        if (fsm_counter == 0) begin
                            fsm_state <= WRITE_DATA_ACK;
                        end
                    end
                end
                WRITE_DATA_ACK: begin             //Slave to master
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        sda_q_set <= 1'b1;
                    end
                    if (scl_high_en && sda_q_set) begin
                        if (i_sda == 1'b0) begin
                            fsm_state <= WRITE_STOP_CONDITION_PRE;
                            fsm_counter <= 5'd7;
                            sda_q_set <= 1'b0;
                        end else begin
                            //SDA is high, we did not get an ACK
                            //TODO!! 
                            //FIXME!!
                            $error("Unimplemented WRITE_DATA_ACK");
                        end
                    end
                end
                WRITE_STOP_CONDITION_PRE: begin
                    if (state_advance_en) begin
                        sda_q <= 1'b0;
                        fsm_state <= WRITE_STOP_CONDITION;
                    end
                end
                WRITE_STOP_CONDITION: begin	
                    if (state_advance_en) begin
                        fsm_state <= IDLE;
                        sda_q <= 1'b1;
                    end
                end
                
                //READ PACKET
                READ_OUT_START: begin
                    if (state_advance_en) begin
                        fsm_state <= READ_OUT_SLV_ADDR;
                        fsm_counter <= 5'd6;
                        sda_q <= 1'b0;
                    end
                end 
                READ_OUT_SLV_ADDR: begin
                    if (state_advance_en) begin
                        sda_q <= slave_address_q[fsm_counter[2:0]];
                        fsm_counter <= fsm_counter - 1'b1;
                        if (fsm_counter == 0) begin
                            fsm_state <= READ_OUT_BIT;
                        end
                    end
                end
                READ_OUT_BIT: begin
                    if (state_advance_en) begin
                        sda_q <= 1'b0;
                        fsm_state <= READ_OUT_SLV_ADDR_ACK;
                    end
                end
                READ_OUT_SLV_ADDR_ACK: begin                //Slave to master
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        sda_q_set <= 1'b1;
                    end
                    if (scl_high_en && sda_q_set) begin
                        if (i_sda == 1'b0) begin
                            sda_q_set <= 1'b0;
                            fsm_state <= READ_OUT_REG_ADDR;
                            fsm_counter <= 5'd7;
                        end else begin
                            //SDA is high, we did not get an ACK
                            //TODO!! 
                            //FIXME!!
                            $error("Unimplemented READ_OUT_SLV_ADDR_ACK");
                        end
                    end
                end         
                READ_OUT_REG_ADDR: begin
                    if (state_advance_en) begin
                        sda_q <= rw_address_q[fsm_counter[2:0]];
                        fsm_counter <= fsm_counter - 1'b1;
                        if (fsm_counter == 0) begin
                            fsm_state <= READ_OUT_REG_ADDR_ACK;
                        end
                    end
                end
                READ_OUT_REG_ADDR_ACK: begin       //Slave to master
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        sda_q_set <= 1'b1;
                    end
                    if (scl_high_en && sda_q_set) begin
                        if (i_sda == 1'b0) begin
                            fsm_state <= READ_OUT_STOP_CONDITION_PRE;
                            fsm_counter <= 5'd7;
                            sda_q_set <= 1'b0;
                        end else begin
                            //SDA is high, we did not get an ACK
                            //TODO!! 
                            //FIXME!!
                            $error("Unimplemented READ_OUT_REG_ADDR_ACK");
                        end
                    end
                end
                READ_OUT_STOP_CONDITION_PRE: begin
                    if (state_advance_en) begin
                        sda_q <= 1'b0;
                        fsm_state <= READ_OUT_STOP_CONDITION;
                    end
                end
                READ_OUT_STOP_CONDITION: begin	
                    if (state_advance_en) begin
                        fsm_state <= READ_IN_START;
                        sda_q <= 1'b1;
                    end
                end

                //Second read packet
                READ_IN_START: begin
                    if (state_advance_en) begin
                        fsm_state <= READ_IN_SLV_ADDR;
                        fsm_counter <= 5'd6;
                        sda_q <= 1'b0;
                    end
                end 
                READ_IN_SLV_ADDR: begin
                    if (state_advance_en) begin
                        sda_q <= slave_address_q[fsm_counter[2:0]];
                        fsm_counter <= fsm_counter - 1'b1;
                        if (fsm_counter == 0) begin
                            fsm_state <= READ_IN_BIT;
                        end
                    end
                end
                READ_IN_BIT: begin
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        fsm_state <= READ_IN_SLV_ADDR_ACK;
                    end
                end
                READ_IN_SLV_ADDR_ACK: begin                //Slave to master
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        sda_q_set <= 1'b1;
                    end
                    if (scl_high_en && sda_q_set) begin
                        if (i_sda == 1'b0) begin
                            sda_q_set <= 1'b0;
                            fsm_state <= READ_IN_DATA;
                            fsm_counter <= 5'd7;
                        end else begin
                            //SDA is high, we did not get an ACK
                            //TODO!! 
                            //FIXME!!
                            $error("Unimplemented READ_IN_SLV_ADDR_ACK");
                        end
                    end
                end         
                READ_IN_DATA: begin
                    if (state_advance_en) begin 
                        data_q[fsm_counter[2:0]] <= i_sda;
                        fsm_counter <= fsm_counter - 1'b1;
                        if (fsm_counter == 0) begin
                            fsm_state <= READ_IN_DATA_NACK;
                        end
                    end
                end
                READ_IN_DATA_NACK: begin       //Slave to master
                    if (state_advance_en) begin
                        sda_q <= 1'b1;
                        fsm_state <= READ_IN_STOP_CONDITION_PRE;
                    end
                end
                READ_IN_STOP_CONDITION_PRE: begin
                    if (state_advance_en) begin
                        sda_q <= 1'b0;
                        fsm_state <= READ_IN_STOP_CONDITION;
                    end
                end
                READ_IN_STOP_CONDITION: begin	
                    if (state_advance_en) begin
                        fsm_state <= IDLE;
                        sda_q <= 1'b1;
                    end
                end


                default: $error("Unreachable");
            endcase
        end
    end

endmodule;
