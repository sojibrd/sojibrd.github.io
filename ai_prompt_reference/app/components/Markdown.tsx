"use client";

import { isValidElement, type ReactNode } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import Link from "next/link";
import { slugify } from "../lib/slug";

/**
 * The markdown files link to each other with repo-relative paths
 * (`01-basic-techniques/`, `../02-reasoning-techniques/`, `README.md`).
 * Turn those into site routes, relative to the page being rendered.
 */
function resolveHref(href: string, base: string[]): string | null {
  if (/^(https?:|mailto:|#)/.test(href)) return null;

  const segments = [...base];
  for (const part of href.split("/")) {
    if (part === "" || part === "." || part === "README.md") continue;
    if (part === "..") segments.pop();
    else segments.push(part);
  }

  return segments.length === 0 ? "/" : `/${segments.join("/")}/`;
}

/** The heading text as a plain string, however react-markdown nested it. */
function getNodeText(children: ReactNode): string {
  if (typeof children === "string") return children;
  if (typeof children === "number") return String(children);
  if (Array.isArray(children)) return children.map(getNodeText).join("");
  if (isValidElement<{ children?: ReactNode }>(children)) {
    return getNodeText(children.props.children);
  }
  return "";
}

/** The id the table of contents links to; must match `extractHeadings`. */
function headingId(children: ReactNode): string {
  return slugify(getNodeText(children).trim().replace(/[*_`]/g, ""));
}

export default function Markdown({
  content,
  base,
}: {
  content: string;
  base: string[];
}) {
  return (
    <div className="doc-prose">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          h2({ children, ...props }) {
            return (
              <h2 id={headingId(children)} {...props}>
                {children}
              </h2>
            );
          },
          h3({ children, ...props }) {
            return (
              <h3 id={headingId(children)} {...props}>
                {children}
              </h3>
            );
          },
          a({ href, children, ...props }) {
            const internal = href ? resolveHref(href, base) : null;
            if (internal) {
              return (
                <Link href={internal} {...props}>
                  {children}
                </Link>
              );
            }
            return (
              <a href={href} target="_blank" rel="noreferrer" {...props}>
                {children}
              </a>
            );
          },
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  );
}
