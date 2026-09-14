# Safe return URLs with `new URL()` — reject protocol-relative paths

A return-URL helper must distinguish an internal path from a protocol-relative
URL. `//evil.example/steal` starts with `/`, but browsers interpret it as an
external URL using the current scheme.

## The bug

This path-only check is an open redirect:

```ts
export const getSafeReturnUrl = (candidate, fallbackPath) => {
  if (!candidate?.startsWith('/')) return fallbackPath
  return candidate
}
```

`//evil.example/steal` passes `startsWith('/')`; when used in a `Location`
header or client redirect, it navigates to `https://evil.example/steal`.

## The fix

Resolve slash-prefixed paths and require the resolved origin to match. Parse
absolute URLs without a base, then apply the same origin check:

```ts
export const getSafeReturnUrl = (candidate, fallbackPath, appBaseUrl) => {
  const baseUrl = new URL(appBaseUrl)
  const fallback = new URL(fallbackPath, baseUrl)
  if (!candidate) return fallback.toString()

  if (candidate.startsWith('/')) {
    const requested = new URL(candidate, baseUrl)
    return requested.origin === baseUrl.origin
      ? requested.toString()
      : fallback.toString()
  }

  try {
    const absolute = new URL(candidate)
    return absolute.origin === baseUrl.origin
      ? absolute.toString()
      : fallback.toString()
  } catch {
    return fallback.toString()
  }
}
```

The resolved-origin check rejects both `//evil.example/steal` and
`/\\evil.example/steal`; the WHATWG parser treats the latter as an external URL.
Malformed strings such as `ht!tp://evil.example/steal` resolve to internal paths
and are not open redirects. Reject them separately if the product requires a
strict return-path allowlist.

## Regression test cases

- `undefined` / `''` → fallback
- `'ht!tp://%%%not a url'` → fallback
- `'//evil.com/steal'` → fallback
- `'/\\evil.com/steal'` → fallback
- `'https://evil.example/steal'` → fallback
- `'/dashboard?ok=1'` → `base/dashboard?ok=1`
- `'https://app.example/ok'` (same origin) → allowed

## Why this matters for agents

Treat a redirect that accepts a user-controlled path as a stop-and-verify
trigger. Prefer an explicit allowlist of internal paths for authentication or
callback flows. Severity is typically Medium, but rises to High when an
auth/login/callback endpoint enables credential theft or token disclosure.
