import type { Metadata } from "next";
import { notFound } from "next/navigation";
import DocPage from "../components/DocPage";
import { getAllDocs, getDoc } from "../lib/content";

export function generateStaticParams() {
  return getAllDocs()
    .filter((doc) => doc.slug.length > 0)
    .map((doc) => ({ slug: doc.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string[] }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const doc = getDoc(slug);
  return { title: doc ? doc.title : "পাওয়া যায়নি" };
}

export default async function Page({
  params,
}: {
  params: Promise<{ slug: string[] }>;
}) {
  const { slug } = await params;
  if (!getDoc(slug)) notFound();
  return <DocPage slug={slug} />;
}
