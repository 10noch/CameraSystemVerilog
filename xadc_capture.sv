`timescale 1ns / 1ps

module xadc_capture (
    input  logic        clk,                  // 100 MHz board clock
    input  logic        vauxp0,               // Analog positive: Pmod JA pin 1 (B13)
    input  logic        vauxn0,               // Analog negative: Pmod JA pin 2 (A13)
    output logic [11:0] sample       = '0,    // 12-bit result (0..4095)
    output logic        sample_valid = 1'b0   // 1-clock pulse when 'sample' updates
);

    logic [15:0] adc_data;
    logic        adc_ready;
    logic        adc_eoc;

    xadc_wiz_0 adc (
        // Clock and analog inputs
        .dclk_in     (clk),
        .vauxp0      (vauxp0),
        .vauxn0      (vauxn0),

        // DRP interface
        .daddr_in    (7'h10),       // VAUX0 result register
        .den_in      (adc_eoc),     // Read result when conversion ends
        .di_in       (16'b0),
        .dwe_in      (1'b0),

        // ADC results
        .do_out      (adc_data),
        .drdy_out    (adc_ready),
        .eoc_out     (adc_eoc),

        // Unused analog inputs
        .vp_in       (1'b0),
        .vn_in       (1'b0),

        // Unused outputs (remove any port Vivado flags as non-existent)
        .busy_out    (),
        .channel_out (),
        .eos_out     (),
        .alarm_out   ()
    );

    // Grab top 12 bits [15:4] whenever drdy_out pulses
    always_ff @(posedge clk) begin
        sample_valid <= adc_ready;
        if (adc_ready)
            sample <= adc_data[15:4];
    end

endmodule