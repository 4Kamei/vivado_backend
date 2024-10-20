`default_nettype none

package axis_cam_pkg;  
    
endpackage
    
interface axis_cam_if #(
        parameter int DATA_WIDTH = 0, 
        parameter int KEY_WIDTH = 0,
        parameter int TID_WIDTH  = 0
    ) ();

    typedef struct packed {
        logic [KEY_WIDTH * 8 - 1:0] key;
        logic [DATA_WIDTH * 8 - 1:0] data;
    } data_t;

    logic                           ready;
    logic                           valid;
    logic                           last;
    data_t                          data;
    logic [2:0]                     user;
    logic [TID_WIDTH - 1 : 0]       id;

    modport slave (
            output ready,
            input  valid,
            input  last,
            input  data,
            input  user,
            input  id
    );
    
    modport master (
            input  ready,
            output valid,
            output last,
            output data,
            output user,
            output id
    );

endinterface;

