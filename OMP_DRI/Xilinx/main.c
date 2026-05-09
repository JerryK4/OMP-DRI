#include <stdio.h>
#include <stdlib.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "sleep.h"
#include "xtime_l.h"
#include "omp_test_data.h"

#define OMP_BASE        0x43C00000
#define DMA_YX_ID       XPAR_AXIDMA_0_DEVICE_ID
#define DMA_PHI_ID      XPAR_AXIDMA_1_DEVICE_ID

#define R_CTRL          0x00
#define R_N_COLS        0x04
#define R_M_ROWS        0x08
#define R_K             0x0C

u32 N_CFG[3] = {15, 63, 255};
u32 M_CFG[3] = {1, 3, 15};
u32 K_CFG[3] = {4, 6, 16};

u32 x_results[16] __attribute__((aligned(32)));
XAxiDma dma_yx, dma_phi;

// Hàm tính thời gian ra Micro giây (us)
double get_time_us(XTime start, XTime end) {
    return (double)(end - start) * 1000000.0 / (double)COUNTS_PER_SECOND;
}

void print_float_custom(u32 hex_val) {
    int s_val = (hex_val & 0x800000) ? (hex_val | 0xFF000000) : hex_val;
    float f = (float)s_val / 8192.0f;
    int ip = (int)f;
    int fp = (int)((((f<0)?-f:f) - (float)abs(ip)) * 1000000.0f);
    if (f < 0 && ip == 0) xil_printf("-%d.%06d", ip, fp);
    else xil_printf("%d.%06d", ip, fp);
}

int main() {
	XTime tStart, tEnd;
    double stage_time_us;
    double total_time_us = 0;

    xil_printf("\r\n===================================================\r\n");
    xil_printf("   OMP-DRI HARDWARE ACCELERATION (ZYNQ-7000)   \r\n");
    xil_printf("===================================================\r\n");

    XAxiDma_Config *c;
    c = XAxiDma_LookupConfig(DMA_YX_ID);  XAxiDma_CfgInitialize(&dma_yx, c);
    c = XAxiDma_LookupConfig(DMA_PHI_ID); XAxiDma_CfgInitialize(&dma_phi, c);

    // 1. NẠP TOÀN BỘ MA TRẬN PHI VÀ Y (1 LẦN DUY NHẤT)
    xil_printf("[*] Dang nap toan bo Ma tran Phi (16384) va Y (64)...\r\n");
    Xil_Out32(OMP_BASE + R_CTRL, 0x02);

    Xil_DCacheFlushRange((UINTPTR)phi_data, 16384 * 4);
    XAxiDma_SimpleTransfer(&dma_phi, (UINTPTR)phi_data, 16384 * 4, XAXIDMA_DMA_TO_DEVICE);
    while(XAxiDma_Busy(&dma_phi, XAXIDMA_DMA_TO_DEVICE));

    Xil_DCacheFlushRange((UINTPTR)y_data, 64 * 4);
    XAxiDma_SimpleTransfer(&dma_yx, (UINTPTR)y_data, 64 * 4, XAXIDMA_DMA_TO_DEVICE);
    while(XAxiDma_Busy(&dma_yx, XAXIDMA_DMA_TO_DEVICE));
    xil_printf("[+] Nap BRAM thanh cong!\r\n");

    // 2. VÒNG LẶP DRI
    for(int s = 0; s < 3; s++) {
        int res_size = (s==0)?4:( (s==1)?8:16 );
        xil_printf("\r\n--- CHAY STAGE %d: Anh %dx%d (K=%d) ---\r\n", s+1, res_size, res_size, K_CFG[s]);

        // ==============================================================
        // DỘI SẠCH FIFO CỦA DMA TRƯỚC MỖI STAGE
        // Lệnh này ép DMA xóa mọi số 0 thừa mứa đọng lại từ Stage trước
        // ==============================================================
        XAxiDma_Reset(&dma_yx);
        while(!XAxiDma_ResetIsDone(&dma_yx));
        // ==============================================================

        // Ghi tham số
        Xil_Out32(OMP_BASE + R_N_COLS, N_CFG[s]);
        Xil_Out32(OMP_BASE + R_M_ROWS, M_CFG[s]);
        Xil_Out32(OMP_BASE + R_K, K_CFG[s]);

        // Chuẩn bị nhận kết quả X qua DMA RX
        Xil_DCacheInvalidateRange((UINTPTR)x_results, K_CFG[s] * 4);
        XAxiDma_SimpleTransfer(&dma_yx, (UINTPTR)x_results, K_CFG[s] * 4, XAXIDMA_DEVICE_TO_DMA);

		// ========================================================
        // BẮT ĐẦU ĐO THỜI GIAN (us)
        // ========================================================
        XTime_GetTime(&tStart);

        // Kích hoạt lõi OMP
        Xil_Out32(OMP_BASE + R_CTRL, 0x01);

        // Đợi DMA nhận xong
        int timeout = 20000000;
        while(XAxiDma_Busy(&dma_yx, XAXIDMA_DEVICE_TO_DMA) && timeout > 0) { timeout--; }

		XTime_GetTime(&tEnd);
        // ========================================================

        stage_time_us = get_time_us(tStart, tEnd);
        total_time_us += stage_time_us;

        if(timeout == 0) {
            xil_printf(" [!] Loi: Stage %d bi treo!\r\n", s+1);
        } else {
            Xil_DCacheInvalidateRange((UINTPTR)x_results, K_CFG[s] * 4);
			printf(" >> Thoi gian thuc thi: %.2f us\r\n", stage_time_us);
            xil_printf(" >> KET QUA STAGE %d:\r\n", s+1);
            xil_printf(" No | Pixel Index (Lambda) | Cuong do\r\n");
            xil_printf(" ------------------------------------\r\n");

            for(int i = 0; i < K_CFG[s]; i++) {
                u32 raw = x_results[i];
                u32 lambda_val = (raw >> 24) & 0xFF;
                u32 pixel_val  = raw & 0xFFFFFF;

                xil_printf(" %2d |         %3d          | ", i, lambda_val);
                print_float_custom(pixel_val);
                xil_printf("\r\n");
            }
        }
        usleep(500000);
    }

    xil_printf("\r\n===================================================\r\n");
    xil_printf("             HOAN TAT QUY TRINH DRI\r\n");
	printf(" TONG THOI GIAN THUC THI TOAN THUAT TOAN: %.2f us\r\n", total_time_us);
    xil_printf("===================================================\r\n");

    return 0;
}
