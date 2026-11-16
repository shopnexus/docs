"""Build the current API playground: python3 build_playground_current.py > ../mockups/playground-current.html

Ground truth for /en/api/playground as it renders today (light, 1440 wide): the site's top bar, the wide page
header (breadcrumb, title, description, chips, Copy page) and Scalar 1.76.4 below it, themed from the site's
tokens: a 288px sidebar of tag groups, the intro from info.description, and the Server, Authentication and
Client Libraries cards on the right.
"""
from common import icon, shell, topbar

CSS = """
.head{max-width:1096px;padding:40px 48px 24px}
.crumb{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--text-soft)}
h1{margin:12px 0 0;font-size:36px;line-height:44px;font-weight:650;letter-spacing:-.025em}
.desc{margin:16px 0 0;max-width:1000px;font-size:18px;line-height:30px;color:var(--text-sub)}
.meta{margin-top:20px;display:flex;align-items:center;gap:10px;font-size:13px;color:var(--text-soft)}
.copy{margin-left:auto;height:28px;padding:0 10px;border-radius:8px;border:1px solid var(--stroke-sub);display:flex;align-items:center;gap:6px;color:var(--text-body)}
.app{display:flex;border-top:1px solid var(--stroke-soft)}
.side{width:288px;flex:none;background:var(--bg-nav);border-right:1px solid var(--stroke-soft);padding:12px;min-height:700px}
.sq{height:32px;border-radius:8px;border:1px solid var(--stroke-sub);background:var(--bg-page);display:flex;align-items:center;gap:8px;padding:0 10px;font-size:14px;color:var(--text-soft)}
.grp{display:flex;align-items:center;justify-content:space-between;height:33px;padding:0 8px;font-size:14px;color:var(--text-sub)}
.grp.on{color:var(--text-strong);font-weight:500}.sub{padding-left:28px}
.main{flex:1;padding:72px 60px 0 60px;display:flex;gap:48px}
.intro{width:492px;font-size:16px;line-height:26px;color:var(--text-body)}
.ver{display:flex;gap:6px}.ver span{font-size:12px;padding:1px 6px;border-radius:6px;border:1px solid var(--stroke-sub);color:var(--text-sub)}
.intro h2{margin:6px 0 10px;font-size:24px;line-height:32px;font-weight:650;color:var(--text-strong)}
.intro h3{margin:28px 0 10px;font-size:20px;font-weight:650;color:var(--text-strong)}
.intro a.dl{color:var(--link);text-decoration:underline;text-underline-offset:4px;font-weight:500}
.intro code{font:12.5px var(--mono);background:var(--bg-subtle);border:1px solid var(--stroke-soft);border-radius:4px;padding:1px 4px}
.intro ol{padding-left:22px;margin:0}.intro li{margin:6px 0}
.cards{flex:1;padding-top:62px;display:flex;flex-direction:column;gap:14px}
.card{border:1px solid var(--stroke-soft);border-radius:12px;overflow:hidden;background:var(--bg-page)}
.card .h{background:var(--bg-subtle);padding:8px 12px;font-size:14px;font-weight:500;display:flex;justify-content:space-between;color:var(--text-strong)}
.card .r{padding:8px 12px;font-size:14px;color:var(--text-body);border-top:1px solid var(--stroke-soft)}
.libs{display:flex;gap:22px;padding:8px 24px;font-size:14px;color:var(--text-sub);border-top:1px solid var(--stroke-soft)}
.libs .on{color:var(--text-strong);border-bottom:2px solid var(--text-strong);padding-bottom:6px}
"""

GROUPS = [("Introduction", False, []), ("Accounts", True, ["auth", "account", "media"]),
          ("Listings and search", False, []), ("Deals", False, []), ("After the sale", False, []),
          ("App screens", False, []), ("Staff console", False, []), ("System", False, []), ("Models", False, [])]


def sidebar():
    rows = []
    for name, open_, subs in GROUPS:
        rows.append(f'<div class="grp{" on" if name == "Introduction" else ""}">{name}{icon("arrow-down-s-line" if open_ else "arrow-right-s-line")}</div>')
        rows += [f'<div class="grp sub">{s}{icon("arrow-right-s-line")}</div>' for s in subs]
    return f'<aside class="side"><div class="sq">{icon("search-line")}<span style="flex:1">Search</span><span class="kbd">⌃ J</span></div><div style="margin-top:20px">{"".join(rows)}</div></aside>'


BODY = f"""{topbar()}
<div class="head">
  <div class="crumb">API {icon("arrow-right-s-line", 14)} <span style="color:var(--text-sub)">Playground</span></div>
  <h1>Playground</h1>
  <p class="desc">Every endpoint of the spec, with a form to call it. Pick production, dev or a local stack under Server; sign in with an email code, then paste the access token under Authentication.</p>
  <div class="meta">
    <span class="chip" style="background:var(--brand-soft);color:var(--brand-text)">{icon("code-s-slash-line", 13)} Developers</span>
    <span class="chip" style="background:var(--bg-subtle);color:var(--text-sub);border:1px solid var(--stroke-soft)">{icon("file-list-3-line", 13)} Reference</span>
    <span>{icon("time-line", 13)} 1 min read</span><span>·</span><span>Updated 16 Nov 2026</span>
    <a id="copy-page" href="#copy" class="copy">{icon("file-copy-line", 14)} Copy page</a>
  </div>
</div>
<div class="app">
  {sidebar()}
  <div class="main">
    <div class="intro">
      <div class="ver"><span>v0.1.0</span><span>OpenAPI 3.2.0</span></div>
      <h2>ShopNexus API</h2>
      <a id="download-spec" href="#openapi" class="dl">Download OpenAPI Document</a>
      <p>The HTTP contract between the ShopNexus app and its server. The server validates every request against this document, and the end-to-end suite validates every response against it. The docs site explains each module: <a id="docs-api" href="https://docs.shopnexus.id.vn/en/api" class="dl">https://docs.shopnexus.id.vn/en/api</a>.</p>
      <h3>Signing in</h3>
      <ol>
        <li><code>POST /v1/auth/email-codes</code> mails a six-digit code to an email address.</li>
        <li><code>POST /v1/auth/sign-in</code> with that code returns an access token and a refresh token. The first sign-in of an address creates the account.</li>
        <li>Send the access token as <code>Authorization: Bearer &lt;token&gt;</code>. It lasts 15 minutes.</li>
      </ol>
    </div>
    <div class="cards">
      <div class="card"><div class="h">Server</div><div class="r" style="border:0">https://api.shopnexus.id.vn {icon("arrow-down-s-line", 14)}</div><div class="r" style="color:var(--text-soft)">Production</div></div>
      <div class="card"><div class="h">Authentication <span style="font-weight:400;color:var(--text-sub)">Selected Auth Type: bearerAuth {icon("arrow-down-s-line", 14)}</span></div><div class="r" style="border:0">Bearer Token: <span style="color:var(--text-soft)">Token</span></div></div>
      <div class="card"><div class="h">Client Libraries</div><div class="libs"><span class="on">{icon("terminal-line", 14)} Shell</span><span>Ruby</span><span>Node.js</span><span>PHP</span><span>Python</span><span>More</span></div><div class="r mono" style="font-size:13px">Shell Curl</div></div>
    </div>
  </div>
</div>"""

if __name__ == "__main__":
    print(shell("API playground (current)", BODY, CSS))
