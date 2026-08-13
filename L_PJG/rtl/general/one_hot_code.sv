// one_hot_encoder
// use barrel shifter
module one_hot_encoder #(
    parameter WIDTH = 4  // one hot code width
)(
    input wire [$clog2(WIDTH)-1:0] binary_in,  // 二进制码输入
    output reg [WIDTH-1:0] one_hot_out  // 独热码输出
);
    generate
        for (genvar i = 0; i < WIDTH; i = i + 1) begin
            assign one_hot_out[i] = binary_in == i ? 1'b1 : 1'b0;
        end
    endgenerate
endmodule

module one_hot_decoder #(
    parameter WIDTH = 4  // 输入独热码的位宽
)(
    input wire [WIDTH-1:0] one_hot_in,  // 独热码输入
    output reg [$clog2(WIDTH)-1:0] binary_out  // 二进制输出
);

    `ifndef DISABLE_SV_ASSERTION
        assert property (@(one_hot_in) $onehot0(one_hot_in)) else begin $display("one hot error: %x\n", one_hot_in); $fatal(1); end
    `endif

    logic [WIDTH-2:0] bit_extracted[$clog2(WIDTH)-1:0];
    generate
        for (genvar i = 0; i < $clog2(WIDTH); i = i + 1) begin
            for (genvar j = 0; j < WIDTH-1; j = j + 1) begin
                assign bit_extracted[i][j] = (j+1) % (2 ** (i+1)) >= (2 ** i) ? one_hot_in[j+1] : 'b0;
            end
            assign binary_out[i] = |bit_extracted[i];
        end
    endgenerate

endmodule