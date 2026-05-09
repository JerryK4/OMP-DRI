#include <stdio.h>
#include <stdlib.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "sleep.h"
#include "xtime_l.h" // Thư viện đo thời gian

// Gọi file Header 64x64 (Được sinh tự động từ MATLAB chứa Phi và 16 mảng Y)
#include "omp_bcs_data_64x64.h"

#define OMP_BASE        0x43C00000
#define DMA_YX_ID       XPAR_AXIDMA_0_DEVICE_ID
#define DMA_PHI_ID      XPAR_AXIDMA_1_DEVICE_ID

#define R_CTRL          0x00
#define R_N_COLS        0x04
#define R_M_ROWS        0x08
#define R_K             0x0C

u32 x_results[16] __attribute__((aligned(32)));
XAxiDma dma_yx, dma_phi;

// Hàm in số thực với 6 chữ số sau dấu phẩy (Q11.13)
void print_float_custom(u32 hex_val) {
    int s_val = (hex_val & 0x800000) ? (hex_val | 0xFF000000) : hex_val;
    float f = (float)s_val / 8192.0f;
    int ip = (int)f;
    int fp = (int)((((f<0)?-f:f) - (float)abs(ip)) * 1000000.0f);
    if (f < 0 && ip == 0) xil_printf("-%d.%06d", ip, fp);
    else xil_printf("%d.%06d", ip, fp);
}

int main() {
	XTime tStart, tEnd, tPhiStart, tPhiEnd;
    double total_time_64x64_us = 0;
    double block_time_us,phi_time_us;
    xil_printf("\r\n===========================================\r\n");
    xil_printf("   OMP BCS 64x64 (16 khoi 16x16) TEST      \r\n");
    xil_printf("===========================================\r\n");

    // 1. Khởi tạo DMA
    XAxiDma_Config *c;
    c = XAxiDma_LookupConfig(DMA_YX_ID);  XAxiDma_CfgInitialize(&dma_yx, c);
    c = XAxiDma_LookupConfig(DMA_PHI_ID); XAxiDma_CfgInitialize(&dma_phi, c);

    // 2. Nạp Ma trận Phi 16x16 (Chỉ 1 lần duy nhất cho cả 16 khối)
    xil_printf("[*] Dang nap Ma tran Phi vao hardware...");
    XTime_GetTime(&tPhiStart);
    Xil_DCacheFlushRange((UINTPTR)phi_data, 16384 * 4);
    Xil_Out32(OMP_BASE + R_CTRL, 0x02); // Reset địa chỉ ghi BRAM
    XAxiDma_SimpleTransfer(&dma_phi, (UINTPTR)phi_data, 16384 * 4, XAXIDMA_DMA_TO_DEVICE);
    while(XAxiDma_Busy(&dma_phi, XAXIDMA_DMA_TO_DEVICE));
    XTime_GetTime(&tPhiEnd);
    phi_time_us = (double)(tPhiEnd - tPhiStart) * 1000000.0 / (double)COUNTS_PER_SECOND;
    total_time_64x64_us += phi_time_us;
    xil_printf(" XONG!\r\n");

    // (Mảng con trỏ y_blocks[16] đã được tự động khai báo bên trong file .h)

    // 3. Vòng lặp xử lý 16 khối ảnh (Tiling 64x64)
    for(int s = 0; s < 16; s++) {
        xil_printf("\r\n--- CHAY KHOI %d / 16 ---\r\n", s+1);
		// Bắt đầu đo thời gian cho khối này
        XTime_GetTime(&tStart);

        // A. Ghi tham số cấu hình OMP cho khối 16x16 hiện tại
        Xil_Out32(OMP_BASE + R_CTRL, 0x02);  // Reset địa chỉ nạp Y
        Xil_Out32(OMP_BASE + R_N_COLS, 255); // N = 256 -> 255
        Xil_Out32(OMP_BASE + R_M_ROWS, 15);  // M = 64 -> (64/4)-1 = 15
        Xil_Out32(OMP_BASE + R_K, 16);       // K = 16

        // B. Chuẩn bị kênh DMA để nhận kết quả X (16 pixel)
        Xil_DCacheInvalidateRange((UINTPTR)x_results, 16 * 4);
        XAxiDma_SimpleTransfer(&dma_yx, (UINTPTR)x_results, 16 * 4, XAXIDMA_DEVICE_TO_DMA);

        // C. Bơm lượng dữ liệu Y tương ứng của khối hiện tại (y_blocks[s])
        Xil_DCacheFlushRange((UINTPTR)y_blocks[s], 64 * 4);
        XAxiDma_SimpleTransfer(&dma_yx, (UINTPTR)y_blocks[s], 64 * 4, XAXIDMA_DMA_TO_DEVICE);
        while(XAxiDma_Busy(&dma_yx, XAXIDMA_DMA_TO_DEVICE));

        // D. Kích hoạt OMP
        Xil_Out32(OMP_BASE + R_CTRL, 0x01); // START PULSE

        // E. Đợi kết quả đổ về qua DMA
        int timeout = 10000000;
        while(XAxiDma_Busy(&dma_yx, XAXIDMA_DEVICE_TO_DMA) && timeout > 0) { timeout--; }

		// Kết thúc đo thời gian cho khối này
        XTime_GetTime(&tEnd);
        block_time_us = (double)(tEnd - tStart) * 1000000.0 / (double)COUNTS_PER_SECOND;
        total_time_64x64_us += block_time_us;

        if(timeout == 0) {
            xil_printf(" [!] Loi: Khoi %d bi treo!\r\n", s+1);
            // Giữ nguyên luồng tự nhiên theo cấu trúc thành công của bạn
        } else {
            // F. Đọc dữ liệu và in kết quả
            Xil_DCacheInvalidateRange((UINTPTR)x_results, 16 * 4);
			printf(" >> Thoi gian khoi %d: %.2f us\r\n", s+1, block_time_us);
            xil_printf(" No | Lambda | Cuong do\r\n");
            xil_printf(" ------------------------\r\n");
            for(int i = 0; i < 16; i++) {
                u32 raw = x_results[i];
                u32 idx = (raw >> 24) & 0xFF;
                u32 val = raw & 0xFFFFFF;

                xil_printf(" %2d |  %3d   | ", i, idx);
                print_float_custom(val);
                xil_printf("\r\n");
            }
        }
        usleep(200000); // Nghỉ 0.2s giữa các khối để Terminal kịp in mượt mà
    }

    xil_printf("\r\n===========================================\r\n");
    xil_printf("    HOAN TAT QUY TRINH BCS 64x64       \r\n");
	printf(" TONG THOI GIAN PHUC HOI ANH 64x64: %.2f us\r\n", total_time_64x64_us);
    xil_printf("===========================================\r\n");

    return 0;
}
