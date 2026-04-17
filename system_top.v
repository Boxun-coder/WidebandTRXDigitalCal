`timescale 1ns / 1ps

module system_top (
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        fmc_refclk_p,
    input  wire        fmc_refclk_n,
    input  wire        fmc_sysref_p,
    input  wire        fmc_sysref_n,
    input  wire        fmc_sync_p,
    input  wire        fmc_sync_n,
    output wire [7:0]  fmc_tx_p,
    output wire [7:0]  fmc_tx_n,
    output wire        fmc_spi_sclk,
    output wire        fmc_spi_mosi,
    input  wire        fmc_spi_miso,
    output wire        fmc_spi_csn_dac,
    output wire        fmc_spi_csn_clk,
    output wire        fmc_spi_csn_pll,
    output wire        fmc_spi_en,
    output wire        fmc_dac_reset_n,
    output wire        fmc_txen0,
    output wire        fmc_hmc849_vctrl,
    output wire        uart_ext_txd,
    input  wire        uart_ext_rxd,
    output wire        scope_trig
);

    wire        jesd_refclk;
    wire        jesd_sysref;
    wire        jesd_sync;
    wire [15:0] dbg_chirp_tdata;
    wire        dbg_chirp_tvalid;
    wire        dbg_chirp_marker;

    (* mark_debug = "true" *) wire [15:0] ila_chirp_tdata  = dbg_chirp_tdata;
    (* mark_debug = "true" *) wire        ila_chirp_tvalid = dbg_chirp_tvalid;
    (* mark_debug = "true" *) wire        ila_chirp_marker = dbg_chirp_marker;
    (* mark_debug = "true" *) wire        ila_sync         = jesd_sync;
    (* mark_debug = "true" *) wire        ila_sysref       = jesd_sysref;

    IBUFDS_GTE2 i_fmc_refclk_ibufds (
        .CEB   (1'b0),
        .I     (fmc_refclk_p),
        .IB    (fmc_refclk_n),
        .O     (jesd_refclk),
        .ODIV2 ()
    );

    IBUFDS i_fmc_sysref_ibufds (
        .I  (fmc_sysref_p),
        .IB (fmc_sysref_n),
        .O  (jesd_sysref)
    );

    IBUFDS i_fmc_sync_ibufds (
        .I  (fmc_sync_p),
        .IB (fmc_sync_n),
        .O  (jesd_sync)
    );

    ads7_ad9164_bd_wrapper i_ads7_ad9164_bd (
        .sys_clk          (sys_clk),
        .sys_rst_n        (sys_rst_n),
        .jesd_refclk      (jesd_refclk),
        .jesd_sysref      (jesd_sysref),
        .jesd_sync        (jesd_sync),
        .jesd_tx_p        (fmc_tx_p),
        .jesd_tx_n        (fmc_tx_n),
        .fmc_spi_sclk     (fmc_spi_sclk),
        .fmc_spi_mosi     (fmc_spi_mosi),
        .fmc_spi_miso     (fmc_spi_miso),
        .fmc_spi_csn_dac  (fmc_spi_csn_dac),
        .fmc_spi_csn_clk  (fmc_spi_csn_clk),
        .fmc_spi_csn_pll  (fmc_spi_csn_pll),
        .fmc_spi_en       (fmc_spi_en),
        .fmc_dac_reset_n  (fmc_dac_reset_n),
        .fmc_txen0        (fmc_txen0),
        .fmc_hmc849_vctrl (fmc_hmc849_vctrl),
        .uart_ext_txd     (uart_ext_txd),
        .uart_ext_rxd     (uart_ext_rxd),
        .scope_trig       (scope_trig),
        .dbg_chirp_tdata  (dbg_chirp_tdata),
        .dbg_chirp_tvalid (dbg_chirp_tvalid),
        .dbg_chirp_marker (dbg_chirp_marker)
    );

endmodule
