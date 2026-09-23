/**
 * The two icons the chassis needs, drawn inline.
 *
 * Pulling a whole icon library in for a pair of glyphs would be the largest
 * dependency on the list. They take `currentColor`, so the theme still owns
 * the ink.
 */

const base = {
  width: 16,
  height: 16,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 2,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

export function PanelLeftClose() {
  return (
    <svg {...base} aria-hidden="true">
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <path d="M9 3v18" />
      <path d="m16 15-3-3 3-3" />
    </svg>
  );
}

export function PanelLeftOpen() {
  return (
    <svg {...base} aria-hidden="true">
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <path d="M9 3v18" />
      <path d="m14 9 3 3-3 3" />
    </svg>
  );
}

export function Menu() {
  return (
    <svg {...base} width={20} height={20} aria-hidden="true">
      <path d="M4 6h16M4 12h16M4 18h16" />
    </svg>
  );
}

export function ListFilter() {
  return (
    <svg {...base} width={13} height={13} aria-hidden="true">
      <path d="M3 6h18" />
      <path d="M7 12h10" />
      <path d="M10 18h4" />
    </svg>
  );
}

export function ArrowLeft() {
  return (
    <svg {...base} width={11} height={11} aria-hidden="true">
      <path d="M19 12H5" />
      <path d="m12 19-7-7 7-7" />
    </svg>
  );
}

export function ArrowRight() {
  return (
    <svg {...base} width={11} height={11} aria-hidden="true">
      <path d="M5 12h14" />
      <path d="m12 5 7 7-7 7" />
    </svg>
  );
}

export function Check() {
  return (
    <svg {...base} width={13} height={13} aria-hidden="true">
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}

export function Circle() {
  return (
    <svg {...base} width={13} height={13} aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
    </svg>
  );
}

export function RotateCcw() {
  return (
    <svg {...base} width={13} height={13} aria-hidden="true">
      <path d="M3 12a9 9 0 1 0 3-6.7L3 8" />
      <path d="M3 3v5h5" />
    </svg>
  );
}

export function NotebookPen() {
  return (
    <svg {...base} width={13} height={13} aria-hidden="true">
      <path d="M4 3h11v8" />
      <path d="M4 3v18h12" />
      <path d="M4 8h4M4 13h4M4 18h4" />
      <path d="m20 9-6.5 6.5-.5 2.5 2.5-.5L22 11z" />
    </svg>
  );
}

export function ChevronDown() {
  return (
    <svg {...base} width={12} height={12} aria-hidden="true">
      <path d="m6 9 6 6 6-6" />
    </svg>
  );
}

export function ChevronUp() {
  return (
    <svg {...base} width={12} height={12} aria-hidden="true">
      <path d="m18 15-6-6-6 6" />
    </svg>
  );
}

export function Search() {
  return (
    <svg {...base} width={13} height={13} aria-hidden="true">
      <circle cx="11" cy="11" r="7" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
}

export function X() {
  return (
    <svg {...base} width={12} height={12} aria-hidden="true">
      <path d="M18 6 6 18M6 6l12 12" />
    </svg>
  );
}
