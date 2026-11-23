module HDMout
    import HDMI_info::*; // Header include
(
    input logic clk, // 100MHz clock
    output logic pixel_clk, // Clock at HDMI rate
    output logic [ADDR_BITS-1:0] read_addr, // Sized for memory
    input logic [PIXEL_BITS-1:0] read_data, // Sized for memory
    output logic [7:0] red, // red pixel information
    output logic [7:0] green, // green pixel information
    output logic [7:0] blue, // blue pixel information
    output logic hsync, // HSYNC to HDMI
    output logic vsync, // VSYNC for HDMI
    output logic de // Data enable – During VSYNC
);
    // 640 x 480 @ 60 Hz VGA timing
    localparam int SCREEN_W = 640;
    localparam int SCREEN_H = 480;
    localparam int H_TOTAL = 800;
    localparam int V_TOTAL = 525;
    // 100 MHz input clock -> 25 MHz pixel clock
    logic [1:0] clk_div = 0;
    // Where you are in the HDMI display area
    logic [9:0] x = 0;
    logic [9:0] y = 0;
    // Memory address for the next pixel to display.
    logic [9:0] next_x;
    logic [9:0] next_y;
    logic image_on;
    // Delay image enable to match synchronous BRAM output.
    logic image_valid = 0;
    always_ff @(posedge clk)
        clk_div <= clk_div + 1'b1;
    // Keeping track of whether you are in the HDMI display.
    // 640x800.
    always_ff @(posedge pixel_clk) begin
        if (x == H_TOTAL-1) begin
            x <= 0;
            if (y == V_TOTAL-1)
                y <= 0;
            else
                y <= y + 1'b1;
        end
        else
            x <= x + 1'b1;
    end
    // Main display stuff.
    always_comb begin
        next_x = x + 1'b1;
        next_y = y;
    if (x == H_TOTAL-1) begin
        next_x = 0;
        if (y == V_TOTAL-1)
            next_y = 0;
        else
            next_y = y + 1'b1;
    end
    read_addr = '0;
    image_on = 1'b0;
    // Should the image be magnified to full display?
    if (next_x < SCREEN_W && next_y < SCREEN_H) begin
        if (EXPAND) begin
            read_addr =
                (next_y * ROWS / SCREEN_H) * COLS
                + (next_x * COLS / SCREEN_W);
            image_on = 1'b1;
        end
        else if (next_x < COLS && next_y < ROWS) begin
            read_addr = next_y * COLS + next_x;
            image_on = 1'b1;
        end
    end
end
always_ff @(posedge pixel_clk)
image_valid <= image_on;
// RGB output
always_comb begin
red = 0;
green = 0;
blue = 0;
if (de && image_valid) begin
if (COLOR) begin
red = read_data[23:16];
green = read_data[15:8];
blue = read_data[7:0];
end
else begin
red = read_data[7:0];
green = read_data[7:0];
blue = read_data[7:0];
end
end
end
// For generating clock for HDMI
assign pixel_clk = clk_div[1];
// VGA synchronization
assign de = (x < SCREEN_W && y < SCREEN_H);
assign hsync = ~((x >= 656) && (x < 752));
assign vsync = ~((y >= 490) && (y < 492));
endmodule