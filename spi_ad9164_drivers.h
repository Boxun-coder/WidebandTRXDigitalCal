#ifndef SPI_AD9164_DRIVERS_H
#define SPI_AD9164_DRIVERS_H

#include "xil_printf.h"
#include "xspi.h"

#define AD9164_SPI_SS_MASK                0x01U

#define AD9164_REG_SPI_INTFCONFA          0x0000U
#define AD9164_REG_SPI_INTFCONFB          0x0001U
#define AD9164_REG_CHIP_ID_HIGH           0x0003U
#define AD9164_REG_CHIP_ID_LOW            0x0004U
#define AD9164_REG_POWERDOWN              0x0010U
#define AD9164_REG_SCRATCHPAD             0x000AU

#define AD9164_REG_ILS_DID                0x0450U
#define AD9164_REG_ILS_BID                0x0451U
#define AD9164_REG_ILS_LID0               0x0452U
#define AD9164_REG_ILS_SCR_L              0x0453U
#define AD9164_REG_ILS_F                  0x0454U
#define AD9164_REG_ILS_K                  0x0455U
#define AD9164_REG_ILS_M                  0x0456U
#define AD9164_REG_ILS_CS_N               0x0457U
#define AD9164_REG_ILS_SUBCLASS_NP        0x0458U
#define AD9164_REG_ILS_JESDV_S            0x0459U
#define AD9164_REG_ILS_HD_CF              0x045AU
#define AD9164_REG_ILS_CHECKSUM           0x045DU

#define AD9164_REG_ILS_F_CHECK            0x0476U
#define AD9164_REG_LINK_ENABLE            0x047DU
#define AD9164_REG_LINK_CONTROL           0x0475U
#define AD9164_REG_PHYSICAL_MODE          0x0314U
#define AD9164_REG_SYNC_CTRL              0x003AU

#define AD9164_REG_XBAR_LANE_0_1          0x0308U
#define AD9164_REG_XBAR_LANE_2_3          0x0309U
#define AD9164_REG_XBAR_LANE_4_5          0x030AU
#define AD9164_REG_XBAR_LANE_6_7          0x030BU

#define AD9164_REG_CGS_STATUS             0x0470U
#define AD9164_REG_FRAME_STATUS           0x0471U
#define AD9164_REG_CHECKSUM_STATUS        0x0472U
#define AD9164_REG_ILAS_STATUS            0x0473U

#define AD9164_CHIP_ID_HIGH_EXPECTED      0x91U
#define AD9164_CHIP_ID_LOW_EXPECTED       0x64U

#define AD9164_RETURN_ON_ERROR(expr) \
    do { \
        int _status = (expr); \
        if (_status != XST_SUCCESS) { \
            return _status; \
        } \
    } while (0)

typedef struct {
    u16 reg;
    u8  value;
} ad9164_reg_write_t;

typedef struct {
    u8 did;
    u8 bid;
    u8 l;
    u8 f;
    u8 k;
    u8 m;
    u8 n;
    u8 np;
    u8 s;
    u8 cs;
    u8 subclassv;
    u8 jesdv;
    u8 scrambling;
    u8 hd;
    u8 cf;
} ad9164_jesd_config_t;

static inline int ad9164_spi_xfer(XSpi *spi, u8 *buf, unsigned byte_count)
{
    int status;

    XSpi_SetSlaveSelect(spi, AD9164_SPI_SS_MASK);
    status = XSpi_Transfer(spi, buf, buf, byte_count);
    return status;
}

static inline int ad9164_write_reg(XSpi *spi, u16 reg_addr, u8 reg_data)
{
    u8 buf[3];

    buf[0] = (u8)((reg_addr >> 8) & 0x7FU);
    buf[1] = (u8)(reg_addr & 0xFFU);
    buf[2] = reg_data;
    return ad9164_spi_xfer(spi, buf, sizeof(buf));
}

static inline int ad9164_read_reg(XSpi *spi, u16 reg_addr, u8 *reg_data)
{
    u8 buf[3];
    int status;

    buf[0] = (u8)(0x80U | ((reg_addr >> 8) & 0x7FU));
    buf[1] = (u8)(reg_addr & 0xFFU);
    buf[2] = 0x00U;

    status = ad9164_spi_xfer(spi, buf, sizeof(buf));
    if (status == XST_SUCCESS) {
        *reg_data = buf[2];
    }
    return status;
}

static inline u8 ad9164_compute_jesd_checksum(const ad9164_jesd_config_t *cfg)
{
    u16 sum = 0U;

    sum += cfg->did;
    sum += cfg->bid;
    sum += 0U;
    sum += cfg->scrambling ? 1U : 0U;
    sum += (u16)(cfg->l  - 1U);
    sum += (u16)(cfg->f  - 1U);
    sum += (u16)(cfg->k  - 1U);
    sum += (u16)(cfg->m  - 1U);
    sum += (u16)(cfg->n  - 1U);
    sum += cfg->cs;
    sum += (u16)(cfg->np - 1U);
    sum += cfg->subclassv;
    sum += cfg->jesdv;
    sum += (u16)(cfg->s  - 1U);
    sum += cfg->hd ? 1U : 0U;
    sum += cfg->cf;
    return (u8)(sum & 0xFFU);
}

static inline int ad9164_soft_reset(XSpi *spi)
{
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_SPI_INTFCONFA, 0x18U));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_POWERDOWN, 0x00U));
    return XST_SUCCESS;
}

static inline int ad9164_check_chip_id(XSpi *spi)
{
    u8 id_high = 0U;
    u8 id_low  = 0U;

    AD9164_RETURN_ON_ERROR(ad9164_read_reg(spi, AD9164_REG_CHIP_ID_HIGH, &id_high));
    AD9164_RETURN_ON_ERROR(ad9164_read_reg(spi, AD9164_REG_CHIP_ID_LOW,  &id_low));

    xil_printf("AD9164 chip ID = 0x%02X%02X\r\n", id_high, id_low);
    if (id_high != AD9164_CHIP_ID_HIGH_EXPECTED || id_low != AD9164_CHIP_ID_LOW_EXPECTED) {
        xil_printf("Unexpected AD9164 chip ID.\r\n");
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

static inline int ad9164_enable_spi_txen(XSpi *spi)
{
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_LINK_CONTROL, 0x09U));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_PHYSICAL_MODE, 0x01U));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_SYNC_CTRL,     0x01U));
    return XST_SUCCESS;
}

static inline int ad9164_configure_datapath(XSpi *spi, const ad9164_jesd_config_t *cfg)
{
    const u8 checksum = ad9164_compute_jesd_checksum(cfg);

    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_DID,         cfg->did));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_BID,         cfg->bid));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_LID0,        0x00U));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_SCR_L,
                                            (u8)((cfg->scrambling ? 0x80U : 0x00U) | (cfg->l - 1U))));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_F,           (u8)(cfg->f - 1U)));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_K,           (u8)(cfg->k - 1U)));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_M,           (u8)(cfg->m - 1U)));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_CS_N,
                                            (u8)(((cfg->cs & 0x3U) << 6) | (cfg->n - 1U))));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_SUBCLASS_NP,
                                            (u8)(((cfg->subclassv & 0x7U) << 5) | (cfg->np - 1U))));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_JESDV_S,
                                            (u8)(((cfg->jesdv & 0x7U) << 5) | (cfg->s - 1U))));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_HD_CF,
                                            (u8)((cfg->hd ? 0x80U : 0x00U) | (cfg->cf & 0x1FU))));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_CHECKSUM,    checksum));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_ILS_F_CHECK,     cfg->f));
    return XST_SUCCESS;
}

static inline int ad9164_apply_lane_map(XSpi *spi, const ad9164_reg_write_t *entries, unsigned count)
{
    unsigned i;
    for (i = 0U; i < count; ++i) {
        AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, entries[i].reg, entries[i].value));
    }
    return XST_SUCCESS;
}

static inline int ad9164_enable_link(XSpi *spi)
{
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_LINK_ENABLE, 0xFFU));
    AD9164_RETURN_ON_ERROR(ad9164_write_reg(spi, AD9164_REG_LINK_CONTROL, 0x01U));
    return XST_SUCCESS;
}

static inline int ad9164_wait_for_link(XSpi *spi, u32 timeout_ms)
{
    u8 cgs = 0U;
    u8 frame = 0U;
    u8 checksum = 0U;
    u32 wait_ms;

    for (wait_ms = 0U; wait_ms < timeout_ms; ++wait_ms) {
        AD9164_RETURN_ON_ERROR(ad9164_read_reg(spi, AD9164_REG_CGS_STATUS, &cgs));
        AD9164_RETURN_ON_ERROR(ad9164_read_reg(spi, AD9164_REG_FRAME_STATUS, &frame));
        AD9164_RETURN_ON_ERROR(ad9164_read_reg(spi, AD9164_REG_CHECKSUM_STATUS, &checksum));

        if (cgs == 0xFFU && frame == 0xFFU && checksum == 0xFFU) {
            xil_printf("JESD link aligned: CGS=0x%02X FRAME=0x%02X CHKSUM=0x%02X\r\n",
                       cgs, frame, checksum);
            return XST_SUCCESS;
        }

        usleep(1000U);
    }

    xil_printf("Timed out waiting for JESD link: CGS=0x%02X FRAME=0x%02X CHKSUM=0x%02X\r\n",
               cgs, frame, checksum);
    return XST_FAILURE;
}

static inline int ad9164_link_alarm_pending(XSpi *spi)
{
    u8 ilas = 0U;
    if (ad9164_read_reg(spi, AD9164_REG_ILAS_STATUS, &ilas) != XST_SUCCESS) {
        return 1;
    }
    return (ilas != 0xFFU);
}

#endif
