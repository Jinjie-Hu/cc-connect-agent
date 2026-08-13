`include "common.svh"

module A_systolic_array (
    // data in as systolic array
    input [SYSTOLIC_PARALLEL-1:0][TX-1:0][H_QTZ.width-1:0] H_in,
    input [SYSTOLIC_PARALLEL-1:0][Y_QTZ.width-1:0] y_in,
    input [N0_QTZ.width-1:0] n0_in,
    input systolic_rx_valid,
    output systolic_rx_ready,
    input [ITER_NUM_WIDTH-1:0] iter_num_i,
    input finish_flag_i,

    // data out as systolic array
    output [TX-1:0][G_QTZ.width-1:0] A_out,
    output [A_DIAG_QTZ.width-1:0] A_diag_out,
    output [YMF_QTZ.width-1:0] y_mf_out,
    output [N0_QTZ.width-1:0] n0_out,
    output [ITER_NUM_WIDTH-1:0] iter_num_o,

    // handshake with ping-pong buffer
    output systolic_data_tx_valid,
    input systolic_data_tx_ready,
    output [$clog2(TX)-1:0] data_tx_addr_o,

    input clk,
    input rst_n
);
    logic [TX-1:0] G_store_EN;
    logic [TX-1:0] G_reg_rst, G_reg_rst_reg, G_reg_rst_reg_new, G_reg_rst_reg_load;
    logic [TX-1:0] y_mf_rst;
    logic G_out_EN;
    logic y_mf_out_EN;
    logic [TX-1:0] systolic_clk_En, systolic_clk_En_reg, systolic_clk_En_reg_new;
    logic [TX-1:0] systolic_clk_En_reg_ld_En;


    wire [TX:0][TX-1:0][SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_send;
    wire [TX-1:0][TX:0][SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_conj_send;
    wire [TX:0][SYSTOLIC_PARALLEL-1:0][Y_QTZ.width-1:0] y_send;
    wire [TX-1:0][TX-1:0][1:0][G_QTZ.width-1:0] G_send;
    wire [TX-1:0][TX-1:0][1:0][G_QTZ.width-1:0] G_send_new;
    wire [TX-1:0][  G_QTZ.width-1:0] G_conj_send;
    wire [  TX:0][YMF_QTZ.width-1:0] y_mf_send  ;

    // status trasfer
    // unit status
    enum logic [0:0] {
        S_UNIT_RUN,     // normal status 
        S_UNIT_STALL    // wait for out_status
    }
        unit_status, unit_status_new;

    enum logic [1:0] {
        S_OUT_IDLE,     // idle
        S_OUT_PRE_RUN,  // systolic array calculation
        S_OUT_STALL,    // wait for ping-pong buffer
        S_OUT_RUN       // transfer data to IU
    }
        out_status, out_status_new;

    // status transfer must use always to avoid verilog error
    always_ff @( posedge clk or negedge rst_n ) begin : OUT_STATUS
        if (!rst_n) begin
            out_status <= S_OUT_IDLE;
            unit_status <= S_UNIT_RUN;
        end else begin
            out_status <= out_status_new;
            unit_status <= unit_status_new;
        end
    end

    logic [TX-1:0] out_cnt, out_cnt_new; // TX one-hot code
    logic out_cnt_load_En;

    logic out_unit_ready, out_unit_valid;
    assign out_unit_ready = out_status == S_OUT_IDLE ||
                            out_status == S_OUT_RUN && out_cnt[TX - 1] && systolic_data_tx_ready && systolic_data_tx_valid;
    assign out_unit_valid = unit_status == S_UNIT_STALL || 
                            unit_status == S_UNIT_RUN && finish_flag_i && systolic_rx_valid && systolic_rx_ready;

    always_comb begin
        case (unit_status)
            S_UNIT_RUN: begin
                unit_status_new = finish_flag_i & systolic_rx_valid & systolic_rx_ready & !(out_unit_ready & out_unit_valid) ? S_UNIT_STALL : S_UNIT_RUN;
            end
            S_UNIT_STALL: begin
                unit_status_new = (out_unit_ready & out_unit_valid) ? S_UNIT_RUN : S_UNIT_STALL;
            end
            default: begin
                unit_status_new = S_UNIT_RUN;
            end
        endcase
    end

    // status 
    assign systolic_rx_ready = unit_status == S_UNIT_RUN;

    // out status control
    assign out_cnt_load_En = out_status == S_OUT_PRE_RUN || systolic_data_tx_ready && systolic_data_tx_valid;
    assign out_cnt_new = {out_cnt[TX-2:0], out_cnt[TX-1]}; // left shift (loop)
    dfflr #($bits(out_cnt), 'b1) u_out_cnt_reg(
        .data_in(out_cnt_new),
        .data_out(out_cnt),
        .load_EN(out_cnt_load_En),
        .*
    );

    always_comb begin
        case (out_status)
            S_OUT_IDLE: begin
                out_status_new = out_unit_ready && out_unit_valid ? S_OUT_PRE_RUN : S_OUT_IDLE;
            end
            S_OUT_PRE_RUN: begin
                out_status_new = !(out_cnt[TX - 1] && G_store_EN[TX-1]) ? S_OUT_PRE_RUN :
                                 systolic_data_tx_ready ?  S_OUT_RUN : S_OUT_STALL;
            end
            S_OUT_STALL: begin
                out_status_new = systolic_data_tx_ready && systolic_data_tx_valid ? S_OUT_RUN : S_OUT_STALL;
            end
            S_OUT_RUN: begin
                out_status_new = !(out_cnt[TX - 1] && systolic_data_tx_ready && systolic_data_tx_valid) ? S_OUT_RUN :
                                 out_unit_ready && out_unit_valid ? S_OUT_PRE_RUN : S_OUT_IDLE;
            end
            default: begin
                out_status_new = S_OUT_IDLE;
            end
        endcase
    end

    // control signal
    assign systolic_data_tx_valid = out_status == S_OUT_RUN || out_status == S_OUT_STALL;

    assign G_out_EN = systolic_data_tx_ready && systolic_data_tx_valid;
    assign y_mf_out_EN = G_out_EN;

    generate
        for (genvar i = 1; i < $bits(systolic_clk_En_reg); i++) begin
            dffr u_systolic_clk_En_reg (
                .data_in(systolic_clk_En_reg_new[i]),
                .data_out(systolic_clk_En_reg[i]),
                .*
            );
            assign systolic_clk_En_reg_new[i] = systolic_clk_En[i-1];
        end
    endgenerate
    assign systolic_clk_En_reg[0] = systolic_rx_ready & systolic_rx_valid;
    assign systolic_clk_En_reg_new[0] = 'b0;
    assign systolic_clk_En_reg_ld_En[0] = 'b0;
    assign systolic_clk_En = systolic_clk_En_reg;

    assign G_store_EN = out_status == S_OUT_PRE_RUN ? out_cnt : 'b0;

    `ifndef DISABLE_SV_ASSERTION
    assert property (@(posedge clk) $onehot0(G_store_EN)) else $stop();
    `endif

    generate
        for (genvar i = 0; i < TX ; i += 1) begin: G_REG_RST
            assign G_reg_rst_reg_new[i] = !G_reg_rst_reg[i];
            assign G_reg_rst_reg_load[i] = G_reg_rst_reg[i] && systolic_clk_En[i] || !G_reg_rst_reg[i] && G_store_EN[i] && !systolic_clk_En[i];
            dfflr #(1, 1'b1) u_G_reg_rst_dff (
                .data_in(G_reg_rst_reg_new[i]),
                .data_out(G_reg_rst_reg[i]),
                .load_EN(G_reg_rst_reg_load[i]),
                .*
            );
            assign G_reg_rst[i] = G_reg_rst_reg[i] | G_store_EN[i];
        end
    endgenerate
    assign y_mf_rst = G_reg_rst;

    // Gram matrix systolic array & y_mf calculate
    assign y_send[0] = y_in;
    assign y_mf_send[TX] = 'b0;
    assign y_mf_out = y_mf_send[0];

    generate
        for (genvar i = 0; i < TX; i = i + 1) begin : G_row
            for (genvar j = 0; j < SYSTOLIC_PARALLEL; j = j + 1) begin: SYSTOLIC_PARALLEL_INPUT
                assign H_send[i][i][j] = H_in[j][i];
                complex_conj #(
                    .INPUT_QTZ(H_QTZ)
                ) u_conjunction (
                    .InputA (H_send[i][i][j]),
                    .OutputB(H_conj_send[i][i+1][j])
                );
            end

            MF_PE mf_pe (
                .y_in(y_send[i]),
                .y_out(y_send[i+1]),
                .H_conj_in(H_conj_send[i][1]),
                .y_mf_out(y_mf_send[i]),
                .y_mf_in(y_mf_send[i+1]),
                .y_mf_out_EN(y_mf_out_EN),
                .y_mf_store_EN(G_store_EN[i]),
                .y_mf_rst(y_mf_rst[i]),
                .y_mf_clk_En(systolic_clk_En[i]),
                .*
            );

            for (genvar j = 0; j <= i; j = j + 1) begin : G_column
                if (j == i) begin
                    G_PE_diag u_pe_diag (
                        .H_in(H_send[i][j]),
                        .H_conj_in(H_conj_send[i][j+1]),
                        .H_out(H_send[i+1][j]),
                        .H_conj_out(H_conj_send[i][j]),
                        .G_out(G_send[i][j]),
                        .G_in(G_send_new[i][j]),
                        .G_out_EN(G_out_EN),
                        .G_reg_rst(G_reg_rst[i-j]),
                        .G_store_EN(G_store_EN[i-j]),
                        .G_clk_En(systolic_clk_En[i-j]),
                        .*
                    );
                end else begin
                    G_PE u_pe (
                        .H_in(H_send[i][j]),
                        .H_conj_in(H_conj_send[i][j+1]),
                        .H_out(H_send[i+1][j]),
                        .H_conj_out(H_conj_send[i][j]),
                        .G_out(G_send[i][j]),
                        .G_in(G_send_new[i][j]),
                        .G_out_EN(G_out_EN),
                        .G_reg_rst(G_reg_rst[i-j]),
                        .G_store_EN(G_store_EN[i-j]),
                        .G_clk_En(systolic_clk_En[i-j]),
                        .*
                    );
                end
                assign G_send_new[i][j][0] = i != j && j == TX-1 ? 'b0 :
                                             i != j ? G_send[i][j+1][0] : G_conj_send[i]; // horizontal
                assign G_send_new[i][j][1] = i == TX-1 ? 'b0 :
                                             i != j ? G_send[i+1][j][1] : 'b0;  // vertical
            end

            assign A_out[i] = out_cnt[i] ? {A_diag_out, {(G_QTZ.width/2){1'b0}}} : G_send[i][0][0];

            if (i < TX - 1) begin
                complex_conj #(
                    .INPUT_QTZ(G_QTZ)
                ) u_conjunction_G_out_0 (
                    .InputA (G_send[i+1][i][1]),
                    .OutputB(G_conj_send[i])
                );
            end else begin
                assign G_conj_send[i] = 'b0;
            end
        end
    endgenerate

    logic [$clog2(TX)-1:0] out_index;

    one_hot_decoder #($bits(out_cnt)) u_one_hot_dec(
        .one_hot_in(out_cnt),
        .binary_out(out_index)
    );


	real_adder #(
		.INPUT_A_QTZ(G_DIAG_QTZ),
		.INPUT_B_QTZ(N0_QTZ),
		.OUTPUT_QTZ (A_DIAG_QTZ)
    ) u_real_add(
		.InputA(G_send[out_index][0][0][G_QTZ.width-1 -: G_DIAG_QTZ.width]),
		.InputB(n0_out),
		.OutputC(A_diag_out)
	);

    assign data_tx_addr_o = out_index;

    // n0 dfflr
    logic [N0_QTZ.width-1:0] n0_stall, n0_out_new;
    logic n0_stall_ld_En, n0_out_ld_En;
    dffl #(
        (N0_QTZ.width)
    ) u_dfflr_n0_stall_reg (
        .data_in (n0_in),
        .data_out(n0_stall),
        .load_EN (n0_stall_ld_En),
        .*
    );
    assign n0_stall_ld_En = unit_status == S_UNIT_RUN && (finish_flag_i & systolic_rx_valid & systolic_rx_ready & !(out_unit_ready & out_unit_valid));

    assign n0_out_new = unit_status == S_UNIT_STALL ? n0_stall : n0_in;
    assign n0_out_ld_En = out_unit_ready & out_unit_valid; 
    dffl #(
        (N0_QTZ.width)
    ) u_dfflr_n0_out_reg (
        .data_in (n0_out_new),
        .load_EN (finish_flag_i & systolic_rx_valid & systolic_rx_ready),
        .data_out(n0_out),
        .*
    );

    // iter_num dfflr
    logic [ITER_NUM_WIDTH-1:0] iter_num_stall, iter_num_o_new;
    logic iter_num_stall_ld_En, iter_num_out_ld_En;

    assign iter_num_stall_ld_En = n0_stall_ld_En;
    dffl #(ITER_NUM_WIDTH) u_iter_num_stall_reg (
        .data_in (iter_num_i),
        .data_out(iter_num_stall),
        .load_EN (iter_num_stall_ld_En),
        .*
    );

    assign iter_num_out_ld_En = n0_out_ld_En;
    assign iter_num_o_new = unit_status == S_UNIT_STALL ? iter_num_stall : iter_num_i;
    dffl #(ITER_NUM_WIDTH) u_iter_num_out_reg (
        .data_in (iter_num_o_new),
        .data_out(iter_num_o),
        .load_EN (iter_num_out_ld_En),
        .*
    );

endmodule
