# Inkwell Keeper — Universal Links site

Source for the website that powers Inkwell Keeper's QR codes / deep links. Hosting it makes a
scanned QR **open the app** when installed and **go to the App Store** when not.

## Files (all must sit at the REPO ROOT, not in a subfolder)

| File | Purpose |
|------|---------|
| `CNAME` | Binds the custom domain `inkwellkeeper.app`. **Keeping this committed is what stops the site from un-binding ("There isn't a GitHub Pages site here") on redeploys.** |
| `.well-known/apple-app-site-association` | AASA file iOS downloads to verify the app may open links on this domain. No file extension. |
| `.nojekyll` | Forces GitHub Pages to serve dotfolders like `.well-known/`. Without it, Jekyll hides the AASA → 404. |
| `404.html` | Catch-all fallback: any path without the app (e.g. `/card?id=…`) redirects to the App Store. Bulletproofs against a missing per-path page. |
| `index.html`, `deck/`, `card/`, `set/` | Landing + per-path fallback pages (redirect to the App Store). |

AASA `appIDs` = `<TeamID>.<BundleID>` = `YFXZ6WNN53.co.brevinb.Inkwell-Keeper`.

## Deploy

1. Copy the **contents** of this folder to the site repo root (AASA ends up at
   `/.well-known/apple-app-site-association`, and `CNAME` at the root).
2. Commit & push. Settings → Pages → Source = your branch, `/ (root)`.
3. Settings → Pages → Custom domain should already read `inkwellkeeper.app` (from the CNAME file).
   If it's blank, type it and Save once.
4. Tick **Enforce HTTPS** when available (`.app` is HSTS — it won't load over plain HTTP).

Cloudflare DNS (already done): apex A records → `185.199.108–111.153`, **DNS only / grey cloud**.

## Verify

```sh
curl -I https://inkwellkeeper.app/                                            # 200
curl -I https://inkwellkeeper.app/.well-known/apple-app-site-association      # 200 + JSON
curl -I "https://inkwellkeeper.app/card?id=test"                             # 200 (page) or 404→still redirects
```

Apple's cached copy (can lag hours after first deploy):
https://app-site-association.cdn-apple.com/a/v1/inkwellkeeper.app

## Different domain?

Change it in three places to the same host: `AppLinks.universalHost`, the app entitlement
(`applinks:<domain>`), and this `CNAME` file.
