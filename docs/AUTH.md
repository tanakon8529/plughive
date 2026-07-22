# Authentication & the "easy plug" rule

plughive is **self-hosted**: every user runs their own instance and connects
their own accounts. Auth follows one rule, and every plug obeys it.

## The Rule

1. **Each user authenticates their own accounts, on their own machine.**
   Credentials live in `.env` or `config/*.local.*` — always **gitignored**,
   never committed. The project ships **no shared secrets**.

2. **Auth is a per-plug step in `setup.sh`.** Adding a plug that needs auth
   means adding one guided step to the wizard — not editing core code.

3. **Prefer providers whose web login needs no manual app registration.**
   Some providers (e.g. Anthropic) support dynamic client registration, so
   login is one browser click: `claude login`. Use that whenever available.

4. **When a provider requires its own OAuth app, the user creates ONE, once.**
   Google has **no** dynamic client registration (that's the
   `does not support dynamic client registration` error you'd hit trying
   `claude mcp login` on Google's endpoints). So the user registers a single
   OAuth "Desktop app" client in Google Cloud (~2 min), and `setup.sh` guides
   the rest (paste id/secret → authorize in the browser).

5. **Default to own-client-per-user. Never ship a shared client for a
   restricted scope.** A shared client (one client id embedded in the repo,
   used by everyone) would be capped by Google at **100 users** and show an
   "unverified app" warning until the app passes Google's (expensive)
   verification — and everyone would share one quota.

## Why the 100-user / verification limit does NOT apply here

That limit is **per OAuth client**, not per person who clones the code.

- In plughive's model, **each user creates their own client** and authorizes
  **only themselves** → every client has exactly one user (its owner) → the
  100-user cap and Google verification are **never** reached. ✅
- The limit would only bite if many people shared **one** client. We don't do
  that.

So "they clone the code and log in themselves" is exactly right, and it scales
to unlimited users — because each is an independent, single-user app.

## The trade-off, stated plainly

| Model | Per-user Google Console work | 100-user cap / verification |
|---|---|---|
| **Own client per user** (default) | ~2 min, once | Never applies |
| Shared client shipped in repo | none | Applies (100 users, unverified warning, shared quota) |

You cannot have *both* "zero Console work" *and* "no cap" for a restricted
scope like Gmail — that's Google's security model, not a plughive choice. We
pick own-client-per-user so the tool scales and stays private.

## Adding auth to a new plug (checklist)

- [ ] Put any secret in `.env` (documented in `.env.example`) or a
      gitignored `config/*.local.*` — never in committed files.
- [ ] If the provider needs a config/server, ship an opt-in
      `*.local.example.*` the user copies; keep the committed default inert.
- [ ] Add a guided step to `setup.sh` (localized in `locales/*.sh`): explain
      the one-time provider setup, prompt for secrets (hidden), run the
      authorize/login command.
- [ ] Prefer `provider login` (web, no client) when supported; fall back to
      "create your own client, then authorize" when the provider forces it.
