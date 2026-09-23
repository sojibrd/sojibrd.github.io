import Markdown from "./Markdown";
import DocNav from "./DocNav";
import DocTracker from "./DocTracker";
import TableOfContents from "./TableOfContents";
import { getDoc, getNeighbours, parseDoc } from "../lib/content";
import { href } from "../lib/href";

export default function DocPage({ slug }: { slug: string[] }) {
  const doc = getDoc(slug);
  if (!doc) return null;

  const { title, body, headings } = parseDoc(doc);
  const { prev, next } = getNeighbours(slug);

  return (
    <div className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-8 sm:py-12 flex justify-center gap-8 xl:gap-12">
      <article className="w-full max-w-3xl min-w-0">
        <header className="seam-b mb-8 pb-6">
          {doc.category && (
            <div className="mb-3 flex flex-wrap items-center gap-2">
              <span className="chip">{doc.category}</span>
            </div>
          )}

          <h1 className="t-title text-2xl sm:text-3xl">{title}</h1>
        </header>

        <Markdown content={body} base={doc.slug} />

        {/* Home and the category indexes are contents pages, not reading. */}
        {doc.slug.length === 2 && <DocTracker route={href(doc.slug)} />}

        <DocNav prev={prev} next={next} />
      </article>

      <TableOfContents headings={headings} />
    </div>
  );
}
