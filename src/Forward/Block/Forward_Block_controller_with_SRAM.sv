module Forward_Block_controller_with_SRAM

#(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 11, // 2^11 - 1 = 2047
    parameter WINDOW_SIZE = 32,
    // parameter Banks = 16,
    parameter GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision,
    parameter resoultion = 307200
)

// Testbench (Top controller && DDR RAM에서의 데이터)
(
    input wire clk,
    input wire rst_n,

    // From Top Controller
    input wire Block_data_done,
    input wire pixel_out_value_ready,
    // input wire gradient_data_done,


    input wire [15:0] block_id_in,

    input wire [GID_bit-1:0] last_gaussian_index_in, // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리
    
    
    // To Top controller
    output wire Block_data_ready,
    output wire pixel_out_value_valid,
    // output wire pixel_out_value_done,


    // From External DDR Memory to SRAM
    input wire [(3 * precision) -1:0] gaussian_color_from_DDR [gaussian_inputs-1:0],
    input wire [precision-1:0] gaussian_depth_from_DDR [gaussian_inputs-1:0],
    input wire [(2 * precision)-1:0] mean2D_from_DDR [gaussian_inputs-1:0],
    input wire [(4 * precision)-1:0] conic_opacity_from_DDR [gaussian_inputs-1:0],
    input wire [GID_bit-1:0] gaussian_id_from_DDR [gaussian_inputs-1:0],

    input wire [(2 * $clog2(BLOCK_SIZE))-1:0] pixel_id_from_DDR [num_pixels-1:0],

    input wire Gaussian_SRAM_WEB [gaussian_inputs-1:0],

    
    // Gradient DDR signal
    input wire pixel_out_value_SRAM_REB_from_Top_control [num_pixels-1:0],
    input wire [$clog2(num_pixels)-1:0] pixel_out_value_SRAM_Read_address_from_Top_control [num_pixels-1:0],  // Gradient SRAM Addr


    
    output wire pixel_out_value_valid_to_Top [num_pixels-1:0], // Gradient REB 0 이후? 혹은 동일 clock cycle에 발생
    output wire [(6 * precision + GID_bit)-1:0] pixel_out_value_to_Top [num_pixels-1:0]
);

    localparam GAUSSIAN_SRAM_DEPTH = 1 << GID_bit;
    localparam PIXEL_SRAM_DEPTH = 1 << ($clog2(BLOCK_SIZE));
    
    localparam GAUSSIAN_SRAM_WIDTH = 10 * precision;
    localparam PIXEL_SRAM_WIDTH = 6 * precision + GID_bit;

    // localparam GRADIENT_MERGE_WIDTH = 11 * precision;



    // Wire declaration

        // Gaussian SRAM    
        wire [(10 * precision)-1:0] gaussian_data_from_DDR [gaussian_inputs-1:0];
        // assign gaussian_data_from_DDR = {gaussian_color_from_DDR, gaussian_depth_from_DDR, mean2D_from_DDR, conic_opacity_from_DDR};

        wire [GID_bit-1:0] write_address_to_gaussian_SRAM [gaussian_inputs-1:0];
        assign write_address_to_gaussian_SRAM = gaussian_id_from_DDR;

    

        wire [10 * precision -1:0] gaussian_data_from_SRAM [gaussian_inputs-1:0];

        wire [3 * precision - 1:0] gaussian_color_from_SRAM [gaussian_inputs-1:0];
        wire [precision - 1:0] gaussian_depth_from_SRAM [gaussian_inputs-1:0];
        wire [(2 * precision)-1:0] mean2D_from_SRAM [gaussian_inputs-1:0];
        wire [(4 * precision)-1:0] conic_opacity_from_SRAM [gaussian_inputs-1:0];
        wire [GID_bit-1:0] gaussian_id_to_SRAM [gaussian_inputs-1:0];


        // To Rasterizer
            // Gausisan Inputs
            wire [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire i_valid [gaussian_inputs * num_pixels - 1:0];

            wire last_input_done_to_rasterizer [gaussian_inputs * num_pixels - 1:0];

            // // Pixel Inputs
            wire start [num_pixels-1:0]; 
            wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_current [num_pixels-1:0];
            wire stall_backpressure_from_controller;


        // To SRAM

            // Gaussian SRAM
            wire [GID_bit-1:0] Read_address_to_Gaussian_SRAM [gaussian_inputs-1:0];
            wire REB_to_gaussian_SRAM [gaussian_inputs-1:0];

            wire WEB_to_pixel_SRAM [num_pixels-1:0];

        // To Block controller

        wire stall_to_controller_from_rasterizer [num_pixels-1:0];
    

        reg [PIXEL_SRAM_WIDTH-1:0] input_data_to_pixel_out_value_SRAM [num_pixels-1:0];

        

        wire [$clog2(num_pixels)-1:0] pixel_out_value_SRAM_write_address [num_pixels-1:0];
        wire [$clog2(num_pixels)-1:0] Write_address_to_Pixel_SRAM [num_pixels-1:0];
        
        

        wire [PIXEL_SRAM_WIDTH-1:0] pixel_out_value_SRAM_data_out [num_pixels-1:0];

        
        wire [15:0] block_id;

        




    reg pixel_out_value_valid_to_Top_FF [num_pixels-1:0];

    wire pixel_out_value_SRAM_WEB [num_pixels-1:0];


    // Rasterizer Out

    wire [GID_bit-1:0] gaussian_id_out_from_rasterizer [num_pixels-1:0];
    wire pixel_valid_out_from_rasterizer [num_pixels-1:0];

    wire [(3 * precision)-1:0] pixel_color_out_from_rasterizer [num_pixels-1:0];
    wire [precision-1:0] pixel_depth_out_from_rasterizer [num_pixels-1:0];
    wire [precision-1:0] pixel_opacity_out_from_rasterizer [num_pixels-1:0];
    wire [precision-1:0] T_first_out_from_rasterizer [num_pixels-1:0];
    wire [GID_bit-1:0] n_contrib_out_from_rasterizer [num_pixels-1:0];
    



    Forward_Block_controller #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .gaussian_inputs(gaussian_inputs),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE)
    )
    Forward_Block_controller_inst (
        .clk(clk),
        .rst_n(rst_n),

        .Block_data_done(Block_data_done),
        .pixel_out_value_ready(pixel_out_value_ready),
        // .gradient_data_done(gradient_data_done),

        .block_id_in(block_id_in),

        .last_gaussian_index_in(last_gaussian_index_in),

        .Block_data_ready(Block_data_ready),
        .pixel_out_value_valid(pixel_out_value_valid),
        // .pixel_out_value_done(pixel_out_value_done),

        .stall_to_controller_from_rasterizer(stall_to_controller_from_rasterizer),
        .stall_to_rasterizer_from_controller(stall_backpressure_from_controller),
        
        .last_input_done_from_rasterizer(pixel_valid_out_from_rasterizer),


        .i_valid(i_valid),
        .gaussian_color_to_rasterizer(gaussian_color_to_rasterizer),
        .gaussian_depth_to_rasterizer(gaussian_depth_to_rasterizer),
        .mean2D_to_rasterizer(mean2D_to_rasterizer),
        .conic_opacity_to_rasterizer(conic_opacity_to_rasterizer),
        .last_input_done_to_rasterizer(last_input_done_to_rasterizer),

        .gaussian_id_to_rasterizer(gaussian_id_to_rasterizer),
        
        

        .start(start),

        .block_id(block_id),
        .pixel_id(pixel_id_current),


        // .pixel_id_current(pixel_id_current),

        .gaussian_color_from_SRAM(gaussian_color_from_SRAM),
        .gaussian_depth_from_SRAM(gaussian_depth_from_SRAM),
        .mean2D_from_SRAM(mean2D_from_SRAM),
        .conic_opacity_from_SRAM(conic_opacity_from_SRAM),
        .gaussian_id_to_SRAM(gaussian_id_to_SRAM),

        // .Read_address_to_Gaussian_SRAM(Read_address_to_Gaussian_SRAM),
        .REB_to_gaussian_SRAM(REB_to_gaussian_SRAM),

        .WEB_to_Pixel_SRAM(WEB_to_pixel_SRAM),
        .Write_address_to_Pixel_SRAM(Write_address_to_Pixel_SRAM)
    );


    genvar gau;
    // Input gaussian cache
    generate 
        for (gau = 0; gau < gaussian_inputs; gau++) begin : Gaussian_SRAM_inst
            dp_ram #( .N(GAUSSIAN_SRAM_WIDTH), .W(GAUSSIAN_SRAM_DEPTH))
            Gaussian_SRAM_inst(
            .clk(clk),

            // rst_n 없는 신호임
            .rst_n(rst_n),

            .AA(write_address_to_gaussian_SRAM[gau]), // write address
            .D(gaussian_data_from_DDR[gau]), // write data
            .WEB(Gaussian_SRAM_WEB[gau]), // write enable

            .AB(gaussian_id_to_SRAM[gau]), // read address
            .REB(REB_to_gaussian_SRAM[gau]), // read enable
            .Q(gaussian_data_from_SRAM[gau]) // read data
            );


            assign gaussian_color_from_SRAM[gau] = gaussian_data_from_SRAM[gau][10 * precision - 1:7 * precision];
            assign gaussian_depth_from_SRAM[gau] = gaussian_data_from_SRAM[gau][7 * precision - 1:6 * precision];
            assign mean2D_from_SRAM[gau] = gaussian_data_from_SRAM[gau][6 * precision - 1:4 * precision];
            assign conic_opacity_from_SRAM[gau] = gaussian_data_from_SRAM[gau][4* precision - 1:0];

            assign gaussian_data_from_DDR[gau] = {gaussian_color_from_DDR[gau], gaussian_depth_from_DDR[gau], mean2D_from_DDR[gau], conic_opacity_from_DDR[gau]};
        end


    endgenerate 


    // Rasterizer & Gradient Merge
    Forward_Rasterizer_group_unit #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .gaussian_inputs(gaussian_inputs),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    )
    Forward_Rasterizer_group_unit_inst(
        .clk(clk),
        .rst_n(rst_n),

        .i_valid(i_valid),


        .start(start),

        .block_id(block_id),
        .pixel_id(pixel_id_current),

        .stall_backpressure(stall_backpressure_from_controller),

        .last_input(last_input_done_to_rasterizer),

        .mean2D(mean2D_to_rasterizer),
        .conic_opacity(conic_opacity_to_rasterizer),

        .gaussian_id_in(gaussian_id_to_rasterizer),
        .gaussian_color(gaussian_color_to_rasterizer),
        .gaussian_depth(gaussian_depth_to_rasterizer),



        .gaussian_id_out(gaussian_id_out_from_rasterizer),
        .pixel_valid_out(pixel_valid_out_from_rasterizer),

        .stall_to_controller(stall_to_controller_from_rasterizer),


        .pixel_color_out(pixel_color_out_from_rasterizer),
        .pixel_depth_out(pixel_depth_out_from_rasterizer),
        .pixel_opacity_out(pixel_opacity_out_from_rasterizer),
        .T_first_out(T_first_out_from_rasterizer),
        .n_contrib_out(n_contrib_out_from_rasterizer)
    );


    

    // Top에서 pixel에 대한 병렬 처리를 위한 Bank (한번에 한 Row씩 가져오게끔)
    genvar pix;
    generate

        for (pix = 0; pix < num_pixels; pix++) begin : pixel_SRAM_inst

            // REB 이후 한 사이클 대기하고 받아야 함.
            assign pixel_out_value_valid_to_Top[pix] = pixel_out_value_valid_to_Top_FF[pix];
            assign pixel_out_value_to_Top[pix] = pixel_out_value_SRAM_data_out[pix];


            // Rasterizer 결과를 Write하는 신호
            assign pixel_out_value_SRAM_WEB[pix] = WEB_to_pixel_SRAM[pix];
            assign pixel_out_value_SRAM_write_address[pix] = Write_address_to_Pixel_SRAM[pix];

        

            // assign input_data_to_pixel_out_value_SRAM[pix] = {pixel_color_out_from_rasterizer[pix], pixel_depth_out_from_rasterizer[pix], pixel_opacity_out_from_rasterizer[pix], T_first_out_from_rasterizer[pix], n_contrib_out_from_rasterizer[pix]};


            // 이거 SRAM은 초기화 해야함
            dp_ram #( .N(PIXEL_SRAM_WIDTH), .W(PIXEL_SRAM_DEPTH) )
            Pixel_SRAM_inst(
                .clk(clk),

                // rst_n 없는 신호임
                .rst_n(rst_n),

                .AA(pixel_out_value_SRAM_write_address[pix]), // write address
                .D(input_data_to_pixel_out_value_SRAM[pix]), // write data
                .WEB(pixel_out_value_SRAM_WEB[pix]), // write enable                

                .AB(pixel_out_value_SRAM_Read_address_from_Top_control[pix]), // read address
                .REB(pixel_out_value_SRAM_REB_from_Top_control[pix]), // read enable
                .Q(pixel_out_value_SRAM_data_out[pix]) // read data
            );
        end
    endgenerate


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int pixel = 0; pixel < num_pixels; pixel++) begin
                pixel_out_value_valid_to_Top_FF[pixel] <= 1'b0;

                input_data_to_pixel_out_value_SRAM[pixel] <= 'd0;

            end
        end
        else begin
            for (int pixel = 0; pixel < num_pixels; pixel++) begin
                pixel_out_value_valid_to_Top_FF[pixel] <= !pixel_out_value_SRAM_REB_from_Top_control[pixel];

                input_data_to_pixel_out_value_SRAM[pixel] <= {pixel_color_out_from_rasterizer[pixel], pixel_depth_out_from_rasterizer[pixel], pixel_opacity_out_from_rasterizer[pixel], T_first_out_from_rasterizer[pixel], n_contrib_out_from_rasterizer[pixel]};
            end
        end
    end


    // // Gradient를 모으는 FIFO
    // // 이거 추후 테스트 진행
    // push_pop_fifo #(
    //     .DATA_WIDTH(GRADIENT_MERGE_WIDTH),
    //     .DEPTH(Banks)
    // )
    // TOP_Gradient_FIFO_inst(

    // );




   // // BRAM port 
    // wire s_aresetn;




    // // DRAM operational BRAM
    // Gaussian_Block_RAM #()
    // Gaussian_Block_RAM_inst
    // (
    //     .rsta_busy(),
    //     .rstb_busy(),
        
    //     .s_aclk(clk),
    //     .s_aresetn(s_aresetn),
    //     .s_axi_awid(), // write address id
    //     .s_axi_awaddr(), // write address
    //     .s_axi_awlen(), // write address length
    //     .s_axi_awsize(), // write address size
    //     .s_axi_awburst(), // write address burst
    //     .s_axi_awvalid(), // write address valid
    //     .s_axi_awready(), // write address ready
    //     .s_axi_wdata(),
    //     .s_axi_wstrb(),
    //     .s_axi_wlast(),
    //     .s_axi_wvalid(),
    //     .s_axi_wready(),
    //     .s_axi_bid(),
    //     .s_axi_bresp(),
    //     .s_axi_bvalid(),
    //     .s_axi_bready(),
    //     .s_axi_arid(),
    //     .s_axi_araddr(),
    //     .s_axi_arlen(),
    //     .s_axi_arsize(),
    //     .s_axi_arburst(),
    //     .s_axi_arvalid(),
    //     .s_axi_arready(),
    //     .s_axi_rid(),
    //     .s_axi_rdata(),
    //     .s_axi_rresp(),
    //     .s_axi_rlast(),
    //     .s_axi_rvalid(),
    //     .s_axi_rready()
    // );


    // Pixel_Block_RAM #()
    // Pixel_Block_RAM_inst
    // (
    //     .rsta_busy(),
    //     .rstb_busy(),
        
    //     .s_aclk(clk),
    //     .s_aresetn(rst_n),
    //     .s_axi_awid(),
    //     .s_axi_awaddr(),
    //     .s_axi_awlen(),
    //     .s_axi_awsize(),
    //     .s_axi_awburst(),
    //     .s_axi_awvalid(),
    //     .s_axi_awready(),
    //     .s_axi_wdata(),
    //     .s_axi_wstrb(),
    //     .s_axi_wlast(),
    //     .s_axi_wvalid(),
    //     .s_axi_wready(),
    //     .s_axi_bid(),
    //     .s_axi_bresp(),
    //     .s_axi_bvalid(),
    //     .s_axi_bready(),
    //     .s_axi_arid(),
    //     .s_axi_araddr(),
    //     .s_axi_arlen(),
    //     .s_axi_arsize(),
    //     .s_axi_arburst(),
    //     .s_axi_arvalid(),
    //     .s_axi_arready(),
    //     .s_axi_rid(),
    //     .s_axi_rdata(),
    //     .s_axi_rresp(),
    //     .s_axi_rlast(),
    //     .s_axi_rvalid(),
    //     .s_axi_rready()        
    // );

    // Gradient_Block_RAM #()
    // Gradient_Block_RAM_inst
    // (
    //     .rsta_busy(),
    //     .rstb_busy(),
    //     .s_aclk(clk),
    //     .s_aresetn(rst_n),
    //     .s_axi_awid(),
    //     .s_axi_awaddr(),
    //     .s_axi_awlen(),
    //     .s_axi_awsize(),
    //     .s_axi_awburst(),
    //     .s_axi_awvalid(),
    //     .s_axi_awready(),
    //     .s_axi_wdata(),
    //     .s_axi_wstrb(),
    //     .s_axi_wlast(),
    //     .s_axi_wvalid(),
    //     .s_axi_wready(),
    //     .s_axi_bid(),
    //     .s_axi_bresp(),
    //     .s_axi_bvalid(),
    //     .s_axi_bready(),
    //     .s_axi_arid(),
    //     .s_axi_araddr(),
    //     .s_axi_arlen(),
    //     .s_axi_arsize(),
    //     .s_axi_arburst(),
    //     .s_axi_arvalid(),
    //     .s_axi_arready(),
    //     .s_axi_rid(),
    //     .s_axi_rdata(),
    //     .s_axi_rresp(),
    //     .s_axi_rlast(),
    //     .s_axi_rvalid(),
    //     .s_axi_rready()
    // );



endmodule