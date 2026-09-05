`timescale 1ns/1ps
`include "common.svh"

// Differential functional check for the G_PE -> G_PE_fused arithmetic swap
// (see doc/G_PE_full_library面积对比总结.md).
//
// The testbench is compiled twice with identical, fully deterministic stimulus:
//   1) compact G_PE   : -f syn/script/g_pe_struct/G_PE.filelist        (no define)
//   2) fused G_PE_fused: -f syn/script/g_pe_fused/G_PE_fused.filelist  (+define+USE_FUSED)
// Every sampled cycle prints one line
//     S <t> <acc_clean> <gout_chk> <greg> <gout0> <gout1>
// and compare_gpe_diff.py diffs the two traces.
//
// Two classes of vector are used:
//   * clean  : H / H_conj real/imag are EVEN fp6 codes, so every product is
//              exactly representable in G_MAC_QTZ.fp_w -> both implementations
//              must be BIT-IDENTICAL (diff == 0) while acc_clean == 1.
//   * random : arbitrary codes -> implementations may differ only by rounding
//              (bounded by compare_gpe_diff.py tolerance).
//
// Same register/control structure is shared by both DUTs; the only difference
// is the arithmetic core (compact per-stage-truncated mult/adder tree vs the
// fused arithmetic_unit_full complex_mac_w_bias).

module tb_gpe_diff;

    localparam int SP  = SYSTOLIC_PARALLEL;
    localparam int HW  = H_QTZ.width;     // H complex width (20)
    localparam int GW  = G_MAC_QTZ.width; // accumulator width (40)
    localparam int GOW = G_QTZ.width;     // G_out width (30)
    localparam int NC  = 8;               // clean accumulate cycles per window
    localparam int NR  = 8;               // random accumulate cycles per window
    localparam int NW  = 3;               // windows

    logic clk = 0;
    always #1 clk = ~clk;                 // 2 ns clock

    logic rst_n;
    logic G_reg_rst, G_out_EN, G_store_EN, G_clk_En;
    logic [SP-1:0][HW-1:0]  H_in, H_conj_in;
    logic [1:0][GOW-1:0]    G_in;
    wire   [1:0][GOW-1:0]   G_out;

`ifdef USE_FUSED
    G_PE_fused u_pe (
        .H_in(H_in), .H_conj_in(H_conj_in), .H_out(), .H_conj_out(),
        .clk(clk), .rst_n(rst_n), .G_reg_rst(G_reg_rst),
        .G_out(G_out), .G_in(G_in),
        .G_out_EN(G_out_EN), .G_store_EN(G_store_EN), .G_clk_En(G_clk_En)
    );
`else
    G_PE u_pe (
        .H_in(H_in), .H_conj_in(H_conj_in), .H_out(), .H_conj_out(),
        .clk(clk), .rst_n(rst_n), .G_reg_rst(G_reg_rst),
        .G_out(G_out), .G_in(G_in),
        .G_out_EN(G_out_EN), .G_store_EN(G_store_EN), .G_clk_En(G_clk_En)
    );
`endif

    wire [GW-1:0] greg = u_pe.G_reg;

    // classification flags for the data currently being accumulated
    bit acc_clean  = 0;
    bit gout_valid = 0;
    int err_cnt    = 0;

    // ------------------------------------------------------------------
    // deterministic value generator
    // H_QTZ real part = 10 b (sgn1 int3 fp6). Codes stay small so the
    // G_MAC accumulator (real range ~ +-0.5) never overflows.
    // ------------------------------------------------------------------
    function automatic logic [HW-1:0] mkH(input int w, input int t,
                                          input int lane, input bit conj,
                                          input bit clean);
        int p, rr, ri;
        logic signed [9:0] rr10, ri10;
        p = w * 997 + t * 131 + lane * 17 + (conj ? 1009 : 3);
        if (clean) begin
            rr = ((p % 5) - 2) * 2;              // -4,-2,0,2,4  (even fp6 code)
            ri = (((p / 7) % 5) - 2) * 2;
        end else begin
            rr = (p % 17) - 8;                   // -8..8
            ri = ((p / 7) % 17) - 8;
        end
        rr10 = rr;
        ri10 = ri;
        return {rr10, ri10};
    endfunction

    // ------------------------------------------------------------------
    // sample + in-run self checks
    // ------------------------------------------------------------------
    task automatic do_sample();
        bit gout_chk;
        gout_chk = (G_store_EN && acc_clean) || G_out_EN;
        $display("S %0t %0b %0b %h %h %h",
                 $time, acc_clean, gout_chk, greg, G_out[0], G_out[1]);
        if ($isunknown(greg)) begin
            $display("ERR_GREG_XZ @%0t", $time); err_cnt++;
        end
        if (gout_valid) begin
            if ($isunknown(G_out[0]) || $isunknown(G_out[1])) begin
                $display("ERR_GOUT_XZ @%0t", $time); err_cnt++;
            end
            if (G_out_EN) begin
                // bypass: both lanes must equal G_in
                if (G_out[0] !== G_in[0] || G_out[1] !== G_in[1]) begin
                    $display("ERR_BYPASS @%0t g0=%h g1=%h", $time, G_out[0], G_out[1]);
                    err_cnt++;
                end
            end else if (gout_chk) begin
                // clean store: both lanes hold the same transferred accumulator
                if (G_out[0] !== G_out[1]) begin
                    $display("ERR_GOUT_MISMATCH @%0t g0=%h g1=%h", $time, G_out[0], G_out[1]);
                    err_cnt++;
                end
            end
        end
    endtask

    // ------------------------------------------------------------------
    // stimulus
    // ------------------------------------------------------------------
    initial begin
        int t;
        rst_n = 0; G_reg_rst = 0; G_out_EN = 0; G_store_EN = 0; G_clk_En = 0;
        H_in = '0; H_conj_in = '0; G_in = '0;

        repeat (3) @(posedge clk);   // run a few cycles before releasing reset
        rst_n = 1;

        // ---- first G_reg clear (register starts at x) ----
        G_reg_rst = 1; G_clk_En = 1;
        @(posedge clk); #1;
        if (greg !== '0) begin $display("ERR_RESET greg=%h", greg); err_cnt++; end
        G_reg_rst = 0;

        for (int w = 0; w < NW; w++) begin
            // ---- clear accumulator for the window ----
            G_reg_rst = 1; G_clk_En = 1; H_in = '0; H_conj_in = '0;
            @(posedge clk); #1; do_sample();
            G_reg_rst = 0;

            // ---- clean accumulate ----
            acc_clean = 1;
            for (t = 0; t < NC; t++) begin
                for (int l = 0; l < SP; l++) begin
                    H_in[l]      = mkH(w, t, l, 1'b0, 1'b1);
                    H_conj_in[l] = mkH(w, t, l, 1'b1, 1'b1);
                end
                @(posedge clk); #1; do_sample();
            end
            // clean store
            gout_valid = 1;
            G_clk_En = 0; G_store_EN = 1; H_in = '0; H_conj_in = '0;
            @(posedge clk); #1; do_sample();
            G_store_EN = 0;
            // hold + read
            repeat (2) begin @(posedge clk); #1; do_sample(); end
            // bypass G_in through G_out (output one-by-one mode)
            G_out_EN = 1; G_in[0] = 30'h2AAAAAA; G_in[1] = 30'h1555555;
            @(posedge clk); #1; do_sample();
            G_out_EN = 0; G_in = '0;
            @(posedge clk); #1; do_sample();

            // ---- random accumulate ----
            acc_clean = 0;
            G_reg_rst = 1; G_clk_En = 1; H_in = '0; H_conj_in = '0;
            @(posedge clk); #1; do_sample();
            G_reg_rst = 0;
            for (t = 0; t < NR; t++) begin
                for (int l = 0; l < SP; l++) begin
                    H_in[l]      = mkH(w, t, l, 1'b0, 1'b0);
                    H_conj_in[l] = mkH(w, t, l, 1'b1, 1'b0);
                end
                @(posedge clk); #1; do_sample();
            end
            // random store
            G_clk_En = 0; G_store_EN = 1; H_in = '0; H_conj_in = '0;
            @(posedge clk); #1; do_sample();
            G_store_EN = 0;
            @(posedge clk); #1; do_sample();
        end

        // ---- tail idle ----
        G_clk_En = 0; G_store_EN = 0; G_out_EN = 0; H_in = '0; H_conj_in = '0;
        repeat (3) begin @(posedge clk); #1; do_sample(); end

        if (err_cnt == 0)
            $display("SELF_CHECK: PASS (no in-run xz / reset / bypass / store errors)");
        else
            $display("SELF_CHECK: FAIL (%0d errors)", err_cnt);
        $display("TB_DONE");
        $finish;
    end

endmodule