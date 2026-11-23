# Tài liệu ShopNexus

Repository này lưu tài liệu phát triển ShopNexus và các sản phẩm của đồ án tốt nghiệp. Nội dung gồm tài liệu sản phẩm, yêu cầu, kiến trúc, API, vận hành và các báo cáo được biên soạn bằng tiếng Việt.

Website tài liệu có bản tiếng Việt và tiếng Anh. Chạy website bằng Bun:

```bash
cd web
bun install
bun run dev
```

Để tạo bản tĩnh, chạy `bun run build` trong thư mục website. Các báo cáo và slide được biên dịch bằng Typst:

```bash
cd typst
make all
```

Các mã yêu cầu và thông tin truy vết được dùng chung giữa báo cáo và website tài liệu.
