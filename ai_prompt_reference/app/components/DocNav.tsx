"use client";

import { useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { href } from "../lib/href";
import type { Doc } from "../lib/content";
import { ArrowLeft, ArrowRight } from "./icons";

/**
 * Previous / next, plus the `[` and `]` shortcuts that go with them.
 *
 * A client island purely for the key handler; the page around it stays a
 * server component.
 */
export default function DocNav({ prev, next }: { prev?: Doc; next?: Doc }) {
  const router = useRouter();

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      const typing =
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.tagName === "SELECT" ||
          target.isContentEditable);
      if (typing) return;

      if (event.key === "[" && prev) {
        event.preventDefault();
        router.push(href(prev.slug));
      } else if (event.key === "]" && next) {
        event.preventDefault();
        router.push(href(next.slug));
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [prev, next, router]);

  if (!prev && !next) return null;

  return (
    <nav className="seam-t mt-12 flex flex-col gap-3 pt-8 sm:flex-row sm:justify-between">
      {prev ? (
        <Link
          href={href(prev.slug)}
          className="surface-raised flex flex-1 flex-col gap-1 p-4 min-w-0"
        >
          <span className="t-label flex items-center gap-1.5">
            <ArrowLeft /> আগের অধ্যায়
            <kbd className="t-mono hidden sm:inline text-[10px] ml-1">[</kbd>
          </span>
          <span className="t-strong text-sm truncate">{prev.title}</span>
        </Link>
      ) : (
        <div className="flex-1" />
      )}

      {next && (
        <Link
          href={href(next.slug)}
          className="surface-raised flex flex-1 flex-col gap-1 p-4 text-right min-w-0"
        >
          <span className="t-label flex items-center justify-end gap-1.5">
            পরের অধ্যায়
            <kbd className="t-mono hidden sm:inline text-[10px] mr-1">]</kbd>
            <ArrowRight />
          </span>
          <span className="t-strong text-sm truncate">{next.title}</span>
        </Link>
      )}
    </nav>
  );
}
