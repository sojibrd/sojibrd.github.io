import type { Metadata } from "next";
import {
  Barlow_Semi_Condensed,
  JetBrains_Mono,
  Noto_Sans_Bengali,
} from "next/font/google";
import "./globals.css";
import { getNav } from "./lib/content";
import Shell from "./components/Shell";

/**
 * The font shelf. Families are declared once, each on its own variable; the
 * theme picks which role gets which family via `--t-font-sans` /
 * `--t-font-mono` / `--t-doc-family`.
 *
 * Bengali is on the shelf because the Latin faces carry no Bengali glyphs —
 * without it the browser falls back silently and the reference loses the
 * theme's typography exactly where most of the reading happens.
 *
 * Adding a family no theme uses yet is the ONLY reason to edit this file.
 */
const condensed = Barlow_Semi_Condensed({
  variable: "--font-condensed",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
  display: "swap",
});

const mono = JetBrains_Mono({
  variable: "--font-mono-family",
  subsets: ["latin"],
  display: "swap",
});

const bengali = Noto_Sans_Bengali({
  variable: "--font-bengali",
  subsets: ["bengali", "latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Prompt Reference",
  description:
    "A reference for the techniques, patterns, and common pitfalls of prompt engineering.",
  other: {
    "theme-color": "#17140f",
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const nav = getNav();

  return (
    <html
      lang="bn"
      className={`${condensed.variable} ${mono.variable} ${bengali.variable} h-full antialiased`}
    >
      <body className="min-h-full">
        <Shell nav={nav}>{children}</Shell>
      </body>
    </html>
  );
}
