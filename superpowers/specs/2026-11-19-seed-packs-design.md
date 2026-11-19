# Seed packs: a documented dataset format and one loader

Date: 2026-11-19. Status: approved (chat), building.

## Problem

Wiring the app and the website needs a marketplace that looks real: many
sellers, every category filled, search and For You with enough to rank.
`cmd/devseed` posts 44 listings from the app fixtures through the HTTP API.
That path is right for a scripted scenario but cannot carry volume: each
listing goes through upload, MediaProcess, ListingPublish and ListingEmbed,
and SigLIP 2 runs on CPU in module ai.

The old system (branch `escrow`, and its compose volumes `server_db-data`
and `server_object-data` on khoakomlem-internal) still holds 135,678
listings, 125,948 of them active, with 294,901 photos (25 GB) and a BGE-M3
dense vector per listing. Its seed code (`escrow:cmd/seed`) wrote rows
straight into its own schema; it is not reused.

## Goals

- One open, documented on-disk format, a **seed pack**, that anyone can
  read without our code (JSONL, JPEG, `.npy`), with its license and source
  in its manifest.
- One loader for every pack, dev only, with two vector modes:
  `--vectors=pack` writes the pack's precomputed BGE-M3 and SigLIP 2
  vectors, `--vectors=recompute` leaves them to the server.
- Builders are separate from the loader: a pack is built once from a
  source, then loaded many times.
- Packs live outside git; the loader downloads and caches them.

- Profiles that look lived in: avatars, bios, join dates, last active,
  followers, items on sale and items sold, and the reviews both ways.
- A CLI that is pleasant to use: subcommands, `--help` with examples,
  progress bars, a dry-run summary, a confirm before writing.

Non-goals: open chats and offers in packs (`devseed`'s scenario makes a
few through the API); prod use.

## The format (pack v1)

A pack is a directory, shipped as `<name>-<version>.tar` (uncompressed:
the JPEGs do not shrink) with a `.sha256` beside it.

```
pack.json
accounts.jsonl
listings.jsonl
photos/<aa>/<sha256>.jpg      processed photo, long side ≤ 1600, JPEG q85
thumbs/<aa>/<sha256>.jpg      thumbnail, long side ≤ 400
vectors/text.npy              optional, float16 [listings, 1024]
vectors/photo.npy             optional, float16 [photos, 1152]
vectors/photo.keys.jsonl      optional, one {"listing","photo"} per row
avatars/<sha256>.jpg          400 px squares
history.jsonl                 optional, sold items: order, both reviews, replies
follows.jsonl                 optional, {"follower","followee","at"}
README.md                     what is in it, where it came from, license
```

`pack.json`:

```json
{
  "format": 1,
  "name": "vn-catalog",
  "version": "2026.11.1",
  "license": "internal-only",
  "source": "ShopNexus legacy dev database (escrow), originally Tiki product pages",
  "counts": {"accounts": 7000, "listings": 134314, "photos": 294901},
  "vectors": {
    "text":  {"model": "bge-m3@5617a9f61b028005a4858fdac845db406aefb181", "origin": "legacy"},
    "photo": {"model": "siglip2-so400m-patch16-384@29f74e673c298fd07482d8e20138179282001eb7-fp32"}
  }
}
```

The model strings are the server's `EMBED_TEXT_VERSION` and
`EMBED_IMAGE_VERSION`. The loader writes pack vectors only when they equal
the target server's versions, and falls back to `recompute` for a kind that
differs.

`accounts.jsonl`, one person per line:

```json
{"key":"a-000123","name":"Ngô Thu","bio":null,"phone":"+84900100123","commune":"26740","avatar":null}
```

Accounts also carry `joined_at`, `last_active_at` and, for some,
`avatar` (a file in `avatars/`). Phones are in a dev-only range (`+849001xxxxx`), so the dev phone verifier
signs anyone in as any pack person.

`listings.jsonl`, already valid for the server's rules (title ≤ 70,
description ≤ 1,500, price 10,000 to 1,000,000,000, a leaf category, a
commune of the 2025 list, 1 to 10 photos, ≤ 20 specs of ≤ 50 characters):

```json
{"key":"l-089877","seller":"a-000123","title":"UPZ Áo thun gân tay dài cơ bản",
 "price":129000,"description":"…","category":"fashion.men","condition":"new",
 "allow_offers":true,"commune":"26740","specs":[{"label":"Chất liệu","value":"Cotton"}],
 "photos":["3f6a…","9b02…"],"created_at":"2026-08-02T10:14:00Z","text_sha256":"…"}
```

`history.jsonl`, one sold item per line, written as a listing in status
`sold` plus a deal, a delivered order and the reviews:

```json
{"listing":{…as in listings.jsonl, "status":"sold"},"buyer":"a-000881",
 "price":118000,"ordered_at":"…","delivered_at":"…",
 "reviews":[{"role":"seller","stars":5,"text":"Đóng gói kỹ, giao nhanh.","at":"…",
             "reply":{"text":"Cảm ơn bạn nhiều!","at":"…"}},
            {"role":"buyer","stars":4,"text":"","at":"…"}]}
```

`role` is the role of the person reviewed. A review may have no text, a
short one or a long one, and at most one reply by the person reviewed (see
[two-way reviews](2026-11-19-two-way-reviews-design.md)). Until that
feature ships the loader writes only `role: seller` reviews and drops
replies, and says so.

The texts of reviews, replies and bios come from a hand-written corpus in
the builder (by star level and category root, with typos and slang mixed
in as people write), not from the legacy reviews, which were generated.

`text_sha256` is the SHA-256 of `EmbeddingText` as the builder computed it.
Row *i* of `text.npy` belongs to line *i* of `listings.jsonl`. The loader
recomputes the text with the server's own `domain.EmbeddingText`; a listing
whose text no longer matches (the function changed) gets no pack vector and
is left to `recompute`.

## Commands (server repo)

All under one dev-only command, `cmd/seedpack`, refusing any `APP_ENV` but
`dev`:

```
seedpack build legacy --db <dsn> --objects <dir> --out <dir> [--sample N]
seedpack embed --pack <dir> [--text] [--photos]
seedpack verify --pack <dir>
seedpack load  --pack <dir|url> [--vectors pack|recompute] [--limit N]
seedpack wipe  --pack <name>
```

- **build legacy** reads the old database and object folder and writes a
  pack. The mapping is in its own file, so a later source (a Chợ Tốt
  export, hand-written fixtures) is another `build <source>`:
  - sellers: the server allows 20 listings on sale per person; the old
    database has 816 sellers with up to 199. Each old seller's listings are
    split into people of at most 18, named from the old accounts.
  - category: a table from the 34 old leaf categories to the server's
    leaves, then a keyword pass inside the broad ones (`Điện thoại & Máy
    tính bảng` → `phones.iphone`, `phones.android`, `phones.tablet`); what
    nothing fits goes to the root's `.other`.
  - commune: the nearest commune point of `0005_regions` to the old
    listing's location, else to its old ward.
  - title cut at a word boundary to 70, price raised to 10,000, `damaged`
    becomes `used`, specs from the old `specifications` object.
  - photos: decoded and encoded with the media service's own `process`
    (moved from `internal/media/service` to an exported package so the
    builder and the server share it), deduplicated by SHA-256.
  - `--sample N` keeps N listings stratified by category, for laptops.
- **embed** fills `vectors/`: text through the stack's `EMBED_TEXT_*`
  endpoint (LiteLLM → BGE-M3), photos through `internal/ai/embed` (the same
  ONNX SigLIP 2 that module ai runs). Both produce exactly what the server
  would. It resumes from the last row written.
- **verify** checks counts, hashes, that every line passes the domain
  rules and that the `.npy` shapes match.
- **load** writes in batches with `COPY`: accounts, credentials, phone
  identities, uploads (`ready`, `origin = 'listing'`, photo and thumb keys
  `media/<upload>.jpg`), listings (`active`, `published_at = created_at`),
  then the objects into the store, then vectors. With `--vectors=recompute`
  it ends by running `search-reindex`. A second run skips what is there
  (keys are deterministic UUIDv5 of pack name + key). A URL pack is cached
  under `~/.cache/shopnexus/seedpacks/`.
- **wipe** deletes one pack's rows and objects by those UUIDs.

`cmd/devseed` keeps its scenario (sign-ins, saves, chat, offer, a COD
order) and reads its people and 44 listings from a small pack, `demo`,
whose builder is today's `build.py` turned into `seedpack build fixtures`.

## CLI

`seedpack` uses cobra-style subcommands with grouped help and examples,
a progress bar per stage (bytes for downloads, rows for writes), and a
summary before writing:

```
$ seedpack load vn-catalog-10k
Pack      vn-catalog-10k 2026.11.1 (internal-only)
Target    postgres-dev / rustfs-dev, APP_ENV=dev
Writes    1,040 people · 10,000 listings · 11,300 photos · 2,400 sold with 3,900 reviews
Vectors   text: pack (legacy bge-m3) · photo: pack (siglip2 fp32)
Continue? [y/N]
```

`load` options: `--vectors pack|recompute|none`, `--only
accounts,listings,history,follows`, `--limit N`, `--category phones,laptop`,
`--province 79,01`, `--sellers N` (cap people), `--photos full|first`,
`--history-ratio 0.3`, `--workers N`, `--dry-run`, `--yes`, `--json`
(machine output, no bars).

## Packs

| Pack | Content | License | Where |
|---|---|---|---|
| `demo` | 12 people, 44 listings from the app fixtures | the repo's | in the server repo, `cmd/devseed/data` (1.6 MB) |
| `vn-catalog-10k` | 10,000 listings sampled from `vn-catalog` | internal-only | object store on khoakomlem-internal |
| `vn-catalog` | 125,948 listings, 294,901 photos (~30 GB) | internal-only | object store on khoakomlem-internal |

The format and the tool are open source. The `vn-catalog` packs are not:
their titles and photos come from Tiki product pages and cannot be
republished. Their manifest says `internal-only`, and `load` prints it.

## Vectors: the legacy BGE-M3

Decided: the pack reuses the old database's dense vectors, so nobody embeds
126k texts again. They are BGE-M3 (same model and version) of the old text;
the new `EmbeddingText` adds the category name and condition word and the
title is cut for 49,902 listings, so each vector is close to, not exactly,
the vector of the new text. The manifest says `"text": "legacy"`. `load`
writes each with the hash of the listing's current text, so the server
treats it as in line, and the first edit of the listing embeds it fresh.
Listings without an old vector (about 11k) get no text row and are left to
`search-reindex`. `embed --text` still exists for a pack without vectors.

SigLIP 2 has no legacy vectors; `embed --photos` runs once on 294,901
photos (CPU, several hours) and every load after reuses them.

## Compose and the cluster

`seedpack` is a dev tool run against a stack, like `devseed` and
`search-reindex`; neither compose nor the chart gains a service. It reads
the same env as the server (`DATABASE_URL`, object store, `EMBED_*`).

## Decisions (2026-11-19)

1. Legacy BGE-M3 vectors are reused (above).
2. Hidden listings (8,366) are loaded as `hidden`, with active ones;
   drafts and pending ones are not.
3. The old reviews are dropped; reviews come from the builder's corpus.
4. Reviews are two-way with one reply, a separate feature and plan.
5. Only the old local (Tiki) photos are used; 961 listings with only
   Shopee CDN links are dropped. 133,353 listings, 150,738 photos.
