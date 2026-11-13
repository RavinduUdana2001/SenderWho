#!/usr/bin/env python3
"""Package a source release for Hostinger without local secrets or build caches."""
import hashlib
import json
import argparse
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

server = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--release-number", required=True, type=int)
args = parser.parse_args()
if args.release_number < 1:
    parser.error("release number must be positive")
release = f"SenderWho-Hostinger-Mailbox-Fix-v{args.release_number}"
contract = re.search(r'API_CONTRACT_VERSION = "([^"]+)"', (server / "src/health.controller.ts").read_text())
if contract is None:
    raise RuntimeError("API contract version is missing")
output = server.parent / "output"
output.mkdir(exist_ok=True)
archive = output / f"{release}.zip"
if archive.exists():
    raise RuntimeError("Do not overwrite a release archive; choose a new release number")

files = [server / name for name in (
    "package.json", "package-lock.json", "tsconfig.json", "tsconfig.build.json",
    "nest-cli.json", ".npmrc", "HOSTINGER_DEPLOYMENT.md",
)]
for folder in ("src", "prisma", "scripts"):
    files.extend(path for path in (server / folder).rglob("*") if path.is_file())
files = sorted(files)
for path in files:
    relative = path.relative_to(server)
    if path.is_symlink() or any(part in {"node_modules", "dist", "__pycache__"} for part in relative.parts):
        raise RuntimeError(f"Unexpected release input: {relative}")
    if path.name.startswith(".env") or path.suffix in {".pem", ".key", ".log"}:
        raise RuntimeError(f"Sensitive file must not be packaged: {relative}")

manifest = {
    "release": release,
    "apiContractVersion": contract.group(1),
    "nodeVersion": "22",
    "buildCommand": "npm run build",
    "outputDirectory": "dist",
    "entryFile": "main.js",
    "files": {
        str(path.relative_to(server)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in files
    },
}
with ZipFile(archive, "w", ZIP_DEFLATED) as bundle:
    for path in files:
        bundle.write(path, str(path.relative_to(server)))
    bundle.writestr("release-manifest.json", json.dumps(manifest, indent=2) + "\n")

with ZipFile(archive) as bundle:
    if bundle.testzip() is not None:
        raise RuntimeError("Release archive failed its integrity check")
    for name, expected in manifest["files"].items():
        if hashlib.sha256(bundle.read(name)).hexdigest() != expected:
            raise RuntimeError(f"Release content mismatch: {name}")
    for name in ("src/senders/dto/list-senders.dto.ts", "src/email-messages/dto/list-messages.dto.ts"):
        if "emailAccountId?: string" not in bundle.read(name).decode():
            raise RuntimeError(f"Release does not contain mailbox query support: {name}")

checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(".sha256").write_text(f"{checksum}  {archive.name}\n")
print(f"Created {archive} ({len(files) + 1} files)")
print(f"SHA-256: {checksum}")
