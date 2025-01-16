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

module tb_priority_encoder #(INPUTS = 16, OUTPUTS = 4, DATA_SIZE = 24)();

    parameter N_TEST = 83;
    
    // input
    reg clk, rst_n, start;

    reg src_request_i [INPUTS-1:0];
    wire src_grant_o [INPUTS-1:0];
    reg [DATA_SIZE-1:0] src_data_i [INPUTS-1:0];

    reg last_input_done_i [INPUTS-1:0];
    wire last_input_done_o [OUTPUTS-1:0];

    reg stall_backpressure;
    wire stall_from_encoder;

    wire dst_valid_o [OUTPUTS-1:0];
    wire [DATA_SIZE-1:0] dst_data_o [OUTPUTS-1:0];

    reg [DATA_SIZE-1:0] mem_gaussian_id_in [N_TEST-1:0];

    reg [15:0] end_counter;

    integer count;
    
    integer file_handle;


    initial begin
        $fsdbDumpfile("./output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_priority_encoder, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    priority_encoder #( .INPUTS(INPUTS), .OUTPUTS(OUTPUTS), .DATA_SIZE(DATA_SIZE)) 
    uut (
        // .clk(clk),
        // .rst_n(rst_n),

        .src_request_i(src_request_i),
        .src_grant_o(src_grant_o),
        .src_data_i(src_data_i),

        .last_input_done_i(last_input_done_i),
        .last_input_done_o(last_input_done_o),

        .dst_valid_o(dst_valid_o),
        .dst_data_o(dst_data_o),

        .stall_backpressure(stall_backpressure),
        .stall_from_encoder(stall_from_encoder)
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
        file_handle = $fopen("./output_shared_submodules/priority_encoder_output.txt", "w");
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

        for (int i = 0; i < INPUTS; i = i + 1) begin
            src_request_i[i] <= 1'b1;
            src_data_i[i] <= mem_gaussian_id_in[count + i];
            last_input_done_i[i] <= 1'b0;
        end
        count <= count + INPUTS;
    end

    always @(posedge clk) begin

        if (start) begin
            for (int i = 0; i < INPUTS; i = i + 1) begin

                if (!stall_backpressure) begin

                    if (src_request_i[i] && src_grant_o[i]) begin

                        if (count >= N_TEST) begin
                            end_counter <= end_counter + 1;
                            if (end_counter == 10) begin
                                $finish;
                            end
                            src_request_i[i] <= 1'b0;
                            src_data_i[i] <= 0;
                        end

                        else begin
                            src_request_i[i] <= 1'b0;
                            src_data_i[i] <= 0;
                        end 
                    end

                    if (!stall_from_encoder) begin

                        if (count < N_TEST) begin
                            src_data_i[i] <= mem_gaussian_id_in[count + i];
                            src_request_i[i] <= 1'b1;
                            count <= count + INPUTS;
                        end
                        else begin
                            src_data_i[i] <= 0;
                            src_request_i[i] <= 1'b0;
                        end

                        if (count == N_TEST - 1) begin
                            last_input_done_i[i] <= 1'b1;
                        end
                        else begin
                            last_input_done_i[i] <= 1'b0;
                        end
                    end

                end
            end



            for (int i = 0; i < OUTPUTS; i = i + 1) begin
                if (dst_valid_o[i]) begin
                    $fwrite(file_handle, "%h\n", dst_data_o[i]);
                end
            end
        end
    end

endmodule
