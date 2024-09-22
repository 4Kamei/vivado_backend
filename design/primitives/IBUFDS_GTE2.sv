module IBUFDS_GTE2 #(
        parameter string CLKCM_CFG = "",
        parameter string CLKRCV_TRST = "",
        parameter logic [1:0] CLKSWING_CFG = 2'b00
    ) (
        input wire I,
        input wire IB,
        input wire CEB,
        output wire ODIV2,
        output wire O
    );

    assign O = CEB ? 1'b0 : I;

    logic clk_div;
    always_ff @(posedge I) clk_div <= ~clk_div;

    assign ODIV2 = clk_div;

endmodule
