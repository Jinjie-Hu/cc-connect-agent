`include "qtz_def.svh"

module complex_conj #(
	parameter qtz_t INPUT_QTZ = 'b0
) (
	input  [INPUT_QTZ.width-1:0] InputA,
	output [INPUT_QTZ.width-1:0] OutputB
);
	localparam INPUT_BIT_WIDTH = INPUT_QTZ.width, INPUT_BIT_WIDTH_HALF = INPUT_BIT_WIDTH/2;
	
	wire signed [INPUT_BIT_WIDTH_HALF-1:0] InputA_r;
	wire signed [INPUT_BIT_WIDTH_HALF-1:0] InputA_i;
	wire signed [INPUT_BIT_WIDTH_HALF-1:0] OutputB_r;
	wire signed [INPUT_BIT_WIDTH_HALF-1:0] OutputB_i;

	assign InputA_r  = signed'(InputA[INPUT_BIT_WIDTH-1:INPUT_BIT_WIDTH_HALF]);
	assign InputA_i  = signed'(InputA[INPUT_BIT_WIDTH_HALF-1:0]);
	assign OutputB_r = InputA_r;
	assign OutputB_i = ~InputA_i + 1'b1;

	assign OutputB = {OutputB_r, OutputB_i};
endmodule
