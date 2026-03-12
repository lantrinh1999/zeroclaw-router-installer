---
name: deep-research
description: Hướng dẫn nghiên cứu chuyên sâu đa nguồn - tối thiểu 3, tối đa 20 nguồn
version: 1.0.0
---

# Deep Research Protocol

Quy trình nghiên cứu chuyên sâu. Nguyên tắc: **THÀ THỪA CÒN HƠN BỎ SÓT**.

## Quy trình

### 1. Tìm kiếm đa chiều (3-20 lần search)
```
Lần 1: web_search_tool với từ khóa chính (tiếng Việt)
Lần 2: web_search_tool với từ khóa chính (tiếng Anh)
Lần 3: web_search_tool với từ khóa đồng nghĩa/liên quan
Lần 4+: Thêm context: "2026", "review", "so sánh", "reddit"
```

### 2. Nếu search bị chặn, dùng web_fetch trực tiếp
```
web_fetch các URL đã biết:
- Reddit: reddit.com/r/<subreddit>/search?q=<query>
- StackOverflow: stackoverflow.com/search?q=<query>
- GitHub: github.com/search?q=<query>
- Docs chính thức của sản phẩm
```

### 3. Đọc nội dung từng nguồn
```
Với mỗi link từ search results:
- web_fetch URL đó
- Trích xuất thông tin liên quan
- Ghi nhận nguồn
- Bỏ qua nếu bị chặn, chuyển sang nguồn khác
```

### 4. Tổng hợp
```
- Gộp TẤT CẢ thông tin, không lược bỏ
- Cross-check: thông tin ở nhiều nguồn = đáng tin
- Mâu thuẫn: liệt kê cả hai quan điểm
- Cuối cùng: liệt kê tất cả nguồn [1] [2] [3]...
```

## Chiến thuật chống chặn
- Thay đổi user agent (đã set Chrome 134)
- Đổi từ khóa: thêm năm, site:, filetype:
- Fallback: DuckDuckGo -> Jina
- Dùng web_fetch trực tiếp thay vì search
- Tìm tiếng Anh nếu tiếng Việt không có kết quả

## Tiêu chí chất lượng
- Tối thiểu 3 nguồn khác nhau
- Ưu tiên nguồn chính thức (docs, official blog)
- Ghi rõ ngày/thời gian của thông tin nếu có
- Phân biệt fact vs opinion

Tiếng Việt.
