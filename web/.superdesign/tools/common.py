"""Shared pieces of the docs mockups: the document shell with the site's tokens, the top bar and the page header.

Values come from src/styles/tokens.css (light theme) and the layout components under src/components/layout/.
"""

LOGO = ("https://vgbujcuwptvheqijyjbe.supabase.co/storage/v1/object/public/hmac-uploads/projects/"
        "8d739981-a7e4-4382-93ab-20f3edd7705c/brand-assets/docs-web-public-brand-mark.svg/mark.svg")

TOKENS = """
:root{--bg-page:#ffffff;--bg-nav:#fbfbfa;--bg-subtle:#f5f5f3;--bg-hover:#efefec;--bg-selected:#e8e8e4;--bg-raised:#ffffff;
--stroke-soft:#ecece9;--stroke-sub:#dcdcd8;--stroke-strong:#c4c4bf;--text-strong:#1a1a19;--text-body:#3a3a37;--text-sub:#5e5e5a;
--text-soft:#8c8c87;--brand:#066a61;--brand-soft:#e6f2f0;--brand-line:#c2e0db;--brand-text:#005049;--on-brand:#ffffff;
--link:#005049;--info:#2563eb;--info-soft:#eef4ff;--info-line:#d6e4ff;--warning:#c2410c;--warning-soft:#fff4eb;--warning-line:#fcdcc4;
--danger:#dc2626;--danger-soft:#fef1f1;--danger-line:#fbd5d5;--feature:#6d4aff;--feature-soft:#f3f0ff;--feature-line:#e4dcff;
--shadow-chip:0 1px 2px rgba(20,20,19,.06);--shadow-card:0 6px 20px -8px rgba(20,20,19,.18);
--sans:"Inter",ui-sans-serif,system-ui,sans-serif;--mono:"JetBrains Mono",ui-monospace,SFMono-Regular,monospace}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg-page);color:var(--text-strong);font-family:var(--sans);
-webkit-font-smoothing:antialiased}a{color:inherit;text-decoration:none}.mono{font-family:var(--mono)}
iconify-icon{display:inline-block;vertical-align:middle}
.kbd{font:500 11.5px var(--sans);min-width:20px;height:20px;padding:0 5px;border-radius:6px;border:1px solid var(--stroke-soft);
background:var(--bg-subtle);color:var(--text-sub);display:inline-flex;align-items:center;justify-content:center}
.chip{display:inline-flex;align-items:center;gap:4px;height:24px;padding:0 9px;border-radius:999px;font-size:12px;font-weight:500}
.topbar{position:sticky;top:0;z-index:40;height:64px;display:flex;align-items:center;gap:24px;padding:0 24px;
border-bottom:1px solid var(--stroke-soft);background:rgba(251,251,250,.9);backdrop-filter:blur(12px)}
.brand{display:flex;align-items:center;gap:10px;font-size:15px;font-weight:600;letter-spacing:-.01em;white-space:nowrap}
.tabs{display:flex;align-self:stretch;align-items:center;gap:4px;font-size:14px}
.tab{position:relative;height:36px;padding:0 12px;border-radius:10px;display:flex;align-items:center;color:var(--text-sub)}
.tab.on{color:var(--text-strong);font-weight:500}
.tab.on::after{content:"";position:absolute;left:12px;right:12px;bottom:-14px;height:2px;border-radius:999px;background:var(--text-strong)}
.search{width:260px;height:36px;padding:0 12px;border-radius:10px;border:1px solid var(--stroke-sub);background:var(--bg-raised);
display:flex;align-items:center;gap:8px;font-size:14px;color:var(--text-soft)}
.seg{display:inline-flex;padding:3px;border-radius:10px;background:var(--bg-subtle);border:1px solid var(--stroke-soft)}
.seg a,.seg span{height:28px;padding:0 10px;border-radius:7px;display:inline-flex;align-items:center;gap:6px;font-size:13px;
font-weight:500;color:var(--text-sub)}
.seg .on{background:var(--bg-page);color:var(--text-strong);box-shadow:var(--shadow-chip)}
.iconbtn{width:36px;height:36px;border-radius:10px;display:flex;align-items:center;justify-content:center;color:var(--text-body)}
"""


def shell(title, body, css=""):
    """One complete draft document: fonts, iconify, tokens, a single root div."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;650;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
<script src="https://code.iconify.design/iconify-icon/2.1.0/iconify-icon.min.js"></script>
<style>{TOKENS}{css}</style>
</head>
<body>
<div id="root">
{body}
</div>
</body>
</html>
"""


def icon(name, size=16, cls=""):
    return f'<iconify-icon icon="ri:{name}" width="{size}" height="{size}" class="{cls}"></iconify-icon>'


TABS = [("get-started", "Get started"), ("marketplace", "Marketplace"), ("requirements", "Requirements"),
        ("architecture", "Architecture"), ("api", "API"), ("operations", "Operations")]


def topbar(active="api"):
    tabs = "".join(
        f'<a id="tab-{k}" href="#tab-{k}" class="tab{" on" if k == active else ""}">{v}</a>' for k, v in TABS)
    return f"""<header class="topbar">
  <a id="brand-home" href="#home" class="brand"><img src="{LOGO}" width="28" height="28" alt="ShopNexus">ShopNexus <span style="color:var(--text-soft);font-weight:500">Docs</span></a>
  <nav class="tabs">{tabs}</nav>
  <span style="flex:1"></span>
  <a id="site-search" href="#search" class="search">{icon("search-line")}<span style="flex:1">Search docs...</span><span class="kbd">Ctrl K</span></a>
  <span class="seg"><span class="on">EN</span><span>VI</span></span>
  <span class="iconbtn">{icon("computer-line", 18)}</span>
</header>"""
