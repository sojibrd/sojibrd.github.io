"use client";

import { useMemo, useState, type RefObject } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { Category } from "../lib/content";
import { PanelLeftClose, Search, X } from "./icons";

interface SidebarProps {
  nav: Category[];
  /** Supplied only in the drawer, where the list needs a way out. */
  onClose?: () => void;
  /** Supplied only on the rail, where the list can be folded away. */
  onCollapse?: () => void;
  onNavigate?: () => void;
  /** The rail's input, so `/` and Ctrl+K can reach it from anywhere. */
  searchRef?: RefObject<HTMLInputElement | null>;
}

/**
 * Category -> technique navigation.
 *
 * One component serves both mounts: the permanent desktop rail and the
 * drawer. They differ only in the way out; a second component would have
 * meant two lists drifting apart.
 */
export default function Sidebar({
  nav,
  onClose,
  onCollapse,
  onNavigate,
  searchRef,
}: SidebarProps) {
  const pathname = usePathname();
  const current = pathname.replace(/^\/|\/$/g, "");
  const [search, setSearch] = useState("");

  const query = search.trim().toLowerCase();
  const searching = query.length > 0;

  /* While searching the categories are dropped and the matches shown flat.
     Keeping the grouping would leave empty category blocks standing over
     nothing, which reads as broken rather than as "no matches here". */
  const matches = useMemo(() => {
    if (!searching) return [];
    return nav
      .flatMap((category) => category.topics)
      .filter((topic) => topic.title.toLowerCase().includes(query));
  }, [nav, query, searching]);

  return (
    <div className="h-full overflow-y-auto p-4 flex flex-col gap-4">
      {/* The brand lives here, not in a top bar: from `lg:` up this column is
          the only chrome on screen. */}
      <div className="flex items-center justify-between gap-2">
        <Link
          href="/"
          onClick={onNavigate}
          className="flex items-center gap-2 min-w-0"
        >
          <span className="text-xl shrink-0">🧠</span>
          <span className="t-title text-sm truncate">Prompt Reference</span>
        </Link>

        <div className="flex items-center gap-1.5 shrink-0">
          <Link
            href="/progress/"
            onClick={onNavigate}
            className={`control px-2.5 py-1 text-[11px] ${
              current === "progress" ? "control--primary" : ""
            }`}
          >
            Progress
          </Link>

          {onClose && (
            <button
              onClick={onClose}
              className="control control--quiet p-1.5"
              aria-label="সাইডবার বন্ধ করুন"
            >
              <X />
            </button>
          )}

          {onCollapse && (
            <button
              onClick={onCollapse}
              className="control control--quiet p-1.5"
              aria-label="সূচিপত্র লুকান"
              aria-expanded
              aria-controls="site-sidebar"
            >
              <PanelLeftClose />
            </button>
          )}
        </div>
      </div>

      <div className="relative">
        <span className="t-muted absolute left-2.5 top-2.5 flex pointer-events-none">
          <Search />
        </span>
        <input
          ref={searchRef}
          type="text"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          onKeyDown={(event) => {
            if (event.key !== "Escape") return;
            if (search) setSearch("");
            else event.currentTarget.blur();
          }}
          placeholder="টেকনিক খুঁজুন..."
          aria-label="টেকনিক খুঁজুন (শর্টকাট: / বা Ctrl+K)"
          className="surface-well t-body w-full pl-8 pr-8 py-2 text-sm"
        />
        {search ? (
          <button
            type="button"
            onClick={() => setSearch("")}
            className="control control--quiet absolute right-1.5 top-1.5 px-1.5 py-1"
            aria-label="খোঁজা বাতিল"
          >
            <X />
          </button>
        ) : (
          <span
            className="t-caption t-mono hidden lg:inline absolute right-2.5 top-2 pointer-events-none select-none text-[11px]"
            title="শর্টকাট: / অথবা Ctrl+K"
          >
            /
          </span>
        )}
      </div>

      {searching ? (
        <nav className="flex flex-col gap-1.5">
          {matches.length === 0 ? (
            <div className="surface-well t-caption p-4 text-center">
              &ldquo;{search}&rdquo; দিয়ে কিছু পাওয়া যায়নি।
            </div>
          ) : (
            matches.map((topic) => {
              const topicSlug = topic.slug.join("/");
              return (
                <Link
                  key={topicSlug}
                  href={`/${topicSlug}/`}
                  onClick={onNavigate}
                  aria-current={current === topicSlug}
                  className="row block px-2.5 py-1.5 text-xs leading-snug"
                >
                  {topic.title}
                </Link>
              );
            })
          )}
        </nav>
      ) : (
        <nav className="flex flex-col gap-4">
          <Link
            href="/"
            onClick={onNavigate}
            aria-current={current === ""}
            className="row block px-2.5 py-1.5 text-xs"
          >
            ভূমিকা
          </Link>

          {nav.map((category) => {
            const categorySlug = category.slug.join("/");

            return (
              <div
                key={categorySlug}
                className="topic-group pb-4 flex flex-col gap-1.5"
              >
                <div className="flex items-center justify-between gap-2">
                  <Link
                    href={`/${categorySlug}/`}
                    onClick={onNavigate}
                    aria-current={current === categorySlug}
                    className="row block min-w-0 flex-1 px-2.5 py-1.5"
                  >
                    <span className="t-strong text-xs truncate">
                      {category.title}
                    </span>
                  </Link>
                  <span className="chip shrink-0">
                    {category.topics.length}
                  </span>
                </div>

                {category.topics.map((topic) => {
                  const topicSlug = topic.slug.join("/");

                  return (
                    <Link
                      key={topicSlug}
                      href={`/${topicSlug}/`}
                      onClick={onNavigate}
                      aria-current={current === topicSlug}
                      className="row block px-2.5 py-1.5 text-xs leading-snug"
                    >
                      {topic.title}
                    </Link>
                  );
                })}
              </div>
            );
          })}
        </nav>
      )}
    </div>
  );
}
