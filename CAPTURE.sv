module camera_capture import HDMI_info::*; (
    input  logic                  clk,        // 100 MHz
    input  logic                  rst,
    input  logic                  csync_n,    // From LM1881 (active low)
    input  logic                  vsync_n,    // From LM1881 (active low)
    input  logic [11:0]           sample,     // From xadc_capture
    output logic                  wea,        // To HDMI_data BRAM
    output logic [ADDR_BITS-1:0]  write_addr, // To HDMI_data BRAM
    output logic [PIXEL_BITS-1:0] write_data  // To HDMI_data BRAM (8-bit grayscale)
);

    // Timing constants at 100 MHz (10 ns period)
    localparam int SKIP_TOP_LINES  = 20;   // Skip top overscan/blank lines
    localparam int BACK_PORCH_CLKS = 1170; // 9.4 us (HSYNC+back porch) + 2.3 us margin
    localparam int SAMPLE_INT_CLKS = 100;  // 1.0 us between pixels -> 48 pixels = 48 us

    // 2-FF synchronizers + edge detection for external LM1881 pins
    logic [2:0] vsync_sync, csync_sync;
    always_ff @(posedge clk) begin
        vsync_sync <= {vsync_sync[1:0], vsync_n};
        csync_sync <= {csync_sync[1:0], csync_n};
    end

    wire vsync_high = vsync_sync[2];
    wire hsync_fall = (csync_sync[2:1] == 2'b10); // Falling edge of HSYNC

    typedef enum logic [2:0] {
        WAIT_VSYNC_LOW,
        WAIT_VSYNC_HIGH,
        SKIP_LINES,
        WAIT_HSYNC,
        WAIT_PORCH,
        CAPTURE_ROW
    } state_t;

    state_t state;
    logic [10:0] clk_cnt;
    logic [8:0]  line_cnt;
    logic [5:0]  col_cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= WAIT_VSYNC_LOW;
            wea        <= 1'b0;
            write_addr <= '0;
            write_data <= '0;
            clk_cnt    <= '0;
            line_cnt   <= '0;
            col_cnt    <= '0;
        end else begin
            wea <= 1'b0; // Default off; pulse high for 1 clock per pixel write

            // If VSYNC ever drops low mid-frame, reset frame alignment
            if (!vsync_high && state != WAIT_VSYNC_LOW) begin
                state <= WAIT_VSYNC_HIGH;
            end else begin
                case (state)
                    // Wait for current frame to finish
                    WAIT_VSYNC_LOW: begin
                        if (!vsync_high)
                            state <= WAIT_VSYNC_HIGH;
                    end

                    // Wait for vertical blanking to end
                    WAIT_VSYNC_HIGH: begin
                        if (vsync_high) begin
                            line_cnt <= '0;
                            state    <= SKIP_LINES;
                        end
                    end

                    // Skip top non-visible lines
                    SKIP_LINES: begin
                        if (hsync_fall) begin
                            if (line_cnt == SKIP_TOP_LINES - 1) begin
                                line_cnt <= '0;
                                state    <= WAIT_HSYNC;
                            end else begin
                                line_cnt <= line_cnt + 1'b1;
                            end
                        end
                    end

                    // Re-sync at the start of every visible row
                    WAIT_HSYNC: begin
                        if (hsync_fall) begin
                            clk_cnt <= '0;
                            state   <= WAIT_PORCH;
                        end
                    end

                    // Wait 9.4 us + 2.3 us margin before sampling active video
                    WAIT_PORCH: begin
                        if (clk_cnt == BACK_PORCH_CLKS - 1) begin
                            clk_cnt <= '0;
                            col_cnt <= '0;
                            state   <= CAPTURE_ROW;
                        end else begin
                            clk_cnt <= clk_cnt + 1'b1;
                        end
                    end

                    // Grab 48 pixels across the active row
                    CAPTURE_ROW: begin
                        if (clk_cnt == 0) begin
                            wea        <= 1'b1;
                            write_addr <= (line_cnt * COLS) + col_cnt;
                            write_data <= sample[11:4]; // Top 8 bits of 12-bit ADC
                        end

                        if (clk_cnt == SAMPLE_INT_CLKS - 1) begin
                            clk_cnt <= '0;
                            if (col_cnt == COLS - 1) begin
                                // Finished all 48 pixels in this row
                                if (line_cnt == ROWS - 1) begin
                                    state <= WAIT_VSYNC_LOW; // Full 48x48 frame captured
                                end else begin
                                    line_cnt <= line_cnt + 1'b1;
                                    state    <= WAIT_HSYNC;
                                end
                            end else begin
                                col_cnt <= col_cnt + 1'b1;
                            end
                        end else begin
                            clk_cnt <= clk_cnt + 1'b1;
                        end
                    end
                endcase
            end
        end
    end

endmodule