# WidebandTRXDigitalCal

Custom ADS7-V2EBZ and AD9164-FMCC-EBZ integration collateral for a wideband digital calibration and chirp-generation test setup.

## Included Content
- Vivado project-generation and debug scripts
- XDC scaffold for the ADS7-V2EBZ to AD9164-FMCC-EBZ integration
- MATLAB chirp reference model
- Bare-metal MicroBlaze firmware and AD9164 SPI helpers
- Packaged chirp AXI-Stream RTL source tree
- Bench test instructions and verification checklist

## Main Files
- `build_project.tcl`
- `ads7_ad9164_custom.xdc`
- `system_top.v`
- `system_ila.tcl`
- `chirp_gen.m`
- `main.c`
- `spi_ad9164_drivers.h`
- `test_instruction.md`
- `verification_report.md`

## Notes
- This repository currently tracks the authored source and documentation.
- Large downloaded vendor archives and local convenience zip bundles from the working directory are intentionally left out of version control.
- Before hardware testing, replace the placeholder `PACKAGE_PIN` entries in `ads7_ad9164_custom.xdc` with the final ADS7-V2EBZ package pins.
