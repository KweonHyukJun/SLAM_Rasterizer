module gaussian_id_merge_sort #(
    parameter precision = 32,
    parameter data_size = precision + 32,
    parameter num_pixels = 16,
    parameter ID_WIDTH = 32  // Assumes last 32 bits are used as ID for sorting
) 
(
    input wire clk,
    input wire rst_n,
    input wire [data_size-1:0] data_in [num_pixels-1:0],
    input wire data_in_valid [num_pixels-1:0],
    
    output reg [data_size-1:0] data_out [num_pixels-1:0],
    output reg data_out_valid [num_pixels-1:0],

    //For test
    output reg [ID_WIDTH-1:0] GID_out [num_pixels-1:0]
);

    // Internal parameters for sorting stages
    localparam NUM_STAGES = $clog2(num_pixels);

    // Pipeline register declarations
    reg [data_size-1:0] stage_data [NUM_STAGES:0][num_pixels-1:0];
    reg stage_valid [NUM_STAGES:0][num_pixels-1:0];

    // Temporary registers to hold intermediate sorting results
    reg [data_size-1:0] next_stage_data [num_pixels-1:0];
    reg next_stage_valid [num_pixels-1:0];
    
    // Initialize the input stage (stage 0)
    integer k;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < num_pixels; k = k + 1) begin
                stage_data[0][k] <= {data_size{1'b0}};
                stage_valid[0][k] <= 1'b0;
                data_out[k] <= {data_size{1'b0}};
                data_out_valid[k] <= 1'b0;
                GID_out[k] <= 0;
            end
        end else begin
            for (k = 0; k < num_pixels; k = k+ 1) begin
                stage_data[0][k] <= data_in[k];
                stage_valid[0][k] <= data_in_valid[k];
            end
        end
    end

    // Generate merge stages
    genvar stage, i, j;
    generate
        for (stage = 1; stage <= NUM_STAGES; stage = stage + 1) begin : merge_stages
            localparam PAIR_SIZE = num_pixels >> stage;
            localparam ELEMENTS_PER_PAIR = 1 << stage;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (k = 0; k < num_pixels; k = k + 1) begin
                        stage_data[stage][k] <= {data_size{1'b0}};
                        stage_valid[stage][k] <= 1'b0;
                    end
                end else begin
                    // Initialize LEFT_IDX and RIGHT_IDX for each pair within this stage
                    integer LEFT_IDX, RIGHT_IDX;
                    for (i = 0; i < PAIR_SIZE; i = i + 1) begin
                        for (j = 0; j < ELEMENTS_PER_PAIR / 2; j = j + 1) begin
                            LEFT_IDX = i * ELEMENTS_PER_PAIR + j;
                            RIGHT_IDX = LEFT_IDX + ELEMENTS_PER_PAIR / 2;
                            
                            if (stage_data[stage-1][LEFT_IDX][ID_WIDTH-1:0] <= stage_data[stage-1][RIGHT_IDX][ID_WIDTH-1:0]) begin
                                next_stage_data[LEFT_IDX] <= stage_data[stage-1][LEFT_IDX];
                                next_stage_data[RIGHT_IDX] <= stage_data[stage-1][RIGHT_IDX];
                                
                                next_stage_valid[LEFT_IDX] <= stage_valid[stage-1][LEFT_IDX];
                                next_stage_valid[RIGHT_IDX] <= stage_valid[stage-1][RIGHT_IDX];
                            end else begin
                                next_stage_data[LEFT_IDX] <= stage_data[stage-1][RIGHT_IDX];
                                next_stage_data[RIGHT_IDX] <= stage_data[stage-1][LEFT_IDX];
                                
                                next_stage_valid[LEFT_IDX] <= stage_valid[stage-1][RIGHT_IDX];
                                next_stage_valid[RIGHT_IDX] <= stage_valid[stage-1][LEFT_IDX];
                            end
                        end
                    end

                    // Transfer sorted results for this stage
                    for (k = 0; k < num_pixels; k = k + 1) begin
                        stage_data[stage][k] <= next_stage_data[k];
                        stage_valid[stage][k] <= next_stage_valid[k];
                    end
                end
            end
        end
    endgenerate

    // Output assignment (final stage)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < num_pixels; k = k + 1) begin
                data_out[k] <= {data_size{1'b0}};
                data_out_valid[k] <= 1'b0;
                GID_out[k] <= {ID_WIDTH{1'b0}};
            end
        end else begin
            for (k = 0; k < num_pixels; k = k + 1) begin
                data_out[k] <= stage_data[NUM_STAGES][k];
                data_out_valid[k] <= stage_valid[NUM_STAGES][k];
                GID_out[k] <= stage_data[NUM_STAGES][k][ID_WIDTH-1:0];
            end
        end
    end
endmodule
