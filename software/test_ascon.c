#include <stdint.h>
#include <stddef.h>
#include "libsteel.h" // Chứa định nghĩa GPIO, UART, v.v.


// ============================================================================
// 1. CẤU HÌNH GPIO CHO DEBUG
// ============================================================================
// Quy ước:
// - GPIO[7:0]: Chứa 1 byte dữ liệu (Data bus)
// - GPIO[31]:  Tín hiệu báo Valid (Strobe) - Active High

// Hàm gửi 1 byte qua GPIO song song sử dụng thư viện libsteel
void gpio_send_byte(uint8_t data) {
    uint32_t val = (uint32_t)data;

    // Bước 1: Ghi dữ liệu ra GPIO[7:0], đảm bảo Strobe (bit 31) = 0
    // Sử dụng gpio_write_group để ghi thẳng vào thanh ghi OUT
    gpio_write_group(RVSTEEL_GPIO, val);

    // Bước 2: Kéo Strobe (bit 31) lên 1 để báo hiệu cho Testbench
    // Testbench sẽ bắt dữ liệu tại cạnh lên của bit 31
    gpio_write_group(RVSTEEL_GPIO, val | 0x80000000U);

    // Bước 3: Kéo Strobe về 0
    gpio_write_group(RVSTEEL_GPIO, val);
}

// ============================================================================
// 2. IMPLEMENTATION CỦA HÀM DEBUG LOG
// ============================================================================
// Hàm này được ascon_driver.h gọi (vì đã khai báo extern)
void debug_log(uint8_t id, uint64_t data) {
    // 1. Gửi ID Giai đoạn (A0, B0, C0...)
    gpio_send_byte(id); 

    // 2. Gửi 8 byte dữ liệu (Big Endian: Byte cao gửi trước)
    for (int i = 0; i < 8; i++) {
        gpio_send_byte((uint8_t)(data >> (56 - 8 * i)));
    }
    
    // 3. Gửi Marker kết thúc dòng (0xEE)
    gpio_send_byte(0xEE); 
}

// ============================================================================
// 3. MAIN PROGRAM
// ============================================================================
int main(void) {
    // --- 1. SETUP GPIO ---
    // Cấu hình GPIO[7:0] và GPIO[31] là OUTPUT
    // Bit mask: 0x800000FF (Bit 31 và Bits 7-0 là 1)
    gpio_set_output_group(RVSTEEL_GPIO, 0x800000FF);
    
    gpio_write_group(RVSTEEL_GPIO, 0);

    // --- 2. DATA ---
    uint8_t key[16]   = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
    uint8_t nonce[16] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
    uint8_t ad[10]    = {0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA};
    uint8_t pt[10]    = {0xAA,0xBB,0xCC,0xDD,0xEE,0xFF,0x00,0x11,0x22,0x33};
    
    uint8_t ct[8];   
    uint8_t tag[16];

    // --- 3. START TEST ---
    debug_log(0x00, 0x1111111111111111); // START MARKER

    // A. Init Hardware
    ascon_hw_init(key, nonce);

    // B. Process Associated Data
    ascon_hw_process_ad(ad, sizeof(ad));
    
    debug_log(0x0F, 0xFFFFFFFFFFFFFFFF); 

    // C. Encrypt Plaintext
    ascon_hw_encrypt(pt, sizeof(pt), ct, tag);

    debug_log(0xEE, 0xEEEEEEEEEEEEEEEE); // END MARKER
    while(1);
    
    return 0;
}