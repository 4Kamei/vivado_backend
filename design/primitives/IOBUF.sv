module IOBUF (
        input wire I,
        output wire O,
        inout wire IO,
        input wire T
    );

    assign IO = T ? I : 1'bz;

endmodule
