import serial
import time

def in_ra_nhi_phan(tieu_de, du_lieu_bytes):
    chuoi_nhi_phan = ' '.join(format(b, '08b') for b in du_lieu_bytes)
    print(f"{tieu_de}: {chuoi_nhi_phan}")

def main():
    COM_PORT = 'COM5'  
    BAUD_RATE = 115200

    try:
        ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=0.5)
        print(f"[*] Đã kết nối MẠCH TPC tại {COM_PORT}.")
        print("[*] exit\n")

        while True:

            du_lieu_nhap = input("\nNhập Lệnh: ").strip()
            
            if du_lieu_nhap.lower() == 'exit':
                break
            if not du_lieu_nhap:
                continue

            try:
                chuoi_byte_gui = bytes.fromhex(du_lieu_nhap)
            except ValueError:
                print("[LỖI]")
                continue

            # 2. IN RA NHỊ PHÂN TRƯỚC KHI GỬI
            print("-" * 60)
            in_ra_nhi_phan("[TX - GỬI ĐI]", chuoi_byte_gui)
            
            # Gửi xuống FPGA
            ser.write(chuoi_byte_gui)

            # Chờ FPGA xử lý
            time.sleep(0.1) 

            # 3. ĐỌC KẾT QUẢ VÀ IN RA NHỊ PHÂN
            so_byte_nhan_duoc = ser.in_waiting
            if so_byte_nhan_duoc > 0:
                phan_hoi = ser.read(so_byte_nhan_duoc)
                in_ra_nhi_phan("[RX - NHẬN VỀ]", phan_hoi)
            else:
                print("[RX - NHẬN VỀ]:")
            print("-" * 60)

    except Exception as e:
        print(f"Lỗi: {e}")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("[*] Đã đóng cổng COM.")

if __name__ == "__main__":
    main()