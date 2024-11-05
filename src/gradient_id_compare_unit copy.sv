module gradient_id_compare_unit #( 
    parameter precision = 32,
    parameter mantissa_bit = 23,
    parameter exponent_bit = 8,

    parameter data_size = precision * 11 + 32,
    parameter N = 1 // List 개수 
) 
(
    // Input is Wire 
    input wire clk,
    input wire rst_n,
    input wire [data_size-1:0] data_A_in [N-1:0], // 마지막 비트는 valid
    input wire [data_size-1:0] data_B_in [N-1:0],

    // Output is Register
    output reg [data_size-1:0] data_out [(2 * N)-1:0]
);
    // data size : GID를 0x0 인 경우에는 비어있다고 간주? && 같은 GID가 존재하지 않는다고 가정
    // Max size vs Valid size?

    // Input (N) => Compare (N^2) => Output (2N)
    
    // Reg declaration
    reg [(N ** 2)-1:0] compare_result;

    // Wire declaration
    wire [data_size-1:0] data_temp [(2 * N)-1:0];

    // wire [$clog2(N):0] B_match_index [N-1:0]; // Assumes `b` fits within 32 bits
    
    wire [7:0] status_inst [5:1];

    integer k;


    // Make to Output (2N)
    // 첫 N 겹치기 테스트 후 N을 넣는 단계
    genvar a, b;
    generate
        for (a = 0; a < N; a = a + 1) begin : data_temp_assignments_A
            wire A_same_id_exist;
            wire [$clog2(N) : 0] B_match_index ;
            for (b = 0; b < N; b = b + 1) begin: data_temp_assignments_B
                // assign compare_result[(a * N) + b] = 
                //     ((data_A_in[a][31:0] == data_B_in[b][31:0]) && !(data_A_in[a][31:0] == 32'h0) && !(data_B_in[b][31:0] == 32'h0)); // GID 비교 및 GID != 0

                assign B_match_index = ((data_A_in[a][31:0] == data_B_in[b][31:0]) && !(data_A_in[a][31:0] == 32'h0) && !(data_B_in[b][31:0] == 32'h0)) ? b : -1;
                assign A_same_id_exist = (data_A_in[a][31:0] == data_B_in[b][31:0]) && !(data_A_in[a][31:0] == 32'h0) && !(data_B_in[b][31:0] == 32'h0);
            end


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dcolor_adder (
                .a(data_A_in[a][((11 * precision) - 1) + 32:(8 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((11 * precision) - 1) + 32:(8 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((11 * precision) - 1) + 32:(8 * precision) + 32]),
                .status(status_inst[1])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_ddepth_adder (
                .a(data_A_in[a][((8 * precision) - 1) + 32:(7 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((8 * precision) - 1) + 32:(7 * precision) + 32]: 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((8 * precision) - 1) + 32:(7 * precision) + 32]),
                .status(status_inst[2])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dopacity_adder (
                .a(data_A_in[a][((7 * precision) - 1) + 32:(6 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((7 * precision) - 1) + 32:(6 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((7 * precision) - 1) + 32:(6 * precision) + 32]),
                .status(status_inst[3])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dmean2D_adder (
                .a(data_A_in[a][((6 * precision) - 1) + 32 : (4 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((6 * precision) - 1) + 32 : (4 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((6 * precision) - 1) + 32 : (4 * precision) + 32]),
                .status(status_inst[4])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dconic_adder (
                .a(data_A_in[a][((4 * precision) - 1) + 32:32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((4 * precision) - 1) + 32:32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((4 * precision) - 1) + 32:32]),
                .status(status_inst[5])
            );    
        end
    endgenerate


    // 하위 N개 입력 처리 
    genvar A, B;
    generate 
        for (b = 0; b < N; b = b + 1) begin : data_temp_assignments_b
            wire B_same_id_exist;
            wire [$clog2(N) : 0] B_match_index ;
            for (a = 0; a < N; a = a + 1) begin: data_temp_assignments_a

                // assign compare_result[(a * N) + b] = 
                //     ((data_A_in[a][31:0] == data_B_in[b][31:0]) && !(data_A_in[a][31:0] == 32'h0) && !(data_B_in[b][31:0] == 32'h0)); // GID 비교 및 GID != 0
                
                assign data_temp[a * N + b] = ((data_A_in[a][31:0] == data_B_in[b][31:0]) && !(data_A_in[a][31:0] == 32'h0) && !(data_B_in[b][31:0] == 32'h0)) ? b : -1;

                
            end
        end
    endgenerate


    // Register initialization
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 2 * N; k = k + 1) begin
                data_out[k] <= 0;
            end
        end

        else begin
            data_out <= data_temp;
        end
    end

endmodule