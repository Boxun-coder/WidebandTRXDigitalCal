`timescale 1ns / 1ps

module tb_chirp_axi_stream;

    reg         aclk = 1'b0;
    reg         aresetn = 1'b0;
    reg  [7:0]  control_flags = 8'h0;
    reg  [31:0] cfg_num_samples = 32'd256;
    reg  [31:0] cfg_phase_step_init = 32'h0200_0000;
    reg  [31:0] cfg_phase_step_delta = 32'h0000_4000;
    reg  [31:0] cfg_phase_step_limit = 32'h0400_0000;
    wire [15:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready = 1'b1;
    wire        m_axis_tlast;
    wire        marker_out;
    wire [15:0] debug_tdata;
    wire [31:0] debug_sample_count;
    wire [31:0] debug_phase_word;

    always #5 aclk = ~aclk;

    chirp_axi_stream dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .control_flags(control_flags),
        .cfg_num_samples(cfg_num_samples),
        .cfg_phase_step_init(cfg_phase_step_init),
        .cfg_phase_step_delta(cfg_phase_step_delta),
        .cfg_phase_step_limit(cfg_phase_step_limit),
        .debug_tdata(debug_tdata),
        .marker_out(marker_out),
        .debug_sample_count(debug_sample_count),
        .debug_phase_word(debug_phase_word),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    initial begin
        repeat (8) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (4) @(posedge aclk);
        control_flags <= 8'b0000_1011;
        @(posedge aclk);
        control_flags[1] <= 1'b0;
        repeat (280) @(posedge aclk);
        $finish;
    end

endmodule
