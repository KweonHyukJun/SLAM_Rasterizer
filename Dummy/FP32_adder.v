module FP32_adder (
    input wire [31:0]       din_A,
    input wire [31:0]       din_B,

    output reg              exception,
    output reg [31:0]       dout
    );

    // Split the inputs into sign, exponent, and mantissa
    wire sign_a, sign_b;
    wire [7:0] exp_a, exp_b;
    wire [23:0] mant_a, mant_b;

    assign sign_a = din_A[31];
    assign sign_b = din_B[31];
    assign exp_a = din_A[30:23];
    assign exp_b = din_B[30:23];
    assign mant_a = (exp_a == 8'b0) ? {1'b0, din_A[22:0]} : {1'b1, din_A[22:0]}; // implicit leading 1 or denormal
    assign mant_b = (exp_b == 8'b0) ? {1'b0, din_B[22:0]} : {1'b1, din_B[22:0]}; // implicit leading 1 or denormal

    // Special values (NaN, Infinity, Zero)
    wire a_is_zero = (din_A[30:0] == 31'b0);
    wire b_is_zero = (din_B[30:0] == 31'b0);
    wire a_is_inf  = (exp_a == 8'b11111111) && (mant_a[22:0] == 23'b0);
    wire b_is_inf  = (exp_b == 8'b11111111) && (mant_b[22:0] == 23'b0);
    wire a_is_nan  = (exp_a == 8'b11111111) && (mant_a[22:0] != 23'b0);
    wire b_is_nan  = (exp_b == 8'b11111111) && (mant_b[22:0] != 23'b0);

    reg signed [7:0] exp_diff;
    reg [23:0] mant_a_shifted, mant_b_shifted;
    reg [7:0] exp_max;
    reg [24:0] mant_sum;
    reg [23:0] final_mant;
    reg [7:0] final_exp;
    reg final_sign;

    // Exception Handling and Special Cases
    always @(*) begin
        exp_diff = 0;
        mant_a_shifted = 0;
        mant_b_shifted = 0;
        exp_max = 0;
        mant_sum = 0;
        final_mant = 0;
        final_exp = 0;
        final_sign = 0;
        dout = 32'b0;
        exception = 1'b0;

        // Case 1: NaN handling
        if (a_is_nan || b_is_nan) begin
            dout = 32'h7FC00000; // Standard quiet NaN
            exception = 1'b1;
        end
        // Case 2: Infinity handling
        else if (a_is_inf || b_is_inf) begin
            if (a_is_inf && b_is_inf && (sign_a != sign_b)) begin
                dout = 32'h7FC00000; // NaN if Inf - Inf
                exception = 1'b1;
            end else if (a_is_inf) begin
                dout = din_A; // Return infinity with correct sign
                exception = 1'b1;                
            end else begin
                dout = din_B; // Return infinity with correct sign
                exception = 1'b1;
            end
        end
        // Case 3: Zero handling
        else if (a_is_zero) begin
            dout = din_B; // Return b if a is zero
        end else if (b_is_zero) begin
            dout = din_A; // Return a if b is zero
        end
        // Normal FP32 addition
        else begin
            // Align exponents by shifting the smaller mantissa
            if (exp_a > exp_b) begin
                exp_diff = exp_a - exp_b;
                mant_b_shifted = mant_b >> exp_diff;
                mant_a_shifted = mant_a;
                exp_max = exp_a;
            end else begin
                exp_diff = exp_b - exp_a;
                mant_a_shifted = mant_a >> exp_diff;
                mant_b_shifted = mant_b;
                exp_max = exp_b;
            end

            // Add or subtract mantissas based on signs
            if (sign_a == sign_b) begin
                // Same sign: add the mantissas
                mant_sum = mant_a_shifted + mant_b_shifted;
                final_sign = sign_a;
            end else begin
                // Different sign: subtract the mantissas
                if (mant_a_shifted >= mant_b_shifted) begin
                    mant_sum = mant_a_shifted - mant_b_shifted;
                    final_sign = sign_a;
                end else begin
                    mant_sum = mant_b_shifted - mant_a_shifted;
                    final_sign = sign_b;
                end
            end

            // Normalize the dout (shift left if necessary)
            if (mant_sum[24]) begin
                // If carry out is 1, shift right and adjust exponent
                final_mant = mant_sum[24:1];
                final_exp = exp_max + 1;
            end else begin
                final_mant = mant_sum[23:0];
                final_exp = exp_max;
                // Normalize mantissa
                while (final_mant[23] == 0 && final_exp > 0) begin
                    final_mant = final_mant << 1;
                    final_exp = final_exp - 1;
                end
            end

            // Handle overflow (when the exponent exceeds 255)
            if (final_exp >= 8'b11111111) begin
                dout = {final_sign, 8'b11111111, 23'b0}; // Return infinity
                exception = 1'b1;
            end
            // Handle underflow (when the exponent goes below 0)
            else if (final_exp == 8'b0) begin
                dout = {final_sign, final_exp, 23'b0}; // Subnormal or zero
            end
            else begin
                dout = {final_sign, final_exp, final_mant[22:0]}; // Normal result
            end
        end
    end

endmodule