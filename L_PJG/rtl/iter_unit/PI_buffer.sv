`include "common.svh"

module PI_buffer (
    // handshake with systolic array
    input systolic_data_rx_valid,
    output systolic_data_rx_ready,
    input [$clog2(TX)-1:0] input_addr_i,

    // data in from systolic array
    input [TX-1:0][G_QTZ.width-1:0] A_i,
    input [A_DIAG_INV_QTZ.width-1:0] A_diag_inv_i,
    input [YMF_QTZ.width-1:0] y_mf_i,
    // input [N0_QTZ.width-1:0] n0_i,
    input [ITER_NUM_WIDTH-1:0] iter_num_i,

	// buffer active
	input active_ctl_i,	// active current buffer
    output valid_o,
	output valid_buf_idx_o,
	
	// buffer retire
    input retire_ctl_i,
	input retire_idx_i,
	
	// Gram read with 1 CC delay
    input Gram_rd_En_i,
	input Gram_rd_idx_i,
	input [$clog2(TX)-1:0] Gram_rd_addr_i,
	output [VEC_MUL_NUM-1:0][TX-1:0][G_QTZ.width-1:0] Gram_mat_o,
	
	// gradient_neg rd & wr
    input gradient_neg_WEN_i,
	input gradient_neg_idx_i,
	input  [TX-1:0][GD_QTZ.width-1:0] gradient_neg_i,
    output [TX-1:0][GD_QTZ.width-1:0] gradient_neg_o,

	// A_diag_inv rd
	input A_diag_inv_idx_i,
	output [TX-1:0][A_DIAG_INV_QTZ.width-1:0] A_diag_inv_o,
	
	// iter_num rd
	input iter_num_idx_i,
	output [ITER_NUM_WIDTH-1:0] iter_num_o,
	
	//output [N0_QTZ.width-1:0] n0_o,
    // utilities
    input clk, rst_n
);

    // write signal
    logic pp_write;
    assign pp_write = systolic_data_rx_valid && systolic_data_rx_ready;

    // pipeline-interleaving buffer ready cnt
    logic [1:0] valid_cnt, valid_cnt_new;
    logic valid_cnt_load_En;
    dfflr #($bits(valid_cnt), 'b0) u_valid_cnt_reg(
        .data_in    (valid_cnt_new),
        .data_out   (valid_cnt),
        .load_EN    (valid_cnt_load_En),
        .*
    );
    assign valid_cnt_new = retire_ctl_i ? valid_cnt - 1'b1 : valid_cnt + 1'b1;
    assign valid_cnt_load_En = retire_ctl_i ^ (pp_write && input_addr_i == TX - 1);

    // ping-pong buffer status
    assign systolic_data_rx_ready = valid_cnt != 'd2;

    // input index
	// TODO: modify when the iter_num is different
    logic input_index, input_index_new;
    logic input_index_load_En;
    dfflr input_index_reg(
        .data_in(input_index_new),
        .data_out(input_index),
        .load_EN(input_index_load_En),
        .*
    );
	assign input_index_new = !input_index;
    assign input_index_load_En = pp_write && input_addr_i == TX - 1;

    // valid to LPJG_unit
    logic [1:0] active_cnt, active_cnt_new;
	logic active_cnt_load_En;
	dfflr #($bits(active_cnt), 'b0) u_active_cnt_reg(
        .data_in    (active_cnt_new),
        .data_out   (active_cnt),
        .load_EN    (active_cnt_load_En),
        .*
    );
	assign active_cnt_new = retire_ctl_i ? active_cnt - 1'b1 : active_cnt + 1'b1;
	assign active_cnt_load_En = retire_ctl_i ^ (active_ctl_i & valid_o);
    assign valid_o = (active_cnt != valid_cnt) || (pp_write && input_addr_i == TX - 1);

    // valid_buf_idx_o
    // logic output_index;
	// TODO: modify when the iter_num is different
    logic valid_buf_idx_o_ld_En;
    dfflr valid_buf_idx_reg(
        .data_in(!valid_buf_idx_o),
        .data_out(valid_buf_idx_o),
        .load_EN(valid_buf_idx_o_ld_En),
        .*
    );
    assign valid_buf_idx_o_ld_En = (active_ctl_i & valid_o);

    // signal in ping-pong buffer 
    // Gram RAM
    logic [1:0] G_ram_En, G_ram_wEn;
    logic [1:0][$clog2(TX)-1:0] G_ram_Addr;
    logic [1:0][TX-1:0][G_QTZ.width-1:0] G_ram_wData;
    logic [1:0][ITER_PARALLEL-1:0][TX-1:0][G_QTZ.width-1:0] G_ram_rData;

    // gradient_neg reg
    logic [1:0][TX-1:0][GD_QTZ.width-1:0] gradient_neg, gradient_neg_new;
    logic [1:0][TX-1:0] gradient_neg_load_En;

    // A_diag_inv
    logic [1:0][TX-1:0][A_DIAG_INV_QTZ.width-1:0] A_diag_inv, A_diag_inv_new;
    logic [1:0][TX-1:0] A_diag_inv_load_En;

    // n0
    // logic [1:0][N0_QTZ.width-1:0] n0, n0_new;
    // logic [1:0] n0_load_En;

    // iter_num
    logic [1:0][ITER_NUM_WIDTH-1:0] iter_num, iter_num_new;
    logic [1:0] iter_num_load_En;

    // pipeline-interleaving buffer
    generate
        for (genvar i = 0; i < 2; i += 1) begin:PING_PONG_BUFFER
            // Gram sram
            SP_Ram_array #(
                .DATA_WIDTH(G_QTZ.width),
                .DEPTH(TX),
                .RANK(TX),
                .BANK(ITER_PARALLEL)
            ) u_G_Ram (
                .wEn_i  (G_ram_wEn  [i]),
                .En_i   (G_ram_En   [i]),
                .Addr_i (G_ram_Addr [i]),
                .wData_i(G_ram_wData[i]),
                .rData_o(G_ram_rData[i]),
                .*
            );
            assign G_ram_wEn  [i] = input_index == i && pp_write;
            assign G_ram_En   [i] = input_index == i && pp_write || Gram_rd_idx_i == i && Gram_rd_En_i;
            assign G_ram_Addr [i] = G_ram_wEn[i] ? input_addr_i : Gram_rd_addr_i;
            assign G_ram_wData[i] = A_i;

            // reg
            for (genvar j = 0; j < TX; j += 1) begin
                // gradient_neg
			    dffl #(GD_QTZ.width) u_gradient_neg_reg (
			    	.data_in(gradient_neg_new[i][j]),
			    	.data_out(gradient_neg[i][j]),
			    	.load_EN(gradient_neg_load_En[i][j]),
			    	.*
			    );
                assign gradient_neg_new[i][j] = input_index == i && pp_write ? (j == TX - 1 ? `COMPLEX_VALUE_TRANSFER(y_mf_i, YMF_QTZ, GD_QTZ) : gradient_neg[i][j+1]): 
                                                gradient_neg_i[j];
                assign gradient_neg_load_En[i][j] = input_index == i && pp_write || 
                                                    gradient_neg_idx_i == i && gradient_neg_WEN_i;

                // A_diag_inv
                dffl #(A_DIAG_INV_QTZ.width) u_A_diag_inv_reg (
			    	.data_in    (A_diag_inv_new[i][j]),
			    	.data_out   (A_diag_inv[i][j]),
			    	.load_EN    (A_diag_inv_load_En[i][j]),
			    	.*
                );
                assign A_diag_inv_new[i][j] = j == TX - 1 ? A_diag_inv_i : A_diag_inv[i][j+1];
                assign A_diag_inv_load_En[i][j] = input_index == i && pp_write;
            end

            // n0
            // dffl #(N0_QTZ.width) u_n0_reg (
			//     .data_in    (n0_new[i]),
			//     .data_out   (n0[i]),
			//     .load_EN    (n0_load_En[i]),
			//     .*
            // );
            // assign n0_new[i] = n0_i;
            // assign n0_load_En[i] = input_index == i && pp_write;

            // iter_num
            dffl #(ITER_NUM_WIDTH) u_iter_num_reg (
			    .data_in    (iter_num_new[i]),
			    .data_out   (iter_num[i]),
			    .load_EN    (iter_num_load_En[i]),
			    .*
            );
            assign iter_num_new[i] = iter_num_i;
            assign iter_num_load_En[i] = input_index == i && pp_write;
        end
    endgenerate

    // output data
	// Gram_rd_idx needs to be delayed for 1 CC
	logic Gram_rd_idx;
	logic Gram_rd_idx_ld_En;
	dffl u_Gram_rd_idx_reg (
		.data_in(Gram_rd_idx_i),
		.data_out(Gram_rd_idx),
		.load_EN(Gram_rd_idx_ld_En),
		.*
	);
	assign Gram_rd_idx_ld_En = Gram_rd_En_i;
	
    assign Gram_mat_o = G_ram_rData[Gram_rd_idx];
    assign gradient_neg_o = gradient_neg[gradient_neg_idx_i]; 
    assign A_diag_inv_o = A_diag_inv[A_diag_inv_idx_i];
    assign iter_num_o = iter_num[iter_num_idx_i];
    //assign n0_o = n0[output_index];

endmodule