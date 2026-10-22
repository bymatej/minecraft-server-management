# Family Paper authentication

## Version choice matters

The requested server is **Paper 1.21.4, Java 21**. AuthMe's latest stable release was
6.0.1 on inspection (2026-10-22), but both its Paper and Spigot-1.21 JARs declare
`api-version: 1.21.11`. They will not load on 1.21.4. The Legacy build advertises
1.16–1.19 and is not selected as a workaround. Do not patch plugin metadata to force
an incompatible build to load.

For the fixed 1.21.4 example, pin **AuthMe 5.7.0** (Java 17 minimum, API 1.16), whose
manifest is compatible with loading on this Paper generation. Its actual startup
and gameplay checks are still required below. It does not have the 6.x premium or
pre-join-dialog features implicated in the 6.0.1 fixes. This is not a promise that an
older release has no vulnerabilities. If it fails any test, keep the port private.
A future Minecraft upgrade should use the matching current stable AuthMe build and
repeat the full acceptance sequence; do not upgrade the requested version silently.

Official download:
https://github.com/AuthMe/AuthMeReloaded/releases/download/5.7.0/AuthMe-5.7.0.jar

SHA-256 supplied by GitHub's release API and checked on the downloaded file:

```text
67cc5c1923315cedc152616abce81cf79d004d44cb8fe9ab4d0b262728f23e08
```

The pinned file is staged in `.tools/downloads/AuthMe-5.7.0.jar`, not committed to Git.
Reproduce both plugin downloads with `bash scripts/download-family-plugins.sh`.
Upload only this selected AuthMe JAR to the family's `plugins` directory. Never leave
multiple AuthMe builds there. The investigated 6.x assets are not installation choices.

## Bootstrap, without a race to register names

1. Keep gameplay unpublished or use the loopback temporary port/SSH tunnel in
   [networking](networking.md). No public registration window.
2. Create **Family Paper**, choose 1.21.4, Java 21, 512 MiB minimum / 2 GiB maximum
   heap. Stop it and apply `examples/family-paper/server.properties` before gameplay.
   Keep `online-mode=false`, `enforce-secure-profile=false`, `white-list=true` and
   `enforce-whitelist=true`. No proxy integration, no RCON, no command blocks.
3. Upload AuthMe 5.7.0 and CoreProtect CE 24.1 through **Files → plugins**. Start
   privately to generate configs. Check the console for successful enable messages
   and plugin exceptions, then stop again.
4. Merge `examples/family-paper/authme-settings.yml` into
   `plugins/AuthMe/config.yml`. Preserve other generated keys; do not replace the
   entire file with the overlay. Use SQLite, BCrypt, forced password registration
   and login, no sessions, movement/chat blocked, narrowly allowed auth commands,
   120-second shared login/registration timeout and a 10-minute IP ban after five
   incorrect attempts. BCrypt cost defaults to 12 in this version. Keep automatic
   account purging disabled so old family names cannot silently become claimable.
5. Ensure `Hooks.bungeecord=false`, no FastLogin/premium-bypass plugins, no unrestricted
   names/inventories and no `authme.bypass*` grants. AuthMe 5.7.0 has no 6.x premium
   toggle to copy. `Security.SQLProblem.stopServer=true` fails closed on DB failure;
   a missing/disabled JAR is still a deployment error, so check every startup.
6. Add only the **actual approved names**, exact spelling/case, through the trusted
   Crafty console: `whitelist add NAME`. Keep `ops.json` empty initially. Inspect
   `whitelist.json` to verify offline UUIDs; do not reuse online-mode UUID entries.
7. Start privately. Each actual family member joins through the trusted tunnel,
   types `/register PASSWORD PASSWORD`, then `/login PASSWORD`. Choose separate
   strong passwords. Never send those commands through shared logs/chat or put
   credentials in this repository. Run every test below.
8. After all approved names are registered, set `settings.registration.enabled=false`
   while stopped and restart. Existing accounts can still log in; reopening enrollment
   for a new name must happen privately. Do not use `authme unregister` casually.
9. Capture a known-good baseline after testing. Open the family's public mapping only
   after an authorized legacy cutover. Verify from an outside connection again.

AuthMe's optional inventory-packet hiding needs an extra protocol plugin in some
versions; it is not claimed here. Blocking inventory interaction and modifying the
world must pass real-client tests without adding unnecessary dependencies.

## UUIDs, whitelists and OP

Offline Java derives an identity from the case-sensitive string `OfflinePlayer:NAME`
(name-based UUID v3). It proves no Microsoft ownership. Someone choosing that name
gets the same identity and could otherwise inherit inventory, whitelist and OP.
Changing online-mode later changes identity mapping and can strand player data.
Keep AuthMe's `preventOtherCase=true` and check case variants during acceptance.

AuthMe temporarily removes OP during its unauthenticated/limbo state and restores it
after successful login. Verify this behavior on the deployed build; it is not a reason
to make everyone OP. Prefer the trusted Crafty console for administration. If needed,
after authenticating your own account issue `op YOUR_NAME` in that console, disconnect
and test impersonation with the exact name **and case**. A wrong/no password must not
allow `/op`, `/give`, `/gamemode`, CoreProtect or any world interaction. Use `deop
YOUR_NAME` to remove privileges. Never grant `authme.admin.*` or bypass permissions to
family accounts. AuthMe's limbo and database files are covered by the cold backup.

## Required acceptance tests (real clients)

Record pass/fail, plugin versions and date before setting `FAMILY_BIND=0.0.0.0`:

| Test | Expected result |
| --- | --- |
| New, approved name through private tunnel | Registration works once; subsequent joins require login |
| Registered name, no password | No movement, block break/place, item pickup/drop, chest access, damage or arbitrary command |
| Same name, wrong password | Rejected; repeated failures trigger configured temporary ban |
| Same name from a second client while owner authenticates/is online | Cannot inherit session, evict/bypass authentication or act as owner |
| Unapproved name / capitalization variant | Whitelist/case enforcement rejects entry |
| Previously OP name, unauthenticated | No administrative command or rollback access |
| Correct password | Normal intended gameplay allowed |
| Restart instance and recreate Crafty | Existing password still required; account DB persists |
| Registration disabled after enrollment | Unregistered accounts cannot claim a name |
| Plugin error/missing AuthMe | Keep endpoint private and stop instance; never accept this state |

Temporary IP bans can affect everyone behind the same NAT or SSH tunnel. Wait out a
test ban or remove it using the documented administrator workflow; do not weaken
rate limits just to make testing convenient. Test OP impersonation last, with a backup.

References: [5.7.0 release](https://github.com/AuthMe/AuthMeReloaded/releases/tag/5.7.0),
[versioned configuration](https://github.com/AuthMe/AuthMeReloaded/blob/5.7.0/docs/config.md),
[6.0.1 release/security fixes](https://github.com/AuthMe/AuthMeReloaded/releases/tag/6.0.1).
