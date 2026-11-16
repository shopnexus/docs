"""Build the API playground redesign: python3 build_playground.py > ../mockups/playground.html

/en/api/playground as a workbench, on an operation the docs care about (POST /v1/deals/{id}/offer):

- A slim page header (breadcrumb, title, one line, openapi.json and the API design guide).
- A connection bar that stays under the top bar: the server as a three-way segment (Production, Dev, Local) with
  its base URL and a /healthz dot, and the session: who is signed in and how long the 15-minute access token has
  left. Signing in happens here (email code), so nobody pastes tokens by hand.
- Three columns: the tag groups with operation counts; the operation's contract with the use case it serves
  (x-uc, linked to Requirements); the request and its answer. An error code in the answer names the exception
  flow of the use case that returns it.

Data is the real spec: summaries, the Offer body, the responses and their codes, the 7 tag groups and counts.
"""
from common import icon, shell, topbar

CSS = """
.page{background:var(--bg-page)}
.ph{display:flex;align-items:flex-end;gap:24px;padding:24px 24px 18px}
.crumb{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--text-soft)}
.ph h1{margin:6px 0 0;font-size:28px;line-height:34px;font-weight:650;letter-spacing:-.022em}
.ph p{margin:4px 0 0;font-size:14px;line-height:22px;color:var(--text-sub)}
.btn{height:34px;padding:0 12px;border-radius:9px;display:inline-flex;align-items:center;gap:7px;font-size:13.5px;font-weight:500;white-space:nowrap}
.btn.outline{border:1px solid var(--stroke-sub);background:var(--bg-page);color:var(--text-strong)}
.btn.pri{background:var(--brand);color:var(--on-brand)}
.btn.ghost{color:var(--text-sub)}
.conn{position:sticky;top:64px;z-index:30;height:56px;display:flex;align-items:center;gap:14px;padding:0 24px;
background:var(--bg-nav);border-top:1px solid var(--stroke-soft);border-bottom:1px solid var(--stroke-soft)}
.lbl{font-size:12px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;color:var(--text-soft)}
.dot,.seg .dot{width:8px;height:8px;padding:0;border-radius:999px;display:inline-block;flex:none}
.url{height:30px;padding:0 10px;border-radius:8px;border:1px solid var(--stroke-soft);background:var(--bg-page);display:inline-flex;align-items:center;gap:8px;font:12.5px var(--mono);color:var(--text-body)}
.health{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;color:var(--text-sub)}
.vr{width:1px;height:24px;background:var(--stroke-sub)}
.who{display:flex;align-items:center;gap:10px;font-size:13px;white-space:nowrap}
.av{width:28px;height:28px;border-radius:999px;background:var(--brand-soft);color:var(--brand-text);display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600}
.ttl{display:inline-flex;align-items:center;gap:6px;height:26px;padding:0 9px;border-radius:999px;background:var(--brand-soft);color:var(--brand-text);font-size:12px;font-weight:500}
.cols{display:grid;grid-template-columns:272px minmax(0,1fr) 540px;min-height:1180px}
.nav{background:var(--bg-nav);border-right:1px solid var(--stroke-soft);padding:14px 12px}
.find{height:34px;border-radius:9px;border:1px solid var(--stroke-sub);background:var(--bg-page);display:flex;align-items:center;gap:8px;padding:0 10px;font-size:13.5px;color:var(--text-soft)}
.g{margin-top:14px}
.gh{display:flex;align-items:center;justify-content:space-between;height:30px;padding:0 8px;font-size:12px;font-weight:600;letter-spacing:.03em;text-transform:uppercase;color:var(--text-soft)}
.t{display:flex;align-items:center;justify-content:space-between;height:32px;padding:0 8px;border-radius:8px;font-size:14px;color:var(--text-body)}
.t .n{font-size:12px;color:var(--text-soft)}
.t.open{color:var(--text-strong);font-weight:500}
.op{display:flex;align-items:flex-start;gap:8px;padding:6px 8px 6px 14px;margin-left:10px;border-left:1px solid var(--stroke-soft);font-size:13px;line-height:18px;color:var(--text-sub)}
.op.on{background:var(--bg-selected);border-left:2px solid var(--brand);color:var(--text-strong);border-radius:0 8px 8px 0;font-weight:500}
.m{flex:none;width:44px;font:600 10.5px/18px var(--mono);letter-spacing:.02em}
.GET{color:var(--info)}.POST{color:var(--brand)}.PUT{color:var(--warning)}.PATCH{color:var(--feature)}.DELETE{color:var(--danger)}
.doc{padding:32px 48px 64px;max-width:760px}
.doc h2{margin:8px 0 0;font-size:28px;line-height:36px;font-weight:650;letter-spacing:-.02em}
.path{margin-top:16px;display:flex;align-items:center;gap:10px;height:40px;padding:0 6px 0 12px;border:1px solid var(--stroke-soft);border-radius:10px;background:var(--bg-subtle);font:13.5px var(--mono);color:var(--text-strong)}
.mb{flex:none;white-space:nowrap;height:22px;padding:0 7px;border-radius:6px;font:600 11px/22px var(--mono)}
.mb.POST{background:var(--brand-soft)}
.tags{margin-top:14px;display:flex;flex-wrap:wrap;gap:8px}
.tag{height:26px;padding:0 10px;border-radius:999px;display:inline-flex;align-items:center;gap:6px;font-size:12.5px;border:1px solid var(--stroke-soft);color:var(--text-sub);background:var(--bg-page)}
.tag.uc{border-color:var(--brand-line);background:var(--brand-soft);color:var(--brand-text);font-weight:500}
.lead{margin:18px 0 0;font-size:16px;line-height:27px;color:var(--text-body)}
.sec{margin-top:32px}
.sec h3{margin:0 0 10px;font-size:15px;font-weight:600;display:flex;align-items:center;gap:10px}
.sec h3 .k{font-weight:400;font-size:12.5px;color:var(--text-soft)}
.field{border-top:1px solid var(--stroke-soft);padding:12px 0}
.fn{display:flex;align-items:baseline;gap:8px;font-size:13.5px}
.fn b{font:600 13.5px var(--mono);color:var(--text-strong)}
.fn .ty{font:12.5px var(--mono);color:var(--text-soft)}
.req{font-size:12px;color:var(--warning);font-weight:500}
.fd{margin:6px 0 0;font-size:14px;line-height:22px;color:var(--text-sub)}
.code{display:inline-block;font:12px var(--mono);padding:1px 6px;border-radius:5px;background:var(--bg-subtle);border:1px solid var(--stroke-soft);color:var(--text-body)}
.resp{border:1px solid var(--stroke-soft);border-radius:12px;overflow:hidden}
.rr{display:grid;grid-template-columns:56px 1fr;align-items:start;gap:4px 12px;padding:11px 14px;border-top:1px solid var(--stroke-soft);font-size:14px;color:var(--text-body)}
.rr:first-child{border-top:0}
.st{font:600 13px var(--mono)}
.s2{color:var(--brand)}.s4{color:var(--warning)}
.codes{grid-column:2;display:flex;flex-wrap:wrap;gap:6px}.codes:empty{display:none}
.right{border-left:1px solid var(--stroke-soft);background:var(--bg-nav);padding:20px}
.stick{position:sticky;top:140px;display:flex;flex-direction:column;gap:14px}
.panel{border:1px solid var(--stroke-soft);border-radius:14px;background:var(--bg-page);overflow:hidden;box-shadow:var(--shadow-chip)}
.pt{display:flex;align-items:center;gap:10px;padding:10px 14px;border-bottom:1px solid var(--stroke-soft);font-size:13px;font-weight:600}
.pt .sp{flex:1}
.addr{display:flex;align-items:center;gap:8px;padding:12px 14px;font:12.5px var(--mono);color:var(--text-body);border-bottom:1px solid var(--stroke-soft);word-break:break-all}
.addr .base{color:var(--text-soft)}
.tabsx{display:flex;gap:18px;padding:0 14px;border-bottom:1px solid var(--stroke-soft);font-size:13px;color:var(--text-sub)}
.tabsx span{padding:9px 0}.tabsx .on{color:var(--text-strong);font-weight:500;box-shadow:inset 0 -2px var(--text-strong)}
.kv{display:grid;grid-template-columns:150px 1fr;gap:8px 12px;padding:12px 14px;font-size:12.5px;align-items:center}
.kv .k{font:12.5px var(--mono);color:var(--text-sub)}
.inp{height:30px;border:1px solid var(--stroke-sub);border-radius:8px;padding:0 9px;display:flex;align-items:center;gap:6px;font:12.5px var(--mono);color:var(--text-strong);background:var(--bg-page)}
.inp .hint{margin-left:auto;font:11.5px var(--sans);color:var(--brand-text)}
.editor{margin:0 14px 14px;border:1px solid var(--stroke-soft);border-radius:10px;background:var(--bg-subtle);padding:10px 0;font:12.5px/20px var(--mono)}
.ln{display:flex}.ln i{font-style:normal;width:34px;text-align:right;padding-right:12px;color:var(--text-soft)}
.p{color:var(--text-strong)}.s{color:var(--brand-text)}.nu{color:var(--feature)}.kk{color:var(--info)}
.foot{display:flex;align-items:center;gap:10px;padding:12px 14px;border-top:1px solid var(--stroke-soft)}
.status{display:inline-flex;align-items:center;gap:6px;height:26px;padding:0 10px;border-radius:999px;font:600 12.5px var(--mono)}
.status.w{background:var(--warning-soft);color:var(--warning);border:1px solid var(--warning-line)}
.meta{font-size:12.5px;color:var(--text-soft);display:flex;align-items:center;gap:6px}
.explain{margin:0 14px 14px;padding:10px 12px;border-radius:10px;border:1px solid var(--warning-line);background:var(--warning-soft);font-size:13px;line-height:20px;color:var(--text-body);display:flex;gap:10px}
"""

GROUPS = [
    ("Accounts", [("Sign-in", 7), ("Account", 16), ("Uploads", 1)]),
    ("Listings and search", [("Listings", 16), ("Listing assist", 4), ("Search and saved listings", 17)]),
    ("Deals", [("Chat", 8), ("Deals and orders", 15), ("Shipping", 7)]),
    ("After the sale", [("Reviews and reports", 6), ("Support", 4), ("Notifications", 8), ("Live updates", 3)]),
    ("App screens", [("Screens", 12)]),
    ("Staff console", [("Console", 27)]),
    ("System", [("Health", 2)]),
]
DEAL_OPS = [("POST", "Open the caller's deal on a listing"), ("GET", "Read a deal, as its buyer or its seller"),
            ("POST", "Make an offer, or a counter to the buyer's offer"), ("POST", "Agree the deal at a price"),
            ("POST", "Turn down the other side's open price"), ("POST", "Take back the caller's own open price"),
            ("POST", "Drop the agreed price, and a pending order with it"), ("GET", "List the caller's deals on one side"),
            ("POST", "Ask for cash on delivery on an agreed deal"), ("POST", "Create the shipment of a pending order"),
            ("PUT", "Correct the carrier and tracking code")]


def nav():
    out = [f'<div class="find">{icon("search-line")}<span style="flex:1">Search endpoints</span><span class="kbd">Ctrl J</span></div>']
    for group, tags in GROUPS:
        out.append(f'<div class="g"><div class="gh">{group}</div>')
        for name, n in tags:
            is_open = name == "Deals and orders"
            out.append(f'<div class="t{" open" if is_open else ""}"><span>{name}</span><span class="n">{n}</span></div>')
            if is_open:
                for i, (m, s) in enumerate(DEAL_OPS):
                    out.append(f'<a id="op-{i}" href="#op-{i}" class="op{" on" if i == 2 else ""}"><span class="m {m}">{m}</span><span>{s}</span></a>')
        out.append("</div>")
    out.append(f'<div class="g"><div class="t"><span>{icon("shapes-line", 15)} Models</span><span class="n">210</span></div></div>')
    return "".join(out)


RESPONSES = [
    ("200", "s2", "The deal, with the new open price.", []),
    ("400", "s4", "The body does not match the spec.", ["invalid_request"]),
    ("401", "s4", "No valid access token.", ["unauthenticated", "session_expired"]),
    ("403", "s4", "The account is suspended.", ["account_suspended"]),
    ("404", "s4", "No such deal of the caller's.", ["deal_not_found"]),
    ("409", "s4", "The deal or the listing does not allow it now.", ["move_not_allowed", "listing_unavailable", "deal_changed"]),
    ("422", "s4", "The amount breaks the offer range.", ["invalid_amount"]),
]


def responses():
    rows = "".join(
        f'<div class="rr"><span class="st {c}">{code}</span><span>{text}</span><span class="codes">{"".join(f"<span class=code>{x}</span>" for x in codes)}</span></div>'
        for code, c, text, codes in RESPONSES)
    return f'<div class="resp">{rows}</div>'


def editor(lines):
    return '<div class="editor">' + "".join(f'<div class="ln"><i>{i}</i><span>{l}</span></div>' for i, l in enumerate(lines, 1)) + "</div>"


BODY = f"""{topbar()}
<div class="page">
  <div class="ph">
    <div style="flex:1">
      <div class="crumb">API {icon("arrow-right-s-line", 14)} <span style="color:var(--text-sub)">Playground</span></div>
      <h1>API playground</h1>
      <p>Read any endpoint and call it on production, dev or your local stack. Requests go straight from this browser to the server.</p>
    </div>
    <a id="guide" href="https://docs.shopnexus.id.vn/en/api" class="btn ghost">{icon("book-open-line")} API design guide</a>
    <a id="spec" href="#openapi-json" class="btn outline">{icon("download-2-line")} openapi.json</a>
  </div>

  <div class="conn">
    <span class="lbl">Server</span>
    <span class="seg">
      <a id="srv-prod" href="#prod"><span class="dot" style="background:var(--brand)"></span>Production</a>
      <a id="srv-dev" href="#dev" class="on"><span class="dot" style="background:var(--brand)"></span>Dev</a>
      <a id="srv-local" href="#local"><span class="dot" style="background:var(--stroke-strong)"></span>Local</a>
    </span>
    <span class="url">https://api.dev.shopnexus.id.vn {icon("file-copy-line", 13)}</span>
    <span class="health"><span class="dot" style="background:var(--brand)"></span>Up · 38 ms</span>
    <span style="flex:1"></span>
    <div class="who">
      <span class="av">KL</span>
      <span><span style="color:var(--text-soft)">Signed in as</span> <b style="font-weight:500">linh.nguyen@gmail.com</b></span>
      <span class="ttl">{icon("time-line", 13)} 12:41 left</span>
      <span class="vr"></span>
      <a id="copy-token" href="#copy-token" class="iconbtn" title="Copy token">{icon("key-2-line", 17)}</a>
      <a id="sign-out" href="#sign-out" class="btn outline">Sign out</a>
    </div>
  </div>

  <div class="cols">
    <aside class="nav">{nav()}</aside>

    <main class="doc">
      <div class="crumb">Deals {icon("arrow-right-s-line", 14)} Deals and orders</div>
      <h2>Make an offer, or a counter to the buyer's offer</h2>
      <div class="path"><span class="mb POST">POST</span><span style="flex:1">/v1/deals/<b style="color:var(--brand-text)">&#123;id&#125;</b>/offer</span><a id="copy-path" href="#copy-path" class="iconbtn" style="width:30px;height:30px">{icon("file-copy-line", 15)}</a></div>
      <div class="tags">
        <a id="uc-deal-02" href="https://docs.shopnexus.id.vn/en/requirements/use-cases#uc-deal-02" class="tag uc">{icon("flow-chart", 13)} UC-DEAL-02 · Negotiate a price</a>
        <span class="tag">{icon("lock-2-line", 13)} Bearer token</span>
        <span class="tag">{icon("restart-line", 13)} Safe to retry: no</span>
      </div>
      <p class="lead">The buyer offers; the seller counters the buyer's open offer. The amount must lie inside the deal's <span class="code">offer_range</span>.</p>

      <div class="sec">
        <h3>Path <span class="k">1 parameter</span></h3>
        <div class="field"><div class="fn"><b>id</b><span class="ty">string · uuid</span><span class="req">required</span></div><p class="fd">The deal.</p></div>
      </div>

      <div class="sec">
        <h3>Body <span class="k">application/json · Offer</span></h3>
        <div class="field"><div class="fn"><b>amount</b><span class="ty">integer · int64</span><span class="req">required</span></div>
        <p class="fd">Whole đồng in multiples of 1,000, inside the deal's <span class="code">offer_range</span>. The range is a business rule, so an amount outside it is 422.</p></div>
      </div>

      <div class="sec">
        <h3>Responses <span class="k">with the error codes each one returns</span></h3>
        {responses()}
      </div>
    </main>

    <aside class="right">
      <div class="stick">
        <div class="panel">
          <div class="pt">Request<span class="sp"></span><span class="seg"><span class="on">Form</span><span>curl</span></span></div>
          <div class="addr"><span class="mb POST" style="color:var(--brand)">POST</span><span><span class="base">https://api.dev.shopnexus.id.vn</span>/v1/deals/0193f2a4-7c1e-7d42-9b6a-3e51c0a8f210/offer</span></div>
          <div class="tabsx"><span class="on">Params</span><span>Headers 2</span><span>Body</span></div>
          <div class="kv">
            <span class="k">id</span><span class="inp">0193f2a4-7c1e-7d42-9b6a…<span class="hint">from your deals</span></span>
            <span class="k">Authorization</span><span class="inp">Bearer eyJhbGciOi••••••<span class="hint">signed in</span></span>
          </div>
          {editor(['<span class="p">{</span>', '&nbsp;&nbsp;<span class="kk">"amount"</span><span class="p">:</span> <span class="nu">1200000</span>', '<span class="p">}</span>'])}
          <div class="foot">
            <span class="meta">{icon("information-line", 14)} offer_range on this deal: 900,000 – 1,450,000</span>
            <span style="flex:1"></span>
            <a id="send" href="#send" class="btn pri">{icon("send-plane-2-line")} Send <span class="kbd" style="background:rgba(255,255,255,.16);border-color:transparent;color:#fff">Ctrl ↵</span></a>
          </div>
        </div>

        <div class="panel">
          <div class="pt">Response<span class="sp"></span><span class="status w">422 Unprocessable</span><span class="meta">96 ms</span></div>
          {editor(['<span class="p">{</span>',
                   '&nbsp;&nbsp;<span class="kk">"error"</span><span class="p">: {</span>',
                   '&nbsp;&nbsp;&nbsp;&nbsp;<span class="kk">"code"</span><span class="p">:</span> <span class="s">"invalid_amount"</span><span class="p">,</span>',
                   '&nbsp;&nbsp;&nbsp;&nbsp;<span class="kk">"message"</span><span class="p">:</span> <span class="s">"the amount is outside the offer range; see fields"</span><span class="p">,</span>',
                   '&nbsp;&nbsp;&nbsp;&nbsp;<span class="kk">"fields"</span><span class="p">: {</span> <span class="kk">"amount"</span><span class="p">:</span> <span class="s">"out_of_range"</span> <span class="p">},</span>',
                   '&nbsp;&nbsp;&nbsp;&nbsp;<span class="kk">"trace_id"</span><span class="p">:</span> <span class="s">"4bf92f3577b34da6a3ce929d0e0e4736"</span>',
                   '&nbsp;&nbsp;<span class="p">}</span>', '<span class="p">}</span>'])}
          <div class="explain">{icon("error-warning-line", 18, "")}<span><b style="font-weight:600">invalid_amount</b> is exception flow <a id="flow-e6" href="https://docs.shopnexus.id.vn/en/requirements/use-cases#uc-deal-02" style="color:var(--link);text-decoration:underline">UC-DEAL-02 E6</a>: the price is off the 1,000 step or outside the range (BR-DEAL-03).</span></div>
          <div class="foot" style="padding-top:10px"><span class="meta">{icon("fingerprint-line", 14)} Trace-Id 4bf92f35…4736</span><span style="flex:1"></span><a id="copy-response" href="#copy-response" class="btn ghost">{icon("file-copy-line")} Copy</a></div>
        </div>
      </div>
    </aside>
  </div>
</div>"""

if __name__ == "__main__":
    print(shell("API playground", BODY, CSS))
