import fs from "fs";
import path from "path";
import { slugify } from "./slug";
import { href } from "./href";

export { slugify, href };

const ROOT = process.cwd();

export type Doc = {
  slug: string[];
  title: string;
  content: string;
  /** The category this page sits under, for the breadcrumb. Absent on home. */
  category?: string;
};

export type HeadingItem = {
  id: string;
  text: string;
  level: number;
};

export type Topic = {
  slug: string[];
  title: string;
};

export type Category = {
  slug: string[];
  title: string;
  topics: Topic[];
};

/** Folders that hold the reference content, in reading order. */
function categoryDirs(): string[] {
  return fs
    .readdirSync(ROOT, { withFileTypes: true })
    .filter((e) => e.isDirectory() && /^\d\d-/.test(e.name))
    .map((e) => e.name)
    .sort();
}

function topicDirs(category: string): string[] {
  return fs
    .readdirSync(path.join(ROOT, category), { withFileTypes: true })
    .filter((e) => e.isDirectory() && /^\d\d-/.test(e.name))
    .map((e) => e.name)
    .sort();
}

function readMarkdown(segments: string[]): string {
  return fs.readFileSync(path.join(ROOT, ...segments, "README.md"), "utf8");
}

/** First `# heading` of the file, falling back to a prettified folder name. */
function titleOf(markdown: string, fallback: string): string {
  const match = markdown.match(/^#\s+(.+)$/m);
  if (match) return match[1].trim();
  return fallback.replace(/^\d\d-/, "").replace(/-/g, " ");
}

export function getNav(): Category[] {
  return categoryDirs().map((category) => ({
    slug: [category],
    title: titleOf(readMarkdown([category]), category),
    topics: topicDirs(category).map((topic) => ({
      slug: [category, topic],
      title: titleOf(readMarkdown([category, topic]), topic),
    })),
  }));
}

/** Every page on the site, home first, then categories and their topics. */
export function getAllDocs(): Doc[] {
  const home = fs.readFileSync(path.join(ROOT, "README.md"), "utf8");
  const docs: Doc[] = [{ slug: [], title: titleOf(home, "Home"), content: home }];

  for (const category of categoryDirs()) {
    const categoryMd = readMarkdown([category]);
    docs.push({
      slug: [category],
      title: titleOf(categoryMd, category),
      content: categoryMd,
    });

    for (const topic of topicDirs(category)) {
      const topicMd = readMarkdown([category, topic]);
      docs.push({
        slug: [category, topic],
        title: titleOf(topicMd, topic),
        content: topicMd,
        category: titleOf(categoryMd, category),
      });
    }
  }

  return docs;
}

/** `##` and `###` only: `#` is the page title and `####` is too fine to index. */
export function extractHeadings(markdown: string): HeadingItem[] {
  const headings: HeadingItem[] = [];
  for (const line of markdown.split(/\r?\n/)) {
    const match = /^(#{2,3})\s+(.+)$/.exec(line);
    if (!match) continue;
    const text = match[2].trim().replace(/[*_`]/g, "");
    headings.push({ id: slugify(text), text, level: match[1].length });
  }
  return headings;
}

/**
 * Split the leading `# heading` off the body.
 *
 * The title is rendered by the header plate, so leaving it in the markdown
 * would print it twice.
 */
export function parseDoc(doc: Doc): {
  title: string;
  body: string;
  headings: HeadingItem[];
} {
  const lines = doc.content.split(/\r?\n/);
  const bodyLines: string[] = [];
  let title = "";

  for (const line of lines) {
    const match = /^#\s+(.+)$/.exec(line);
    if (!title && match) {
      title = match[1].trim();
      continue;
    }
    bodyLines.push(line);
  }

  const body = bodyLines.join("\n").trim();
  return { title: title || doc.title, body, headings: extractHeadings(body) };
}

/**
 * The pages progress is counted over: the techniques themselves.
 *
 * Home and the category indexes are tables of contents, not reading; counting
 * them would make the percentage lie about how much has actually been read.
 */
export function getTechniqueDocs(): Doc[] {
  return getAllDocs().filter((doc) => doc.slug.length === 2);
}

export function getDoc(slug: string[]): Doc | undefined {
  const key = slug.join("/");
  return getAllDocs().find((doc) => doc.slug.join("/") === key);
}

/** Previous/next page in reading order, for the footer links. */
export function getNeighbours(slug: string[]) {
  const docs = getAllDocs();
  const key = slug.join("/");
  const index = docs.findIndex((doc) => doc.slug.join("/") === key);
  return {
    prev: index > 0 ? docs[index - 1] : undefined,
    next: index >= 0 && index < docs.length - 1 ? docs[index + 1] : undefined,
  };
}
