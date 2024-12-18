module majority_adder #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 16, mantissa_bit = 7, num_pixels = 16)
(
    input wire clk,
    input wire rst_n,

    input wire [(3 * precision)-1:0] dL_dcolor_in [num_pixels-1:0],
    input wire [precision-1:0] dL_ddepth_in [num_pixels-1:0],
    input wire [(2 * precision)-1:0] dL_dmean2D_in [num_pixels-1:0],
    input wire [(4 * precision)-1:0] dL_dconic_in [num_pixels-1:0],
    input wire [precision-1:0] dL_dopacity_in [num_pixels-1:0],

    input wire is_majority_gid_in [num_pixels-1:0], // controll MUXing signal

    input wire stall_backpressure,

    output reg [(3 * precision)-1:0] majority_dL_dcolor_out ,
    output reg [precision-1:0] majority_dL_ddepth_out ,
    output reg [(2 * precision)-1:0] majority_dL_dmean2D_out ,
    output reg [(4 * precision)-1:0] majority_dL_dconic_out ,
    output reg [precision-1:0] majority_dL_dopacity_out,

    output reg majority_valid_out
);

    // Wire Declare
    logic [(3 * precision) -1 :0] dL_dcolor_wire [(2 * num_pixels)-2:0];
    

    logic [precision - 1:0] dL_ddepth_wire [(2 * num_pixels)-2:0];
    

    logic [(2*precision)-1:0] dL_dmean2D_wire [(2 * num_pixels)-2:0];
    

    logic [(4*precision)-1:0] dL_dconic_wire [(2 * num_pixels)-2:0];
    

    logic [precision-1:0] dL_dopacity_wire [(2 * num_pixels)-2:0];
    

    logic is_majority_gid_wire [(2 * num_pixels)-2:num_pixels];


    // Reg Declare
    // Stage registers for dL_dcolor
    logic [(3 * precision)-1:0] dL_dcolor_reg [(2 * num_pixels)-2:0];
    
    // Stage registers for dL_ddepth  
    logic [precision-1:0] dL_ddepth_reg [(2 * num_pixels)-2:0];
    
    // Stage registers for dL_dmean2D
    logic [(2 * precision)-1:0] dL_dmean2D_reg [(2 * num_pixels)-2:0];
    
    // Stage registers for dL_dconic
    logic [(4 * precision)-1:0] dL_dconic_reg [(2 * num_pixels)-2:0];
    
    // Stage registers for dL_dopacity
    logic [precision-1:0] dL_dopacity_reg [(2 * num_pixels)-2:0];
    
    // Valid registers for each stage
    logic is_majority_gid_reg [(2 * num_pixels)-2:0];

    wire [7:0] status_inst [num_pixels-1:0][1:11];

    genvar j;
    generate 
        for (j = 0; j < num_pixels; j++) begin : first_inst

            assign dL_dcolor_wire[j] = is_majority_gid_in[j] ? dL_dcolor_in[j] : 'h0;
            assign dL_ddepth_wire[j] = is_majority_gid_in[j] ? dL_ddepth_in[j] : 'h0;
            assign dL_dmean2D_wire[j] = is_majority_gid_in[j] ? dL_dmean2D_in[j] : 'h0;
            assign dL_dconic_wire[j] = is_majority_gid_in[j] ? dL_dconic_in[j] : 'h0;
            assign dL_dopacity_wire[j] = is_majority_gid_in[j] ? dL_dopacity_in[j] : 'h0;

        end
    endgenerate

    genvar i;
    generate 
        for (i = 0; i < num_pixels - 1; i++) begin : majority_adder_inst 

            assign is_majority_gid_wire[i + num_pixels] = is_majority_gid_reg[i] | is_majority_gid_reg[i+1];

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_R_adder_inst (
                .a(dL_dcolor_reg[2*i][(3 * precision) - 1: 2*precision]),
                .b(dL_dcolor_reg[2*i+1][(3 * precision) - 1: 2*precision]),
                .rnd(3'b000),
                .z(dL_dcolor_wire[i + num_pixels][(3 * precision) - 1: 2*precision]),
                .status(status_inst[i][1])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_G_adder_inst (
                .a(dL_dcolor_reg[2*i][(2 * precision) - 1: precision]),
                .b(dL_dcolor_reg[2*i+1][(2 * precision) - 1: precision]),
                .rnd(3'b000),
                .z(dL_dcolor_wire[i + num_pixels][(2 * precision) - 1: precision]),
                .status(status_inst[i][2])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_B_adder_inst (
                .a(dL_dcolor_reg[2*i][precision - 1: 0]),
                .b(dL_dcolor_reg[2*i+1][precision - 1: 0]),
                .rnd(3'b000),
                .z(dL_dcolor_wire[i + num_pixels][precision - 1: 0]),
                .status(status_inst[i][3])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_ddepth_adder_inst (
                .a(dL_ddepth_reg[(2 * i)]),
                .b(dL_ddepth_reg[(2 * i) + 1]),
                .rnd(3'b0),
                .z(dL_ddepth_wire[i + num_pixels]),
                .status(status_inst[i][4])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_mean2D_x_adder_inst (
                .a(dL_dmean2D_reg[2*i][(2 * precision) - 1: precision]),
                .b(dL_dmean2D_reg[2*i+1][(2 * precision) - 1: precision]),
                .rnd(3'b000),
                .z(dL_dmean2D_wire[i + num_pixels][(2 * precision) - 1: precision]),
                .status(status_inst[i][5])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_mean2D_y_adder_inst (
                .a(dL_dmean2D_reg[2*i][precision - 1: 0]),
                .b(dL_dmean2D_reg[2*i+1][precision - 1: 0]),
                .rnd(3'b000),
                .z(dL_dmean2D_wire[i + num_pixels][precision - 1: 0]),
                .status(status_inst[i][6])
            );


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_x_adder_inst (
                .a(dL_dconic_reg[2*i][(4 * precision) - 1: 3*precision]),
                .b(dL_dconic_reg[2*i+1][(4 * precision) - 1: 3*precision]),
                .rnd(3'b000),
                .z(dL_dconic_wire[i + num_pixels][(4 * precision) - 1: 3*precision]),
                .status(status_inst[i][7])
            );            


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_y_adder_inst (
                .a(dL_dconic_reg[2*i][(3 * precision) - 1: 2 * precision]),
                .b(dL_dconic_reg[2*i+1][(3 * precision) - 1: 2 * precision]),
                .rnd(3'b000),
                .z(dL_dconic_wire[i + num_pixels][(3 * precision) - 1: 2 * precision]),
                .status(status_inst[i][8])
            );


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_z_adder_inst (
                .a(dL_dconic_reg[2*i][(2 * precision) - 1: precision]),
                .b(dL_dconic_reg[2*i+1][(2 * precision) - 1: precision]),
                .rnd(3'b000),
                .z(dL_dconic_wire[i + num_pixels][(2 * precision) - 1: precision]),
                .status(status_inst[i][9])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_w_adder_inst (
                .a(dL_dconic_reg[2*i][precision - 1: 0]),
                .b(dL_dconic_reg[2*i+1][precision - 1: 0]),
                .rnd(3'b000),
                .z(dL_dconic_wire[i + num_pixels][precision - 1: 0]),
                .status(status_inst[i][10])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dopacity_adder_inst (
                .a(dL_dopacity_reg[2*i]),
                .b(dL_dopacity_reg[2*i+1]),
                .rnd(3'b000),
                .z(dL_dopacity_wire[i + num_pixels]),
                .status(status_inst[i][11])
            );

        end

    endgenerate  




    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            for (int k = 0; k < (2 * num_pixels)-1; k++) begin
                dL_dcolor_reg[k] <= 'h0;
                dL_ddepth_reg[k] <= 'h0;
                dL_dmean2D_reg[k] <= 'h0;
                dL_dconic_reg[k] <= 'h0;
                dL_dopacity_reg[k] <= 'h0;
                is_majority_gid_reg[k] <= 0;
            end
            majority_dL_dcolor_out <= 'h0;
            majority_dL_ddepth_out <= 'h0;
            majority_dL_dmean2D_out <= 'h0;
            majority_dL_dconic_out <= 'h0;
            majority_dL_dopacity_out <= 'h0;
            majority_valid_out <= 1'b0;
            
        end

        else begin

                if (!stall_backpressure) begin
                    for (int k = 0; k < num_pixels; k++) begin
                        dL_dcolor_reg[k] <= dL_dcolor_wire[k];
                        dL_ddepth_reg[k] <= dL_ddepth_wire[k];
                        dL_dmean2D_reg[k] <= dL_dmean2D_wire[k];
                        dL_dconic_reg[k] <= dL_dconic_wire[k];
                        dL_dopacity_reg[k] <= dL_dopacity_wire[k];
                        is_majority_gid_reg[k] <= is_majority_gid_in[k];
                    end
                    
                    for (int k = num_pixels; k < (2 * num_pixels) - 1; k++) begin
                        dL_dcolor_reg[k] <= dL_dcolor_wire[k];
                        dL_ddepth_reg[k] <= dL_ddepth_wire[k];
                        dL_dmean2D_reg[k] <= dL_dmean2D_wire[k];
                        dL_dconic_reg[k] <= dL_dconic_wire[k];
                        dL_dopacity_reg[k] <= dL_dopacity_wire[k];

                        is_majority_gid_reg[k] <= is_majority_gid_wire[k]; // 이거 Adding 처럼 처리해야함
                    end

                majority_dL_dcolor_out <= dL_dcolor_wire[(2 * num_pixels) - 2];
                majority_dL_ddepth_out <= dL_ddepth_wire[(2 * num_pixels) - 2];
                majority_dL_dmean2D_out <= dL_dmean2D_wire[(2 * num_pixels)-2];
                majority_dL_dconic_out <= dL_dconic_wire[(2 * num_pixels) - 2];
                majority_dL_dopacity_out <= dL_dopacity_wire[(2 * num_pixels)-2];
                majority_valid_out <= is_majority_gid_wire[(2 * num_pixels) - 2];
            end

        end

    end



endmodule