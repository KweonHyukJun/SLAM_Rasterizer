module Backward_Block_controller_with_SRAM_pipelining_controller

#(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 12, // 2^11 - 1 = 2047
    parameter WINDOW_SIZE = 32,
    parameter Banks = 16,
    parameter GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision,
    parameter resoultion = 307200
)

// Testbench (Top controller && DDR RAM에서의 데이터)
(
    input wire clk,
    input wire rst_n,

    // From Top Controller
    input wire Block_data_done,
    input wire gradient_value_ready,
    // input wire gradient_data_done,

    input wire [11:0] W_in,
    input wire [11:0] H_in,
    input wire [15:0] block_id_in,

    input wire [GID_bit-1:0] last_gaussian_index_in, // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리
    
    
    // To Top controller
    output wire Block_data_ready,
    output wire gradient_value_valid,
    // output wire gradient_value_done,


    // From External DDR Memory to SRAM
    input wire [(3 * precision) -1:0] gaussian_color_from_DDR [gaussian_inputs-1:0],
    input wire [precision-1:0] gaussian_depth_from_DDR [gaussian_inputs-1:0],
    input wire [(2 * precision)-1:0] mean2D_from_DDR [gaussian_inputs-1:0],
    input wire [(4 * precision)-1:0] conic_opacity_from_DDR [gaussian_inputs-1:0],
    input wire [GID_bit-1:0] gaussian_id_from_DDR [gaussian_inputs-1:0],

    input wire [(2 * $clog2(BLOCK_SIZE))-1:0] pixel_id_from_DDR [num_pixels-1:0],

    input wire Gaussian_SRAM_WEB [gaussian_inputs-1:0],


    input wire [(3 * precision)-1:0] dL_dpixel_from_DDR [num_pixels-1:0],
    input wire [precision-1:0] dL_dpixel_depth_from_DDR [num_pixels-1:0],
    input wire [precision-1:0] T_first_from_DDR [num_pixels-1:0],
    input wire [GID_bit-1:0] n_contrib_from_DDR [num_pixels-1:0],

    input wire Pixel_SRAM_WEB [num_pixels-1:0],

    


    // Gradient DDR signal
    input wire Gradient_SRAM_REB_from_Top_control [Banks-1:0],
    input wire [GID_bit-1:0] gradient_id_to_SRAM_from_Top_control [Banks-1:0],  // Gradient SRAM Addr
    
    output wire push_to_Top_FIFO, // Gradient REB 0 이후? 혹은 동일 clock cycle에 발생
    output wire [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_merge_to_Top_FIFO

    // Gradient 받고 Gradient 0으로 초기화
    // output wire Gradient_SRAM_WEB
);

    localparam GAUSSIAN_SRAM_DEPTH = 1 << GID_bit;
    localparam PIXEL_SRAM_DEPTH = 1 << ($clog2(BLOCK_SIZE));
    
    localparam GAUSSIAN_SRAM_WIDTH = 10 * precision;
    localparam PIXEL_SRAM_WIDTH = 5 * precision + GID_bit;
    localparam GRADIENT_MERGE_WIDTH = 11 * precision;



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

        // assign {gaussian_color_from_SRAM, gaussian_depth_from_SRAM, mean2D_from_SRAM, conic_opacity_from_SRAM} = gaussian_data_from_SRAM;
        // assign gaussian_color_from_SRAM = gaussian_data_from_SRAM[10 * precision - 1:7 * precision];
        // assign gaussian_depth_from_SRAM = gaussian_data_from_SRAM[7 * precision - 1:6 * precision];
        // assign mean2D_from_SRAM = gaussian_data_from_SRAM[6 * precision - 1:4 * precision];
        // assign conic_opacity_from_SRAM = gaussian_data_from_SRAM[4* precision - 1:0];


        // Pixel SRAM
        wire [(5 * precision + GID_bit)-1:0] pixel_data_from_DDR [num_pixels-1:0];
        // assign pixel_data_from_DDR = {dL_dpixel_from_DDR, dL_dpixel_depth_from_DDR, T_first_from_DDR, n_contrib_from_DDR};

        wire [(5 * precision + GID_bit)-1:0] pixel_data_from_SRAM [num_pixels-1:0];

        // wire [precision-1:0] T_first_from_SRAM;
        // wire [(3 * precision)-1:0] dL_dpixel_from_SRAM;
        // wire [precision-1:0] dL_dpixel_depth_from_SRAM;
        // wire [GID_bit-1:0] n_contrib_from_SRAM;

        wire [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0];
        wire [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0];
        wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0];
        wire [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0];


        // assign {T_first_from_SRAM, dL_dpixel_from_SRAM, dL_dpixel_depth_from_SRAM, n_contrib_from_SRAM} = pixel_data_from_SRAM;
        
        // assign next_dL_dpixel_from_SRAM = pixel_data_from_SRAM[(5 * precision) + GID_bit - 1: (2 * precision) + GID_bit];
        // assign next_dL_dpixel_depth_from_SRAM = pixel_data_from_SRAM[(2 * precision) + GID_bit - 1: precision + GID_bit];
        // assign next_T_first_from_SRAM = pixel_data_from_SRAM[precision + GID_bit - 1:GID_bit];
        // assign next_n_contrib_from_SRAM = pixel_data_from_SRAM[GID_bit-1:0];


        // To Rasterizer
            // Gausisan Inputs
            wire [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire i_valid [gaussian_inputs * num_pixels - 1:0];

            wire last_input_done_to_rasterizer [gaussian_inputs * num_pixels - 1:0];

            // Pixel Inputs
            wire start [num_pixels-1:0]; 
            wire [(3 * precision)-1:0] dL_dpixel_current [num_pixels-1:0];
            wire [precision-1:0] dL_dpixel_depth_current [num_pixels-1:0];
            wire [precision-1:0] T_first_current [num_pixels-1:0];
            wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_current [num_pixels-1:0];
            wire stall_backpressure_from_controller;


        // To SRAM

            // Gaussian SRAM
            wire [GID_bit-1:0] Read_address_to_Gaussian_SRAM [gaussian_inputs-1:0];
            wire REB_to_gaussian_SRAM [gaussian_inputs-1:0];

            // Pixel SRAM
            // wire [2 * $clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM [num_pixels-1:0];
            wire [$clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM [num_pixels-1:0];
            wire REB_to_Pixel_SRAM [num_pixels-1:0];

            // Gradient SRAM
            wire REB_to_gradient_SRAM [Banks-1:0];
            wire WEB_to_gradient_SRAM [Banks-1:0];

        // To Block controller

        wire stall_to_controller_from_rasterizer [num_pixels-1:0];
        // wire last_input_done_from_rasterizer [Banks-1:0];
        wire last_input_done_from_rasterizer [num_pixels-1:0];
        wire last_input_done_from_gradient_merge [Banks-1:0];

        wire stall_to_rasterizer_to_controller;

        // // Gradient SRAM ports


        // wire [GID_bit-1:0] write_address_to_gradient_SRAM;
        // assign write_address_to_gradient_SRAM = gaussian_id_from_DDR;


        wire [GRADIENT_MERGE_WIDTH-1:0] FIFO_to_SRAM_data [Banks-1:0];
        wire [GRADIENT_MERGE_WIDTH-1:0] INPUT_DATA_TO_GRADIENT_SRAM [Banks-1:0];

        wire [GRADIENT_MERGE_WIDTH-1:0] SRAM_data_in_to_Adder [Banks-1:0];

        wire [GID_bit-1:0] Read_address_before_add [Banks-1:0];
        wire [GID_bit-1:0] Write_address_after_add [Banks-1:0];
        
        wire [GID_bit-1:0] gradient_SRAM_read_address [Banks-1:0];

        wire [GRADIENT_MERGE_WIDTH-1:0] SRAM_data_out [Banks-1:0];

        wire gradient_ID_used [Banks-1:0];

        wire FIFO_pop_valid_in [Banks-1:0];
        wire FIFO_pop_ready_out [Banks-1:0];

        
        wire [11:0] W;
        wire [11:0] H;
        wire [15:0] block_id;

        wire last_input_done_and_data_zero [Banks-1:0];


        reg REB_to_gradient_SRAM_from_Top_control_before [Banks-1:0];
        // reg REB_to_gradient_SRAM_from_Block_control_before [Banks-1:0];

        wire gradient_SRAM_REB [Banks-1:0];

        wire [GAUSSIAN_SRAM_DEPTH-1:0] gradient_first_used_LUT;


    // combinational regitser
    reg push_to_Top_FIFO_reg;
    reg [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_merge_to_Top_FIFO_reg;

    reg [GID_bit-1:0] gradient_id_to_SRAM_from_Top_control_reg;




    // Gradient SRAM reseting or writing singals
    // REB 한 후 다음 사이클에 0 처리 때려넣으면 되는거 아닌가?
    reg [GID_bit-1:0] gradient_SRAM_write_address_from_Top [Banks-1:0];
    reg gradient_SRAM_WEB_from_Top [Banks-1:0];

    wire [GID_bit-1:0] gradient_SRAM_write_address [Banks-1:0];
    wire gradient_SRAM_WEB [Banks-1:0];



    Backward_Block_controller_pipelining_controller #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .gaussian_inputs(gaussian_inputs),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE),
        .Banks(Banks)
    )
    Backward_Block_controller_inst (
        .clk(clk),
        .rst_n(rst_n),

        .Block_data_done(Block_data_done),
        .gradient_value_ready(gradient_value_ready),
        // .gradient_data_done(gradient_data_done),

        .W_in(W_in),
        .H_in(H_in),
        .block_id_in(block_id_in),

        .last_gaussian_index_in(last_gaussian_index_in),

        .Block_data_ready(Block_data_ready),
        .gradient_value_valid(gradient_value_valid),
        // .gradient_value_done(gradient_value_done),

        .stall_to_controller_from_rasterizer(stall_to_controller_from_rasterizer),
        
        // Grad merge에서 Rasterizer stall. input row control시 사용
        .stall_to_rasterizer_to_controller(stall_to_rasterizer_to_controller),


        .stall_to_rasterizer_from_controller(stall_backpressure_from_controller),
        
        
        .last_input_done_from_rasterizer(last_input_done_from_rasterizer),
        .last_input_done_from_gradient_merge(last_input_done_from_gradient_merge),

        .rasterizer_FIFO_pop_valid_in(FIFO_pop_valid_in),
        .rasterizer_FIFO_pop_ready_out(FIFO_pop_ready_out),

        .i_valid(i_valid),
        .gaussian_id_to_rasterizer(gaussian_id_to_rasterizer),
        .gaussian_color_to_rasterizer(gaussian_color_to_rasterizer),
        .gaussian_depth_to_rasterizer(gaussian_depth_to_rasterizer),
        .mean2D_to_rasterizer(mean2D_to_rasterizer),
        .conic_opacity_to_rasterizer(conic_opacity_to_rasterizer),
        .last_input_done_to_rasterizer(last_input_done_to_rasterizer),
        
        

        .start(start),

        .W(W),
        .H(H),
        .block_id(block_id),
        .pixel_id(pixel_id_current),

        .T_first_current(T_first_current),
        .dL_dpixel_current(dL_dpixel_current),
        .dL_dpixel_depth_current(dL_dpixel_depth_current),
        // .pixel_id_current(pixel_id_current),

        .gaussian_color_from_SRAM(gaussian_color_from_SRAM),
        .gaussian_depth_from_SRAM(gaussian_depth_from_SRAM),
        .mean2D_from_SRAM(mean2D_from_SRAM),
        .conic_opacity_from_SRAM(conic_opacity_from_SRAM),

        .gaussian_id_to_SRAM(gaussian_id_to_SRAM),

        // .Read_address_to_Gaussian_SRAM(Read_address_to_Gaussian_SRAM),
        .REB_to_gaussian_SRAM(REB_to_gaussian_SRAM),

        .next_n_contrib_from_SRAM(next_n_contrib_from_SRAM),
        .next_T_first_from_SRAM(next_T_first_from_SRAM),
        .next_dL_dpixel_from_SRAM(next_dL_dpixel_from_SRAM),
        .next_dL_dpixel_depth_from_SRAM(next_dL_dpixel_depth_from_SRAM),

        .Read_address_to_Pixel_SRAM(Read_address_to_Pixel_SRAM),
        .REB_to_Pixel_SRAM(REB_to_Pixel_SRAM),

        .Read_address_from_rasterizer_to_gradient_SRAM(Read_address_before_add),

        .REB_to_gradient_SRAM(REB_to_gradient_SRAM),
        .WEB_to_gradient_SRAM(WEB_to_gradient_SRAM),

        .gradient_ID_used(gradient_ID_used),

        .Gradient_first_used_LUT(gradient_first_used_LUT)

        ,.last_input_done_and_data_zero(last_input_done_and_data_zero)
    );


    genvar pix, gau;

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
            // .AB(Read_address_to_Gaussian_SRAM), // read address
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

    generate
        for (pix = 0; pix < num_pixels; pix++) begin : Pixel_SRAM_inst
            dp_ram #( .N(PIXEL_SRAM_WIDTH), .W(PIXEL_SRAM_DEPTH))
            Pixel_SRAM_inst(
                .clk(clk),
                .rst_n(rst_n),

                .AA(pixel_id_from_DDR[pix]), // write address
                .D(pixel_data_from_DDR[pix]), // write data
                .WEB(Pixel_SRAM_WEB[pix]), // write enable
                .AB(Read_address_to_Pixel_SRAM[pix]), // read address
                .REB(REB_to_Pixel_SRAM[pix]), // read enable
                .Q(pixel_data_from_SRAM[pix]) // read data
            );

            assign pixel_data_from_DDR[pix] = {dL_dpixel_from_DDR[pix], dL_dpixel_depth_from_DDR[pix], T_first_from_DDR[pix], n_contrib_from_DDR[pix]};

            assign next_dL_dpixel_from_SRAM[pix] = pixel_data_from_SRAM[pix][(5 * precision) + GID_bit - 1: (2 * precision) + GID_bit];
            assign next_dL_dpixel_depth_from_SRAM[pix] = pixel_data_from_SRAM[pix][(2 * precision) + GID_bit - 1: precision + GID_bit];
            assign next_T_first_from_SRAM[pix] = pixel_data_from_SRAM[pix][precision + GID_bit - 1:GID_bit];
            assign next_n_contrib_from_SRAM[pix] = pixel_data_from_SRAM[pix][GID_bit-1:0];
        end
    endgenerate

    // Rasterizer & Gradient Merge
    // Combined_Backward_Rasterizer_and_merge_with_changed_encoder #(
    Combined_Backward_Rasterizer_and_merge_pipelining_controller #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .gaussian_inputs(gaussian_inputs),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE),
        .Banks(Banks)
    )
    Combined_Backward_Rasterizer_and_merge_pipelining_controller_inst(
        .clk(clk),
        .rst_n(rst_n),

        .i_valid(i_valid),

        .W(W),
        .H(H),

        .start(start),
        .dL_dpixel(dL_dpixel_current),
        .dL_dpixel_depth(dL_dpixel_depth_current),
        .T_first(T_first_current),

        .block_id(block_id),
        .pixel_id(pixel_id_current),

        .stall_backpressure(stall_backpressure_from_controller),

        .last_input(last_input_done_to_rasterizer),

        .mean2D(mean2D_to_rasterizer),
        .conic_opacity(conic_opacity_to_rasterizer),
        .gaussian_id_in(gaussian_id_to_rasterizer),
        .gaussian_color(gaussian_color_to_rasterizer),
        .gaussian_depth(gaussian_depth_to_rasterizer),

        .stall_to_controller(stall_to_controller_from_rasterizer),

        .stall_to_rasterizer_to_controller(stall_to_rasterizer_to_controller),

        .FIFO_pop_valid_in(FIFO_pop_valid_in),
        .FIFO_pop_ready_out(FIFO_pop_ready_out),

        .last_input_done_from_rasterizer(last_input_done_from_rasterizer),

        .last_input_done_from_gradient_merge(last_input_done_from_gradient_merge),
        // .last_input_done_out(last_input_done_from_rasterizer),
        


        .SRAM_data_in_to_Adder(SRAM_data_in_to_Adder),
        .FIFO_to_SRAM_data(FIFO_to_SRAM_data),
        .Read_address_before_add(Read_address_before_add),
        .Write_address_after_add(Write_address_after_add)

        ,.last_input_done_and_data_zero(last_input_done_and_data_zero)
    );


    // 이건 Raster module과 해서 추후 테스트 진행
    // 추가적으로 Block 데이터 처음 들어올 시 새거에 대한 컨트롤이 필요할듯?

    genvar m;
    generate
        // // Gradient Write 신호
        // assign gradient_SRAM_WEB = Gradient_SRAM_REB_from_Top_control;
        // assign gradient_SRAM_write_address = ;

        assign push_to_Top_FIFO = push_to_Top_FIFO_reg;
        assign gradient_merge_to_Top_FIFO =  gradient_first_used_LUT[gradient_id_to_SRAM_from_Top_control_reg] ? gradient_merge_to_Top_FIFO_reg : 'h0;


        for (m = 0; m < Banks; m++) begin : Gradient_SRAM_inst

        assign gradient_SRAM_REB[m] = (REB_to_gradient_SRAM[m] && Gradient_SRAM_REB_from_Top_control[m]);

        // assign gradient_SRAM_read_address[m] = !Gradient_SRAM_REB_from_Top_control[m] ? gradient_id_to_SRAM_from_Top_control[m] >> $clog2(Banks) : 
        assign gradient_SRAM_read_address[m] = !Gradient_SRAM_REB_from_Top_control[m] ? gradient_id_to_SRAM_from_Top_control[m] >> $clog2(Banks) : 

                                                ( !REB_to_gradient_SRAM[m] ? Read_address_before_add[m] >> $clog2(Banks): 'h0);

        assign SRAM_data_in_to_Adder[m] = gradient_ID_used[m] ? SRAM_data_out[m] : 'h0;


        // Gradient Write 신호


         // WEB_to gradient SRAM == Rasterizer value
         // Gradient_SRAM_REB_from_Top_control == Top value
        // assign gradient_SRAM_WEB[m] = (WEB_to_gradient_SRAM[m] && gradient_SRAM_WEB_from_Top[m]);
        // 결과값이 last_input_done = 1 이고, 기존 데이터가 없는 경우는 없어야 함
        assign gradient_SRAM_WEB[m] = (WEB_to_gradient_SRAM[m] && gradient_SRAM_WEB_from_Top[m]);
        assign gradient_SRAM_write_address[m] = !gradient_SRAM_WEB_from_Top[m] ? gradient_SRAM_write_address_from_Top[m] >> $clog2(Banks) :
                                                ( !WEB_to_gradient_SRAM[m] ? Write_address_after_add[m] >> $clog2(Banks) : 'h0);


        assign INPUT_DATA_TO_GRADIENT_SRAM[m] = !gradient_SRAM_WEB_from_Top[m] ? 'h0 : 
                                                ( !WEB_to_gradient_SRAM[m] ? FIFO_to_SRAM_data[m] : 'h0);

            // 이거 SRAM은 초기화 해야함
            dp_ram #( .N(GRADIENT_MERGE_WIDTH), .W(GAUSSIAN_SRAM_DEPTH) )
            Gradient_SRAM_inst(
                .clk(clk),
                // rst_n 없는 신호임
                .rst_n(rst_n),

                // .AA((Write_address_after_add[m] >> $clog2(Banks))), // write address
                // .D(FIFO_to_SRAM_data[m]), // write data
                // .WEB(WEB_to_gradient_SRAM[m]), // write enable

                .AA(gradient_SRAM_write_address[m]), // write address
                .D(INPUT_DATA_TO_GRADIENT_SRAM[m]), // write data
                .WEB(gradient_SRAM_WEB[m]), // write enable                

                .AB(gradient_SRAM_read_address[m]), // read address
                // .REB(REB_to_gradient_SRAM[m]), // read enable
                .REB(gradient_SRAM_REB[m]), // read enable
                .Q(SRAM_data_out[m]) // read data
            );


            // SRAM data_in_to Adder 신호를 controller에서 할당해야할듯?
            // assign SRAM_data_in_to_Adder[k] = !SRAM_REB_cyi_cle_before_FF[k] ? SRAM_data_out[k] : 'h0;
            
        end
    endgenerate


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            gradient_id_to_SRAM_from_Top_control_reg <= 'h0;
            for (int Bank = 0; Bank < Banks; Bank++) begin
                REB_to_gradient_SRAM_from_Top_control_before[Bank] <= 1'b1;

                gradient_SRAM_WEB_from_Top[Bank] <= 1'b1;
                gradient_SRAM_write_address_from_Top[Bank] <= 'h0;

            end
        end
        else begin
            gradient_id_to_SRAM_from_Top_control_reg <= gradient_id_to_SRAM_from_Top_control[0];

            for (int Bank = 0; Bank < Banks; Bank++) begin
                REB_to_gradient_SRAM_from_Top_control_before[Bank] <= Gradient_SRAM_REB_from_Top_control[Bank];

                gradient_SRAM_WEB_from_Top[Bank] <= Gradient_SRAM_REB_from_Top_control[Bank];
                gradient_SRAM_write_address_from_Top[Bank] <= gradient_id_to_SRAM_from_Top_control[0];
                
            end
        end
    end

    
    // combinational regitser


    always_comb begin
        push_to_Top_FIFO_reg = 0;
        gradient_merge_to_Top_FIFO_reg = 'h0;

        for (int Bank = 0; Bank < Banks; Bank++) begin
            if (!REB_to_gradient_SRAM_from_Top_control_before[Bank]) begin
                push_to_Top_FIFO_reg = 1'b1;
                gradient_merge_to_Top_FIFO_reg = SRAM_data_out[Bank];
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