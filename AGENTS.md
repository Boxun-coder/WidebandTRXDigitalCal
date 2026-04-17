# EXECUTION MANDATE: AD9164-FMCC-EBZ & ADS7-V2EBZ Custom Integration

## 1. Operational Overview
**Objective:** Bypass default ADI evaluation software to achieve fully customized control of the AD9164-FMCC-EBZ high-speed DAC via the ADS7-V2EBZ evaluation board (Virtex-7). Simultaneously generate a customized chirp waveform and drive an external on-chip USART utilizing a strict 1.8V logic level.

**Core Toolchain:** Xilinx Vivado, Xilinx Vitis, and MATLAB HDL Coder.

---

## 2. Agent Roles & Task Assignments

### **Agent-Alpha: System & FPGA Architect**
**Focus:** Infrastructure, Datapath, and Constraints.
* **Task 1:** Instantiate a MicroBlaze soft processor for system control.
* **Task 2:** Configure and integrate the Xilinx JESD204B PHY and TX IP cores targeting the FMC interface.
* **Task 3:** Instantiate an AXI UART Lite IP block for the USART communication.
* **Task 4:** Write the XDC constraints file (`ads7_ad9164_custom.xdc`). Pin assignments must map high-speed transceivers to the FMC connector, and the AXI UART TX/RX pins must be explicitly constrained with `IOSTANDARD LVCMOS18` to guarantee the 1.8V requirement.
* **Output:** `build_project.tcl`, `ads7_ad9164_custom.xdc`

### **Agent-Beta: DSP & Logic Designer**
**Focus:** Chirp Waveform Generation.
* **Task 1:** Utilize MATLAB to design the chirp waveform generator (Numerically Controlled Oscillator or LUT-based sweep).
* **Task 2:** Leverage MATLAB HDL Coder to generate synthesizable, optimized Verilog RTL from the algorithm.
* **Task 3:** Wrap the generated HDL in an AXI-Stream interface and simulate baseband performance.
* **Output:** `chirp_gen.m`, `chirp_axi_stream_ip.zip`

### **Agent-Gamma: Embedded Firmware Engineer**
**Focus:** AD9164 Initialization and Hardware Coordination.
* **Task 1:** Develop bare-metal C code (`main.c`) for the MicroBlaze processor.
* **Task 2:** Implement the SPI initialization sequence for the AD9164 (Power-up, PLL lock, JESD204B CGS/ILAS link establishment, crossbar routing).
* **Task 3:** Write the control routines to trigger the AXI-Stream chirp generator and send data payloads via the AXI UART Lite simultaneously.
* **Output:** `main.c`, `spi_ad9164_drivers.h`

### **Agent-Delta: Verification & Bring-Up Engineer**
**Focus:** Debugging, Link Verification, and RF Validation.
* **Task 1:** Generate a TCL script (`system_ila.tcl`) to insert Integrated Logic Analyzers (ILAs) on the JESD204B link status signals and AXI-Stream chirp data.
* **Task 2:** Verify 1.8V logic levels on the physical GPIO pins prior to external USART connection.
* **Task 3:** Execute the RF verification plan using a high-speed real-time oscilloscope.
* **Output:** `system_ila.tcl`, `verification_report.md`

---

## 3. Step-by-Step Execution Protocol

1.  **Phase 1: Component Generation (Parallel Execution)**
    * *Agent-Beta* completes MATLAB HDL generation.
    * *Agent-Alpha* drafts the XDC file and TCL build scripts.
    * *Agent-Gamma* drafts the C firmware for SPI and UART.
2.  **Phase 2: System Integration (Sequential Execution)**
    * *Agent-Alpha* imports *Agent-Beta's* IP into the Vivado block design and links it to the JESD204B TX core.
    * *Agent-Alpha* runs synthesis, implementation, and bitstream generation.
    * *Agent-Alpha* exports the `.xsa` hardware handoff file.
3.  **Phase 3: Software Compilation**
    * *Agent-Gamma* imports the `.xsa` into Vitis, applies the `main.c` firmware, and compiles the `.elf` executable.
4.  **Phase 4: Hardware Bring-up & Validation**
    * *Agent-Delta* flashes the FPGA and initiates the ILA debug probes.

---

## 4. Hardware Verification Plan (Agent-Delta)

### **Stage 1: Pre-Connection Safety & Digital Check**
* [ ] Boot system and halt before AD9164 SPI initialization.
* [ ] Probe UART TX/RX pins with a multimeter/logic probe. **Verify idle state is strictly 1.8V.**
* [ ] Verify Vivado ILA shows `SYNC~` assertion (JESD204B link established).
* [ ] Verify Vivado ILA shows valid AXI-Stream data moving from the chirp IP to the JESD core.

### **Stage 2: Analog/RF Verification (Oscilloscope)**
* [ ] Connect AD9164-FMCC-EBZ RF output to a high-bandwidth oscilloscope.
* [ ] Route an external trigger signal from the ADS7 GPIO to the Oscilloscope `EXT TRIG`.
* [ ] Configure oscilloscope to trigger on the rising edge of the marker.
* [ ] Capture the time-domain waveform.
* [ ] **Validation Criteria:** Apply a Short-Time Fourier Transform (STFT) / Spectrogram math function on the oscilloscope. Confirm the frequency sweeps linearly across the target bandwidth matching the MATLAB HDL simulation.
