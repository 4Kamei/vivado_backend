//      // verilator_coverage annotation
        `default_nettype none
        `timescale 1ns / 1ps
        
        
        //Counts the size of packets coming into the fifo. Keeps all bytes, including
        //ones where tkeep == 0.
        //Fifo is not fall-through
        
        module axis_sync_fifo #(
                parameter AXIS_TDATA_WIDTH = 8,
                parameter AXIS_FIFO_DEPTH = 4
            ) (
 206053         input wire i_clk,
%000003         input wire i_rst_n,
        
                //Master interface, out of the fifo
 010412         output wire                         o_m_axis_tvalid,
 000297         input  wire                         i_m_axis_tready,
 031053         output wire [AXIS_TDATA_WIDTH-1:0]  o_m_axis_tdata,
 020341         output wire                         o_m_axis_tlast,
%000000         output wire                         o_m_axis_tstrb,
%000003         output wire                         o_m_axis_tkeep,
%000000         output wire                         o_m_axis_tid,
%000000         output wire                         o_m_axis_tdest,
%000000         output wire                         o_m_axis_tuser,
                
                //Slave interface, into the fifo
 010160         input  wire                         i_s_axis_tvalid,
 009919         output wire                         o_s_axis_tready,
 028402         input  wire [AXIS_TDATA_WIDTH-1:0]  i_s_axis_tdata,
 020432         input  wire                         i_s_axis_tlast,
%000000         input  wire                         i_s_axis_tstrb,
%000003         input  wire                         i_s_axis_tkeep,
%000000         input  wire                         i_s_axis_tid,
%000000         input  wire                         i_s_axis_tdest,
%000000         input  wire                         i_s_axis_tuser
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
%000000     logic [FIFO_INPUT_WIDTH-1: 0] fifo_input_data; 
        
%000001     always_comb fifo_input_data = {
%000001         i_s_axis_tkeep, 
%000001         i_s_axis_tstrb, 
%000001         i_s_axis_tid, 
%000001         i_s_axis_tdest, 
%000001         i_s_axis_tuser,
%000001         i_s_axis_tlast,
%000001         i_s_axis_tdata};
           
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
 028615     logic [AXIS_FIFO_DEPTH_BITWIDTH-1:0] fifo_read_ptr;
 028615     logic [AXIS_FIFO_DEPTH_BITWIDTH-1:0] fifo_write_ptr;
        
            //May want to do this?           
            // RAMB18E1 #( 
            //     .RDADDR_COLLISION_HWCONFIG("PERFORMANCE"),  //Same-clock for read and write, and guaranteed to not have overlapping addresses
            //     .SIM_CHECK_COLLISION("ALL"),                //Yes, always check in sim
            //     .DOA_REG(0),                                //Disable output registers on the primitive for better latency
            //     .DOB_REG(0),                                //Disable output registers on the primitive for better lacency
            //     .RAM_MODE("TDP"),
            //     axis_sync_fifo_memory ( );
          
%000000     logic [AXIS_FIFO_DEPTH-1:0] [FIFO_INPUT_WIDTH-1:0] memory;
            
%000000     logic [FIFO_INPUT_WIDTH-1:0] memory_read_data;
%000000     logic [FIFO_INPUT_WIDTH-1:0] memory_write_data_q;
 018418     logic memory_write_enable;
        
            //Have two always_ff blocks for separate reading/writing to try infer sync
            //two-port block ram
 103027     always_ff @(posedge i_clk) begin
 103027         memory_read_data <= memory[fifo_read_ptr];
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
        
 000294     logic output_buffer_valid;     
%000000     logic [FIFO_INPUT_WIDTH-1:0] output_buffer;
        
 010412     logic o_m_axis_tvalid_q;
            assign o_m_axis_tvalid = o_m_axis_tvalid_q;
             
 103028     always_ff @(posedge i_clk or negedge i_rst_n) begin
%000004         if (!i_rst_n) begin
%000004             o_m_axis_tvalid_q <= 1'b0;
%000004             output_buffer_valid <= 1'b0;
%000004             fifo_read_ptr <= 0;
 103024         end else begin
                    //What to do about o_m_axis_tvalid_q?
 103024             casez ({output_buffer_valid, empty_q, i_m_axis_tready})
 000147                 3'b000: begin //We don't have a buffer, but there is valid data to read. We shouldn't be outputting data. Load the data into the buffer, increment the fifo pointer
 000014                     if (o_m_axis_tvalid_q) begin
                                //TODO probably not an error?
                                //$error("o_m_axis_tvalid_q = 1'b1 but we don't have data loaded");
                            end
 000147                     output_buffer <= memory_read_data;
 000014                     if (!o_m_axis_tvalid_q) begin
 000014                         fifo_read_ptr <= 1'b1 + fifo_read_ptr;
                            end
 000147                     output_buffer_valid <= 1'b1;   
 000147                     o_m_axis_tvalid_q <= 1'b1;
                        end
 062273                 3'b001: begin //Need to read directly from the memory and output according to valid = !empty_q
 005205                     if (!empty) begin
 057068                         fifo_read_ptr <= 1'b1 + fifo_read_ptr;
 057068                         o_m_axis_tvalid_q <= 1'b1;
 005205                     end else begin
 005205                         o_m_axis_tvalid_q <= 1'b0;
                            end
                        end
 038366                 3'b01?: begin //We don't have a buffer, and there aren't any valid data to read anyway - do nothing, output not valid
 038366                     if (o_m_axis_tvalid_q) begin
                                $error("o_m_axis_tvalid_q = 1'b1 but queue is empty -- we may have sent over junk");
                            end
 038366                     o_m_axis_tvalid_q <= 1'b0;    
                        end
 002083                 3'b100: begin //We have valid data in the buffer, output is valid but we wait for ready
 002083                     o_m_axis_tvalid_q <= 1'b1;    
                        end
 000147                 3'b101: begin //We have valid data in the buffer, output is valid and we just wrote a packet out - increment the fifo pointer. What do we do about valid? 
%000000                     if (o_m_axis_tvalid_q) begin
 000147                         output_buffer_valid <= 1'b0;
 000147                         fifo_read_ptr <= 1'b1 + fifo_read_ptr;
                            end
 000147                     o_m_axis_tvalid_q <= 1'b1;
                        end
%000008                 3'b110: begin //Is this state even legal?
                            //Do nothing here
                        end
%000000                 3'b111: begin //Should output, but why is empty_q important here?
%000000                     if (o_m_axis_tvalid_q) begin
%000000                         output_buffer_valid <= 1'b0;
%000000                         o_m_axis_tvalid_q <= 1'b0;
%000000                     end else begin
%000000                         o_m_axis_tvalid_q <= 1'b1;
                            end
                        end
                    endcase
                end
            end
        
 019500     logic memory_write_condition;
%000001     always_comb memory_write_condition = (!full & memory_write_enable | memory_write_queued);
            
 009064     logic memory_write_queued;
        
        
            //If the memory is full AND we have a write in the pipeline, then need to
            //'save' the memory_enable to be used when we unqueue the write
 103028     always_ff @(posedge i_clk or negedge i_rst_n) begin
 103028         memory_write_queued <= 1'b0;
%000004         if (!i_rst_n) begin
                    //nothing, just here to keep the structure
 103024         end else begin
 004532             if (memory_write_enable & full) begin
 004532                 memory_write_queued <= 1'b1;
                    end 
                end
            end
        
            //Write block
 103027     always_ff @(posedge i_clk) begin
 045796         if (memory_write_condition) begin
 057231             memory[fifo_write_ptr] <= memory_write_data_q;
                end
            end
           
            //Write pointer incrementing
 103028     always_ff @(posedge i_clk or negedge i_rst_n) begin
%000004         if (!i_rst_n) begin
%000004             fifo_write_ptr <= 0;
 103024         end else begin
 045794             if (memory_write_condition) begin
 057230                 fifo_write_ptr <= 1'b1 + fifo_write_ptr;
                    end
                end
            end
        
            //Take modulo AXIS_FIFO_DEPTH
            //fifo_write_ptr <= (fifo_write_ptr + 1'b1) & {AXIS_FIFO_DEPTH_BITWIDTH{1'b1}};
 103027     always_ff @(posedge i_clk) begin
 103027         memory_write_enable <= 1'b0;
 103027         begin
                    //If we have space, and we're being sent a valid packet then we
                    //write this into the memory at THIS address
 045796             if (!full & i_s_axis_tvalid) begin
 057231                memory_write_data_q <= fifo_input_data;
 057231                memory_write_enable <= 1'b1;
                    end
                end
            end
            
 010429     logic empty;
 010429     logic empty_q;
 009916     logic full;
            
 103028     always_ff @(posedge i_clk or negedge i_rst_n) begin
%000004         if (!i_rst_n) begin
%000004             empty_q <= 1'b1;
 103024         end else begin
 103024             empty_q <= empty;
                end
            end
        
%000001     always_comb empty = fifo_read_ptr == fifo_write_ptr;
%000001     always_comb full = (fifo_write_ptr + 2'b10 == fifo_read_ptr | fifo_write_ptr + 1'b1 == fifo_read_ptr);
            
            assign o_s_axis_tready = !full & i_rst_n;
        
            //o_m_axis_tvalid == !empty  //
            //o_s_axis_tready == !full   //Won't store full packets, but that's fine! 
        
        
        endmodule
        
