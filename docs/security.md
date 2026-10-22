# Administration and trust boundary

Crafty is bound to `127.0.0.1:8443`. No IPv6 wildcard, reverse proxy, RCON, JMX or
Query publication is configured. Use the SSH tunnel in the README. SSH is on port 22
on this host; preserve host-key verification. On shared client machines, bind the
local tunnel to 127.0.0.1 too.

The generated login file is `runtime/config/default-creds.txt` (inside the container:
`/crafty/app/config/default-creds.txt`). Read it privately, change the password on first
login, and store the replacement in a password manager. Never run a support-log upload
without checking it for secrets. Runtime files and backups are excluded from Git.

TOTP: profile menu → **Account Settings → Multi Factor Auth → Add New Multi Factor
Auth**, name the token, scan the QR, enter a current code, verify and save recovery
codes outside Git. Log out and test login before closing your existing SSH session.
Then **Panel Settings → config.json → Security → Require superusers to enable MFA**.
Additional users should receive only the servers/actions needed through roles;
disable unused accounts. These interactive enrollment steps are not automated.

For TLS, compare the certificate served through the tunnel with one retrieved directly
on the VPS over trusted SSH:

```bash
openssl s_client -connect 127.0.0.1:8443 </dev/null 2>/dev/null |
  openssl x509 -noout -fingerprint -sha256 -dates
```

Accept a browser exception only for this verified tunnel endpoint. Do not disable
certificate verification globally. The local health probe uses an unverified TLS
context solely for the loopback self-signed endpoint. Persistent config preserves
panel accounts/MFA and TLS across recreation.

Crafty can execute processes and modify all instance files. JARs from a compromised
plugin author can cross instance boundaries in this single-container model. AuthMe
protects player actions; it cannot sandbox plugins or stop volumetric DDoS, server
vulnerabilities, malicious administrators or disk failure. Offline-mode protocol
connections do not provide Microsoft's normal authenticated encrypted login channel:
use unique Minecraft passwords, never passwords reused for email or panel accounts.

Docker-published ports can bypass UFW INPUT policy. See [networking](networking.md).
Loopback bootstrap avoids relying on unverified firewall rules. Other host processes
and users with Docker access remain trusted; Docker access is effectively host-root
authority. No additional Docker access is delegated to Crafty.

Sources: [Crafty TOTP](https://docs.craftycontrol.com/pages/user-guide/user-authentication/totp-configuration/),
[Docker port publishing](https://docs.docker.com/engine/network/port-publishing/).
