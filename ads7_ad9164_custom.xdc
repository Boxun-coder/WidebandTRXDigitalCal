# ADS7-V2EBZ + AD9164-FMCC-EBZ custom constraint scaffold
#
# Notes:
# 1. The FMC logical signal assignment is aligned with Analog Devices' AD916x FMC
#    reference design:
#      fmc_refclk_p/n  -> FMC_GBTCLK0_M2C_C_P/N
#      fmc_sync_p/n    -> FMC_LA00_CC_P/N  (DAC SYNC~ back to FPGA)
#      fmc_sysref_p/n  -> FMC_LA01_CC_P/N  (SYSREF from clocking tree)
#      fmc_tx_p/n[i]   -> FMC_DP<i>_C2M_P/N for i = 0..7
#      SPI and DAC GPIO -> FMC_LA03/04/05/07/09
# 2. The official ADS7 board archive was used to confirm the FMC net names, but
#    the exact XC7VX330T package-pin cross-reference still needs a final check
#    against `ads7-v2ebz_13052c_brd.brd` before implementation on hardware.
# 3. UART and scope trigger pins are intentionally constrained to 1.8 V only.

## JESD204B reference clock and control pairs
# set_property PACKAGE_PIN <ADS7_FMC_GBTCLK0_M2C_C_P> [get_ports fmc_refclk_p]
# set_property PACKAGE_PIN <ADS7_FMC_GBTCLK0_M2C_C_N> [get_ports fmc_refclk_n]
create_clock -name fmc_refclk -period 3.200 [get_ports fmc_refclk_p]

# set_property PACKAGE_PIN <ADS7_FMC_LA00_CC_P> [get_ports fmc_sync_p]
# set_property PACKAGE_PIN <ADS7_FMC_LA00_CC_N> [get_ports fmc_sync_n]
# set_property PACKAGE_PIN <ADS7_FMC_LA01_CC_P> [get_ports fmc_sysref_p]
# set_property PACKAGE_PIN <ADS7_FMC_LA01_CC_N> [get_ports fmc_sysref_n]
set_property IOSTANDARD LVDS [get_ports {fmc_sync_p fmc_sync_n fmc_sysref_p fmc_sysref_n}]
set_property DIFF_TERM TRUE [get_ports {fmc_sync_p fmc_sync_n fmc_sysref_p fmc_sysref_n}]

## JESD204B transmit lanes to the FMC connector
# set_property PACKAGE_PIN <ADS7_FMC_DP0_C2M_P> [get_ports {fmc_tx_p[0]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP0_C2M_N> [get_ports {fmc_tx_n[0]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP1_C2M_P> [get_ports {fmc_tx_p[1]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP1_C2M_N> [get_ports {fmc_tx_n[1]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP2_C2M_P> [get_ports {fmc_tx_p[2]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP2_C2M_N> [get_ports {fmc_tx_n[2]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP3_C2M_P> [get_ports {fmc_tx_p[3]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP3_C2M_N> [get_ports {fmc_tx_n[3]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP4_C2M_P> [get_ports {fmc_tx_p[4]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP4_C2M_N> [get_ports {fmc_tx_n[4]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP5_C2M_P> [get_ports {fmc_tx_p[5]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP5_C2M_N> [get_ports {fmc_tx_n[5]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP6_C2M_P> [get_ports {fmc_tx_p[6]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP6_C2M_N> [get_ports {fmc_tx_n[6]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP7_C2M_P> [get_ports {fmc_tx_p[7]}]
# set_property PACKAGE_PIN <ADS7_FMC_DP7_C2M_N> [get_ports {fmc_tx_n[7]}]

## DAC-side SPI and enable/reset controls on FMC LA pins
# Expected logical connector map:
#   fmc_spi_sclk     -> FMC_LA03_P
#   fmc_spi_mosi     -> FMC_LA03_N
#   fmc_spi_miso     -> FMC_LA04_P
#   fmc_spi_csn_dac  -> FMC_LA04_N
#   fmc_spi_csn_clk  -> FMC_LA05_P
#   fmc_spi_csn_pll  -> FMC_LA05_N
#   fmc_spi_en       -> FMC_LA09_P
#   fmc_txen0        -> FMC_LA07_P
#   fmc_hmc849_vctrl -> FMC_LA09_N
set_property IOSTANDARD LVCMOS18 [get_ports {
    fmc_spi_sclk
    fmc_spi_mosi
    fmc_spi_miso
    fmc_spi_csn_dac
    fmc_spi_csn_clk
    fmc_spi_csn_pll
    fmc_spi_en
    fmc_dac_reset_n
    fmc_txen0
    fmc_hmc849_vctrl
}]

## Candidate 1.8 V GPIO bank for user-controlled UART/trigger breakout.
## Replace the PACKAGE_PIN values below with the actual accessible ADS7 header pins
## you intend to wire into the external USART and oscilloscope trigger input.
# set_property PACKAGE_PIN <ADS7_UART_TX_PIN> [get_ports uart_ext_txd]
# set_property PACKAGE_PIN <ADS7_UART_RX_PIN> [get_ports uart_ext_rxd]
# set_property PACKAGE_PIN <ADS7_SCOPE_TRIG_PIN> [get_ports scope_trig]
set_property IOSTANDARD LVCMOS18 [get_ports {uart_ext_txd uart_ext_rxd scope_trig}]
set_property SLEW FAST [get_ports {uart_ext_txd scope_trig}]
set_property DRIVE 8 [get_ports {uart_ext_txd scope_trig}]

## Keep system clock unconstrained here because the ADS7 carrier source for the
## MicroBlaze fabric clock depends on the user-selected oscillator/header route.
## Constrain `sys_clk` once that source is finalized.
