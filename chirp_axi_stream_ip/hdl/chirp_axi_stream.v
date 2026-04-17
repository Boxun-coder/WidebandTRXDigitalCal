`timescale 1ns / 1ps

module chirp_axi_stream #(
    parameter integer PHASE_WIDTH = 32,
    parameter integer OUTPUT_WIDTH = 16
) (
    input  wire                       aclk,
    input  wire                       aresetn,
    input  wire [7:0]                 control_flags,
    input  wire [31:0]                cfg_num_samples,
    input  wire [PHASE_WIDTH-1:0]     cfg_phase_step_init,
    input  wire [PHASE_WIDTH-1:0]     cfg_phase_step_delta,
    input  wire [PHASE_WIDTH-1:0]     cfg_phase_step_limit,
    output wire [OUTPUT_WIDTH-1:0]    debug_tdata,
    output wire                       marker_out,
    output wire [31:0]                debug_sample_count,
    output wire [PHASE_WIDTH-1:0]     debug_phase_word,
    output wire [OUTPUT_WIDTH-1:0]    m_axis_tdata,
    output wire                       m_axis_tvalid,
    input  wire                       m_axis_tready,
    output wire                       m_axis_tlast
);

    wire enable        = control_flags[0];
    wire restart       = control_flags[1];
    wire continuous    = control_flags[2];
    wire marker_enable = control_flags[3];

    chirp_core #(
        .PHASE_WIDTH (PHASE_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) i_chirp_core (
        .clk              (aclk),
        .rstn             (aresetn),
        .enable           (enable),
        .restart          (restart),
        .continuous       (continuous),
        .marker_enable    (marker_enable),
        .cfg_num_samples  (cfg_num_samples),
        .cfg_phase_step_init (cfg_phase_step_init),
        .cfg_phase_step_delta(cfg_phase_step_delta),
        .cfg_phase_step_limit(cfg_phase_step_limit),
        .sample_data      (m_axis_tdata),
        .sample_valid     (m_axis_tvalid),
        .sample_ready     (m_axis_tready),
        .sample_last      (m_axis_tlast),
        .marker_out       (marker_out),
        .sample_count     (debug_sample_count),
        .phase_word       (debug_phase_word)
    );

    assign debug_tdata = m_axis_tdata;

endmodule
