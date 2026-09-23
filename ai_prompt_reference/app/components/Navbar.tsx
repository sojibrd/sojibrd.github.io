"use client";

import Link from "next/link";
import { Menu } from "./icons";

interface NavbarProps {
  onOpenSidebar: () => void;
}

/**
 * The mobile top bar. From `lg:` up the rail carries the identity and this
 * disappears entirely, so there is only ever one brand on screen.
 */
export default function Navbar({ onOpenSidebar }: NavbarProps) {
  return (
    <header className="surface-app seam-b shrink-0 w-full py-3 px-4 sm:px-6 flex items-center gap-3 lg:hidden">
      <button
        onClick={onOpenSidebar}
        className="control control--quiet p-2 shrink-0"
        aria-label="নেভিগেশন খুলুন"
      >
        <Menu />
      </button>

      <span className="text-2xl shrink-0">🧠</span>
      <div className="min-w-0">
        <Link href="/" className="t-title block text-base truncate">
          প্রম্পট রেফারেন্স
        </Link>
      </div>
    </header>
  );
}
