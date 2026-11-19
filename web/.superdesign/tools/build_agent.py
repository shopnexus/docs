"""Build the Agent tab mockups: python3 build_agent.py  (writes ../mockups/agent-overview.html and agent-run.html)

A new tab for the console agent, in Vietnamese (the /vi pages). Two pages:
- Tổng quan: what the agent does and never does, a sequence map of the four parts, a preview of a run as a
  member sees it, and cards to the other pages.
- Một câu hỏi chạy thế nào: the same sequence in full, the steps, and the statuses a run ends in.
The sequence and run preview styles here are the ones the real components use (src/styles/agent.css).
"""
from pathlib import Path

from common import icon, shell

CSS = """
.page{display:flex;max-width:1440px}
.nav{width:272px;flex:none;background:var(--bg-nav);border-right:1px solid var(--stroke-soft);padding:20px 12px 32px;min-height:1800px}
.ng{padding:6px 10px;font-size:12px;font-weight:500;color:var(--text-soft)}
.ng+.nl{margin-top:2px}.nl+.ng{margin-top:14px}
.nl{display:flex;align-items:center;min-height:32px;padding:6px 10px;border-radius:8px;font-size:14px;color:var(--text-body);position:relative}
.nl.on{background:var(--bg-selected);color:var(--text-strong);font-weight:500}
.nl.on::before{content:"";position:absolute;left:0;top:6px;bottom:6px;width:2px;border-radius:999px;background:var(--brand)}
.main{flex:1;display:flex;justify-content:center;padding:40px 48px 80px;gap:48px}
.art{width:760px}
.toc{width:200px;flex:none;padding-top:8px;font-size:13px;color:var(--text-sub)}
.toc p{margin:0 0 10px;font-weight:500;color:var(--text-strong)}.toc a{display:block;padding:4px 0 4px 12px;border-left:1px solid var(--stroke-soft)}
.toc a.on{border-color:var(--brand);color:var(--brand-text);font-weight:500}
.crumb{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--text-soft)}
h1{margin:12px 0 0;font-size:36px;line-height:44px;font-weight:650;letter-spacing:-.025em}
.desc{margin:12px 0 0;font-size:18px;line-height:30px;color:var(--text-sub)}
.meta{margin-top:20px;display:flex;align-items:center;gap:8px;font-size:13px;color:var(--text-soft)}
.cb{background:var(--brand-soft);color:var(--brand-text)}.co{background:var(--bg-subtle);color:var(--text-sub);border:1px solid var(--stroke-soft)}
.prose{margin-top:36px;font-size:16px;line-height:28px;color:var(--text-body)}
.prose h2{margin:48px 0 14px;font-size:24px;line-height:32px;font-weight:600;color:var(--text-strong);letter-spacing:-.015em}
.prose p{margin:0 0 16px}.prose strong{color:var(--text-strong);font-weight:600}
.prose code{font:13px var(--mono);background:var(--bg-subtle);border:1px solid var(--stroke-soft);border-radius:5px;padding:1px 5px}
.prose a.l{color:var(--link);text-decoration:underline;text-decoration-color:rgba(0,80,73,.3);text-underline-offset:4px}
.fig{margin:24px 0 28px}.figcap{margin-top:10px;font-size:13px;color:var(--text-soft);text-align:center}
/* do / never */
.dn{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:20px 0 8px}
.dn>div{border:1px solid var(--stroke-soft);border-radius:16px;padding:18px 20px}
.dn h4{margin:0 0 10px;font-size:14px;font-weight:600;display:flex;align-items:center;gap:8px;color:var(--text-strong)}
.dn ul{margin:0;padding:0;list-style:none;font-size:14.5px;line-height:24px}.dn li{display:flex;gap:8px;padding:4px 0}
.dn li iconify-icon{margin-top:4px;flex:none}
.dn .yes iconify-icon{color:var(--brand)}.dn .no{background:var(--bg-nav)}.dn .no iconify-icon{color:var(--text-soft)}
/* cards */
.cards{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:16px}
.card{display:flex;gap:14px;border:1px solid var(--stroke-soft);border-radius:16px;padding:16px 18px}
.card .ci{width:34px;height:34px;border-radius:10px;background:var(--brand-soft);color:var(--brand-text);display:flex;align-items:center;justify-content:center;flex:none}
.card b{display:block;font-size:15px;font-weight:600;color:var(--text-strong)}.card span{font-size:14px;line-height:22px;color:var(--text-sub)}
.callout{display:flex;gap:12px;border:1px solid var(--info-line);background:var(--info-soft);border-radius:12px;padding:14px 16px;font-size:15px;line-height:25px}
.callout iconify-icon{color:var(--info);margin-top:3px;flex:none}
/* steps */
.steps{list-style:none;margin:20px 0;padding:0;position:relative}
.steps::before{content:"";position:absolute;left:13px;top:14px;bottom:14px;width:2px;background:var(--stroke-soft)}
.steps li{position:relative;padding:0 0 22px 44px}
.steps .n{position:absolute;left:0;top:0;width:28px;height:28px;border-radius:999px;background:var(--bg-page);border:1px solid var(--stroke-sub);font-size:13px;font-weight:600;display:flex;align-items:center;justify-content:center;color:var(--text-strong)}
.steps b{display:block;font-size:16px;font-weight:600;color:var(--text-strong);margin-bottom:4px}
/* statuses */
.sts{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin:18px 0}
.st{border:1px solid var(--stroke-soft);border-radius:12px;padding:12px}
.st .dot{display:inline-block;width:8px;height:8px;border-radius:999px;margin-right:6px}
.st b{font:600 12.5px var(--mono);color:var(--text-strong)}.st p{margin:6px 0 0;font-size:13px;line-height:19px;color:var(--text-sub)}
"""

AGENT_CSS = """
/* Sequence: actors in columns, numbered messages as arrows between their lifelines. */
.seq{--n:4;border:1px solid var(--stroke-soft);border-radius:16px;background:var(--bg-nav);padding:20px 16px 12px;position:relative;overflow:hidden}
.seq-actors,.seq-row{display:grid;grid-template-columns:repeat(calc(var(--n) * 2),minmax(0,1fr))}
.seq-actor{grid-column:span 2;display:flex;flex-direction:column;align-items:center;text-align:center;gap:6px;position:relative;z-index:1}
.seq-ico{width:40px;height:40px;border-radius:12px;background:var(--bg-page);border:1px solid var(--stroke-sub);display:flex;align-items:center;justify-content:center;color:var(--brand-text);box-shadow:var(--shadow-chip)}
.seq-name{font-size:14px;font-weight:600;color:var(--text-strong);line-height:18px}
.seq-sub{font-size:12px;line-height:16px;color:var(--text-soft);max-width:140px}
.seq-body{position:relative;margin-top:14px;padding-bottom:4px}
.seq-life{position:absolute;top:0;bottom:0;width:0;border-left:1.5px dashed var(--stroke-sub)}
.seq-row{position:relative;min-height:58px;align-items:center}
.seq-arrow{position:relative;height:100%;display:flex;flex-direction:column;justify-content:center;padding:8px 0}
.seq-label{display:flex;align-items:center;justify-content:center;gap:6px;font-size:13px;line-height:18px;color:var(--text-strong);font-weight:500;text-align:center;padding:0 10px}
.seq-num{flex:none;width:18px;height:18px;border-radius:999px;background:var(--brand);color:var(--on-brand);font-size:11px;font-weight:600;display:inline-flex;align-items:center;justify-content:center}
.seq-line{position:relative;height:2px;margin:6px 0 5px;background:var(--brand)}
.seq-line::after{content:"";position:absolute;right:-1px;top:-4px;border:5px solid transparent;border-left:8px solid var(--brand);border-right:0}
.seq-arrow.back .seq-line{background:repeating-linear-gradient(90deg,var(--text-soft) 0 6px,transparent 6px 10px)}
.seq-arrow.back .seq-line::after{border-left-color:var(--text-soft)}
.seq-arrow.rtl .seq-line::after{right:auto;left:-1px;border-left:0;border-right:8px solid var(--brand)}
.seq-arrow.rtl.back .seq-line::after{border-right-color:var(--text-soft)}
.seq-detail{font-size:12px;line-height:16px;color:var(--text-soft);text-align:center;padding:0 10px}
.seq-detail code{font:11.5px var(--mono)}
/* Run preview: a run as a console member sees it. */
.run{border:1px solid var(--stroke-soft);border-radius:16px;background:var(--bg-page);box-shadow:var(--shadow-card);overflow:hidden;font-size:14px;line-height:22px;color:var(--text-body)}
.run-bar{display:flex;align-items:center;gap:10px;padding:10px 16px;border-bottom:1px solid var(--stroke-soft);background:var(--bg-nav);font-size:13px}
.run-ava{width:24px;height:24px;border-radius:8px;background:var(--brand);color:var(--on-brand);display:flex;align-items:center;justify-content:center}
.run-bar b{color:var(--text-strong);font-weight:600}
.run-tag{font:500 11.5px var(--mono);color:var(--text-sub);border:1px solid var(--stroke-sub);border-radius:6px;padding:0 6px}
.run-body{padding:18px 20px 6px}
.run-q{margin-left:auto;max-width:78%;background:var(--bg-subtle);border-radius:14px 14px 4px 14px;padding:10px 14px;color:var(--text-strong)}
.run-who{text-align:right;font-size:12px;color:var(--text-soft);margin:4px 0 14px}
.run-steps{border:1px solid var(--stroke-soft);border-radius:12px;padding:6px 14px}
.run-step{display:flex;gap:10px;padding:10px 0}.run-step+.run-step{border-top:1px solid var(--stroke-soft)}
.run-check{width:20px;height:20px;border-radius:999px;background:var(--brand-soft);color:var(--brand-text);display:flex;align-items:center;justify-content:center;flex:none;margin-top:1px}
.run-step b{color:var(--text-strong);font-weight:600}.run-step .sum{color:var(--text-sub);font-size:13px}
.run-tools{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}
.run-tool{display:inline-flex;align-items:center;gap:5px;height:24px;padding:0 8px;border-radius:7px;border:1px solid var(--stroke-soft);background:var(--bg-nav);font:500 12px var(--mono);color:var(--text-body)}
.run-tool i{font-style:normal;color:var(--text-soft)}
.run-figs{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:16px 0 12px}
.run-fig{border:1px solid var(--stroke-soft);border-radius:12px;padding:10px 12px}
.run-fig b{display:block;font-size:20px;line-height:26px;font-weight:650;color:var(--text-strong);letter-spacing:-.01em}
.run-fig span{font-size:12px;color:var(--text-sub)}
.run-ans p{margin:0 0 10px}
.run-cite{display:inline-flex;align-items:center;justify-content:center;min-width:17px;height:17px;padding:0 4px;margin:0 1px;border-radius:5px;background:var(--brand-soft);color:var(--brand-text);font-size:11px;font-weight:600;vertical-align:1px}
.run-src{margin:4px 0 12px;border-top:1px solid var(--stroke-soft);padding-top:10px}
.run-src-h{font-size:12px;font-weight:500;color:var(--text-soft);margin-bottom:6px}
.run-src-i{display:flex;gap:8px;align-items:baseline;padding:3px 0;font-size:13px}
.run-src-i b{color:var(--text-strong);font-weight:500}.run-src-i span{color:var(--text-soft);font-size:12px}
.run-fu{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:12px}
.run-fu span{border:1px solid var(--stroke-sub);border-radius:999px;padding:2px 10px;font-size:12.5px;color:var(--text-body)}
.run-foot{display:flex;align-items:center;gap:10px;padding:10px 12px;border-top:1px solid var(--stroke-soft);background:var(--bg-nav)}
.run-input{flex:1;height:36px;border:1px solid var(--stroke-sub);border-radius:10px;background:var(--bg-page);display:flex;align-items:center;padding:0 12px;color:var(--text-soft);font-size:13px}
.run-meter{display:flex;align-items:center;gap:6px;font-size:12px;color:var(--text-soft)}
.run-meter i{display:block;width:44px;height:4px;border-radius:999px;background:var(--stroke-soft);overflow:hidden}
.run-meter i::after{content:"";display:block;width:34%;height:100%;background:var(--brand)}
.run-btn{height:32px;padding:0 12px;border-radius:9px;border:1px solid var(--stroke-sub);background:var(--bg-page);display:flex;align-items:center;gap:6px;font-size:13px;font-weight:500;color:var(--text-strong)}
"""

NAV = [("Tổng quan", ["Agent làm gì"]),
       ("Một lượt chạy", ["Một câu hỏi chạy thế nào", "Tạm dừng, chỉnh hướng, hỏi lại"]),
       ("Kết quả", ["Câu trả lời và nguồn"]),
       ("Bên trong", ["Tool và quyền đọc", "Giới hạn và lỗi", "Agent và cấu hình"])]

ACTORS = [("Console", "computer-line", "Moderator hỏi, xem từng bước"),
          ("Server", "server-line", "Kiểm phiên, lưu lượt, phát lại event"),
          ("Agent", "robot-2-line", "Vòng lặp model, không giữ dữ liệu"),
          ("LiteLLM", "sparkling-2-line", "Chọn model, tính ngân sách")]

SHORT = [(1, 2, "Gửi câu hỏi", "<code>POST …/turns</code> → 202"),
         (2, 3, "Bắt đầu một đoạn chạy", "<code>POST /runs</code> kèm cấu hình agent"),
         (3, 4, "Gọi model", "<code>user</code> = moderator, để tính ngân sách"),
         (3, 2, "Đọc dữ liệu qua MCP", "chỉ tool chỉ đọc, kiểm moderator mỗi lần gọi"),
         (3, 2, "Trả từng dòng NDJSON", "event, tool call, checkpoint, dòng end", "back"),
         (2, 1, "Phát event qua SSE", "đóng tab không dừng lượt chạy", "back")]

FULL = SHORT[:4] + [(4, 3, "Trả lời, có khi kèm tool", "", "back")] + SHORT[4:] + \
       [(1, 2, "Tạm dừng hoặc chỉnh hướng", "<code>POST …/pause</code>, <code>…/steer</code>"),
        (3, 2, "Hỏi lệnh điều khiển mỗi giây", "<code>GET /agent/turns/{id}/control</code>")]


def sequence(steps):
    n = len(ACTORS)
    actors = "".join(f'<div class="seq-actor"><span class="seq-ico">{icon(ic, 20)}</span><span class="seq-name">{a}</span>'
                     f'<span class="seq-sub">{s}</span></div>' for a, ic, s in ACTORS)
    lives = "".join(f'<span class="seq-life" style="left:calc({(2 * i + 1) / (2 * n) * 100:.4f}%)"></span>' for i in range(n))
    rows = []
    for k, st in enumerate(steps, 1):
        a, b, label, detail = st[:4]
        kind = st[4] if len(st) > 4 else ""
        lo, hi = min(a, b), max(a, b)
        cls = "seq-arrow" + (" rtl" if b < a else "") + (" back" if kind == "back" else "")
        det = f'<div class="seq-detail">{detail}</div>' if detail else ""
        rows.append(f'<div class="seq-row"><div class="{cls}" style="grid-column:{2 * lo} / {2 * hi}">'
                    f'<div class="seq-label"><span class="seq-num">{k}</span>{label}</div><div class="seq-line"></div>{det}</div></div>')
    return (f'<div class="seq" style="--n:{n}"><div class="seq-actors">{actors}</div>'
            f'<div class="seq-body">{lives}{"".join(rows)}</div></div>')


def run_preview():
    tool = lambda name, ms: f'<span class="run-tool">{icon("checkbox-circle-line", 12)}{name}<i>{ms}</i></span>'
    return f"""<div class="run">
  <div class="run-bar"><span class="run-ava">{icon("robot-2-line", 14)}</span><b>Console assistant</b><span class="run-tag">console-agent</span><span style="flex:1"></span><span style="color:var(--text-soft)">Report case · Minh Tuấn</span></div>
  <div class="run-body">
    <div class="run-q">Tài khoản này có dấu hiệu lừa đảo không?</div>
    <div class="run-who">Lan · 09:50</div>
    <div class="run-steps">
      <div class="run-step"><span class="run-check">{icon("check-line", 13)}</span><div><b>Đọc ca báo cáo</b> <span class="sum">· 3 báo cáo, cùng lý do lừa đảo</span>
        <div class="run-tools">{tool("report_case_get", "412 ms")}{tool("account_get", "180 ms")}</div></div></div>
      <div class="run-step"><span class="run-check">{icon("check-line", 13)}</span><div><b>So giá tin đăng</b> <span class="sum">· thấp hơn nhiều so với giá thường</span>
        <div class="run-tools">{tool("listing_get", "96 ms")}{tool("price_guide", "240 ms")}</div></div></div>
    </div>
    <div class="run-figs">
      <div class="run-fig"><b>3</b><span>báo cáo đang mở</span></div>
      <div class="run-fig"><b>−58%</b><span>so với giá giữa</span></div>
      <div class="run-fig"><b>0</b><span>đơn đã giao</span></div>
    </div>
    <div class="run-ans"><p>Có dấu hiệu. Ba người báo cáo cùng lý do lừa đảo trong hai ngày <span class="run-cite">1</span>, tin iPhone 13 Pro đặt giá 7,2 triệu <span class="run-cite">2</span>, thấp hơn 58% so với giá giữa của tin cùng loại <span class="run-cite">3</span>. Tài khoản mới 4 ngày và chưa giao đơn nào.</p></div>
    <div class="run-src"><div class="run-src-h">Sources</div>
      <div class="run-src-i"><span class="run-cite">1</span><b>Ca báo cáo: Minh Tuấn</b><span>3 báo cáo · lừa đảo · đang mở</span></div>
      <div class="run-src-i"><span class="run-cite">2</span><b>iPhone 13 Pro 128GB</b><span>Tin đăng · đang bán</span></div>
      <div class="run-src-i"><span class="run-cite">3</span><b>Giá tham khảo, iPhone 13 Pro</b><span>price_guide · 41 tin</span></div>
    </div>
    <div class="run-fu"><span>Xem các đơn của người bán</span><span>Soạn lời nhắn cho người báo cáo</span></div>
  </div>
  <div class="run-foot"><span class="run-input">Ask the agent or change the reply…</span><span class="run-meter"><i></i>34%</span><span class="run-btn" style="width:32px;padding:0;justify-content:center;border-radius:999px;background:var(--brand);color:var(--on-brand);border:0">{icon("arrow-up-line", 16)}</span></div>
</div>"""


def topbar_vi():
    from common import LOGO
    tabs = [("get-started", "Bắt đầu"), ("marketplace", "Mô hình sàn"), ("requirements", "Yêu cầu"),
            ("architecture", "Kiến trúc"), ("agent", "AI agent"), ("api", "API"), ("operations", "Vận hành")]
    t = "".join(f'<a id="tab-{k}" href="#tab-{k}" class="tab{" on" if k == "agent" else ""}">{v}</a>' for k, v in tabs)
    return f"""<header class="topbar">
  <a id="brand-home" href="#home" class="brand"><img src="{LOGO}" width="28" height="28" alt="ShopNexus">ShopNexus <span style="color:var(--text-soft);font-weight:500">Docs</span></a>
  <nav class="tabs">{t}</nav><span style="flex:1"></span>
  <a id="site-search" href="#search" class="search">{icon("search-line")}<span style="flex:1">Tìm trong tài liệu...</span><span class="kbd">Ctrl K</span></a>
  <span class="seg"><span>EN</span><span class="on">VI</span></span><span class="iconbtn">{icon("computer-line", 18)}</span>
</header>"""


def nav(active):
    out = []
    for g, pages in NAV:
        out.append(f'<div class="ng">{g}</div>')
        out += [f'<a id="nav-{i}-{abs(hash(p)) % 999}" href="#p" class="nl{" on" if p == active else ""}">{p}</a>' for i, p in enumerate(pages)]
    return f'<nav class="nav">{"".join(out)}</nav>'


def header(group, title, desc, kind, minutes):
    return f"""<div class="crumb">AI agent {icon("arrow-right-s-line", 14)} {group} {icon("arrow-right-s-line", 14)} <span style="color:var(--text-sub)">{title}</span></div>
<h1>{title}</h1><p class="desc">{desc}</p>
<div class="meta"><span class="chip cb">{icon("code-s-slash-line", 13)} Nhà phát triển</span><span class="chip co">{icon(kind[0], 13)} {kind[1]}</span><span>{icon("time-line", 13)} {minutes} phút đọc</span><span>·</span><span>Cập nhật 19 thg 11, 2026</span></div>"""


def toc(items):
    return '<aside class="toc"><p>Trên trang này</p>' + "".join(
        f'<a id="toc-{i}" href="#s{i}" class="{"on" if i == 0 else ""}">{t}</a>' for i, t in enumerate(items)) + "</aside>"


def overview():
    card = lambda ic, t, d: f'<a id="card-{ic}" href="#{ic}" class="card"><span class="ci">{icon(ic, 18)}</span><span><b>{t}</b><span>{d}</span></span></a>'
    body = f"""{header("Tổng quan", "Agent làm gì", "Trợ lý AI của console: đọc ticket, ca báo cáo và tài khoản qua tool, tìm hiểu qua nhiều bước rồi trả lời có dẫn nguồn. Moderator quyết định và tự tay làm.", ("lightbulb-line", "Khái niệm"), 4)}
<div class="prose">
<p>Moderator mở một ticket hay một ca báo cáo trong console và hỏi agent bằng lời thường. Agent tự chọn tool để đọc dữ liệu, chia việc thành từng bước có tên, rồi trả lời bằng chữ, số liệu, bảng hoặc biểu đồ. Mỗi ý trong câu trả lời gắn số <span class="run-cite">1</span> chỉ về đúng bản ghi nó lấy ra.</p>
<div class="dn">
  <div class="yes"><h4>{icon("check-double-line", 16)} Agent làm</h4><ul>
    <li>{icon("check-line", 14)}Đọc ticket, ca báo cáo, tài khoản, đơn, tin đăng, nhật ký console</li>
    <li>{icon("check-line", 14)}Tóm tắt, so sánh, đếm, viết tài liệu có phiên bản</li>
    <li>{icon("check-line", 14)}Hỏi lại moderator khi câu hỏi chưa rõ</li>
    <li>{icon("check-line", 14)}Ghi lại từng bước, từng lần gọi tool và chi phí</li></ul></div>
  <div class="no"><h4>{icon("forbid-line", 16)} Agent không bao giờ</h4><ul>
    <li>{icon("close-line", 14)}Sửa dữ liệu: khoá, ẩn, gửi tin là việc của moderator</li>
    <li>{icon("close-line", 14)}Nghe theo chữ người dùng viết trong tin nhắn hay ghi chú</li>
    <li>{icon("close-line", 14)}Có địa chỉ công khai: chỉ server gọi được nó</li>
    <li>{icon("close-line", 14)}Giữ dữ liệu: server lưu mọi lượt chạy</li></ul></div>
</div>
<h2>Bốn phần, một đường đi</h2>
<p>Console chỉ nói chuyện với server. Server mở từng đoạn chạy trên agent, agent gọi model qua LiteLLM và đọc dữ liệu ngược lại qua MCP server của chính server. Mọi thứ agent làm chảy về server thành từng dòng, server lưu lại và phát cho console.</p>
<div class="fig">{sequence(SHORT)}<div class="figcap">Một câu hỏi đi qua bốn phần. Mũi tên nét đứt là dữ liệu chảy về.</div></div>
<h2>Moderator thấy gì</h2>
<p>Lượt chạy hiện ra ngay khi nó diễn ra: từng bước với một dòng tóm tắt, từng tool kèm thời gian, rồi câu trả lời và danh sách nguồn. Trong lúc chạy, moderator bấm <strong>Pause</strong> (hoặc Esc), hoặc gõ thêm một dòng để chỉnh hướng agent.</p>
<div class="fig">{run_preview()}<div class="figcap">Một lượt chạy trên ca báo cáo, đã xong.</div></div>
<div class="callout">{icon("information-line", 18)}<span>Khi agent đề xuất khoá tài khoản, moderator vẫn bấm nút khoá trong console như thường. Hành động đó đi qua endpoint của console và vào nhật ký với tên moderator.</span></div>
<h2>Đọc tiếp</h2>
<div class="cards">
{card("route-line", "Một câu hỏi chạy thế nào", "Từ lúc bấm gửi tới dòng cuối, từng bước.")}
{card("pause-circle-line", "Tạm dừng, chỉnh hướng, hỏi lại", "Điều khiển một lượt đang chạy.")}
{card("double-quotes-l", "Câu trả lời và nguồn", "Khối trả lời, số dẫn nguồn, tài liệu, skill.")}
{card("tools-line", "Tool và quyền đọc", "16 tool chỉ đọc và ai được đọc gì.")}
{card("timer-line", "Giới hạn và lỗi", "Thời hạn, ngân sách, ngữ cảnh, khi nào chạy tiếp được.")}
{card("settings-3-line", "Agent và cấu hình", "Agent của console, biến môi trường, chạy thử.")}
</div>
</div>"""
    page = f"""{topbar_vi()}<div class="page">{nav("Agent làm gì")}<main class="main"><article class="art">{body}</article>{toc(["Bốn phần, một đường đi", "Moderator thấy gì", "Đọc tiếp"])}</main></div>"""
    return shell("Agent · Tổng quan", page, CSS + AGENT_CSS)


def run_page():
    sts = [("SUCCEEDED", "var(--brand)", "Có câu trả lời."), ("PAUSED", "var(--info)", "Pause, Stop now, chạy tiếp được."),
           ("AWAITING_INPUT", "var(--feature)", "Chờ moderator trả lời câu hỏi."), ("FAILED", "var(--text-soft)", "Model, MCP hay ngân sách lỗi."),
           ("TIMED_OUT", "var(--text-soft)", "Hết thời hạn của đoạn chạy.")]
    st = "".join(f'<div class="st"><span class="dot" style="background:{c}"></span><b>{n}</b><p>{d}</p></div>' for n, c, d in sts)
    steps = [("Server nhận câu hỏi", "Kiểm phiên console, ngân sách tháng, giới hạn 30 câu một phút, làm sạch câu hỏi. Lượt mở ở trạng thái <code>running</code> và console nhận ngay <code>202</code>."),
             ("Server mở một đoạn chạy", "Gửi <code>POST /runs</code> cho agent: câu hỏi, moderator, bản ghi đang mở, 20 lượt trước làm lịch sử, cấu hình agent đọc từ <code>ai_agents</code>."),
             ("Agent làm việc", "Mở client MCP riêng cho đoạn chạy, chỉ lấy tool có <code>readOnlyHint</code>. Model mở bước, gọi tool, đóng bước với một dòng tóm tắt."),
             ("Từng dòng chảy về", "Mỗi việc là một dòng NDJSON. Server lưu event với số thứ tự kế tiếp và báo các stream đang mở bằng <code>pg_notify</code>."),
             ("Dòng end khép lượt", "Trạng thái, câu trả lời, nguồn, chi phí và checkpoint đi chung một dòng. Server ghi tất cả trong một transaction.")]
    sl = "".join(f'<li><span class="n">{i}</span><b>{t}</b>{d}</li>' for i, (t, d) in enumerate(steps, 1))
    body = f"""{header("Một lượt chạy", "Một câu hỏi chạy thế nào", "Từ lúc moderator bấm gửi tới dòng cuối cùng: ai gọi ai, cái gì được lưu, và lượt chạy kết thúc ra sao.", ("route-line", "Khái niệm"), 5)}
<div class="prose">
<p>Một câu hỏi là một <strong>lượt</strong>. Lượt có thể chạy thành nhiều <strong>đoạn</strong>: tạm dừng rồi chạy tiếp, hay hỏi lại moderator rồi chạy tiếp, mỗi lần là một đoạn mới trên agent, nối tiếp từ checkpoint của đoạn trước.</p>
<div class="fig">{sequence(FULL)}<div class="figcap">Đủ các bước của một đoạn chạy, kể cả điều khiển.</div></div>
<h2>Từng bước</h2>
<ol class="steps">{sl}</ol>
<h2>Năm cách một đoạn kết thúc</h2>
<div class="sts">{st}</div>
<p>Đóng tab chỉ đóng stream, lượt vẫn chạy. Mở lại trang thì console xin phát lại từ số thứ tự cuối nó đã thấy, qua <code>Last-Event-ID</code>.</p>
</div>"""
    page = f"""{topbar_vi()}<div class="page">{nav("Một câu hỏi chạy thế nào")}<main class="main"><article class="art">{body}</article>{toc(["Từng bước", "Năm cách một đoạn kết thúc"])}</main></div>"""
    return shell("Agent · Một câu hỏi chạy thế nào", page, CSS + AGENT_CSS)


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "mockups"
    (out / "agent-overview.html").write_text(overview())
    (out / "agent-run.html").write_text(run_page())
    print("ok")
