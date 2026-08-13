`include "common.svh"

module LPJG_unit (
    // data path with pipeline-interleaving buffer
	// buffer active
	output active_ctl_o,	// active current buffer
    input  valid_i,
	input  valid_buf_idx_i,
	
	// buffer retire
    output retire_ctl_o,
	output retire_idx_o,
	
	// Gram read with 1 CC delay
    output Gram_rd_En_o,
	output logic Gram_rd_idx_o,
	output [$clog2(TX)-1:0] Gram_rd_addr_o,
	input  [VEC_MUL_NUM-1:0][TX-1:0][G_QTZ.width-1:0] Gram_mat_i,
	
	// gradient_neg rd & wr
    output gradient_neg_WEN_o,
	output gradient_neg_idx_o,
	output  [TX-1:0][GD_QTZ.width-1:0] gradient_neg_o,
    input  [TX-1:0][GD_QTZ.width-1:0] gradient_neg_i,

	// A_diag_inv rd
	output A_diag_inv_idx_o,
	input  [TX-1:0][A_DIAG_INV_QTZ.width-1:0] A_diag_inv_i,
	
	// iter_num rd
	output iter_num_idx_o,
	input  [ITER_NUM_WIDTH-1:0] iter_num_i,

    // x output
    output [TX-1:0][X_QTZ.width-1:0] x_o,
    output x_valid_o,

    input clk, rst_n
);

    // pipeline occupation definition
	// pip_status[0]: PIP_1 (delta_x cal. & gradient_neg update)
	// pip_status[1]: PIP_2	(x update)
    enum logic [1:0] {
        S_IDX_0, 
        S_IDX_1,
		S_IDLE
    } pip_status[1:0], pip_status_new[1:0], pip_ocp_idx;
	logic pip_ocp_En;
	
	// pipeline occupation
	generate
		for (genvar i = 0; i < 2; i++) begin:PIP_OCP
			always_ff @( posedge clk or negedge rst_n ) begin
				if (!rst_n) begin
					pip_status[i] <= S_IDLE;
				end else begin
					pip_status[i] <= pip_status_new[i];
				end
			end
			assign pip_status_new[i] = (i == 1) ? pip_status[0] :
									   pip_ocp_En ? pip_ocp_idx : 
									   retire_ctl_o ? S_IDLE : pip_status[1];
		end
	endgenerate
	assign pip_ocp_En = active_ctl_o & valid_i;
	assign active_ctl_o = valid_i && (pip_status[1] == S_IDLE || retire_ctl_o);
	assign pip_ocp_idx = valid_buf_idx_i ? S_IDX_1 : S_IDX_0; 

    // outer iter & inner iter cnt
    logic [1:0][TX-1:0] inner_iter_cnt, inner_iter_cnt_new, outer_iter_cnt, outer_iter_cnt_new, inner_iter_cnt_pip;
    logic [1:0] inner_iter_cnt_load_En, outer_iter_cnt_load_En;
	
	generate
		for (genvar i = 0; i < 2; i++) begin:ITER_CNT
			dfflr #($bits(inner_iter_cnt[0]), 'b0) u_inner_iter_cnt_reg (
				.data_in    (inner_iter_cnt_new[i]),
				.data_out   (inner_iter_cnt[i]),
				.load_EN    (inner_iter_cnt_load_En[i]),
				.*
			);
			assign inner_iter_cnt_new[i] = inner_iter_cnt[i] == TX / ITER_PARALLEL - 1 ? 'b0 : inner_iter_cnt[i] + 1'b1;
			assign inner_iter_cnt_load_En[i] = i == 0 && pip_status[1] == S_IDX_0 ||
											   i == 1 && pip_status[1] == S_IDX_1;
		
			dfflr #($bits(outer_iter_cnt[0]), 'b0) u_outer_iter_cnt_reg (
				.data_in    (outer_iter_cnt_new[i]),
				.data_out   (outer_iter_cnt[i]),
				.load_EN    (outer_iter_cnt_load_En[i]),
				.*
			);
			assign outer_iter_cnt_new[i] = outer_iter_cnt[i] == iter_num_i ? 'b0 : outer_iter_cnt[i] + 1'b1;
			assign outer_iter_cnt_load_En[i] = inner_iter_cnt[i] == TX / ITER_PARALLEL - 1 && inner_iter_cnt_load_En[i];
		end
	endgenerate


    // PIP1: delta_x cal. & gradient_neg update
	// occupation flag to sign the first inner iter
	logic ocp_flag, ocp_flag_new;
	dffr u_ocp_flag_reg (
		.data_in(ocp_flag_new),
		.data_out(ocp_flag),
		.*
	);
	assign ocp_flag_new = pip_ocp_En;
	
	// data
	logic [TX-1:0][GD_QTZ.width-1:0] gradient_neg_now;
    logic [ITER_PARALLEL-1:0][GD_QTZ.width-1:0] gradient_neg_mux_out;
    logic [ITER_PARALLEL-1:0][A_DIAG_INV_QTZ.width-1:0] A_diag_inv_mux_out; 
    logic [ITER_PARALLEL-1:0][X_QTZ.width-1:0] delta_x, delta_x_new;
    logic [ITER_PARALLEL-1:0] delta_x_load_En;
	
	assign gradient_neg_now = ocp_flag ? gradient_neg_i : gradient_neg_o;
    generate
        for (genvar i = 0; i < ITER_PARALLEL; i += 1) begin
			complex_real_multiplier #(
				.INPUT_COMPLEX_QTZ(GD_QTZ),
				.INPUT_REAL_QTZ(A_DIAG_INV_QTZ),
				.OUTPUT_COMPLEX_QTZ (X_QTZ)
			) multiplier(.complex_in(gradient_neg_mux_out[i]), .real_in(A_diag_inv_mux_out[i]), .complex_out(delta_x_new[i]));
            assign gradient_neg_mux_out[i] = gradient_neg_now[inner_iter_cnt_pip[0] + i * (TX / ITER_PARALLEL)];
            assign A_diag_inv_mux_out[i] = A_diag_inv_i[inner_iter_cnt_pip[0] + i * (TX / ITER_PARALLEL)];

            dffl #(X_QTZ.width) u_delta_x_reg (
                .data_in    (delta_x_new[i]),
                .data_out   (delta_x[i]),
                .load_EN    (delta_x_load_En[i]),
                .*
            );
            assign delta_x_load_En[i] = pip_status[0] != S_IDLE;
        end
    endgenerate
	
	// pip1 ctl signal
	assign gradient_neg_WEN_o = !ocp_flag && pip_status[0] != S_IDLE;
    assign gradient_neg_idx_o = pip_status[0] == S_IDX_0 ? 'b0 : 'b1;
	
    assign inner_iter_cnt_pip[0] = pip_status[0] == S_IDX_0 ? inner_iter_cnt[0] : inner_iter_cnt[1];
	assign A_diag_inv_idx_o = gradient_neg_idx_o;
	
    // PIP2: delta gradient_neg (part cal) & x update
    logic [1:0][TX-1:0][X_QTZ.width-1:0] x, x_new;
	logic [TX-1:0][X_QTZ.width-1:0] x_now;
    logic [ITER_PARALLEL-1:0][X_QTZ.width-1:0] x_update;
    logic [1:0][TX-1:0] x_load_En;
    logic [1:0] x_rst_sync;
    //assign x_rst_sync = pip_status[1] == S_IDLE;

    logic [ITER_PARALLEL/4-1:0][TX-1:0][GD_ACC_QTZ.width-1:0] delta_gradient_neg_part, delta_gradient_neg_part_new;
    logic [ITER_PARALLEL/4-1:0][TX-1:0] delta_gradient_neg_ld_En;

	// pip2 ctl signal
    assign Gram_rd_En_o = pip_status[0] != S_IDLE;
	assign Gram_rd_addr_o = pip_status[0] == S_IDX_0 ? inner_iter_cnt[0] : inner_iter_cnt[1];
	always_comb begin : GRAM_RD_IDX_O
		case (pip_status[0])
			S_IDX_0: begin
				Gram_rd_idx_o = 'b0;
			end S_IDX_1: begin
				Gram_rd_idx_o = 'b1;
			end S_IDLE: begin
				Gram_rd_idx_o = pip_status[1] == S_IDX_0 ? 'b0 : 'b1;
			end default: begin
				Gram_rd_idx_o = 'b0;
			end
		endcase
	end

    generate
        // x reg
		for (genvar j = 0; j < 2; j++) begin:X_UPDATE
			for (genvar i = 0; i < TX; i++) begin:X_REG
				dffl #(X_QTZ.width) u_x_reg (
					.data_in    (x_new[j][i]),
					.data_out   (x[j][i]),
					.load_EN    (x_load_En[j][i]),
					.*
				);
				assign x_new[j][i] = x_rst_sync[j] ? 'b0 : x_update[i / (TX / ITER_PARALLEL)];
				assign x_load_En[j][i] = x_rst_sync[j] ||
										 (j == 0 && pip_status[1] == S_IDX_0 || j == 1 && pip_status[1] == S_IDX_1) && inner_iter_cnt[j] == i % (TX / ITER_PARALLEL);
			end
			assign x_rst_sync[j] = ocp_flag && gradient_neg_idx_o == j;
		end
		
        // x update
		assign x_now = pip_status[1] == S_IDX_0 ? x[0] : x[1];
        assign inner_iter_cnt_pip[1] = pip_status[1] == S_IDX_0 ? inner_iter_cnt[0] : inner_iter_cnt[1];
		for (genvar i = 0; i < ITER_PARALLEL; i++) begin:X_UPDATE_ADDER
			complex_adder #(
				.INPUT_A_QTZ(X_QTZ),
				.INPUT_B_QTZ(X_QTZ),
				.OUTPUT_QTZ (X_QTZ)
			) adder(.InputA(x_now[inner_iter_cnt_pip[1] + i*(TX/ITER_PARALLEL)]), .InputB(delta_x[i]), .OutputC(x_update[i]));
		end

        // multiplier
		logic [ITER_PARALLEL-1:0][TX-1:0][GD_ACC_QTZ.width-1:0] delta_gradient_neg_mulout;
        for (genvar i = 0; i < ITER_PARALLEL; i += 1) begin
            for (genvar j = 0; j < TX; j += 1) begin
				complex_multiplier #(
					.INPUT_A_QTZ(G_QTZ),
					.INPUT_B_QTZ(X_QTZ),
					.OUTPUT_QTZ (GD_ACC_QTZ)
				) multiplier(.InputA(Gram_mat_i[i][j]), .InputB(delta_x[i]), .OutputC(delta_gradient_neg_mulout[i][j]));
            end
        end
    endgenerate

	// adder tree across PIP_1 and PIP_2
	logic [ITER_PARALLEL-1:0][TX-1:0][GD_ACC_QTZ.width-1:0] gradient_adder_out;
    logic [ITER_PARALLEL-1:0][TX-1:0][1:0][GD_ACC_QTZ.width-1:0] gradient_adder_in;
    generate
        for (genvar i = 0; i < ITER_PARALLEL; i += 1) begin:ADDER_TREE
            for (genvar j = 0; j < TX; j += 1) begin
			    complex_adder #(
			    	.INPUT_A_QTZ(GD_ACC_QTZ),
			    	.INPUT_B_QTZ(GD_ACC_QTZ),
			    	.OUTPUT_QTZ (GD_ACC_QTZ),
                    .SUB_EN(i == 0)
			    ) adder(.InputA(gradient_adder_in[i][j][0]), .InputB(gradient_adder_in[i][j][1]), .OutputC(gradient_adder_out[i][j]));

				// only for ITER_PARALLEL = 8
                assign gradient_adder_in[i][j][0] = i == 0 ? `COMPLEX_VALUE_TRANSFER(gradient_neg_i[j], GD_QTZ, GD_ACC_QTZ) :
													i < ITER_PARALLEL/4 ? delta_gradient_neg_part[2*(i-ITER_PARALLEL/8)][j] :
                                                    i >= ITER_PARALLEL/2 ? delta_gradient_neg_mulout[2*(i - ITER_PARALLEL/2)][j] :
                                                    gradient_adder_out[2*i][j];
                assign gradient_adder_in[i][j][1] = i == 0 ? gradient_adder_out[1][j]:
													i < ITER_PARALLEL/4 ? delta_gradient_neg_part[2*(i-ITER_PARALLEL/8)+1][j] :
                                                    i >= ITER_PARALLEL/2 ? delta_gradient_neg_mulout[2*(i - ITER_PARALLEL/2) + 1][j] :
                                                    gradient_adder_out[2*i+1][j];
            end
        end        

        // delta gradient_neg (pip_2 output)
        for (genvar i = 0; i < ITER_PARALLEL / 4; i += 1) begin
            for (genvar j = 0; j < TX; j += 1) begin
                dffl #(GD_ACC_QTZ.width) u_delta_gradient_neg_reg (
                    .data_in    (delta_gradient_neg_part_new[i][j]),
                    .data_out   (delta_gradient_neg_part[i][j]),
                    .load_EN    (delta_gradient_neg_ld_En[i][j]),
                    .*
                );
                assign delta_gradient_neg_ld_En[i][j] = pip_status[1] != S_IDLE;
				assign delta_gradient_neg_part_new[i][j] = gradient_adder_out[i + ITER_PARALLEL/4][j];
            end
        end

        for (genvar i = 0; i < TX; i++) begin
            assign gradient_neg_o[i] = `COMPLEX_VALUE_TRANSFER(gradient_adder_out[0][i], GD_ACC_QTZ, GD_QTZ);
        end
    endgenerate

    // x output
	logic x_out_idx, x_out_idx_new;
	logic x_out_idx_ld_En;
	dffl u_x_out_idx_reg (
		.data_in(x_out_idx_new),
		.data_out(x_out_idx),
		.load_EN(x_out_idx_ld_En),
		.*
	);
	assign x_out_idx_new = retire_idx_o;
	assign x_out_idx_ld_En = retire_ctl_o;

	// x valid
	logic x_valid_ld_En;
	dfflr u_x_valid_reg (
		.data_in(!x_valid_o),
		.data_out(x_valid_o),
		.load_EN(x_valid_ld_En),
		.*
	);
	assign x_valid_ld_En = x_valid_o && x_rst_sync[x_out_idx] || !x_valid_o && retire_ctl_o;

    assign retire_ctl_o = outer_iter_cnt[retire_idx_o] == iter_num_i && outer_iter_cnt_load_En[retire_idx_o];
    assign retire_idx_o = pip_status[1] == S_IDX_0 ? 'b0 : 'b1;
    assign iter_num_idx_o = retire_idx_o;

    assign x_o = x[x_out_idx];
endmodule