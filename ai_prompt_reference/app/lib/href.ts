/**
 * Slug to route. Kept out of `content.ts` because that module reads the
 * filesystem and is server-only; client components need this one function.
 */
export function href(slug: string[]): string {
  return slug.length === 0 ? "/" : `/${slug.join("/")}/`;
}
