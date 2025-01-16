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

module tb_serializer #(Encoder_outs = 4, DATA_SIZE = 24)();

    parameter N_TEST = 83;
    
    // input
    reg clk, rst_n, start;

    reg [DATA_SIZE-1:0] data_in [Encoder_outs-1:0];
    reg valid_in [Encoder_outs-1:0];

    // output
    wire [DATA_SIZE-1:0] data_out;
    wire valid_out;

    reg stall_backpressure;

    reg last_input_done_i [Encoder_outs-1:0];
    wire last_input_done_o;

    wire pop_next_valid_out;
    reg dst_ready_i;

    reg [DATA_SIZE-1:0] mem_gaussian_id_in [N_TEST-1:0];

    reg [15:0] end_counter;

    integer count;
    
    integer file_handle;


    initial begin
        $fsdbDumpfile("./output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_serializer, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    serializer #( .Encoder_outs(Encoder_outs), .DATA_SIZE(DATA_SIZE)) 
    uut (
        .clk(clk),
        .rst_n(rst_n),

        .data_in(data_in),
        .valid_in(valid_in),

        .data_out(data_out),
        .valid_out(valid_out),

        .last_input_done_i(last_input_done_i),
        .last_input_done_o(last_input_done_o),

        .stall_backpressure(stall_backpressure),
        .pop_next_valid_out(pop_next_valid_out),

        .dst_ready_i(dst_ready_i)
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
        dst_ready_i <= 1'b0;
        start <= 1'b0;

        for (int i = 0; i < Encoder_outs; i = i + 1) begin
            data_in[i] <= 0;
            valid_in[i] <= 1'b0;
            last_input_done_i[i] <= 1'b0;
        end

        @(posedge clk);
        rst_n <= 1'b1;
        
        @ (posedge clk);
        start <= 1'b1;
        dst_ready_i <= 1'b1;

        for (int i = 0; i < Encoder_outs; i = i + 1) begin
            data_in[i] <= mem_gaussian_id_in[count + i];
            valid_in[i] <= 1'b1;
            last_input_done_i[i] <= 1'b0;
        end
        count <= count + Encoder_outs;
    end

    always @(posedge clk) begin

        if (start) begin
            for (int i = 0; i < Encoder_outs; i = i + 1) begin

                if (!stall_backpressure) begin

                    // if (valid_in[i] && pop_next_valid_out) begin

                    //     if (count >= N_TEST) begin
                    //         end_counter <= end_counter + 1;
                    //         if (end_counter == 10) begin
                    //             $finish;
                    //         end
                    //         valid_in[i] <= 1'b0;
                    //         data_in[i] <= 0;
                    //     end

                    //     else begin
                    //         valid_in[i] <= 1'b0;
                    //         data_in[i] <= 0;
                    //     end 
                    // end
                    if (pop_next_valid_out) begin
                        if (count + i  < N_TEST) begin
                            data_in[i] <= mem_gaussian_id_in[count + i];
                            valid_in[i] <= 1'b1;
                            count <= count + Encoder_outs;
                        end
                        else begin
                            valid_in[i] <= 1'b0;
                            data_in[i] <= 0;
                        end

                        if (count + i == N_TEST - 1) begin
                            last_input_done_i[i] <= 1'b1;
                        end

                        else begin
                            last_input_done_i[i] <= 1'b0;
                        end
                    end
                    
                end

            end

            if (clk_cnt == 10) begin
                dst_ready_i <= 1'b0;
            end
            else begin
                dst_ready_i <= 1'b1;
            end
    
        end

        

            for (int i = 0; i < Encoder_outs; i = i + 1) begin
                if (valid_out) begin
                    $fwrite(file_handle, "%h\n", data_out);
                end
            end
        end

    always @(posedge clk) begin
        if (last_input_done_o) begin
            $finish;
        end
    end
    

endmodule
