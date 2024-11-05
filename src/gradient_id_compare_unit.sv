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


    // Wire declaration
    wire [data_size-1:0] data_temp [(2 * N)-1:0];
<<<<<<< HEAD
    wire A_same_id_exist [N-1:0];
    wire [$clog2(N) : 0] B_match_index [N-1:0];

    wire [N-1:0] match_conditions_array [N-1:0];
    // wire match_conditions [N-1:0];


    wire B_same_id_exist [N-1:0];
    
    wire B_match_conditions [N-1:0];
    
=======

>>>>>>> parent of 4c16995 (id_compare unit changed for multiple N 24-11-05 18:21)
    // wire [$clog2(N):0] B_match_index [N-1:0]; // Assumes `b` fits within 32 bits
    
    wire [7:0] status_inst [5:1];

    integer k;


    // Make to Output (2N)
    // 첫 N 겹치기 테스트 후 N을 넣는 단계
    genvar a, b;
    generate
        for (a = 0; a < N; a = a + 1) begin : data_temp_assignments_A
            // wire [N - 1:0] A_same_id_exist_list;
            wire A_same_id_exist;
            wire [$clog2(N) : 0] B_match_index ;
            wire [N-1:0] match_conditions;
            for (b = 0; b < N; b = b + 1) begin: data_temp_assignments_B
                // assign compare_result[(a * N) + b] = 
                //     ((data_A_in[a][31:0] == data_B_in[b][31:0]) && !(data_A_in[a][31:0] == 32'h0) && !(data_B_in[b][31:0] == 32'h0)); // GID 비교 및 GID != 0

                // assign match_conditions[b] = 
                //     (data_A_in[a][31:0] == data_B_in[b][31:0]) &&
                //     (data_A_in[a][31:0] != 32'h0) &&
                //     (data_B_in[b][31:0] != 32'h0);
                assign match_conditions[a][b] = 
                    (data_A_in[a][31:0] == data_B_in[b][31:0]) &&
                    (data_A_in[a][31:0] != 32'h0) &&
<<<<<<< HEAD
                    (data_B_in[b][31:0] != 32'h0);                    
                assign B_match_index[a] = match_conditions[b] ? b : 'b0;                
                assign A_same_id_exist[a] = |match_conditions[b];
=======
                    (data_B_in[b][31:0] != 32'h0);
                assign B_match_index = match_conditions[b] ? b : B_match_index;
                
>>>>>>> parent of 4c16995 (id_compare unit changed for multiple N 24-11-05 18:21)
            end

            assign A_same_id_exist = |match_conditions;

            assign data_temp[a][31:0] = data_A_in[a][31:0];

            // dL_dcolor 
            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dcolor_R_adder (
                .a(data_A_in[a][((11 * precision) - 1) + 32:(10 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((11 * precision) - 1) + 32:(10 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((11 * precision) - 1) + 32:(10 * precision) + 32]),
                .status(status_inst[1])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dcolor_G_adder (
                .a(data_A_in[a][((10 * precision) - 1) + 32:(9 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((10 * precision) - 1) + 32:(9 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((10 * precision) - 1) + 32:(9 * precision) + 32]),
                .status(status_inst[1])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dcolor_B_adder (
                .a(data_A_in[a][((9 * precision) - 1) + 32:(8 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((9 * precision) - 1) + 32:(8 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((9 * precision) - 1) + 32:(8 * precision) + 32]),
                .status(status_inst[1])
            );


            // dL_ddepth 
            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_ddepth_adder (
                .a(data_A_in[a][((8 * precision) - 1) + 32:(7 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((8 * precision) - 1) + 32:(7 * precision) + 32]: 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((8 * precision) - 1) + 32:(7 * precision) + 32]),
                .status(status_inst[2])
            );

            // dL_dopacity
            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dopacity_adder (
                .a(data_A_in[a][((7 * precision) - 1) + 32:(6 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((7 * precision) - 1) + 32:(6 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((7 * precision) - 1) + 32:(6 * precision) + 32]),
                .status(status_inst[3])
            );

            // dL_dmean2D
            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dmean2D_x_adder (
                .a(data_A_in[a][((6 * precision) - 1) + 32 : (5 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((6 * precision) - 1) + 32 : (5 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((6 * precision) - 1) + 32 : (5 * precision) + 32]),
                .status(status_inst[4])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dmean2D_y_adder (
                .a(data_A_in[a][((5 * precision) - 1) + 32 : (4 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((5 * precision) - 1) + 32 : (4 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((5 * precision) - 1) + 32 : (4 * precision) + 32]),
                .status(status_inst[4])
            );

            // dL_dconic
            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dconic_x_adder (
                .a(data_A_in[a][((4 * precision) - 1) + 32: (3 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((4 * precision) - 1) + 32: (3 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((4 * precision) - 1) + 32: (3 * precision) + 32]),
                .status(status_inst[5])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dconic_y_adder (
                .a(data_A_in[a][((3 * precision) - 1) + 32: (2 * precision) + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((3 * precision) - 1) + 32: (2 * precision) + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((3 * precision) - 1) + 32: (2 * precision) + 32]),
                .status(status_inst[5])
            );
            
            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dconic_z_adder (
                .a(data_A_in[a][((2 * precision) - 1) + 32: precision + 32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][((2 * precision) - 1) + 32: precision + 32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][((2 * precision) - 1) + 32: precision + 32]),
                .status(status_inst[5])
            );            

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            dL_dconic_w_adder (
                .a(data_A_in[a][(precision - 1) + 32:32]),
                .b(A_same_id_exist ? data_B_in[B_match_index][(precision - 1) + 32:32] : 'h0),
                .rnd(3'b0),
                .z(data_temp[a][(precision - 1) + 32:32]),
                .status(status_inst[5])
            );

        end

        for (b = 0; b < N; b = b + 1) begin : data_temp_assignments_b
            wire B_same_id_exist;
            
            // Temporary wire to check if a match exists for `B_same_id_exist`
            wire [N-1:0] B_match_conditions;
            for (a = 0; a < N; a = a + 1) begin: data_temp_assignments_a                
                assign B_match_conditions[a] = 
                (data_A_in[a][31:0] == data_B_in[b][31:0]) &&
                (data_A_in[a][31:0] != 32'h0) &&
                (data_B_in[b][31:0] != 32'h0);
            end

            // OR-combine to see if any match exists for B_same_id_exist
            assign B_same_id_exist = |B_match_conditions;

            // Set data_temp[N + b] based on B_same_id_exist condition
            assign data_temp[N + b] = !B_same_id_exist ? data_B_in[b] : 'h0;
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
            for (k = 0; k < (2 * N); k = k + 1) begin
                data_out[k] <= data_temp[k];
            end
        end
    end

endmodule
