import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  basePath:
    process.env.BASE_PATH ??
    (process.env.GITHUB_ACTIONS ? "/ai_prompt_reference" : ""),
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
