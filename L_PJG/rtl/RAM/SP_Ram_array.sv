`include "common.svh"

module SP_Ram_array #(
    parameter DATA_WIDTH = 4,
    parameter DEPTH = 4,
    parameter RANK = 4,
    parameter BANK = 4,

    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input clk,
    input wEn_i,
    input En_i,
    input [ADDR_WIDTH-1:0] Addr_i,
    input [RANK-1:0][DATA_WIDTH-1:0] wData_i,

    // read data 
    output [BANK-1:0][RANK-1:0][DATA_WIDTH-1:0] rData_o

);
    // parameter assertion
    initial begin
        assert ( DEPTH % BANK == 0 ) else $fatal;
    end

    // SP_Ram
    logic SP_Ram_En[BANK-1:0][RANK-1:0];
    generate
        for (genvar i = 0; i < BANK; i = i + 1) begin : G_row_RAM
            for (genvar j = 0; j < RANK; j = j + 1) begin
                SP_Ram #(
                    .DEPTH(DEPTH / BANK),
                    .BIT_WIDTH(DATA_WIDTH),  
                    .ADDR_WIDTH($clog2(DEPTH / BANK))
                ) u_DRAM (
                    .wData(wData_i[j]),
                    .rData(rData_o[i][j]),
                    .wEn(wEn_i),
                    .En(SP_Ram_En[i][j]),
                    .Addr(Addr_i[0 +: $clog2(DEPTH / BANK)]),
                    .clk(clk)
                );
                assign SP_Ram_En[i][j] = En_i && (
                                         wEn_i && (Addr_i[ADDR_WIDTH-1 -: $clog2(BANK)] == i) ||
                                         !wEn_i
                                         );
            end
        end
    endgenerate

endmodule
