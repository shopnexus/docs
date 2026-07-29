#!/usr/bin/env python3
import re, os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "weekly")   # nguồn: các báo cáo tuần
OUT = HERE                                  # đích: thư mục baocao12

def extract_body(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    start = None
    for i, ln in enumerate(lines):
        if ln.startswith("= BÁO CÁO TIẾN ĐỘ TUẦN"):
            start = i
            break
    assert start is not None, path
    return lines[start:]

# level-1 heading replacements (week -> chapter title)
CH_TITLE = {
    "= BÁO CÁO TIẾN ĐỘ TUẦN 1: THIẾT LẬP VÀ HIỂU BIẾT DỰ ÁN":
        "= Khảo sát hiện trạng và xác định tầm nhìn dự án",
    "= BÁO CÁO TIẾN ĐỘ TUẦN 2: THU THẬP YÊU CẦU & THIẾT KẾ CHI TIẾT":
        "= Phân tích yêu cầu và thiết kế sơ bộ hệ thống",
    "= BÁO CÁO TIẾN ĐỘ TUẦN 3: HOÀN THÀNH YÊU CẦU":
        "= Đặc tả yêu cầu và mô phỏng giao diện",
    "= BÁO CÁO TIẾN ĐỘ TUẦN 4: ĐỊNH NGHĨA KIẾN TRÚC":
        "= Thiết kế kiến trúc hệ thống",
    "= BÁO CÁO TIẾN ĐỘ TUẦN 5: THIẾT KẾ CẤP CAO":
        "= Thiết kế cấp cao (High-level Design)",
    "= BÁO CÁO TIẾN ĐỘ TUẦN 6: THIẾT KẾ CHI TIẾT":
        "= Thiết kế chi tiết (Detailed Design)",
    "= BÁO CÁO TIẾN ĐỘ TUẦN 7: LẬP KẾ HOẠCH TRIỂN KHAI":
        "= Lập kế hoạch triển khai",
}

# prose cross-references -> tham chiếu chương trong cùng một quyển báo cáo
PROSE = [
    ("Tuần 5 chuyển từ kiến trúc tổng thể (Tuần 4) sang thiết kế cấp cao:",
     "Các chương trước đã định nghĩa kiến trúc tổng thể; chương này chuyển sang thiết kế cấp cao:"),
    ("đã chốt ở Tuần 4.", "đã chốt ở Chương 4."),
    ("(xem ADR-02, Tuần 4)", "(xem ADR-02, Chương 4)"),
    ("Tuần 6 chi tiết hóa", "Chương này chi tiết hóa"),
    ("Ở Tuần 4 đã có sơ đồ trình tự", "Ở Chương 4 đã có sơ đồ trình tự"),
    ("wireframe Tuần 3", "wireframe (Chương 3)"),
    ("Tuần 7 khép lại", "Chương này khép lại"),
    ("(xem R-02, Tuần 4)", "(xem R-02, Chương 4)"),
    ("Kết thúc Tuần 7,", "Kết thúc giai đoạn thiết kế,"),
]

DOC_RE = re.compile(r"\s*\(DOC[^)]*\)")

def clean_heading(ln):
    if ln in CH_TITLE:
        return CH_TITLE[ln]
    if re.match(r"^={1,4}\s", ln):
        return DOC_RE.sub("", ln)
    return ln

def heading_text(ln):
    return DOC_RE.sub("", re.sub(r"^={1,4}\s+", "", ln)).strip()

def caption_from_label(ln):
    m = re.match(r"^\*(.+?)\*$", ln.strip())
    if not m:
        return None
    t = m.group(1).strip().rstrip(":").strip()
    return t

def process(lines):
    # apply prose + heading cleaning first
    out = []
    for ln in lines:
        c = clean_heading(ln)
        for a, b in PROSE:
            c = c.replace(a, b)
        out.append(c)
    lines = out

    # track headings + wrap tables
    result = []
    cur_heading = "Bảng dữ liệu"
    last_nonblank = ""
    i = 0
    n = len(lines)
    tbl_count = 0
    while i < n:
        ln = lines[i]
        s = ln.strip()
        # bỏ ngắt trang thủ công trong thân chương (template đã tự sang trang cho mỗi chương)
        if s == "#pagebreak()":
            i += 1
            continue
        if re.match(r"^={2,4}\s", ln):
            cur_heading = heading_text(ln)
        if s.startswith("#table("):
            # find matching close: next line whose strip == ')'
            j = i + 1
            while j < n and lines[j].strip() != ")":
                j += 1
            assert j < n, f"unterminated table near: {ln}"
            # caption
            lbl = caption_from_label(last_nonblank)
            cap = lbl if lbl else cur_heading
            cap = cap.replace("]", "")
            tbl_count += 1
            result.append(f"#figure(kind: table, caption: [{cap}])[")
            result.extend(lines[i:j+1])
            result.append("]")
            i = j + 1
            last_nonblank = ")"
            continue
        result.append(ln)
        if s:
            last_nonblank = s
        i += 1
    return result, tbl_count

def build(name, srcs):
    alllines = []
    for s in srcs:
        alllines.extend(extract_body(os.path.join(SRC, s)))
    body, tc = process(alllines)
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write("// AUTO-GENERATED body — do not edit by hand.\n")
        f.write('#import "style-report.typ": *\n\n')
        f.write("\n".join(body).rstrip() + "\n")
    print(f"{name}: {len(body)} lines, {tc} tables wrapped")

# Báo cáo lần 1 gộp toàn bộ 7 tuần -> 7 chương.
# (Báo cáo lần 2 đang tạm pause: body-lan-2.typ giữ nguyên, không sinh lại.)
build("body-lan-1.typ", ["Tuan 1-2.typ", "Tuan 3-4.typ", "Tuan 5-6-7.typ"])
