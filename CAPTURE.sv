`timescale 1ns / 1ps

module CAPTURE import HDMI_info::*;(
input logic clk,
input logic reset,
input logic vsync,
input logic hsync,
input logic [11:0] sample,
input logic sample_valid,

output logic wea,
output logic [ADDR_BITS-1:0] addra,
output logic [PIXEL_BITS-1:0] dina
);

logic [1:0] hsync_sync, vsync_sync;
always_ff @(posedge clk) begin
    hsync_sync <= {hsync_sync[0], hsync};
    vsync_sync <= {vsync_sync[0], vsync};
end
// Falling edge of HSYNC: (hsync_sync == 2'b10)
endmodule