"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname } from "next/navigation";
import { useLocalStorage } from "../hooks/useLocalStorage";
import Navbar from "./Navbar";
import Sidebar from "./Sidebar";
import { PanelLeftOpen } from "./icons";
import type { Category } from "../lib/content";

export default function Shell({
  nav,
  children,
}: {
  nav: Category[];
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);
  /* Folding the rail away is a deliberate act, so it outlives a refresh.
     The server has no localStorage; the default keeps the rail visible for
     the first paint and the client reconciles on hydration. */
  const [collapsed, setCollapsed] = useLocalStorage("apr_nav_collapsed", false);
  const pathname = usePathname();
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  /* `/` and Ctrl+K reach the rail's search from anywhere. A folded rail is
     unfolded first, or the focus would land on an input nobody can see. */
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      const typing =
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.tagName === "SELECT" ||
          target.isContentEditable);

      const slash = event.key === "/" && !typing;
      const ctrlK = (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k";
      if (!slash && !ctrlK) return;

      event.preventDefault();
      setCollapsed(false);
      searchRef.current?.focus();
      searchRef.current?.select();
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [setCollapsed]);

  return (
    /* The chassis owns the viewport and the two panes scroll inside it. A
       sticky bar over a page-scrolled rail would have to hardcode the bar's
       height, which changes between breakpoints. */
    <div className="surface-app h-screen flex flex-col overflow-hidden">
      <Navbar onOpenSidebar={() => setOpen(true)} />

      <div className="flex flex-1 min-h-0">
        {/* With no desktop top bar, this strip is the only way back to the
            rail once it is folded away. */}
        {collapsed && (
          <div className="surface-panel hidden lg:flex shrink-0 flex-col items-center px-2 py-3">
            <button
              onClick={() => setCollapsed(false)}
              className="control control--quiet p-1.5"
              aria-label="সূচিপত্র খুলুন"
              aria-expanded={false}
              aria-controls="site-sidebar"
            >
              <PanelLeftOpen />
            </button>
          </div>
        )}
        {/* The permanent rail. This is a reference people move through often,
            so `aria-current` stays on screen instead of behind a trigger. */}
        <aside
          id="site-sidebar"
          className={`surface-panel hidden w-80 shrink-0 min-h-0 ${
            collapsed ? "" : "lg:block"
          }`}
        >
          <Sidebar
            nav={nav}
            onCollapse={() => setCollapsed(true)}
            searchRef={searchRef}
          />
        </aside>

        {/* The page owns its own width and padding; this pane only scrolls. */}
        <main className="flex-1 min-w-0 overflow-y-auto">{children}</main>
      </div>

      {open && (
        <div className="fixed inset-0 z-50 lg:hidden" aria-modal="true">
          <div className="overlay absolute inset-0" onClick={() => setOpen(false)} />
          <aside className="drawer-enter surface-panel absolute left-0 top-0 h-full w-[300px] sm:w-[360px]">
            <Sidebar
              nav={nav}
              onClose={() => setOpen(false)}
              onNavigate={() => setOpen(false)}
            />
          </aside>
        </div>
      )}
    </div>
  );
}
