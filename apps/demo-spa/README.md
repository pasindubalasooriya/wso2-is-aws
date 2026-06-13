# Demo SPA - "Sign in with WSO2 IS"

A ~120-line single-page app that logs a user in through your IdP using **OpenID
Connect (authorization code + PKCE)** and displays the ID-token claims - proof
the login really went through your WSO2 cluster.

## 1. Register the OIDC app in the console

Open `https://<alb-dns>/console` (from your admin IP), log in as `admin`, then:

1. **Applications → New Application → Standards-Based Application → OpenID Connect**.
2. Name it `demo-spa`.
3. **Protocol** settings:
   - **Allowed grant types**: tick **Code** (for the SPA) *and* **Password** (so the
     same client works for the attack/login CLI scripts in `scripts/demos/`).
   - **Public client**: enable (SPA can't keep a secret) - *or* keep it confidential
     and note the client secret for the CLI scripts.
   - **Authorized redirect URLs**: `http://localhost:8080/` (where you'll serve this).
   - **Allowed origins (CORS)**: `http://localhost:8080`.
4. Save. Copy the **Client ID** (and **Client Secret** if confidential).
5. Create a test user: **User Management → Users → Add User** (e.g. `victim`) with a
   known password - used for the login demo and as the credential-stuffing target.

## 2. Serve the SPA locally

```bash
cd apps/demo-spa
python -m http.server 8080
# open http://localhost:8080/
```

In the page, fill **IdP base URL** (`https://<alb-dns>`), **Client ID**, leave the
redirect URI as `http://localhost:8080/`, click **Save config**, then **Login**.


