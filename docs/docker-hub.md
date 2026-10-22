# Docker Hub

No custom image is needed. This project consumes the official
`arcadiatechnology/crafty-4:4.11.0` image directly (pinned digest in `.env.example`).
There is no Dockerfile, no `bymatej` image build, and no Docker push for this deployment.

```bash
docker compose pull
docker compose up -d
bash scripts/verify.sh --live
```

## Only if a legitimate custom image is needed later

Document what upstream cannot provide first. Do not merely re-tag/re-publish Crafty.
Respect Crafty's GPL-3.0 license, corresponding-source obligations and all bundled
software licenses before redistribution. Minecraft server JARs/mods have their own
redistribution terms; avoid bundling them without permission.

Create a Docker Hub repository such as `bymatej/minecraft-server-management` and a
scoped access token under Docker Hub account settings → personal access tokens.
Give CI only the minimum needed permission; use read-only pull tokens on deployment
hosts where possible. Authenticate interactively (paste the token as password):

```bash
docker login --username bymatej
```

Or inject a token through your secret manager/environment, without shell tracing:

```bash
printf '%s' "$DOCKERHUB_TOKEN" |
  docker login --username bymatej --password-stdin
unset DOCKERHUB_TOKEN
```

With a reviewed Dockerfile implementing the justified change, use a real release tag:

```bash
docker buildx build --platform linux/amd64 --load \
  -t bymatej/minecraft-server-management:1.0.0 .
docker push bymatej/minecraft-server-management:1.0.0
# On Contabo:
docker pull bymatej/minecraft-server-management:1.0.0
docker image inspect bymatej/minecraft-server-management:1.0.0 --format '{{json .RepoDigests}}'
```

The audited VPS is AMD64. Build ARM64 separately or deliberately publish a tested
multi-architecture manifest if that becomes necessary. Update Compose/.env to the
versioned image and digest, adjust the image-policy validator for the reviewed custom
namespace, validate, back up, recreate and run the full acceptance checks. Keep the
previous image and state for rollback. Do not rely exclusively on `latest`.

```bash
docker logout
```

Use a Docker credential helper where available. Without one, Docker's config may
store base64 credentials, not encryption. Restrict its permissions and do not commit
or print it. Revoke unused tokens and rotate any exposed token immediately.

Reference: [Docker Hub access tokens](https://docs.docker.com/security/access-tokens/).
