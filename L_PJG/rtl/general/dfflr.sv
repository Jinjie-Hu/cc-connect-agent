`include "common.svh"

// DFF with load_EN, asynchronous reset and configurable reset value (default is 0) 
module dfflr #(
    parameter DATA_WIDTH = 1,
    parameter [DATA_WIDTH-1:0] RESET_VALUE = '0
) (
    input                   load_EN,
    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    input                   clk,
    input                   rst_n
);

    reg [DATA_WIDTH-1:0] data_out_reg;

    always @(posedge clk or negedge rst_n) begin : DFF_LR_PROC
        if (rst_n == 1'b0) data_out_reg <= RESET_VALUE;
        else if (load_EN == 1'b1) data_out_reg <= data_in;
    end

    assign data_out = data_out_reg;

`ifndef FPGA_SOURCE  //{
`ifndef DISABLE_SV_ASSERTION  //{
    //synopsys translate_off
    xchecker #(
        .DATA_WIDTH(1)
    ) xchecker (
        .data_in(load_EN),
        .clk(clk)
    );
    //synopsys translate_on
`endif  //}
`endif  //}

endmodule

// DFF with load_EN & without reset
module dffl #(
    parameter DATA_WIDTH = 1
) (
    input                   load_EN,
    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    input                   clk
);

    reg [DATA_WIDTH-1:0] data_out_reg;

    always @(posedge clk) begin : DFF_L_PROC
        if (load_EN == 1'b1) data_out_reg <= data_in;
    end

    assign data_out = data_out_reg;

`ifndef FPGA_SOURCE  //{
`ifndef DISABLE_SV_ASSERTION  //{
    //synopsys translate_off
    xchecker #(
        .DATA_WIDTH(1)
    ) xchecker (
        .data_in(load_EN),
        .clk(clk)
    );
    //synopsys translate_on
`endif  //}
`endif  //}

endmodule

// DFF without load_EN & with asynchronous reset and reset value 0
module dffr #(
    parameter DATA_WIDTH = 1,
    parameter [DATA_WIDTH-1:0] RESET_VALUE = '0
) (
    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    input                   clk,
    input                   rst_n
);

    reg [DATA_WIDTH-1:0] data_out_reg;

    always @(posedge clk or negedge rst_n) begin : DFF_R_PROC
        if (rst_n == 1'b0) data_out_reg <= RESET_VALUE;
        else data_out_reg <= data_in;
    end

    assign data_out = data_out_reg;

endmodule

// latch
module latch #(
    parameter DATA_WIDTH = 1
) (
    input                   load_EN,
    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] data_out_reg;

    always @(*) begin : LATCH_PROC
        if (load_EN == 1'b1) data_out_reg <= data_in;
    end

    assign data_out = data_out_reg;

`ifndef FPGA_SOURCE  //{
`ifndef DISABLE_SV_ASSERTION  //{
    //synopsys translate_off
    always_comb begin
        CHECK_THE_X_VALUE :
        assert (load_EN !== 1'bx)
        else $fatal("\n Error: Oops, detected a X value!!! This should never happen. \n");
    end

    //synopsys translate_on
`endif  //}
`endif  //}

endmodule
