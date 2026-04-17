`timescale 1ns / 1ps

module chirp_core #(
    parameter integer PHASE_WIDTH = 32,
    parameter integer OUTPUT_WIDTH = 16
) (
    input  wire                         clk,
    input  wire                         rstn,
    input  wire                         enable,
    input  wire                         restart,
    input  wire                         continuous,
    input  wire                         marker_enable,
    input  wire [31:0]                  cfg_num_samples,
    input  wire [PHASE_WIDTH-1:0]       cfg_phase_step_init,
    input  wire [PHASE_WIDTH-1:0]       cfg_phase_step_delta,
    input  wire [PHASE_WIDTH-1:0]       cfg_phase_step_limit,
    output reg  signed [OUTPUT_WIDTH-1:0] sample_data,
    output reg                          sample_valid,
    input  wire                         sample_ready,
    output reg                          sample_last,
    output reg                          marker_out,
    output reg  [31:0]                  sample_count,
    output reg  [PHASE_WIDTH-1:0]       phase_word
);

    reg [PHASE_WIDTH-1:0] phase_accum;
    reg [PHASE_WIDTH-1:0] phase_step;
    reg                   running;

    wire advance_sample = sample_valid && sample_ready;
    wire [7:0] lut_index = phase_accum[PHASE_WIDTH-1 -: 8];

    function automatic signed [15:0] quarter_sine;
        input [5:0] idx;
        begin
            case (idx)
                6'd0:  quarter_sine = 16'sd0;
                6'd1:  quarter_sine = 16'sd804;
                6'd2:  quarter_sine = 16'sd1608;
                6'd3:  quarter_sine = 16'sd2410;
                6'd4:  quarter_sine = 16'sd3212;
                6'd5:  quarter_sine = 16'sd4011;
                6'd6:  quarter_sine = 16'sd4808;
                6'd7:  quarter_sine = 16'sd5602;
                6'd8:  quarter_sine = 16'sd6393;
                6'd9:  quarter_sine = 16'sd7179;
                6'd10: quarter_sine = 16'sd7962;
                6'd11: quarter_sine = 16'sd8739;
                6'd12: quarter_sine = 16'sd9512;
                6'd13: quarter_sine = 16'sd10278;
                6'd14: quarter_sine = 16'sd11039;
                6'd15: quarter_sine = 16'sd11793;
                6'd16: quarter_sine = 16'sd12539;
                6'd17: quarter_sine = 16'sd13279;
                6'd18: quarter_sine = 16'sd14010;
                6'd19: quarter_sine = 16'sd14732;
                6'd20: quarter_sine = 16'sd15446;
                6'd21: quarter_sine = 16'sd16151;
                6'd22: quarter_sine = 16'sd16846;
                6'd23: quarter_sine = 16'sd17530;
                6'd24: quarter_sine = 16'sd18204;
                6'd25: quarter_sine = 16'sd18868;
                6'd26: quarter_sine = 16'sd19519;
                6'd27: quarter_sine = 16'sd20159;
                6'd28: quarter_sine = 16'sd20787;
                6'd29: quarter_sine = 16'sd21403;
                6'd30: quarter_sine = 16'sd22005;
                6'd31: quarter_sine = 16'sd22594;
                6'd32: quarter_sine = 16'sd23170;
                6'd33: quarter_sine = 16'sd23731;
                6'd34: quarter_sine = 16'sd24279;
                6'd35: quarter_sine = 16'sd24811;
                6'd36: quarter_sine = 16'sd25329;
                6'd37: quarter_sine = 16'sd25831;
                6'd38: quarter_sine = 16'sd26318;
                6'd39: quarter_sine = 16'sd26789;
                6'd40: quarter_sine = 16'sd27244;
                6'd41: quarter_sine = 16'sd27683;
                6'd42: quarter_sine = 16'sd28105;
                6'd43: quarter_sine = 16'sd28510;
                6'd44: quarter_sine = 16'sd28898;
                6'd45: quarter_sine = 16'sd29269;
                6'd46: quarter_sine = 16'sd29622;
                6'd47: quarter_sine = 16'sd29957;
                6'd48: quarter_sine = 16'sd30274;
                6'd49: quarter_sine = 16'sd30572;
                6'd50: quarter_sine = 16'sd30853;
                6'd51: quarter_sine = 16'sd31113;
                6'd52: quarter_sine = 16'sd31356;
                6'd53: quarter_sine = 16'sd31580;
                6'd54: quarter_sine = 16'sd31785;
                6'd55: quarter_sine = 16'sd31971;
                6'd56: quarter_sine = 16'sd32137;
                6'd57: quarter_sine = 16'sd32285;
                6'd58: quarter_sine = 16'sd32412;
                6'd59: quarter_sine = 16'sd32521;
                6'd60: quarter_sine = 16'sd32609;
                6'd61: quarter_sine = 16'sd32678;
                6'd62: quarter_sine = 16'sd32728;
                default: quarter_sine = 16'sd32757;
            endcase
        end
    endfunction

    function automatic signed [15:0] sine_lut;
        input [7:0] phase;
        reg [5:0] idx;
        reg signed [15:0] qval;
        begin
            case (phase[7:6])
                2'b00: begin
                    idx = phase[5:0];
                    qval = quarter_sine(idx);
                    sine_lut = qval;
                end
                2'b01: begin
                    idx = ~phase[5:0];
                    qval = quarter_sine(idx);
                    sine_lut = qval;
                end
                2'b10: begin
                    idx = phase[5:0];
                    qval = quarter_sine(idx);
                    sine_lut = -qval;
                end
                default: begin
                    idx = ~phase[5:0];
                    qval = quarter_sine(idx);
                    sine_lut = -qval;
                end
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (!rstn) begin
            running      <= 1'b0;
            phase_accum  <= {PHASE_WIDTH{1'b0}};
            phase_step   <= {PHASE_WIDTH{1'b0}};
            phase_word   <= {PHASE_WIDTH{1'b0}};
            sample_data  <= {OUTPUT_WIDTH{1'b0}};
            sample_valid <= 1'b0;
            sample_last  <= 1'b0;
            marker_out   <= 1'b0;
            sample_count <= 32'd0;
        end else begin
            marker_out <= 1'b0;

            if (restart) begin
                running      <= enable;
                phase_accum  <= {PHASE_WIDTH{1'b0}};
                phase_step   <= cfg_phase_step_init;
                phase_word   <= cfg_phase_step_init;
                sample_count <= 32'd0;
                sample_valid <= enable;
                sample_last  <= 1'b0;
                sample_data  <= sine_lut({2'b00, 6'd0});
            end else if (enable && !running) begin
                running      <= 1'b1;
                phase_accum  <= {PHASE_WIDTH{1'b0}};
                phase_step   <= cfg_phase_step_init;
                phase_word   <= cfg_phase_step_init;
                sample_count <= 32'd0;
                sample_valid <= 1'b1;
                sample_last  <= 1'b0;
                sample_data  <= sine_lut({2'b00, 6'd0});
            end else if (!enable && !continuous) begin
                running      <= 1'b0;
                sample_valid <= 1'b0;
                sample_last  <= 1'b0;
            end else if (running) begin
                sample_valid <= 1'b1;
                sample_data  <= sine_lut(lut_index);
                phase_word   <= phase_step;
                sample_last  <= (cfg_num_samples != 0) && (sample_count == (cfg_num_samples - 1));

                if (advance_sample) begin
                    if (marker_enable && (sample_count == 32'd0)) begin
                        marker_out <= 1'b1;
                    end

                    phase_accum <= phase_accum + phase_step;
                    if (phase_step < cfg_phase_step_limit) begin
                        phase_step <= phase_step + cfg_phase_step_delta;
                    end

                    if (sample_last) begin
                        if (continuous) begin
                            sample_count <= 32'd0;
                            phase_accum  <= {PHASE_WIDTH{1'b0}};
                            phase_step   <= cfg_phase_step_init;
                            phase_word   <= cfg_phase_step_init;
                        end else begin
                            running      <= 1'b0;
                            sample_valid <= 1'b0;
                        end
                    end else begin
                        sample_count <= sample_count + 1'b1;
                    end
                end
            end
        end
    end

endmodule
