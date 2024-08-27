module FP32_multiplier (
    input wire [31:0]       din_A,
    input wire [31:0]       din_B,

    output reg              exception,
    output reg [31:0]       dout
    );

    // 0 inf NaN에 관한 컨트롤 필요

    // Internal signals
    wire [47:0] man_mul;
    wire [7:0]  exp_a, exp_b, exp_mul;
    wire [23:0] man_a, man_b;
    wire        sign_a, sign_b, sign_mul;
    wire [22:0] result_mantissa;
    wire [7:0]  result_exponent;

    // Special case detection
    wire a_is_zero = (din_A[30:0] == 31'b0);
    wire b_is_zero = (din_B[30:0] == 31'b0);
    wire a_is_inf  = (din_A[30:23] == 8'hFF && din_A[22:0] == 23'b0);
    wire b_is_inf  = (din_B[30:23] == 8'hFF && din_B[22:0] == 23'b0);
    wire a_is_nan  = (din_A[30:23] == 8'hFF && din_A[22:0] != 23'b0);
    wire b_is_nan  = (din_B[30:23] == 8'hFF && din_B[22:0] != 23'b0);

    // Extract fields from inputs
    assign sign_a = din_A[31];
    assign exp_a = din_A[30:23];
    assign man_a = {1'b1, din_A[22:0]};  // Implicit leading 1 for normalized numbers

    assign sign_b = din_B[31];
    assign exp_b = din_B[30:23];
    assign man_b = {1'b1, din_B[22:0]};  // Implicit leading 1 for normalized numbers

    // Perform multiplication
    assign sign_mul = sign_a ^ sign_b;
    assign man_mul = man_a * man_b;

    // Exponent addition and adjustment
    assign exp_mul = man_mul[47] ? (exp_a + exp_b - 8'd126) : (exp_a + exp_b - 8'd127);
    assign result_mantissa = man_mul[47] ? man_mul[46:24] : man_mul[45:23];

    always @(*) begin
        // Default values
        dout = 32'b0;
        exception = 1'b0;

        // NaN handling: if either input is NaN, the output is NaN
        if (a_is_nan || b_is_nan) begin
            dout = 32'h7FC00000;  // Standard NaN representation
            exception = 1'b1;
        end
        // Infinity handling
        else if (a_is_inf || b_is_inf) begin
            if (a_is_zero || b_is_zero) begin
                dout = 32'h7FC00000;  // NaN (0 * Inf is invalid)
                exception = 1'b1;
            end else begin
                dout = {sign_mul, 8'hFF, 23'b0};  // Infinity
            end
        end
        // Zero handling
        else if (a_is_zero || b_is_zero) begin
            dout = {sign_mul, 31'b0};  // Zero
        end
        // Normal case: Perform the multiplication
        else begin
            dout = {sign_mul, exp_mul, result_mantissa};
        end
    end





endmodule