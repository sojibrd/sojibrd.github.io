import type { Metadata } from "next";
import { getTechniqueDocs } from "../lib/content";
import { href } from "../lib/href";
import ProgressClient from "./ProgressClient";

export const metadata: Metadata = { title: "Progress Tracker" };

export default function ProgressPage() {
  const docs = getTechniqueDocs().map((doc) => ({
    title: doc.title,
    route: href(doc.slug),
    category: doc.category ?? "",
  }));

  return <ProgressClient docs={docs} />;
}
