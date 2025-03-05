module barrel_shifter #(
    parameter gaussian_inputs = 4,
    parameter shift_width = $clog2(gaussian_inputs)
)(
    input wire [shift_width-1:0] shift_amount,

    output logic [shift_width-1:0] data_out

);

    

    always_comb begin
        if (shift_amount == 0) begin
            shifted_data = data_in;
        end 
        else begin

            shifted_data = data_in >> shift_amount;
        end
    end

endmodule