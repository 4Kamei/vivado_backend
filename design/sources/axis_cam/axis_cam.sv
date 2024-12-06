`timescale 1ns / 1ps
`default_nettype none
//synthesis translate_off
`define SIMULATION
//synthesis translate_on
//
//  each packet should be exactly 1 beat
//  each 1 beat contains tdata and tuser. 
//  TID is respected. A request with one TID will result in a response with
//  the same TID.
//
//  there is no 'keep/strobe' field
//
//  tdata depends on tuser:
//      tuser = LOOKUP:             tdata:  [DATA_LENGTH_BYTES of 0   ] [KEY_LENGTH_BYTES of key]       
//      tuser = UPDATE:             tdata:  [DATA_LENGTH_BYTES of data] [KEY_LENGTH_BYTES of key]       
//      tuser = LOOKUP_RESPONSE:    tdata:  [DATA_LENGTH_BYTES of data] [KEY_LENGTH_BYTES of key]       
//      tuser = EVICTED:            tdata:  [DATA_LENGTH_BYTES of data] [KEY_LENGTH_BYTES of key]       
//  thus, tuser is 2 bits
//  
//  LOOKUP: lookup a key in the cam and get a value
//  UPDATE: store a key under a value. If the value overlaps with a previous
//          value, or if we don't have space, evict the value and send 'EVICTED'
//          packet
//
//  LOOKUP_RESPONSE:    generated by lookup
//  EVICTED:            generated by update in case an element needs to be
//                      evicted
//
//  interface sizes:
//      1 bit   out     tready
//      1 bit   in      tvalid
//      1 bit   in      tlast
//      8 bit   in      tid
//      DATA_W  in      tdata
//      2 bit   in      tuser
//  
//  where DATA_W = DATA_LENGTH_BYTES + KEY_LENGTH_BYTES
//
//  tuser = LOOKUP or tuser = UPDATE:
//  
//  key_hash <= (produce a hash of the key) mod (num of addrs)
//  memory_row <= memory[key_hash]
//  oldest_index <= (lookup memory row, find the 'oldest' 
//

//  Each bucket is stored as a row in memory, with width given by:  
//      ITEMS_IN_BUCKET * (MEMORY_ITEM_WIDTH)
//      where MEMORY_ITEM_WIDTH = KEY_LENGTH_BYTES + DATA_LENGTH_BYTES + CLOG2(ITEMS_IN_BUCKET)
//       


//  MULTIPLE_WRITE_RESOLUTION. The case where we receive multiple writes to
//  the same memory address needs to be handled specially. This can be handled
//  with a pipeline stall (MULTIPLE_WRITE_RESOLUTION_BUFF_SIZE = 0), or it can
//  be handled by buffering the packet, and passing through packets which
//  don't touch the same memory address - essentially, reordering packets, but
//  preserving read/write ordering for each address.
//
//  TODO: MULTIPLE_WRITE_RESOLUTION_BUFF_SIZE != 0 not yet supported!

module axis_cam #(
        parameter int       KEY_LENGTH_BYTES = 6,
        parameter int       DATA_LENGTH_BYTES = 1,
        parameter int       NUM_BUCKETS = 8,
        parameter int       ITEMS_IN_BUCKET = 2,
        parameter int       MULTIPLE_WRITE_RESOLUTION_BUFF_SIZE = 0 
    ) (
        input wire          i_clk,
        input wire          i_rst_n,

        //This devices assumes that the master interface VALID is always high
        //If this is not the case, plug this into a fifo and route the
        //'halfway-full' signal into i_slave_ready, to make sure the fifo is
        //never filled up
        input wire          i_slave_ready,

        axis_cam_if.master  master_axis, 
        axis_cam_if.slave   slave_axis
    );
    //axis_cam_if has:      valid, ready, last, id, user, data

    localparam int NUM_BUCKETS_LOG2 = $clog2(NUM_BUCKETS);

    typedef logic [15:0]                    hash_t;         //If used as addr, can support 64 * 1k rams
    typedef logic [NUM_BUCKETS_LOG2 - 1:0]  mem_addr_t;
    typedef logic [KEY_LENGTH_BYTES * 8 - 1: 0] key_t;
    typedef enum logic [2:0] {
        PKTTYPE_IN_LOOKUP = 0, 
        PKTTYPE_OUT_LOOKUP_RESPONSE_SUCC = 1,
        PKTTYPE_OUT_LOOKUP_RESPONSE_FAIL = 2,
    
        PKTTYPE_IN_UPDATE = 3, 
        PKTTYPE_OUT_UPDATE_SUCC = 4,
        PKTTYPE_OUT_UPDATE_SUCC_WITH_EVICT = 5
        //And the responses
    } packet_type_t;


    localparam int NUM_ITEMS_IN_BUCKET_LOG2 = $clog2(ITEMS_IN_BUCKET);
    typedef logic [NUM_ITEMS_IN_BUCKET_LOG2 - 1 : 0]  memory_item_index_t;
    typedef logic [NUM_ITEMS_IN_BUCKET_LOG2 - 1 : 0]  timestamp_t;
    typedef logic [slave_axis.TID_WIDTH     - 1 : 0]  axis_id_t;

    typedef struct packed {
        key_t                                   key;
        logic [DATA_LENGTH_BYTES * 8 - 1:0]     data;
        timestamp_t                             inserted_timestamp;
        logic                                   is_set;
    } memory_item_t;

    localparam int MEMORY_ITEM_WIDTH= $bits(memory_item_t);

    //Each memory row stores a timestamp
    typedef struct packed {
        timestamp_t                             oldest_element_timestamp;
        memory_item_t [ITEMS_IN_BUCKET-1:0]     items;
    } memory_read_row_t;

    localparam int MEMORY_READ_ROW_WIDTH = $bits(memory_read_row_t);

    typedef struct packed {
        logic [KEY_LENGTH_BYTES * 8 - 1:0]  key;    
        logic [DATA_LENGTH_BYTES * 8 - 1:0] data;    
    } axis_data_t;
    
    function void print_memory_row(memory_read_row_t row);
        $display("\ttimestamp:          %h", row.oldest_element_timestamp);
        $display("\titems    :          %h", ITEMS_IN_BUCKET);
        for (int i = 0; i < ITEMS_IN_BUCKET; i++) begin
            if (row.items[i].is_set) begin
                $display("\titem %d: key        : %h", i, row.items[i].key);    
                $display("\titem %d: data       : %h", i, row.items[i].data);    
                $display("\titem %d: inserted   : %h", i, row.items[i].inserted_timestamp);    
            end else begin
                $display("\titem %d: key        : <not set>", i);
                $display("\titem %d: data       : <not set>", i);
                $display("\titem %d: inserted   : %h <not set>", i, row.items[i].inserted_timestamp);
            end
        end
    endfunction


    function hash_t hash(input key_t key);
        hash_t output_hash;
        output_hash = 0;
    //for (int i = 0; i < KEY_LENGTH_BYTES; i += 2) begin
        //    output_hash = output_hash ^ key[i * 8 +: 16];       //Probably a bad hash function
        //end
        output_hash = key[15:0];
        return output_hash;
    endfunction 

    function memory_item_index_t find_oldest_in_memory(memory_read_row_t row);
        $display("find oldest in memory: ");
        print_memory_row(row);
        for (int i = 0; i < ITEMS_IN_BUCKET; i++) begin
            if (!row.items[i].is_set) begin
                $display("\tFound! => Returning index %d IS UNSET", i);
                return memory_item_index_t'(i);
            end
        end
        for (int i = 0; i < ITEMS_IN_BUCKET; i++) begin
            if (row.items[i].inserted_timestamp == row.oldest_element_timestamp || !row.items[i].is_set) begin
                $display("\tFound! => Returning index %d IS SET", i);
                return memory_item_index_t'(i);
            end
        end
        //Or, if we don't find it for any reason, override the first entry.
        //This shouldn't happend
        $error("We couldn't find the oldest entry - this should never happen");
        return memory_item_index_t'(0);
    endfunction

    typedef struct packed {
        logic               item_found;
        memory_item_index_t index;    
    } memory_item_find_result_t;

    function memory_item_find_result_t find_item_in_memory(memory_read_row_t row, key_t item_key);
        memory_item_find_result_t find_result;
        $display("find item in memory: %h", item_key);
        print_memory_row(row);
        find_result.item_found = 1'b0;
        find_result.index = memory_item_index_t'(0);
        for (int i = 0; i < ITEMS_IN_BUCKET; i++) begin
            $display("Checking %d against %d at index %d", row.items[i].key, item_key, i);
            if (row.items[i].key == item_key && row.items[i].is_set) begin
                find_result.item_found = 1'b1;
                find_result.index = memory_item_index_t'(i);
            end
        end
        return find_result;
    endfunction

    function mem_addr_t hash_to_addr(hash_t hash);
        return mem_addr_t'(hash);
    endfunction

    function memory_read_row_t replace_in_memory(
        memory_read_row_t   row, 
        memory_item_index_t index,
        logic               should_incr_timestamp,
        axis_data_t         input_data);
        memory_read_row_t   output_row;
        memory_item_t       new_item;
        $display("replace in memory    : ");
        print_memory_row(row);
        $display("\treplace at:         %h", index);
        $display("\treplace with:       key=%h data=%h", input_data.key, input_data.data);
        $display("\tincrement timestamp %h", should_incr_timestamp);
        //Copying the data over
        output_row.oldest_element_timestamp = row.oldest_element_timestamp + (should_incr_timestamp ? timestamp_t'(1'b1) : 0);
        output_row.items =  row.items;
        //Create the memory item
        new_item.key = input_data.key;
        new_item.data = input_data.data;
        //We are guaranteed for this to be correct, as the memory on first
        //write is initialized with timestamps 0, 1, 2, ..., ITEMS_IN_BUCKET - 1
        new_item.inserted_timestamp = row.oldest_element_timestamp + timestamp_t'(ITEMS_IN_BUCKET);
        new_item.is_set = 1'b1;

        output_row.items[index] = new_item;
            
        return output_row;

    endfunction
        
    //Not-yet written to rows need to be initialized to this, as we need the
    //item timestamps to be in order. This should be optimised to be just
    //a constant, as the function has no params
    function memory_read_row_t get_init_row();
        memory_read_row_t row;
        row.items = 0;
        row.oldest_element_timestamp = 0;
        for (int i = 0; i < ITEMS_IN_BUCKET; i++) begin
            row.items[i].inserted_timestamp = timestamp_t'(i);
            row.items[i].is_set = 1'b0;
        end
        return row;
    endfunction

    function memory_item_find_result_t item_not_found();
        return memory_item_find_result_t'(0);
    endfunction
   
    function axis_data_t create_output_data(memory_item_t item);
        axis_data_t output_data;
        output_data.key = item.key;
        output_data.data = item.data;
        return output_data;
    endfunction

    function logic should_stall_pipeline(
        hash_t key_hash,
        hash_t q0_key, packet_type_t q0_type, logic valid_q0,
        hash_t q1_key, packet_type_t q1_type, logic valid_q1,
        hash_t q2_key, packet_type_t q2_type, logic valid_q2);

        //Pipeline should stall if we have any update packet that touches the
        //same memory location as this one
        return  (hash_to_addr(q0_key) == hash_to_addr(key_hash) && q0_type == PKTTYPE_IN_UPDATE && valid_q0)
            ||  (hash_to_addr(q1_key) == hash_to_addr(key_hash) && q1_type == PKTTYPE_IN_UPDATE && valid_q1)
            ||  (hash_to_addr(q2_key) == hash_to_addr(key_hash) && q2_type == PKTTYPE_IN_UPDATE && valid_q2);
               
    endfunction

    assign slave_axis.ready = i_slave_ready && ~pipeline_valid_q0_buffered; 

    //Attempt to infer logic via synth for BRAMs
    logic [MEMORY_READ_ROW_WIDTH - 1:0] memory [NUM_BUCKETS - 1:0];

    logic [0:0]                         memory_location_initalized [NUM_BUCKETS - 1:0];
    
    //////////////////////////////////////////////////////////////////
    /////               Pipeline stage 0 : packet reception + hash
    //////////////////////////////////////////////////////////////////

    logic  pipeline_valid_q0;
    hash_t key_hash_q0;
    axis_data_t data_item_q0;
    packet_type_t packet_type_q0;
    axis_id_t   axis_id_q0;
    
    //The buffered pipeline, in case we get multiple writes/reads to the same
    //address, at the same time. More information in file header
    logic  pipeline_valid_q0_buffered;
    hash_t key_hash_q0_buffered;
    axis_data_t data_item_q0_buffered;
    packet_type_t packet_type_q0_buffered;
    axis_id_t   axis_id_q0_buffered;
    
    generate
        if (MULTIPLE_WRITE_RESOLUTION_BUFF_SIZE != 0) begin
            $error("MULTIPLE_WRITE_RESOLUTION_BUFF_SIZE != 0 is not implemented");
            //TODO
        end
    endgenerate
    
    logic pipeline_stall_q0;
    always_comb pipeline_stall_q0 = should_stall_pipeline(
        hash(slave_axis.data.key),
        key_hash_q0,    packet_type_q0, pipeline_valid_q0,     //TODO if we have a memory read AND the key matches, we should stall
        key_hash_q1,    packet_type_q1, pipeline_valid_q1,     //
        key_hash_q2,    packet_type_q2, pipeline_valid_q2      //
    );

    always_ff @(posedge i_clk or negedge i_rst_n) begin : pipeline_q0_reception_b
        if (!i_rst_n) begin
            pipeline_valid_q0 <= 1'b0;
        end else begin
            pipeline_valid_q0 <= 1'b0;
            if (pipeline_valid_q0_buffered) begin
                //We have data that has been buffered due to a previous stall.
                //Only
                if (!pipeline_stall_q0) begin
                    pipeline_valid_q0_buffered <= 1'b0;
                    pipeline_valid_q0 <= 1'b1;
                    key_hash_q0 <= key_hash_q0_buffered;
                    data_item_q0 <= data_item_q0_buffered;
                    packet_type_q0 <= packet_type_q0_buffered;
                    axis_id_q0 <= axis_id_q0_buffered;
                end
            end
            
            if (slave_axis.valid && (slave_axis.ready || pipeline_valid_q0_buffered && !pipeline_stall_q0)) begin
                $display("Got packet: ready = %h", slave_axis.ready);
                $display("            valid = %h", slave_axis.valid);
                $display("            last  = %h", slave_axis.last);
                $display("            data  = %h", slave_axis.data);
                $display("            id    = %h", slave_axis.id);
                $display("            user  = %h", slave_axis.user);
                $display("            hash  = %h", hash(slave_axis.data.key));
                $display("Should stall?     = %h", pipeline_stall_q0);
                case (slave_axis.user)
                    PKTTYPE_IN_LOOKUP, PKTTYPE_IN_UPDATE: begin : packet_lookup_b
                        if (pipeline_stall_q0) begin
                            pipeline_valid_q0_buffered <= 1'b1;
                            key_hash_q0_buffered <= hash(slave_axis.data.key);
                            //$display("Next key_hash_q0 is $h", hash(slave_axis.data.key));
                            data_item_q0_buffered <= slave_axis.data;
                            axis_id_q0_buffered <= slave_axis.id;
                            packet_type_q0_buffered <= packet_type_t'(slave_axis.user);
                        end else begin
                            pipeline_valid_q0 <= 1'b1;
                            key_hash_q0 <= hash(slave_axis.data.key);
                            //$display("Next key_hash_q0 is $h", hash(slave_axis.data.key));
                            data_item_q0 <= slave_axis.data;
                            axis_id_q0 <= slave_axis.id;
                            packet_type_q0 <= packet_type_t'(slave_axis.user);
                        end
                    end
                    default: $error("Incorrect packet type");
                endcase
            end
        end
    end

    //////////////////////////////////////////////////////////////////
    /////               Pipeline stage 1 : memory lookup
    //////////////////////////////////////////////////////////////////
    

    logic               pipeline_valid_q1;
    hash_t              key_hash_q1;
    axis_data_t         data_item_q1;
    packet_type_t       packet_type_q1;
    memory_read_row_t   memory_read_q1;
    axis_id_t   axis_id_q1;

    //Memory read
    always_ff @(posedge i_clk) begin : memory_read_b
        if (pipeline_valid_q0) begin
            memory_read_q1 <= memory[hash_to_addr(key_hash_q0)];
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin : pipeline_q1_lookup_b
        if (!i_rst_n) begin
            pipeline_valid_q1 <= 1'b0;
        end else begin
            pipeline_valid_q1 <= pipeline_valid_q0;
            if (pipeline_valid_q0) begin
                //Passthrough of pipeline items
                key_hash_q1 <= key_hash_q0;
                data_item_q1 <= data_item_q0;
                packet_type_q1 <= packet_type_q0;
                axis_id_q1 <= axis_id_q0;

                //Pipeline stage reads from memory, result used next stage
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////
    /////               Pipeline stage 2 : bucket lookup
    //////////////////////////////////////////////////////////////////

    logic                       pipeline_valid_q2;
    hash_t                      key_hash_q2;
    axis_data_t                 data_item_q2;
    packet_type_t               packet_type_q2;
    memory_read_row_t           memory_read_q2;
    memory_item_index_t         oldest_item_index_q2;

    memory_item_find_result_t   item_find_result_q2;
    logic                       should_incr_timeout_q2;
    axis_id_t                   axis_id_q2;

`ifdef SIMULATION
    logic                       item_find_result__found_q2;
    memory_item_index_t         item_find_result__index_q2;
    
    always_comb item_find_result__found_q2 = item_find_result_q2.item_found;
    always_comb item_find_result__index_q2 = item_find_result_q2.index;

`endif
    
    memory_read_row_t           memory_read_or_init_q2_comb;
    always_comb memory_read_or_init_q2_comb = 
        memory_location_initalized[hash_to_addr(key_hash_q1)] ? memory_read_q1 : get_init_row();

    
    always_ff @(posedge i_clk or negedge i_rst_n) begin : pipeline_q2_lookup_b
        if (!i_rst_n) begin
            pipeline_valid_q2 <= 1'b0;
        end else begin
            pipeline_valid_q2 <= pipeline_valid_q1;
            if (pipeline_valid_q1) begin
                //Passthrough of pipeline items
                key_hash_q2 <= key_hash_q1;
                data_item_q2 <= data_item_q1;
                packet_type_q2 <= packet_type_q1;
                memory_read_q2 <= memory_read_or_init_q2_comb;
                axis_id_q2 <= axis_id_q1;
                
                //Pipeline computations
                oldest_item_index_q2 <= find_oldest_in_memory(memory_read_or_init_q2_comb);
                if (~memory_location_initalized[hash_to_addr(key_hash_q1)]) begin
                    item_find_result_q2 <= item_not_found();
                end else begin
                    item_find_result_q2 <= find_item_in_memory(memory_read_q1, data_item_q1.key);
                end
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////
    /////               Pipeline stage 3 : memory write or return
    //////////////////////////////////////////////////////////////////

    logic                       pipeline_valid_q3;
    hash_t                      key_hash_q3;
    axis_data_t                 data_item_q3;
    packet_type_t               packet_type_q3;
    memory_read_row_t           memory_read_q3;
    memory_item_index_t         oldest_item_index_q3;

    memory_item_find_result_t   item_find_result_q3;
    axis_id_t                   axis_id_q3; 
 
    always_ff @(posedge i_clk or negedge i_rst_n) begin : pipeline_q3_lookup_b
        if (!i_rst_n) begin
            pipeline_valid_q3 <= 1'b0;
        end else begin
            pipeline_valid_q3 <= pipeline_valid_q2;
            if (pipeline_valid_q2) begin
                //Passthrough of pipeline items
                key_hash_q3 <= key_hash_q2;
                data_item_q3 <= data_item_q2;
                packet_type_q3 <= packet_type_q2;
                axis_id_q3 <= axis_id_q2;
                oldest_item_index_q3 <= oldest_item_index_q2;

                memory_read_q3 <= memory_read_q2;
                item_find_result_q3 <= item_find_result_q2;
            end
        end
    end

    //Do the memory write
    always_ff @(posedge i_clk) begin : memory_write_b
        if (pipeline_valid_q2 && packet_type_q2 == PKTTYPE_IN_UPDATE) begin
            memory_location_initalized[hash_to_addr(key_hash_q2)] <= 1'b1;
            memory[hash_to_addr(key_hash_q2)] <= replace_in_memory(
                memory_location_initalized[hash_to_addr(key_hash_q2)] ? memory_read_q2 : get_init_row(), 
                item_find_result_q2.item_found ? item_find_result_q2.index : oldest_item_index_q2,
                ~item_find_result_q2.item_found,
                data_item_q2
            );
        end
    end

    //////////////////////////////////////////////////////////////////
    /////               Pipeline stage 4 : packet output          
    //////////////////////////////////////////////////////////////////

    logic           response_ready_q4;
    axis_data_t     output_data_q4;
    packet_type_t   reply_packet_q4;
    axis_id_t       reply_id_q4;

    always_ff @(posedge i_clk or negedge i_rst_n) begin : pipeline_q4_send_b
        if (!i_rst_n) begin
            response_ready_q4 <= 1'b0;
        end else begin
            response_ready_q4 <= pipeline_valid_q3;
            if (pipeline_valid_q3) begin
                reply_id_q4 <= axis_id_q3;
                case (packet_type_q3)
                    PKTTYPE_IN_LOOKUP: begin
                        if (item_find_result_q3.item_found) begin
                            reply_packet_q4 <= PKTTYPE_OUT_LOOKUP_RESPONSE_SUCC;
                            output_data_q4 <= create_output_data(
                                memory_read_q3.items[item_find_result_q3.index]
                            );
                        end else begin
                            reply_packet_q4 <= PKTTYPE_OUT_LOOKUP_RESPONSE_FAIL;
                            output_data_q4 <= data_item_q3;
                        end
                    end
                    PKTTYPE_IN_UPDATE: begin
                        if (item_find_result_q3.item_found) begin
                            reply_packet_q4 <= PKTTYPE_OUT_UPDATE_SUCC_WITH_EVICT;
                            output_data_q4 <= create_output_data(
                                memory_read_q3.items[item_find_result_q3.index]
                            );
                        end else if (memory_read_q3.items[oldest_item_index_q3].is_set) begin
                            reply_packet_q4 <= PKTTYPE_OUT_UPDATE_SUCC_WITH_EVICT;
                            output_data_q4 <= create_output_data(
                                memory_read_q3.items[oldest_item_index_q3]
                            );
                        end else begin
                            reply_packet_q4 <= PKTTYPE_OUT_UPDATE_SUCC;
                            output_data_q4 <= data_item_q3;
                        end
                    end
                    default: $error("Unhandled packet type $s", packet_type_q3);
                endcase
            end
        end
    end
    
    assign master_axis.valid    = response_ready_q4;
    assign master_axis.data     = output_data_q4;
    assign master_axis.user     = reply_packet_q4;
    assign master_axis.id       = reply_id_q4;
    assign master_axis.last     = 1'b1; //All packets are 1 beat long


endmodule

`resetall
