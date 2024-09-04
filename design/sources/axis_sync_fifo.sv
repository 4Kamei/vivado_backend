`default_nettype none
`timescale 1ns / 1ps


//Counts the size of packets coming into the fifo. Keeps all bytes, including
//ones where tkeep == 0.
//Fifo is not fall-through

module axis_sync_fifo #(
        parameter AXIS_TDATA_WIDTH = 8,
        parameter AXIS_FIFO_DEPTH = 4
    ) (
        input wire i_clk,
        input wire i_rst_n,

        //Master interface, out of the fifo
        output wire                         o_m_axis_tvalid,
        input  wire                         i_m_axis_tready,
        output wire [AXIS_TDATA_WIDTH-1:0]  o_m_axis_tdata,
        output wire                         o_m_axis_tlast,
        output wire                         o_m_axis_tstrb,
        output wire                         o_m_axis_tkeep,
        output wire                         o_m_axis_tid,
        output wire                         o_m_axis_tdest,
        output wire                         o_m_axis_tuser,
        
        //Slave interface, into the fifo
        input  wire                         i_s_axis_tvalid,
        output wire                         o_s_axis_tready,
        input  wire [AXIS_TDATA_WIDTH-1:0]  i_s_axis_tdata,
        input  wire                         i_s_axis_tlast,
        input  wire                         i_s_axis_tstrb,
        input  wire                         i_s_axis_tkeep,
        input  wire                         i_s_axis_tid,
        input  wire                         i_s_axis_tdest,
        input  wire                         i_s_axis_tuser
    );
    //Length needs to be a power of two as this simplifies the wrap-around
    //logic greatly
    localparam AXIS_FIFO_DEPTH_BITWIDTH = $clog2(AXIS_FIFO_DEPTH);
    localparam AXIS_FIFO_DEPTH_ROUNDED = $pow(2, AXIS_FIFO_DEPTH_BITWIDTH);
    if (AXIS_FIFO_DEPTH_ROUNDED != AXIS_FIFO_DEPTH) begin
        $error("AXIS_FIFO_DEPTH is not a multpile of 2");
    end;

    localparam FIFO_INPUT_WIDTH = AXIS_TDATA_WIDTH + 1     + 1    + 1    + 1    + 1    + 1; 
    //Need to concatenate:          tdata,          tkeep, tstrb, tid, tdest, tuser, tlast       as these all
    //belong together. Store them in one line of the memory in the fifo, then
    //when reading data, just read these signals out again.
    logic [FIFO_INPUT_WIDTH-1: 0] fifo_input_data; 

    always_comb fifo_input_data = {
        i_s_axis_tkeep, 
        i_s_axis_tstrb, 
        i_s_axis_tid, 
        i_s_axis_tdest, 
        i_s_axis_tuser,
        i_s_axis_tlast,
        i_s_axis_tdata};
   
    assign {
        o_m_axis_tkeep, 
        o_m_axis_tstrb, 
        o_m_axis_tid, 
        o_m_axis_tdest, 
        o_m_axis_tuser,
        o_m_axis_tlast,
        o_m_axis_tdata} = output_buffer_valid ? output_buffer : memory_read_data;

    //When read_ptr == write_ptr, fifo is empty
    //When write_ptr + 1 == read_ptr, fifo is full
    logic [AXIS_FIFO_DEPTH_BITWIDTH-1:0] fifo_read_ptr;
    logic [AXIS_FIFO_DEPTH_BITWIDTH-1:0] fifo_write_ptr;

    //May want to do this?           
    // RAMB18E1 #( 
    //     .RDADDR_COLLISION_HWCONFIG("PERFORMANCE"),  //Same-clock for read and write, and guaranteed to not have overlapping addresses
    //     .SIM_CHECK_COLLISION("ALL"),                //Yes, always check in sim
    //     .DOA_REG(0),                                //Disable output registers on the primitive for better latency
    //     .DOB_REG(0),                                //Disable output registers on the primitive for better lacency
    //     .RAM_MODE("TDP"),
    //     axis_sync_fifo_memory ( );
  
    logic [FIFO_INPUT_WIDTH-1:0] memory [AXIS_FIFO_DEPTH-1:0];
    
    logic [FIFO_INPUT_WIDTH-1:0] memory_read_data;
    logic [FIFO_INPUT_WIDTH-1:0] memory_write_data_q;
    logic memory_write_enable;

    //Have two always_ff blocks for separate reading/writing to try infer sync
    //two-port block ram
    always_ff @(posedge i_clk) begin
        memory_read_data <= memory[fifo_read_ptr];
    end
    
    //  tvalid -> tready
    //  
    //
        
    //Every read is -> prefetch into buffer, raise tvalid
    //On the next tready clock we now read and sent the buffer contents, begin
    //a new read from memory


    //If !empty AND tready
    //Prefetch into the buffer if !empty AND !tready
    //If we're not empty, prefetch into the output buffer
    //If we read, read one from the buffer, then bypass the buffer as long as
    //tready is held

    logic output_buffer_valid;     
    logic [FIFO_INPUT_WIDTH-1:0] output_buffer;

    logic o_m_axis_tvalid_q;
    assign o_m_axis_tvalid = o_m_axis_tvalid_q;
     
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_m_axis_tvalid_q <= 1'b0;
            output_buffer_valid <= 1'b0;
            fifo_read_ptr <= 0;
        end else begin
            //What to do about o_m_axis_tvalid_q?
            casez ({output_buffer_valid, empty_q, i_m_axis_tready})
                3'b000: begin //We don't have a buffer, but there is valid data to read. We shouldn't be outputting data. Load the data into the buffer, increment the fifo pointer
                    if (o_m_axis_tvalid_q) begin
                        //TODO probably not an error?
                        //$error("o_m_axis_tvalid_q = 1'b1 but we don't have data loaded");
                    end
                    output_buffer <= memory_read_data;
                    if (!o_m_axis_tvalid_q) begin
                        fifo_read_ptr <= 1'b1 + fifo_read_ptr;
                    end
                    output_buffer_valid <= 1'b1;   
                    o_m_axis_tvalid_q <= 1'b1;
                end
                3'b001: begin //Need to read directly from the memory and output according to valid = !empty_q
                    if (!empty) begin
                        fifo_read_ptr <= 1'b1 + fifo_read_ptr;
                        o_m_axis_tvalid_q <= 1'b1;
                    end else begin
                        o_m_axis_tvalid_q <= 1'b0;
                    end
                end
                3'b01?: begin //We don't have a buffer, and there aren't any valid data to read anyway - do nothing, output not valid
                    if (o_m_axis_tvalid_q) begin
                        $error("o_m_axis_tvalid_q = 1'b1 but queue is empty -- we may have sent over junk");
                    end
                    o_m_axis_tvalid_q <= 1'b0;    
                end
                3'b100: begin //We have valid data in the buffer, output is valid but we wait for ready
                    o_m_axis_tvalid_q <= 1'b1;    
                end
                3'b101: begin //We have valid data in the buffer, output is valid and we just wrote a packet out - increment the fifo pointer. What do we do about valid? 
                    if (o_m_axis_tvalid_q) begin
                        output_buffer_valid <= 1'b0;
                        fifo_read_ptr <= 1'b1 + fifo_read_ptr;
                    end
                    o_m_axis_tvalid_q <= 1'b1;
                end
                3'b110: begin //Is this state even legal?
                    //Do nothing here
                end
                3'b111: begin //Should output, but why is empty_q important here?
                    if (o_m_axis_tvalid_q) begin
                        output_buffer_valid <= 1'b0;
                        o_m_axis_tvalid_q <= 1'b0;
                    end else begin
                        o_m_axis_tvalid_q <= 1'b1;
                    end
                end
            endcase
        end
    end

    logic memory_write_condition;
    always_comb memory_write_condition = (!full & memory_write_enable | memory_write_queued);
    
    logic memory_write_queued;


    //If the memory is full AND we have a write in the pipeline, then need to
    //'save' the memory_enable to be used when we unqueue the write
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        memory_write_queued <= 1'b0;
        if (!i_rst_n) begin
            //nothing, just here to keep the structure
        end else begin
            if (memory_write_enable & full) begin
                memory_write_queued <= 1'b1;
            end 
        end
    end

    //Write block
    always_ff @(posedge i_clk) begin
        if (memory_write_condition) begin
            memory[fifo_write_ptr] <= memory_write_data_q;
        end
    end
   
    //Write pointer incrementing
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            fifo_write_ptr <= 0;
        end else begin
            if (memory_write_condition) begin
                fifo_write_ptr <= 1'b1 + fifo_write_ptr;
            end
        end
    end

    //Take modulo AXIS_FIFO_DEPTH
    //fifo_write_ptr <= (fifo_write_ptr + 1'b1) & {AXIS_FIFO_DEPTH_BITWIDTH{1'b1}};
    always_ff @(posedge i_clk) begin
        memory_write_enable <= 1'b0;
        begin
            //If we have space, and we're being sent a valid packet then we
            //write this into the memory at THIS address
            if (!full & i_s_axis_tvalid) begin
               memory_write_data_q <= fifo_input_data;
               memory_write_enable <= 1'b1;
            end
        end
    end
    
    logic empty;
    logic empty_q;
    logic full;
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            empty_q <= 1'b1;
        end else begin
            empty_q <= empty;
        end
    end

    always_comb empty = fifo_read_ptr == fifo_write_ptr;
    always_comb full = (fifo_write_ptr + 2 == fifo_read_ptr | fifo_write_ptr + 1 == fifo_read_ptr);
    
    assign o_s_axis_tready = !full & i_rst_n;

    //o_m_axis_tvalid == !empty  //
    //o_s_axis_tready == !full   //Won't store full packets, but that's fine! 


endmodule
