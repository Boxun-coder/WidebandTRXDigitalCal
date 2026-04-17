#include "xparameters.h"
#include "xgpio.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xspi.h"
#include "xuartlite_l.h"
#include "sleep.h"

#include "spi_ad9164_drivers.h"

#define DAC_CTRL_DEVICE_ID            XPAR_AXI_GPIO_DAC_CTRL_DEVICE_ID
#define CHIRP_CTRL_DEVICE_ID          XPAR_AXI_GPIO_CHIRP_CTRL_DEVICE_ID
#define CHIRP_NSAMP_DEVICE_ID         XPAR_AXI_GPIO_CHIRP_NSAMP_DEVICE_ID
#define CHIRP_STEP_INIT_DEVICE_ID     XPAR_AXI_GPIO_CHIRP_STEP_INIT_DEVICE_ID
#define CHIRP_STEP_DELTA_DEVICE_ID    XPAR_AXI_GPIO_CHIRP_STEP_DELTA_DEVICE_ID
#define CHIRP_STEP_LIMIT_DEVICE_ID    XPAR_AXI_GPIO_CHIRP_STEP_LIMIT_DEVICE_ID
#define SPI_DEVICE_ID                 XPAR_AXI_QUAD_SPI_0_DEVICE_ID
#define UART_BASEADDR                 XPAR_AXI_UARTLITE_0_BASEADDR

#define DAC_CTRL_CH                   1U
#define CHIRP_CTRL_CH                 1U

#define DAC_CTRL_RESET_N_MASK         (1U << 0)
#define DAC_CTRL_TXEN0_MASK           (1U << 1)
#define DAC_CTRL_HMC849_MASK          (1U << 2)
#define DAC_CTRL_SCOPE_TRIG_MASK      (1U << 3)

#define CHIRP_CTRL_ENABLE_MASK        (1U << 0)
#define CHIRP_CTRL_RESTART_MASK       (1U << 1)
#define CHIRP_CTRL_CONTINUOUS_MASK    (1U << 2)
#define CHIRP_CTRL_MARKER_MASK        (1U << 3)

static XSpi   g_spi;
static XGpio  g_dac_ctrl;
static XGpio  g_chirp_ctrl;
static XGpio  g_chirp_nsamp;
static XGpio  g_chirp_step_init;
static XGpio  g_chirp_step_delta;
static XGpio  g_chirp_step_limit;

static int setup_gpio(XGpio *gpio, u16 device_id)
{
    int status = XGpio_Initialize(gpio, device_id);
    if (status != XST_SUCCESS) {
        return status;
    }

    XGpio_SetDataDirection(gpio, 1U, 0x00000000U);
    return XST_SUCCESS;
}

static int setup_spi(XSpi *spi)
{
    int status = XSpi_Initialize(spi, SPI_DEVICE_ID);
    if (status != XST_SUCCESS) {
        return status;
    }

    status = XSpi_SetOptions(spi, XSP_MASTER_OPTION | XSP_MANUAL_SSELECT_OPTION);
    if (status != XST_SUCCESS) {
        return status;
    }

    XSpi_SetSlaveSelect(spi, AD9164_SPI_SS_MASK);
    XSpi_Start(spi);
    XSpi_IntrGlobalDisable(spi);
    return XST_SUCCESS;
}

static void uart_write_string(const char *text)
{
    while (*text != '\0') {
        XUartLite_SendByte(UART_BASEADDR, (u8)(*text));
        ++text;
    }
}

static void pulse_scope_trigger(void)
{
    u32 gpio_word = XGpio_DiscreteRead(&g_dac_ctrl, DAC_CTRL_CH);
    XGpio_DiscreteWrite(&g_dac_ctrl, DAC_CTRL_CH, gpio_word | DAC_CTRL_SCOPE_TRIG_MASK);
    usleep(10U);
    XGpio_DiscreteWrite(&g_dac_ctrl, DAC_CTRL_CH, gpio_word & ~DAC_CTRL_SCOPE_TRIG_MASK);
}

static int ad9164_bootstrap(void)
{
    ad9164_jesd_config_t jesd_cfg = {
        .did             = 0x00U,
        .bid             = 0x00U,
        .l               = 8U,
        .f               = 1U,
        .k               = 32U,
        .m               = 2U,
        .n               = 16U,
        .np              = 16U,
        .s               = 2U,
        .cs              = 0U,
        .subclassv       = 1U,
        .jesdv           = 1U,
        .scrambling      = 1U,
        .hd              = 1U,
        .cf              = 0U
    };

    static const ad9164_reg_write_t lane_map[] = {
        { AD9164_REG_XBAR_LANE_0_1, 0x08U },
        { AD9164_REG_XBAR_LANE_2_3, 0x1AU },
        { AD9164_REG_XBAR_LANE_4_5, 0x2CU },
        { AD9164_REG_XBAR_LANE_6_7, 0x3EU },
    };

    u32 gpio_word = DAC_CTRL_RESET_N_MASK | DAC_CTRL_TXEN0_MASK | DAC_CTRL_HMC849_MASK;
    XGpio_DiscreteWrite(&g_dac_ctrl, DAC_CTRL_CH, gpio_word);
    usleep(1000U);

    AD9164_RETURN_ON_ERROR(ad9164_soft_reset(&g_spi));
    AD9164_RETURN_ON_ERROR(ad9164_check_chip_id(&g_spi));
    AD9164_RETURN_ON_ERROR(ad9164_enable_spi_txen(&g_spi));
    AD9164_RETURN_ON_ERROR(ad9164_configure_datapath(&g_spi, &jesd_cfg));
    AD9164_RETURN_ON_ERROR(ad9164_apply_lane_map(&g_spi, lane_map, sizeof(lane_map) / sizeof(lane_map[0])));
    AD9164_RETURN_ON_ERROR(ad9164_enable_link(&g_spi));
    AD9164_RETURN_ON_ERROR(ad9164_wait_for_link(&g_spi, 1000U));

    return XST_SUCCESS;
}

static void chirp_program_defaults(void)
{
    XGpio_DiscreteWrite(&g_chirp_nsamp,      1U, 16384U);
    XGpio_DiscreteWrite(&g_chirp_step_init,  1U, 0x02000000U);
    XGpio_DiscreteWrite(&g_chirp_step_delta, 1U, 0x00002000U);
    XGpio_DiscreteWrite(&g_chirp_step_limit, 1U, 0x03F00000U);
}

static void chirp_start_burst(void)
{
    XGpio_DiscreteWrite(&g_chirp_ctrl, CHIRP_CTRL_CH,
                        CHIRP_CTRL_ENABLE_MASK |
                        CHIRP_CTRL_RESTART_MASK |
                        CHIRP_CTRL_MARKER_MASK);
    usleep(10U);
    XGpio_DiscreteWrite(&g_chirp_ctrl, CHIRP_CTRL_CH,
                        CHIRP_CTRL_ENABLE_MASK |
                        CHIRP_CTRL_MARKER_MASK);
}

int main(void)
{
    int status;

    xil_printf("\r\nAD9164 custom chirp bring-up\r\n");

    status = setup_spi(&g_spi);
    if (status != XST_SUCCESS) {
        xil_printf("SPI init failed: %d\r\n", status);
        return status;
    }

    status  = setup_gpio(&g_dac_ctrl, DAC_CTRL_DEVICE_ID);
    status |= setup_gpio(&g_chirp_ctrl, CHIRP_CTRL_DEVICE_ID);
    status |= setup_gpio(&g_chirp_nsamp, CHIRP_NSAMP_DEVICE_ID);
    status |= setup_gpio(&g_chirp_step_init, CHIRP_STEP_INIT_DEVICE_ID);
    status |= setup_gpio(&g_chirp_step_delta, CHIRP_STEP_DELTA_DEVICE_ID);
    status |= setup_gpio(&g_chirp_step_limit, CHIRP_STEP_LIMIT_DEVICE_ID);
    if (status != XST_SUCCESS) {
        xil_printf("GPIO init failed: %d\r\n", status);
        return status;
    }

    chirp_program_defaults();

    status = ad9164_bootstrap();
    if (status != XST_SUCCESS) {
        xil_printf("AD9164 bootstrap failed: %d\r\n", status);
        return status;
    }

    uart_write_string("AD9164 JESD link established; chirp burst armed.\r\n");
    pulse_scope_trigger();
    chirp_start_burst();
    uart_write_string("Chirp burst started.\r\n");

    while (1) {
        if (ad9164_link_alarm_pending(&g_spi)) {
            uart_write_string("Warning: JESD status changed.\r\n");
        }
        usleep(100000U);
    }

    return 0;
}
