`timescale 1ns/1ps

module fp32_multiplier_tb;

    // Testbench signals
    reg  [31:0] a, b;       // 32-bit floating-point inputs
    reg         in_valid;   // Input valid signal
    wire [31:0] result;     // 32-bit floating-point result
    wire        out_valid;  // Output valid signal

    // Instantiate the DUT (Device Under Test)
    FP32_multiplier uut (
        .din_A(a),
        .din_B(b),
        .din_valid(in_valid),
        .dout(result),
        .dout_valid(out_valid)
    );

    // Test procedure
    initial begin
        // Display header
        $display("Time | A (Hex) | B (Hex) | in_valid | Result (Hex) | out_valid");

        // Test Case 1: Multiply 1.0 * 2.0
        a = 32'h3F800000;  // 1.0 in FP32
        b = 32'h40000000;  // 2.0 in FP32
        in_valid = 1'b1;
        #10;
        $display("%4d | %h | %h | %b       | %h      | %b", $time, a, b, in_valid, result, out_valid);

        // Test Case 2: Multiply -1.0 * 0.5
        a = 32'hBF800000;  // -1.0 in FP32
        b = 32'h3F000000;  // 0.5 in FP32
        #10;
        $display("%4d | %h | %h | %b       | %h      | %b", $time, a, b, in_valid, result, out_valid);

        // Test Case 3: Multiply 0.0 * 5.0
        a = 32'h00000000;  // 0.0 in FP32
        b = 32'h40A00000;  // 5.0 in FP32
        #10;
        $display("%4d | %h | %h | %b       | %h      | %b", $time, a, b, in_valid, result, out_valid);

        // Test Case 4: Multiply -2.5 * 4.0
        a = 32'hC0200000;  // -2.5 in FP32
        b = 32'h40800000;  // 4.0 in FP32
        #10;
        $display("%4d | %h | %h | %b       | %h      | %b", $time, a, b, in_valid, result, out_valid);

        // Test Case 5: Multiply -0.25 * -0.5
        a = 32'hBE800000;  // -0.25 in FP32
        b = 32'hBF000000;  // -0.5 in FP32
        #10;
        $display("%4d | %h | %h | %b       | %h      | %b", $time, a, b, in_valid, result, out_valid);

        // End of test
        $finish;
    end

endmodule
