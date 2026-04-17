# Test Instructions

## Goal
Bring up the custom ADS7-V2EBZ + AD9164-FMCC-EBZ design safely, verify digital operation first, and only then move to RF measurement.

## Required Software
- AMD Xilinx Vivado
  Use a version that supports Virtex-7 and the JESD204 / MicroBlaze / AXI IP used by this project. Vivado and Vitis should be the same release.
- AMD Xilinx Vitis
  Required to build and load the bare-metal MicroBlaze application from `main.c`.
- MATLAB
  Required to run `chirp_gen.m` and generate the chirp reference.
- MATLAB HDL Coder
  Required if you want to regenerate HDL directly from MATLAB instead of using the provided RTL and packaged IP.
- MATLAB Signal Processing support
  Needed for chirp generation and spectrogram-style reference analysis in MATLAB.
- USB/JTAG drivers for the ADS7-V2EBZ programming connection
  Required so Vivado Hardware Manager and Vitis can access the board.
- Serial terminal program
  Recommended for reading firmware messages if you route the UART to an external USB-to-UART adapter.

## Required Hardware
- ADS7-V2EBZ evaluation board
  This is the main Virtex-7 carrier board.
- AD9164-FMCC-EBZ evaluation board
  This is the DAC FMC card used by the design.
- FMC connection between the ADS7-V2EBZ and AD9164-FMCC-EBZ
  Ensure the FMC mating and standoff/mechanical support are correct before powering the system.
- Host PC or workstation
  Needed to run Vivado, Vitis, MATLAB, and the board programming tools.
- Power source for the boards
  Use the proper supply and power-up method recommended by the board documentation.
- JTAG programming connection
  Required to program the FPGA and load/debug software.
- Multimeter or logic-level probe
  Required to verify `uart_ext_txd` and `uart_ext_rxd` are truly at 1.8 V before connecting external logic.
- Oscilloscope with enough analog bandwidth for the AD9164 output
  Required for final RF waveform capture and chirp verification.
- Oscilloscope probe or coaxial RF connection path
  Use a connection method appropriate for the AD9164 output frequency and amplitude.
- External trigger connection from `scope_trig` to the oscilloscope
  Required for stable waveform capture during chirp bursts.
- 1.8 V-compatible external USART or USB-to-UART adapter
  Only connect this after you confirm idle voltage is 1.8 V on the FPGA pins.

## Files Used
- `build_project.tcl`
- `ads7_ad9164_custom.xdc`
- `system_ila.tcl`
- `chirp_gen.m`
- `main.c`
- `spi_ad9164_drivers.h`
- `verification_report.md`

## Stage 0: Pre-Check
1. Open `ads7_ad9164_custom.xdc`.
2. Replace every commented `PACKAGE_PIN` placeholder with the actual ADS7-V2EBZ FPGA pin you will use.
3. Confirm the pins for `uart_ext_txd`, `uart_ext_rxd`, and `scope_trig` belong to a 1.8 V-compatible bank.
4. Confirm the FMC mappings match your physical connector routing.

Pass criteria:
- No placeholder package pins remain for signals you will test.
- UART and trigger signals are assigned to 1.8 V I/O.

## Stage 1: MATLAB Reference Generation
1. Start MATLAB.
2. Open `chirp_gen.m`.
3. Run:
```matlab
chirp_gen
```
4. Save the reported chirp settings and reference plots.

Expected outputs:
- `chirp_reference_iq.csv` under `chirp_axi_stream_ip/generated`
- `chirp_hdl_config.mat` under `chirp_axi_stream_ip/generated`
- Time-domain and spectrogram plots

Pass criteria:
- MATLAB runs without errors.
- The chirp start, stop, and burst length match what you plan to test on hardware.

## Stage 2: Vivado Build
1. Start Vivado.
2. Open the Tcl console.
3. Run:
```tcl
cd {C:/Users/Boxun Yan/OneDrive - UCLA IT Services/SICR_FPGA}
source build_project.tcl
```
4. Let block design generation, synthesis, implementation, and bitstream generation finish.
5. Verify that the `.xsa` handoff file is produced in the workspace root.

Expected outputs:
- Vivado project under `vivado/ads7_ad9164_custom`
- Bitstream in the implementation run directory
- `ads7_ad9164_custom.xsa`

Pass criteria:
- No fatal errors during IP generation or implementation.
- Bitstream generated successfully.
- `.xsa` file generated successfully.

## Stage 3: Insert ILA Debug
1. In Vivado Tcl console, after the design exists, run:
```tcl
cd {C:/Users/Boxun Yan/OneDrive - UCLA IT Services/SICR_FPGA}
source system_ila.tcl
```
2. Confirm the debug artifacts are produced.

Expected outputs:
- `ads7_ad9164_custom.ltx`
- `ads7_ad9164_custom_debug.dcp`

Pass criteria:
- ILA script completes without errors.
- Probe file is available for Hardware Manager.

## Stage 4: Vitis Software Build
1. Start Vitis.
2. Create a platform using `ads7_ad9164_custom.xsa`.
3. Create a bare-metal application project.
4. Add `main.c` and `spi_ad9164_drivers.h`.
5. Build the application.

Pass criteria:
- The application compiles successfully.
- No unresolved BSP symbols remain.

## Stage 5: Safe Digital Bring-Up
1. Program the FPGA with the bitstream.
2. Load the ELF from Vitis.
3. Do not connect the external USART yet.
4. Power the boards and check the idle levels first.
5. Measure `uart_ext_txd` idle voltage with a multimeter or logic probe.
6. Measure `uart_ext_rxd` idle voltage.
7. Confirm both are at 1.8 V logic level before attaching external circuitry.

Pass criteria:
- `uart_ext_txd` idle is 1.8 V.
- `uart_ext_rxd` idle is 1.8 V.

Stop here if either pin is not 1.8 V.

## Stage 6: AD9164 SPI and JESD Bring-Up
1. Run the firmware.
2. Observe the UART console output.
3. Confirm the firmware reads the AD9164 chip ID successfully.
4. Confirm the firmware reports JESD link alignment.

Expected firmware milestones:
- AD9164 chip ID read
- AD9164 JESD link enabled
- JESD status aligned
- Chirp burst armed

Pass criteria:
- No SPI communication failure
- No JESD timeout from `ad9164_wait_for_link()`

If this stage fails, debug in this order:
1. SPI wiring and chip selects
2. Reset and enable GPIO polarity
3. JESD reference clock and SYSREF
4. XDC FMC lane pin mapping

## Stage 7: ILA Validation
1. Open Vivado Hardware Manager.
2. Connect to the FPGA.
3. Load the `.ltx` file generated by `system_ila.tcl`.
4. Trigger the ILA while the firmware is running.
5. Inspect the following signals:
- `ila_sync`
- `ila_sysref`
- `ila_chirp_marker`
- `ila_chirp_tvalid`
- `ila_chirp_tdata`

Pass criteria:
- `ila_sysref` is present and stable
- `ila_sync` behaves as expected for link establishment
- `ila_chirp_tvalid` asserts
- `ila_chirp_tdata` changes during chirp transmission
- `ila_chirp_marker` pulses at burst start

## Stage 8: RF Measurement
1. Connect AD9164 RF output to the oscilloscope input.
2. Connect `scope_trig` to the oscilloscope external trigger input.
3. Trigger on the rising edge of `scope_trig`.
4. Capture the waveform.
5. Use STFT or spectrogram mode on the oscilloscope.
6. Compare the measured sweep to the MATLAB reference.

Compare against:
- Chirp start frequency
- Chirp stop frequency
- Sweep direction
- Sweep linearity
- Burst duration

Pass criteria:
- Sweep shape matches the MATLAB reference closely
- Trigger is stable
- RF burst timing matches the marker pulse

## Stage 9: Record Results
1. Open `verification_report.md`.
2. Fill in:
- UART idle voltage
- JESD status register values
- Observed chirp frequencies
- Burst length
- Notes about mismatches or anomalies

## Recommended Debug Order If Something Fails
1. XDC pin assignments
2. 1.8 V bank selection for UART and trigger pins
3. FMC connector seating and cabling
4. SPI communication with AD9164
5. DAC reset and enable GPIOs
6. JESD reference clock and SYSREF
7. JESD lane mapping
8. Chirp AXI-Stream generation
9. RF output path

## Minimum Pass Checklist
- [ ] XDC updated with real package pins
- [ ] MATLAB chirp reference generated
- [ ] Vivado bitstream generated
- [ ] `.xsa` exported
- [ ] Vitis ELF built
- [ ] UART idle confirmed at 1.8 V
- [ ] AD9164 chip ID read succeeds
- [ ] JESD link aligns
- [ ] ILA shows chirp data activity
- [ ] Scope shows expected chirp sweep
