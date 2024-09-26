`default_nettype none
`timescale 1ns / 1ps

module external_tx_gearbox (
        input  wire                     i_usrclk2,
        input  wire                     i_rst_n,
        
        input  wire                     i_startseq,

        output wire [6:0]               o_txsequence,

        input  wire [1:0]               i_header,
        output wire [2:0]               o_header,
        
        input  wire [32-1:0] i_data,
        output wire [32-1:0] o_data,
        
        output wire                     o_data_rdy
    );
    

    logic is_started;
    always_ff @(posedge i_usrclk2 or negedge i_rst_n) begin
        if (!i_rst_n) begin
            is_started <= 1'b0;
        end else begin
            if (i_startseq) begin
                is_started <= 1'b1;
            end
        end
    end

    //Temporary assignments, may need to replace this with a reg for timing
    assign o_data = i_data;
    assign o_header = {1'b0, i_header};
    
    logic data_rdy;
    assign o_data_rdy = is_started ? data_rdy : 1'b0;
    //TODO fix this, make the i_data/o_data interface registered, if this
    //doesn't meet timing. Currently there is a path from this, to the
    //previous module, then to the data output, through this, again, and then
    //into the GTX
    assign data_rdy = (txsequence != 63) && 
                      (txsequence != 64) && 
                      (txsequence != 65); 
    //always_ff @(posedge i_usrclk2 or negedge i_rst_n) begin
    //    if (!i_rst_n) begin
    //        data_rdy <= 1'b0;
    //    end else begin
    //    end
    //end

    //Increment TX sequence from 0 to 32
    //Cycles        0   1   2   3  ...  62      63      64      65      66      67
    //TX Sequence   0   0   1   1  ...  31      31      32      32      0       0
    //DATA          D0  D1  D2  D3 ...  D62     D63     D63     D63     D0
    //DATA_RDY      1   1   1   1       1       0       0       0       1
    
    logic [6:0] txsequence;
    assign o_txsequence = {1'b0, txsequence[6:1]};
    always_ff @(posedge i_usrclk2 or negedge i_rst_n) begin
        if (!i_rst_n) begin
            txsequence <= 7'b0;
        end else begin
            if (is_started) begin
                if (txsequence != 65) begin
                    txsequence <= txsequence + 1'b1;
                end else begin
                    txsequence <= 7'b0;
                end
            end
        end
    end
    


endmodule

`resetall
