#!/usr/bin/env bun
// Temporary shim around `bun2nix` until it accepts bun.lock versions 2 and 3.
// Upstream: https://github.com/nix-community/bun2nix/pull/110
//
// Bun 1.4 stamps `lockfileVersion: 2` (and `3` when nested overrides are used)
// without changing the `packages` layout bun2nix reads, so those lockfiles are
// fed to bun2nix as version 1. Once bun2nix accepts them natively this script
// fails on purpose so it gets removed instead of lingering.

import { tmpdir } from "node:os";
import { join } from "node:path";

const COMPATIBLE_VERSIONS = [2, 3];
const UPSTREAM = "https://github.com/nix-community/bun2nix/pull/110";

const bin = Bun.resolveSync("bun2nix/index.ts", import.meta.dir);
const args = process.argv.slice(2);

function bun2nix(argv: string[]) {
    return Bun.spawnSync([process.execPath, bin, ...argv], { stdout: "inherit", stderr: "pipe" });
}

function lockFileArg(argv: string[]): { index: number; path: string } {
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === "-l" || arg === "--lock-file") return { index: i + 1, path: argv[i + 1] };
        if (arg.startsWith("--lock-file=")) return { index: -1, path: arg.slice("--lock-file=".length) };
    }
    return { index: -1, path: "bun.lock" };
}

const lockFile = lockFileArg(args);
const contents = await Bun.file(lockFile.path).text();
const version = Number(contents.match(/"lockfileVersion"\s*:\s*(\d+)/)?.[1]);

const first = bun2nix(args);
const stderr = first.stderr.toString();

if (first.success) {
    process.stderr.write(stderr);
    if (COMPATIBLE_VERSIONS.includes(version)) {
        console.error(
            `\nerror: bun2nix now accepts lockfileVersion ${version} natively (${UPSTREAM}).\n` +
            `This shim is no longer needed:\n` +
            `  1. delete scripts/bun2nix.ts\n` +
            `  2. set "postinstall" in package.json back to "bun2nix -o bun.lock.nix"\n`,
        );
        process.exit(1);
    }
    process.exit(0);
}

const rejected = Number(stderr.match(/Unsupported lockfile version: '(\d+)'/)?.[1]);
if (!COMPATIBLE_VERSIONS.includes(rejected)) {
    process.stderr.write(stderr);
    process.exit(first.exitCode ?? 1);
}

const shimmed = join(tmpdir(), `bun2nix-shim-${process.pid}.lock`);
await Bun.write(shimmed, contents.replace(/("lockfileVersion"\s*:\s*)\d+/, (_, prefix) => `${prefix}1`));

const shimmedArgs = lockFile.index === -1
    ? [...args.filter((arg) => !arg.startsWith("--lock-file=")), "-l", shimmed]
    : args.with(lockFile.index, shimmed);

const second = bun2nix(shimmedArgs);
await Bun.file(shimmed).delete();
process.stderr.write(second.stderr.toString());
process.exit(second.exitCode ?? 1);
