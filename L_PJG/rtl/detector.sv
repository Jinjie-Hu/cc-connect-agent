`include "common.svh"

module detector (
    // clk and rst_n
    input clk,
    input rst_n,

    output systolic_rx_ready,
    input systolic_rx_valid,

    input [SYSTOLIC_PARALLEL-1:0][TX-1:0][H_QTZ.width-1:0] H_in,
    input [SYSTOLIC_PARALLEL-1:0][Y_QTZ.width-1:0] y_in,
    input [N0_QTZ.width-1:0] n0_in,                       
    input [ITER_NUM_WIDTH-1:0] iter_num_i, // iter_num_i == 0 implies one iteration num;
    input finish_flag_i,                                           

    // iter unit output
    output [TX-1:0][X_QTZ.width-1:0] x_o,
    output x_valid_o
);
    
    // A_systolic_array 的输出
    wire [TX-1:0][G_QTZ.width-1:0] A_out;
    wire [A_DIAG_QTZ.width-1:0] G_diag_out;
    wire [YMF_QTZ.width-1:0] y_mf_out;
    wire [N0_QTZ.width-1:0] n0_out, n0_out_2;
    wire [$clog2(TX)-1:0] input_addr;
    wire [ITER_NUM_WIDTH-1:0] iter_num_1, iter_num_2;
    
    // ping_pong_buffer 与 LPJG_unit 之间的信号
    wire valid_o;
    wire retire_ctl_o;
    wire Gram_rd_En_o;
    wire gradient_neg_WEN_o;
    
    wire [VEC_MUL_NUM-1:0][TX-1:0][G_QTZ.width-1:0] Gram_mat_i;
    wire [TX-1:0][GD_QTZ.width-1:0] gradient_neg_i;
    wire [TX-1:0][GD_QTZ.width-1:0] gradient_neg_o;
    wire [TX-1:0][A_DIAG_INV_QTZ.width-1:0] A_diag_inv_i;
    wire systolic_data_ready;
    wire systolic_data_valid;

    // 例化 A_systolic_array
    A_systolic_array u_A_systolic_array (
        .H_in(H_in),
        .y_in(y_in),
        .n0_in(n0_in),
        .systolic_rx_ready(systolic_rx_ready),
        .systolic_rx_valid(systolic_rx_valid),
        .iter_num_i(iter_num_i),
        .finish_flag_i(finish_flag_i),
        
        .A_out(A_out),
        .A_diag_out(G_diag_out),
        .y_mf_out(y_mf_out),
        .n0_out(n0_out),
        
        .data_tx_addr_o(input_addr),
        .systolic_data_tx_ready(systolic_data_ready),
        .systolic_data_tx_valid(systolic_data_valid),
        .iter_num_o(iter_num_1),
        
        .clk(clk),
        .rst_n(rst_n)
    );

    logic [A_DIAG_INV_QTZ.width-1:0] A_diag_inv;
    reciprocal_lut u_reci_lut(.InputA(G_diag_out[A_DIAG_QTZ.width-A_DIAG_QTZ.sgn_w-1 -: A_DIAG_QTZ.int_w]), .OutputB(A_diag_inv));

    logic active_ctl, valid_buf_idx, retire_idx, Gram_rd_idx, gradient_neg_EN, gradient_neg_idx, A_diag_inv_idx, iter_num_idx;
    logic [$clog2(TX)-1:0] Gram_rd_addr;
    // 例化 PI_buffer
    PI_buffer u_PI_buffer (
        .systolic_data_rx_ready(systolic_data_ready),
        .systolic_data_rx_valid(systolic_data_valid),
        .active_ctl_i(active_ctl),
        .valid_buf_idx_o(valid_buf_idx),
        // buffer retire
        .retire_idx_i(retire_idx),
    
        // Gram read with 1 CC delay
        .Gram_rd_idx_i(Gram_rd_idx),
        .Gram_rd_addr_i(Gram_rd_addr),
    
        // gradient_neg rd & wr
        .gradient_neg_idx_i(gradient_neg_idx),

        // A_diag_inv rd
        .A_diag_inv_idx_i(A_diag_inv_idx),
    
        // iter_num rd
        .iter_num_idx_i(iter_num_idx),
    
        .A_i(A_out),                // 来自 A_systolic_array
        .A_diag_inv_i(A_diag_inv),  // 来自 A_systolic_array
        .y_mf_i(y_mf_out),          // 来自 A_systolic_array
        .iter_num_i(iter_num_1),
        .input_addr_i(input_addr),
        
        .valid_o(valid_o),          // 到 LPJG_unit
        .iter_num_o(iter_num_2),
        
        .Gram_mat_o(Gram_mat_i),    // 到 LPJG_unit
        .gradient_neg_i(gradient_neg_o),  // 来自 LPJG_unit
        .gradient_neg_o(gradient_neg_i),  // 到 LPJG_unit
        .A_diag_inv_o(A_diag_inv_i),      // 到 LPJG_unit
        
        .retire_ctl_i(retire_ctl_o),      // 来自 LPJG_unit
        .Gram_rd_En_i(Gram_rd_En_o),      // 来自 LPJG_unit
        .gradient_neg_WEN_i(gradient_neg_WEN_o),  // 来自 LPJG_unit
        
        .clk(clk),
        .rst_n(rst_n)
    );

    // 例化 LPJG_unit
    LPJG_unit u_LPJG_unit (
        .active_ctl_o(active_ctl),	// active current buffer
        .valid_buf_idx_i(valid_buf_idx),
    
    // buffer retire
        .retire_idx_o(retire_idx),
    
    // Gram read with 1 CC delay
        .Gram_rd_idx_o(Gram_rd_idx),
        .Gram_rd_addr_o(Gram_rd_addr),
    
    // gradient_neg rd & wr
        .gradient_neg_idx_o(gradient_neg_idx),

    // A_diag_inv rd
        .A_diag_inv_idx_o(A_diag_inv_idx),
    
    // iter_num rd
        .iter_num_idx_o(iter_num_idx),

        .valid_i(valid_o),          // 来自 ping_pong_buffer
        
        .retire_ctl_o(retire_ctl_o),        // 到 ping_pong_buffer
        .Gram_rd_En_o(Gram_rd_En_o),        // 到 ping_pong_buffer
        .gradient_neg_WEN_o(gradient_neg_WEN_o),  // 到 ping_pong_buffer
        
        .Gram_mat_i(Gram_mat_i),            // 来自 ping_pong_buffer
        .gradient_neg_i(gradient_neg_i),    // 来自 ping_pong_buffer
        .gradient_neg_o(gradient_neg_o),    // 到 ping_pong_buffer
        .A_diag_inv_i(A_diag_inv_i),        // 来自 ping_pong_buffer
        .iter_num_i(iter_num_2),

        .x_o(x_o),
        .x_valid_o(x_valid_o),
        
        .clk(clk),
        .rst_n(rst_n)
    );
endmodule