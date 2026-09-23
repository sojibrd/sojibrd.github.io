"use client";

import { useState } from "react";
import { useLocalStorage } from "../hooks/useLocalStorage";
import {
  Check,
  ChevronDown,
  ChevronUp,
  Circle,
  NotebookPen,
  RotateCcw,
} from "./icons";

export interface DocNote {
  summary?: string;
  unclear?: string;
}

export const READ_KEY = "apr_read_slugs";
export const REVISE_KEY = "apr_revise_slugs";
export const NOTES_KEY = "apr_doc_notes";

export function hasNote(note?: DocNote): boolean {
  return Boolean(note?.summary?.trim() || note?.unclear?.trim());
}

/**
 * Per-page reading state.
 *
 * What a button reports rides on `aria-pressed`; what "on" looks like stays
 * with the theme.
 */
export default function DocTracker({ route }: { route: string }) {
  const [readRoutes, setReadRoutes] = useLocalStorage<string[]>(READ_KEY, []);
  const [reviseRoutes, setReviseRoutes] = useLocalStorage<string[]>(REVISE_KEY, []);
  const [notesMap, setNotesMap] = useLocalStorage<Record<string, DocNote>>(NOTES_KEY, {});

  const [notesOpen, setNotesOpen] = useState(false);

  const isRead = readRoutes.includes(route);
  const isRevise = reviseRoutes.includes(route);
  const note = notesMap[route] || {};

  const toggle = (setter: typeof setReadRoutes) => () =>
    setter((prev) =>
      prev.includes(route) ? prev.filter((r) => r !== route) : [...prev, route]
    );

  function updateNote(field: keyof DocNote, value: string) {
    setNotesMap((prev) => ({ ...prev, [route]: { ...prev[route], [field]: value } }));
  }

  return (
    <div className="surface-panel mt-12 p-5 sm:p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 className="t-title text-sm">অগ্রগতি ও নোট</h3>
          <p className="t-caption mt-1">
            এই টেকনিকের অবস্থা বদলান বা নোট রাখুন
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={toggle(setReadRoutes)}
            aria-pressed={isRead}
            className={`control px-3.5 py-2 text-xs ${isRead ? "control--primary" : ""}`}
          >
            {isRead ? <Check /> : <Circle />}
            {isRead ? "পঠিত" : "পড়া হয়নি"}
          </button>

          <button
            type="button"
            onClick={toggle(setReviseRoutes)}
            aria-pressed={isRevise}
            className={`control px-3.5 py-2 text-xs ${isRevise ? "control--alert" : ""}`}
          >
            <RotateCcw />
            {isRevise ? "রিভাইজ তালিকায়" : "রিভাইজ দরকার"}
          </button>

          <button
            type="button"
            onClick={() => setNotesOpen((open) => !open)}
            aria-expanded={notesOpen}
            className="control px-3.5 py-2 text-xs"
          >
            <NotebookPen />
            {hasNote(note) ? "নোট সংরক্ষিত" : "নোট যুক্ত করুন"}
            {notesOpen ? <ChevronUp /> : <ChevronDown />}
          </button>
        </div>
      </div>

      {notesOpen && (
        <div className="seam-t mt-5 flex flex-col gap-4 pt-5">
          <div>
            <label htmlFor="doc-summary" className="t-label mb-1.5 block">
              মূল শিক্ষণীয় বিষয়
            </label>
            <textarea
              id="doc-summary"
              rows={3}
              value={note.summary || ""}
              onChange={(event) => updateNote("summary", event.target.value)}
              placeholder="এই টেকনিক থেকে যা মনে রাখা দরকার..."
              className="surface-well t-body w-full px-3.5 py-2.5 text-sm"
            />
          </div>

          <div>
            <label htmlFor="doc-unclear" className="t-label mb-1.5 block">
              পরে দেখতে হবে
            </label>
            <textarea
              id="doc-unclear"
              rows={2}
              value={note.unclear || ""}
              onChange={(event) => updateNote("unclear", event.target.value)}
              placeholder="যে জায়গাগুলোতে খটকা রয়ে গেছে..."
              className="surface-well t-body w-full px-3.5 py-2.5 text-sm"
            />
          </div>
        </div>
      )}
    </div>
  );
}
