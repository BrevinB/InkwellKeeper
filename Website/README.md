# Inkwell Keeper — Universal Links site

This folder is the source for the website that powers Inkwell Keeper's QR codes and
deep links. Hosting it is what makes a scanned QR code:

- **open the app** when Inkwell Keeper is installed, and
- **go to the App Store** when it isn't.

A custom URL scheme (`inkwellkeeper://…`) can't do the second case — that's why these
files must live on a real `https://` host you control.

## What's here

| File | Purpose |
|------|---------|
| `.well-known/apple-app-site-association` | The AASA file. iOS downloads this to verify the app may open links on this domain. **No file extension.** |
| `.nojekyll` | Forces GitHub Pages to serve dotfolders like `.well-known/`. Without it, Jekyll hides the AASA and Universal Links silently never work. |
| `deck/`, `card/`, `set/` `index.html` | Fallback pages for visitors **without** the app — they redirect to the App Store. |
| `index.html` | Root landing page (also redirects to the App Store for now). |

The AASA `appIDs` value is `<TeamID>.<BundleID>` = `YFXZ6WNN53.co.brevinb.Inkwell-Keeper`.

## Deploy to GitHub Pages

1. Create a repo (e.g. `inkwellkeeper-site`) and copy the **contents** of this folder to its
   root (so the AASA ends up at `/.well-known/apple-app-site-association`).
2. Push, then in repo **Settings → Pages**, set Source = `main` branch, `/ (root)`.
3. Add your custom domain (Settings → Pages → Custom domain), e.g. `inkwellkeeper.app`.
   GitHub creates a `CNAME` file — leave it.
4. In Cloudflare DNS for the domain, point it at GitHub Pages:
   - `A` records for the apex → GitHub Pages IPs (`185.199.108.153`, `.109.153`, `.110.153`, `.111.153`), **or** a `CNAME` for a subdomain → `<user>.github.io`.
   - Set the Cloudflare records to **DNS only** (grey cloud), not proxied — Apple's CDN
     fetches the AASA and the orange-cloud proxy can interfere. You can re-enable proxy
     later once verified.
5. Wait for HTTPS to provision (GitHub issues the cert automatically).

## Verify before relying on it

```sh
# AASA must return HTTP 200 and JSON (not 404, not HTML):
curl -I https://inkwellkeeper.app/.well-known/apple-app-site-association
curl    https://inkwellkeeper.app/.well-known/apple-app-site-association

# Fallback page should redirect to the App Store:
curl -I https://inkwellkeeper.app/deck
```

Then check Apple's view (it can lag a day after first deploy):
https://app-site-association.cdn-apple.com/a/v1/inkwellkeeper.app

On a **device**: install a build with the Associated Domains entitlement, then tap a
`https://inkwellkeeper.app/deck?code=…` link in Notes/Messages — it should open the app.
First install needs network so iOS can fetch the AASA.

## If you use a domain other than `inkwellkeeper.app`

Change it in **three** places, all to the same host:
1. `Inkwell Keeper/Services/AppLinks.swift` → `universalHost`
2. `Inkwell Keeper/Inkwell Keeper.entitlements` → `applinks:<domain>`
3. This site's custom domain (and the App Store URLs in the HTML if needed)

## Content-type note

Apple no longer strictly requires the AASA be served as `application/json` (the file has no
extension on purpose). GitHub Pages serves it fine. If you ever switch to Cloudflare Pages,
it also handles this correctly out of the box.
