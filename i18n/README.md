# Languages

The app, the website and the server write Vietnamese today and are built to
add English. The design is in
`docs/superpowers/specs/2026-11-23-i18n-design.md`. Words follow
`docs/manual/thuat-ngu.md`.

## Where text lives

| Text | Where | Language picked by |
|---|---|---|
| App screens | `app/**/src/main/res/values/strings.xml`, plurals in the same files; formatting in `core:model` `Formats` | the app's language (Android per-app language) |
| Website pages | `website/src/i18n/vi/<area>.ts`; formatting in `website/src/i18n/format.ts` | the URL (Vietnamese has no prefix) |
| Notices, pushes, mail | `server/internal/notification/domain/text/<tag>.json` | the request's `Accept-Language` for the list; `accounts.locale` for pushes and mail |
| OTP mail | `server/internal/account/service/mail/<tag>.json` | the request's `Accept-Language` |
| Mail layout | `server/internal/platform/mailview/locales/<tag>.json` | the letter's language |

The API sends codes and parameters (error `field_codes`, photo
`failure_code`, scam signal `params`), and each client writes the sentence.
The server writes text only for what it composes from its own state:
notices, pushes, mail.

Keys are grouped by where the text appears. The server catalogs use
`notice.*` for notice text, `title.*` for push titles and mail headers,
`push.*` for chat push bodies, `mail.*` for mail and `money.*`/`name.*` for
shared words. Formats use indexed verbs (`%[1]s`) so a language can reorder
values. Website browser scripts read the `browser` part of each area, which
Layout embeds as JSON, so scripts carry no dictionary.

## Adding text

1. Pick the area that owns the screen (`orders`, `account`…, a feature
   module's `strings.xml`, a server catalog).
2. Write the Vietnamese with the glossary's terms. A count with a noun is a
   plural on the app and a function on the website.
3. Read it through `t` (website), `stringResource` (app) or `say` (server).
   A code from the API gets its label from the client's dictionary.

## Adding a language

- Server: a `<tag>.json` beside each `vi.json` and the tag in
  `locale.Supported`.
- Website: `src/i18n/<tag>.ts` typed as `Dict`, the tag in `LANGS`, and the
  `/<tag>` prefix in `langOf`.
- App: `values-<tag>/strings.xml` and the tag in `locales_config.xml`.
- Each platform's `format` tests read `format-cases.json`; add the language's
  column there.

## Checks

| Check | Fails on |
|---|---|
| server: `locale.MustLoad` at start | a language missing a key or having an extra one |
| server: each catalog's `localetest.Keys` test | a key the code writes that a catalog lacks, and a catalog key no code writes |
| website: `npx astro check` | a language missing a key (types) and a key no dictionary has |
| website: `node --test src/i18n/*.test.ts` | a format case, and a dictionary key no code names |
| app: lint `MissingTranslation`, `UnusedResources` | a string missing in a language, a string no code reads |
| umbrella: `make i18n` | a repo's `format-cases.json` that differs from `docs/i18n/format-cases.json`, and a glossary term listed under "Không dùng" in any product's UI text |

`docs/i18n/sync.sh` copies `format-cases.json` into the three repos after
you change it.
