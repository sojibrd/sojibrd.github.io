// On Windows, `next build` writes segment prefetch files as
// `__next.$c$slug/__PAGE__.txt`, but the client router requests
// `__next.$c$slug.__PAGE__.txt`. Write a flat copy next to each nested one.
import { copyFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (!entry.isDirectory()) continue;
    if (entry.name.startsWith("__next.")) flatten(full, join(dir, entry.name));
    else walk(full);
  }
}

function flatten(dir, prefix) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    const flat = `${prefix}.${entry.name}`;
    if (entry.isDirectory()) flatten(full, flat);
    else copyFileSync(full, flat);
  }
}

walk("out");
