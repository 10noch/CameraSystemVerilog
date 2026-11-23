module top import HDMI_info::*; (
    input  logic       clk,        // 100 MHz Boolean board clock
    input  logic       rst,        // Active-high reset (e.g., BTN0)

    // Analog camera input to XADC (verify pins in Boolean Board XDC)
    input  logic       vauxp0,
    input  logic       vauxn0,

    // Sync signals from LM1881 chip
    input  logic       csync_n,
    input  logic       vsync_n,

    // HDMI output signals (connect to VHDL HDMI transmitter / XDC)
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,
    output logic       hsync,
    output logic       vsync,
    output logic       de,
    output logic       pixel_clk
);

    // XADC -> Capture wires
    logic [11:0] adc_sample;
    logic        adc_valid;

    // Capture -> BRAM write wires
    logic                  mem_we;
    logic [ADDR_BITS-1:0]  mem_write_addr;
    logic [PIXEL_BITS-1:0] mem_write_data;

    // BRAM -> HDMout read wires
    logic [ADDR_BITS-1:0]  read_addr;
    logic [PIXEL_BITS-1:0] read_data;

    // 1. Analog-to-Digital Conversion (Appendix B)
    xadc_capture camera_adc (
        .clk          (clk),
        .vauxp0       (vauxp0),
        .vauxn0       (vauxn0),
        .sample       (adc_sample),
        .sample_valid (adc_valid)
    );

    // 2. Sync & Frame Capture (writes raw grayscale pixels directly to BRAM)
    camera_capture capture_inst (
        .clk        (clk),
        .rst        (rst),
        .csync_n    (csync_n),
        .vsync_n    (vsync_n),
        .sample     (adc_sample),
        .wea        (mem_we),
        .write_addr (mem_write_addr),
        .write_data (mem_write_data)
    );

    // 3. Shared Display BRAM (Appendix A - 8-bit width, 2304 depth)
    HDMI_data hdmi_data (
        .clka  (clk),
        .ena   (1'b1),
        .wea   (mem_we),
        .addra (mem_write_addr),
        .dina  (mem_write_data),
        .clkb  (pixel_clk),
        .addrb (read_addr),
        .doutb (read_data)
    );

    // 4. HDMI Display Driver (Appendix D / project_code.zip)
    HDMout to_display (
        .clk       (clk),
        .pixel_clk (pixel_clk),
        .read_addr (read_addr),
        .read_data (read_data),
        .red       (red),
        .green     (green),
        .blue      (blue),
        .hsync     (hsync),
        .vsync     (vsync),
        .de        (de)
    );

endmodule