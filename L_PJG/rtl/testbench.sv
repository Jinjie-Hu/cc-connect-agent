`include "common.svh"
`timescale 1ns/1ps

module tb_detector;

    // Parameters
    localparam RX = 128;
    //parameter SHIFT_LEN = $clog2(RX);
    localparam ITER_NUM = `TEST_ITER_NUM-1;
    localparam INPUT_CC = RX / SYSTOLIC_PARALLEL;
    localparam real CLK_PERIOD = 1.4; // Clock period in time units

    string output_name = `OUTPUT_FILE_NAME;
    string fsdb_name = {output_name, ".fsdb"};
    string saif_name = {output_name, ".saif"};

    // Clock and reset signals
    reg clk;
    reg rst_n;

	int signed count, count_new;
    reg signed [32-1:0] H_in_real_data[RX*TX-1:0];
    reg signed [32-1:0] H_in_img_data [RX*TX-1:0];
    reg signed [32-1:0] y_in_real_data[RX-1:0];
    reg signed [32-1:0] y_in_img_data[RX-1:0] ;
    reg signed [32-1:0] noise_data[0:0];


    reg signed [SYSTOLIC_PARALLEL-1:0][TX-1:0][H_QTZ.width/2-1:0] H_in_real;
    reg signed [SYSTOLIC_PARALLEL-1:0][TX-1:0][H_QTZ.width/2-1:0] H_in_img ;
    reg signed [SYSTOLIC_PARALLEL-1:0][Y_QTZ.width/2-1:0] y_in_real;
    reg signed [SYSTOLIC_PARALLEL-1:0][Y_QTZ.width/2-1:0] y_in_img ;

    // 输入信号
    reg [SYSTOLIC_PARALLEL-1:0][TX-1:0][H_QTZ.width-1:0] H_in;
    reg [SYSTOLIC_PARALLEL-1:0][Y_QTZ.width-1:0] y_in;
    reg [N0_QTZ.width-1:0] n0_in;
    reg finish_flag_i;
    wire [ITER_NUM_WIDTH-1:0] iter_num;
    
    // 输出信号
    wire [TX-1:0][X_QTZ.width-1:0] x_o;
    wire x_valid_o;
    
    // 例化被测模块 (DUT)
    logic systolic_rx_valid;
    logic systolic_rx_ready;

    detector u_detector (
        .clk(clk),
        .rst_n(rst_n),
        .H_in(H_in),
        .y_in(y_in),
        .n0_in(n0_in),
        .finish_flag_i(finish_flag_i),
        .x_o(x_o),
        .x_valid_o(x_valid_o),
        .iter_num_i(iter_num),
        .*
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Reset generation
    //int test;
    initial begin
        // test
        //test = (1 + $floor((8*5+1)**0.5)/2);
        //$display("test = %f, 7/2 = %f(%d)\n", test, 7/2, 7/2);
        rst_n = 0;
        #(CLK_PERIOD * 2.5);
        rst_n = 1;
    end

    // Test sequence
    initial begin
        // Initialize inputs
        $readmemh("/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/data/128x32_c5/H_r.txt", H_in_real_data);
        $readmemh("/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/data/128x32_c5/H_i.txt" , H_in_img_data);
        $readmemh("/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/data/128x32_c5/y_r.txt", y_in_real_data);
        $readmemh("/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/data/128x32_c5/y_i.txt" , y_in_img_data );
        $readmemh("/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/data/128x32_c5/noise.txt" , noise_data);

        // Initialize vcd/fsdb/saif/sdf
        //$dumpfile("tb_detector_iter5_simple.vcd");
        //$dumpvars(0, tb_detector);
        //$sdf_annotate("../icc/post_apr.sdf", u_detector);
        $fsdbDumpfile("tb_detector_iter5_pre_sdf.fsdb");
        $fsdbDumpvars(0, tb_detector);
        $fsdbDumpMDA(0, tb_detector);
        $set_toggle_region(tb_detector);
        // Wait for reset to complete
        @(posedge rst_n);


        $toggle_start();
        // Simulate systolic array output
        // Wait for some cycles
        repeat (1500) @(posedge clk);

        // Finish simulation
        $toggle_stop();
        $toggle_report(saif_name, 1e-9, "tb_detector");
        $finish;
    end

	assign n0_in = noise_data[0][0+:$bits(n0_in)];
	generate
        for (genvar i = 0; i < SYSTOLIC_PARALLEL; i++) begin
	        assign y_in[i] = {y_in_real[i], y_in_img[i]};
		    for (genvar j = 0; j < TX; j++) begin
		    	assign H_in[i][j] = {H_in_real[i][j], H_in_img[i][j]};
		    end
        end
	endgenerate


    assign count_new = (count == INPUT_CC-1) ? 'b0 : count + 1'b1;
    assign finish_flag_i = count == INPUT_CC - 1;
	always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 'b0;
            systolic_rx_valid <= 1'b1;
        end else if (systolic_rx_valid & systolic_rx_ready) begin
            count <= count_new;
            systolic_rx_valid <= 1'b1;
        end
	end

    generate
        for (genvar i = 0; i < SYSTOLIC_PARALLEL; i++) begin
    	    always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    y_in_real[i] <= y_in_real_data[i];
                    y_in_img [i] <= y_in_img_data [i] ;
                end else if (systolic_rx_ready & systolic_rx_valid) begin
                    y_in_real[i] <= y_in_real_data[count_new*SYSTOLIC_PARALLEL + i];
                    y_in_img [i] <= y_in_img_data [count_new*SYSTOLIC_PARALLEL + i];
                end
            end

            for (genvar j = 0; j < TX; j++) begin
    	        always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        H_in_real[i][j] <= H_in_real_data[i*TX + j][0 +: H_QTZ.width/2];
                        H_in_img [i][j] <= H_in_img_data [i*TX + j][0 +: H_QTZ.width/2];
                    end else if (systolic_rx_valid & systolic_rx_ready) begin
                        H_in_real[i][j] <= H_in_real_data[count_new*(TX*SYSTOLIC_PARALLEL) + i*TX + j ][0 +: H_QTZ.width/2];
                        H_in_img [i][j] <= H_in_img_data [count_new*(TX*SYSTOLIC_PARALLEL) + i*TX + j ][0 +: H_QTZ.width/2];
                    end
                end
            end
        end
    endgenerate

    assign iter_num = ITER_NUM;

    // clk cnt
    int clk_cnt;
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) clk_cnt <= 'b0;
        else        clk_cnt <= clk_cnt + 1'b1;
    end


endmodule
