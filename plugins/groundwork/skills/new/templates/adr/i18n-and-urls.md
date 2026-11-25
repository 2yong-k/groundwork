# NNNN — Multiple languages and URLs
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
With two or more languages, or when search visibility matters, whether the language goes in the URL and how time is stored must be settled before the first page is built. If a cookie or Accept-Language alone picks the language, search engines cannot find the other language versions.

## Decision
- **URL strategy.** Use the path prefix `/[lang]`. The default language is allowed without a prefix: {{default_locale_policy}}. Put the server-rendered `<html lang>`, hreflang (with x-default, and a canonical that points at itself) and sitemap alternate links in from the first public page.
- **Supported languages.** {{locales}}. One language registry holds the per-language font stacks and line-break rules.
- **Dictionaries.** Build the per-language dictionary type from the default language file, so a missing key fails typecheck. No on-screen text written directly in code (check: rg). The server sends error codes, not sentences with a language in them.
- **Language of content users · AI make.** **Store it in the data** as a language column: {{content_language_policy}}. When rendering, put `lang` on elements that have a text size token.
- **Time.** Store · transfer UTC times and show them in the viewer's locale and time zone. Define the meaning of deadline · start · settlement once and share the formatter.
- **CJK fonts.** Pick the per-language font stacks with `:lang()`, and break Korean lines by word. Load CJK fonts only for supported languages, self-hosted.
- (native app) Use language resource files and deep link rules instead of the URL strategy. (webview shell) Follow the web URL strategy and settle the rule for passing the app language to the web: {{app_locale_rule}}. Keep this line only in projects with a native app or webview shell on, and delete the parenthesized part of a form that is not on.

## Alternatives
- Switch the language at the same URL by cookie · Accept-Language: per-language pages are not indexed.
- Write translations straight into components with no dictionary: machines cannot find what is missing.

## Consequences
- Every link must know the language.
- Adding a language grows the dictionary files and font rules with it.

## How to verify
- Delete a key from a dictionary and check that typecheck fails.
- Check that the hardcoded on-screen text check catches an intended violation.
- Validate the hreflang and sitemap of a sample page.
