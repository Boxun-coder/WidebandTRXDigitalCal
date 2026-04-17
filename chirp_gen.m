function chirp_gen()
% chirp_gen
%   MATLAB reference model for the AD9164 chirp source.
%   1. Generates a complex baseband chirp.
%   2. Quantizes the real component into a 16-bit LUT profile.
%   3. Emits HDL Coder-friendly settings for the RTL implementation.
%
% The generated RTL in `chirp_axi_stream_ip/hdl` is the matching hand-authored
% source used by Vivado. When HDL Coder is available, uncomment the `makehdl`
% block at the bottom to regenerate equivalent Verilog from MATLAB directly.

cfg.fs_hz           = 250e6;
cfg.samples_per_burst = 16384;
cfg.f_start_hz      = -20e6;
cfg.f_stop_hz       =  20e6;
cfg.amplitude       = 0.95;
cfg.phase_width     = 32;
cfg.output_width    = 16;
cfg.lut_addr_bits   = 8;

t = (0:cfg.samples_per_burst - 1).' / cfg.fs_hz;
wave = cfg.amplitude .* chirp(t, cfg.f_start_hz, t(end), cfg.f_stop_hz, "linear", 0, "complex");
wave_i = real(wave);
wave_q = imag(wave);

quant_max = 2^(cfg.output_width - 1) - 1;
wave_i_q = int16(max(min(round(wave_i .* quant_max), quant_max), -quant_max - 1));
wave_q_q = int16(max(min(round(wave_q .* quant_max), quant_max), -quant_max - 1));

phase_step_start = uint32(round((cfg.f_start_hz / cfg.fs_hz) * 2^cfg.phase_width));
phase_step_stop  = uint32(round((cfg.f_stop_hz  / cfg.fs_hz) * 2^cfg.phase_width));
phase_step_delta = uint32(round(double(phase_step_stop - phase_step_start) / double(cfg.samples_per_burst)));

fprintf("Reference chirp configuration\n");
fprintf("  Samples per burst : %u\n", cfg.samples_per_burst);
fprintf("  Phase step start  : 0x%08X\n", phase_step_start);
fprintf("  Phase step delta  : 0x%08X\n", phase_step_delta);
fprintf("  Phase step limit  : 0x%08X\n", phase_step_stop);

out_dir = fullfile(fileparts(mfilename("fullpath")), "chirp_axi_stream_ip", "generated");
if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

writematrix([wave_i_q, wave_q_q], fullfile(out_dir, "chirp_reference_iq.csv"));

figure("Name", "AD9164 Chirp Reference", "Color", "w");
tiledlayout(2,1);
nexttile;
plot(t * 1e6, wave_i, "LineWidth", 1.1);
grid on;
xlabel("Time (us)");
ylabel("Amplitude");
title("Real Chirp Waveform");

nexttile;
spectrogram(wave_i, 512, 384, 1024, cfg.fs_hz, "centered", "yaxis");
title("Spectrogram");

hdl_cfg.samples_per_burst = uint32(cfg.samples_per_burst);
hdl_cfg.phase_step_init   = phase_step_start;
hdl_cfg.phase_step_delta  = phase_step_delta;
hdl_cfg.phase_step_limit  = phase_step_stop;
save(fullfile(out_dir, "chirp_hdl_config.mat"), "cfg", "hdl_cfg");

% Optional HDL Coder flow:
% {
% dut = fi(double(wave_i), 1, cfg.output_width, cfg.output_width - 2);
% hdlset_param("chirp_gen", "TargetLanguage", "Verilog");
% hdlset_param("chirp_gen", "GenerateHDLTestBench", "off");
% makehdl("chirp_gen_dut_wrapper");
% }
end
