// File: gradient_merge.sv
// Description: Module for merging gradient values in SLAM Rasterizer

module gradient_merge  #(
    parameter precision = 32,
    parameter pixels = 16,
    parameter data_size = precision * 12 + 32
)

(
    // FIFO signal
    input logic clk,
    input logic rst_n,
    input logic [data_size - 1 : 0] data_in [pixels - 1:0], // inputs = pixel  {G_wire[i], d_wire[i], conic_opacity_wire[i], alpha_wire[i], gaussian_color_wire[i], gaussian_depth_wire[i], gaussian_id_wire[i]}
    input logic FIFO_empty [pixels-1:0],

    output logic FIFO_read [pixels-1:0],


    // Control signal (wire로 할 지)
    input logic gradient_ready,
    output logic gradient_out_valid,
    output logic [precision - 1 : 0] data_out // Gradient output    
    
);

    // Register declaration
    
    // Wire declaration
    // logic [precision-1:0] mux_out;
 


    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin

        end

        else begin

        end
    end
endmodule