`default_nettype none

// -- VGA sync generator (do not modify) --------------------------------------
// Generates hsync, vsync, display_on, hpos[9:0], vpos[9:0]
// for 640x480 @ 60 Hz with a 25 MHz pixel clock.
module hvsync_generator (
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);
    localparam H_DISPLAY = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
    localparam V_DISPLAY = 480, V_TOP   = 10, V_SYNC =  2, V_BOTTOM = 33;
    localparam H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;  // 800
    localparam V_TOTAL   = V_DISPLAY + V_TOP   + V_SYNC + V_BOTTOM; // 525

    reg [9:0] hcount = 0, vcount = 0;

    always @(posedge clk) begin
        if (reset) begin
            hcount <= 0; vcount <= 0;
        end else if (hcount == H_TOTAL - 1) begin
            hcount <= 0;
            vcount <= (vcount == V_TOTAL - 1) ? 0 : vcount + 1;
        end else
            hcount <= hcount + 1;
    end

    assign hpos       = hcount;
    assign vpos       = vcount;
    assign display_on = (hcount < H_DISPLAY) && (vcount < V_DISPLAY);
    assign hsync      = ~((hcount >= H_DISPLAY + H_FRONT) &&
                          (hcount <  H_DISPLAY + H_FRONT + H_SYNC));
    assign vsync      = ~((vcount >= V_DISPLAY + V_TOP) &&
                          (vcount <  V_DISPLAY + V_TOP + V_SYNC));
endmodule


// -- Main design --------------------------------------------------------------
// Rename module to tt_um_YOURGITHUBNAME_vga_stripes
module tt_um_doc4science_vga_stripes (
    input  wire [7:0] ui_in,    // ui_in[0] = optional speed toggle
    output wire [7:0] uo_out,   // VGA: {hsync, B0, G0, R0, vsync, B1, G1, R1}
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,      // 25 MHz
    input  wire       rst_n
);
    wire       hsync, vsync, display_on;
    wire [9:0] hpos, vpos;

    hvsync_generator hvsync_gen (
        .clk(clk), .reset(~rst_n),
        .hsync(hsync), .vsync(vsync),
        .display_on(display_on), .hpos(hpos), .vpos(vpos)
    );

    // Frame counter: increments once per frame (~60 Hz)
    reg [9:0] frame_count;
    reg       vsync_r;
    always @(posedge clk) begin
        if (!rst_n) begin
            frame_count <= 0; vsync_r <= 1;
        end else begin
            vsync_r <= vsync;
            if (vsync_r && !vsync)   // falling edge = new frame
                frame_count <= frame_count + 1;
        end
    end

    // -- MODIFY THIS SECTION ----------------------------------------------------
    // Change + to - to reverse stripe direction.
    // Change [5] to [4] for 16 px stripes, [6] for 64 px stripes.
    // Try different r/g/b combinations for different colours.
    wire [9:0] moving_x = hpos + frame_count;
    wire stripe = moving_x[5];           // stripe every 32 pixels

    wire r = display_on &  stripe;       // red on stripe
    wire g = 1'b0;
    wire b = display_on & ~stripe;       // blue off stripe
    // -------------------------------------------------------------------------

    // TT VGA pinout: {hsync, B0, G0, R0, vsync, B1, G1, R1}
    assign uo_out  = {hsync, b, g, r, vsync, b, g, r};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule


`ifndef HVSYNC_GENERATOR_H
`define HVSYNC_GENERATOR_H

/*
Video sync generator, used to drive a VGA monitor.
Timing from: https://en.wikipedia.org/wiki/Video_Graphics_Array
To use:
- Wire the hsync and vsync signals to top level outputs
- Add a 3-bit (or more) "rgb" output to the top level
*/

module hvsync_generator(clk, reset, hsync, vsync, display_on, hpos, vpos);

  input clk;
  input reset;
  output reg hsync, vsync;
  output display_on;
  output reg [9:0] hpos;
  output reg [9:0] vpos;

  // declarations for TV-simulator sync parameters
  // horizontal constants
  parameter H_DISPLAY       = 640; // horizontal display width
  parameter H_BACK          =  48; // horizontal left border (back porch)
  parameter H_FRONT         =  16; // horizontal right border (front porch)
  parameter H_SYNC          =  96; // horizontal sync width
  // vertical constants
  parameter V_DISPLAY       = 480; // vertical display height
  parameter V_TOP           =  33; // vertical top border
  parameter V_BOTTOM        =  10; // vertical bottom border
  parameter V_SYNC          =   2; // vertical sync # lines
  // derived constants
  parameter H_SYNC_START    = H_DISPLAY + H_FRONT;
  parameter H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
  parameter H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
  parameter V_SYNC_START    = V_DISPLAY + V_BOTTOM;
  parameter V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
  parameter V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

  wire hmaxxed = (hpos == H_MAX) || reset;	// set when hpos is maximum
  wire vmaxxed = (vpos == V_MAX) || reset;	// set when vpos is maximum
  
  // horizontal position counter
  always @(posedge clk)
  begin
    hsync <= ~(hpos>=H_SYNC_START && hpos<=H_SYNC_END);
    if(hmaxxed)
      hpos <= 0;
    else
      hpos <= hpos + 1;
  end

  // vertical position counter
  always @(posedge clk)
  begin
    vsync <= ~(vpos>=V_SYNC_START && vpos<=V_SYNC_END);
    if(hmaxxed)
      if (vmaxxed)
        vpos <= 0;
      else
        vpos <= vpos + 1;
  end
  
  // display_on is set when beam is in "safe" visible frame
  assign display_on = (hpos<H_DISPLAY) && (vpos<V_DISPLAY);

endmodule

`endif

\end{lstlisting}
