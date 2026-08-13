`include "qtz_def.svh"

module real_negative #(
	parameter qtz_t INPUT_QTZ = 'b0
) (
	input  signed [INPUT_QTZ.width-1:0] InputA,
	output signed [INPUT_QTZ.width-1:0] OutputB
);
	assign OutputB = ~InputA + 1'b1;
endmodule
