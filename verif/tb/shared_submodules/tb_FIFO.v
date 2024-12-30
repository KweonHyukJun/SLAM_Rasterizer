//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/19 11:25:32
// Design Name: 
// Module Name: tb_INT_tester
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_round_robin_arbiter #(N_MASTER = 16, DATA_SIZE = 24)();

    parameter N_TEST = 84;
    
    // input
    reg clk, rst_n, start;

    reg src_valid_i [N_MASTER-1:0];
    wire src_ready_o [N_MASTER-1:0];
    reg [DATA_SIZE-1:0] src_data_i [N_MASTER-1:0];

    reg stall_backpressure;
    wire stall_from_arbiter;

    wire dst_valid_o;
    reg dst_ready_i;
    wire [DATA_SIZE-1:0] dst_data_o;

    reg [DATA_SIZE-1:0] mem_gaussian_id_in [N_TEST-1:0];

    reg [15:0] end_counter;

    integer count;
    
    integer file_handle;


    initial begin
        $fsdbDumpfile("./output_backward_grad_merge/dump.fsdb");
        $fsdbDumpvars(0, tb_round_robin_arbiter, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    round_robin_arbiter #( .N_MASTER(N_MASTER), .DATA_SIZE(DATA_SIZE)) 
    uut (
        .clk(clk),
        .rst_n(rst_n),

        .src_valid_i(src_valid_i),
        .src_ready_o(src_ready_o),
        .src_data_i(src_data_i),

        .dst_valid_o(dst_valid_o),
        .dst_ready_i(dst_ready_i),
        .dst_data_o(dst_data_o),

        .stall_backpressure(stall_backpressure),
        .stall_from_arbiter(stall_from_arbiter)
    );


    initial begin
        $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/gaussian_id_changed.hex", mem_gaussian_id_in);
    end

    // Initial reg example
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 500) $finish;
    end

    initial begin
        file_handle = $fopen("./output_backward/arbiter_output.txt", "w");
        end_counter = 0;
        count = 0;
        clk <= 1'b0;
        rst_n <= 1'b0;
        stall_backpressure <= 1'b0;
        start <= 1'b0;

        @(posedge clk);
        rst_n <= 1'b1;
        
        @ (posedge clk);
        start <= 1'b1;

        for (int i = 0; i < N_MASTER; i = i + 1) begin
            src_valid_i[i] <= 1'b1;
            src_data_i[i] <= mem_gaussian_id_in[count + i];
            dst_ready_i <= 1'b1;
        end
        count <= count + N_MASTER;
    end

    always @(posedge clk) begin

        if (start) begin
            for (int i = 0; i < N_MASTER; i = i + 1) begin

                if (!stall_backpressure) begin

                    if (src_valid_i[i] && src_ready_o[i]) begin

                        if (count >= N_TEST) begin
                            end_counter <= end_counter + 1;
                            if (end_counter == N_MASTER) begin
                                $finish;
                            end
                            src_valid_i[i] <= 1'b0;
                            src_data_i[i] <= 0;
                        end

                        else begin
                            src_valid_i[i] <= 1'b0;
                            src_data_i[i] <= 0;
                        end 
                    end

                    if (!stall_from_arbiter) begin
                        src_data_i[i] <= mem_gaussian_id_in[count + i];
                        src_valid_i[i] <= 1'b1;
                        count <= count + N_MASTER;
                    end

                end
            end



            for (int i = 0; i < N_MASTER; i = i + 1) begin
                if (dst_valid_o[i]) begin
                    $fwrite(file_handle, "%h\n", dst_data_o[i]);
                end
            end
        end
    end

endmodule
