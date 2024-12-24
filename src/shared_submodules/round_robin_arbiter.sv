module round_robin_arbiter #(
    parameter int N_MASTER = 16,                 // Number of input masters
    parameter int DATA_SIZE = 200               // Data width
) 
(
    input   wire                    clk,
    input   wire                    rst_n,       // Active low reset

    // Input interfaces
    input   wire                    src_valid_i[N_MASTER-1:0], // Valid signals from sources
    output  reg                     src_ready_o[N_MASTER-1:0], // Ready signals to sources
    input   wire [DATA_SIZE-1:0]    src_data_i [N_MASTER-1:0], // Data from sources

    // Output interface
    output  reg                     dst_valid_o, // Valid signal to destination
    input   wire                    dst_ready_i, // Ready signal from destination
    output  reg [DATA_SIZE-1:0]     dst_data_o   // Data to destination
);

    // Internal signals
    logic [31:0]    grant_idx;       // Current grant index
    logic [31:0]    next_grant_idx;  // Next grant index
    logic           grant_found;     // Indicate if a valid source is found
    logic [31:0]    current_idx;

    // Register the grant index
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            grant_idx <= 'd0;
        end 
        else if (dst_valid_o && dst_ready_i) begin
            // Move to the next source after a successful transaction
            grant_idx <= next_grant_idx;
        end
    end

    always_comb begin
        // Default values

        for (int i = 0; i < N_MASTER; i++) begin
            src_ready_o[i] = 1'b0;
        end

        dst_valid_o = 1'b0;
        dst_data_o  = 'h0;
        grant_found = 1'b0;

        // Priority-based arbitration
        next_grant_idx = grant_idx; // Start with current grant
        for (int i = 0; i < N_MASTER; i++) begin
            // Check for a valid source in round-robin order
            current_idx = (grant_idx + i) % N_MASTER;
            if (src_valid_i[current_idx] && !grant_found) begin
                // Grant to this source
                src_ready_o[current_idx] = dst_ready_i;
                dst_valid_o      = src_valid_i[current_idx];
                dst_data_o       = src_data_i[current_idx];
                next_grant_idx   = current_idx + 1; // Rotate priority
                grant_found      = 1'b1;
            end
        end
    end




endmodule
