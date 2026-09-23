"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useLocalStorage } from "../hooks/useLocalStorage";
import { ArrowRight, Check, Circle, RotateCcw } from "../components/icons";
import {
  hasNote,
  NOTES_KEY,
  READ_KEY,
  REVISE_KEY,
  type DocNote,
} from "../components/DocTracker";

export interface ProgressDoc {
  title: string;
  route: string;
  category: string;
}

type Filter = "all" | "revise" | "unread" | "notes";

export default function ProgressClient({ docs }: { docs: ProgressDoc[] }) {
  const [readRoutes, setReadRoutes] = useLocalStorage<string[]>(READ_KEY, []);
  const [reviseRoutes, setReviseRoutes] = useLocalStorage<string[]>(REVISE_KEY, []);
  const [notesMap] = useLocalStorage<Record<string, DocNote>>(NOTES_KEY, {});

  const [filter, setFilter] = useState<Filter>("all");

  /* A renamed or deleted technique can leave its route behind in storage.
     Counts come from `docs`, so the numbers stay right either way, but there
     is no reason to keep dead entries. Nothing is written when there is
     nothing to prune, so this does not touch storage on every mount. */
  useEffect(() => {
    const live = new Set(docs.map((doc) => doc.route));
    const stale = (routes: string[]) => routes.some((route) => !live.has(route));
    if (stale(readRoutes)) setReadRoutes((prev) => prev.filter((r) => live.has(r)));
    if (stale(reviseRoutes)) setReviseRoutes((prev) => prev.filter((r) => live.has(r)));
  }, [docs, readRoutes, reviseRoutes, setReadRoutes, setReviseRoutes]);

  const total = docs.length;
  const readCount = docs.filter((doc) => readRoutes.includes(doc.route)).length;
  const reviseCount = docs.filter((doc) => reviseRoutes.includes(doc.route)).length;
  const notesCount = docs.filter((doc) => hasNote(notesMap[doc.route])).length;
  const percent = total > 0 ? Math.round((readCount / total) * 100) : 0;

  const toggle = (setter: typeof setReadRoutes) => (route: string) =>
    setter((prev) =>
      prev.includes(route) ? prev.filter((r) => r !== route) : [...prev, route]
    );
  const toggleRead = toggle(setReadRoutes);
  const toggleRevise = toggle(setReviseRoutes);

  const visible = useMemo(
    () =>
      docs.filter((doc) => {
        if (filter === "revise") return reviseRoutes.includes(doc.route);
        if (filter === "unread") return !readRoutes.includes(doc.route);
        if (filter === "notes") return hasNote(notesMap[doc.route]);
        return true;
      }),
    [docs, filter, readRoutes, reviseRoutes, notesMap]
  );

  const filters: { id: Filter; label: string; count: number }[] = [
    { id: "all", label: "সব টেকনিক", count: total },
    { id: "revise", label: "রিভাইজ দরকার", count: reviseCount },
    { id: "unread", label: "অপঠিত", count: total - readCount },
    { id: "notes", label: "নোটযুক্ত", count: notesCount },
  ];

  return (
    <div className="mx-auto w-full max-w-5xl px-4 py-8 sm:px-8 sm:py-12 flex flex-col gap-8">
      <header className="flex flex-col gap-2">
        <h1 className="t-title text-2xl sm:text-3xl">Progress Tracker</h1>
        <p className="t-body text-sm">
          কোন টেকনিকগুলো পড়া হয়েছে, কোনগুলো আবার দেখতে হবে — এক জায়গায়।
        </p>
      </header>

      <div className="surface-panel flex flex-col gap-3 p-5 sm:p-6">
        <div className="flex items-baseline justify-between gap-3">
          <span className="t-label">পঠিত</span>
          <span className="t-mono t-accent text-sm">
            {readCount}/{total} ({percent}%)
          </span>
        </div>
        <div
          role="progressbar"
          aria-valuenow={percent}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-label="সার্বিক অগ্রগতি"
          className="gauge h-2 w-full"
        >
          <div className="gauge-fill" style={{ width: `${percent}%` }} />
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {filters.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setFilter(item.id)}
            aria-selected={filter === item.id}
            className="tab px-3.5 py-2 text-xs"
          >
            {item.label} ({item.count})
          </button>
        ))}
      </div>

      {visible.length === 0 ? (
        <div className="surface-well t-caption p-8 text-center">
          এই ফিল্টারে কিছু নেই।
        </div>
      ) : (
        <ul className="flex flex-col gap-2">
          {visible.map((doc) => {
            const isRead = readRoutes.includes(doc.route);
            const isRevise = reviseRoutes.includes(doc.route);

            return (
              <li
                key={doc.route}
                className="surface-raised flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
              >
                <div className="min-w-0 flex flex-col gap-1">
                  <span className="t-label truncate">{doc.category}</span>
                  <Link
                    href={doc.route}
                    className="t-strong flex items-center gap-1.5 text-sm min-w-0"
                  >
                    <span className="truncate">{doc.title}</span>
                    <ArrowRight />
                  </Link>
                </div>

                <div className="flex flex-wrap items-center gap-2 shrink-0">
                  {hasNote(notesMap[doc.route]) && <span className="chip">নোট</span>}

                  <button
                    type="button"
                    onClick={() => toggleRead(doc.route)}
                    aria-pressed={isRead}
                    className={`control px-3 py-1.5 text-xs ${isRead ? "control--primary" : ""}`}
                  >
                    {isRead ? <Check /> : <Circle />}
                    {isRead ? "পঠিত" : "পড়া হয়নি"}
                  </button>

                  <button
                    type="button"
                    onClick={() => toggleRevise(doc.route)}
                    aria-pressed={isRevise}
                    className={`control px-3 py-1.5 text-xs ${isRevise ? "control--alert" : ""}`}
                  >
                    <RotateCcw />
                    রিভাইজ
                  </button>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
