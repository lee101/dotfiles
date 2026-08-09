---
name: optimize-seo
description: Audit and improve SEO plus Core Web Vitals for web apps and content sites. Use when asked to optimize SEO, metadata, canonical URLs, Open Graph/Twitter cards, JSON-LD structured data, robots.txt, sitemap.xml, route indexability, Netwrck character/page SEO, search-result snippets, Lighthouse/PageSpeed style metrics, LCP, CLS, INP, FCP, or TTFB.
---

# Optimize SEO

## Overview

Use this skill to make focused, testable SEO and Core Web Vitals improvements in an existing codebase. Prefer repo-native metadata helpers, route definitions, performance tooling, and tests over one-off string edits.

## Workflow

1. Map the site surface:
   - Identify the framework, routing layer, SSR/prerender path, and metadata helpers.
   - Locate sitemap, robots, canonical URL, Open Graph, Twitter card, and JSON-LD generation.
   - For Netwrck-style catalogues, inspect character/detail routes, search/category routes, NSFW handling, and high-volume dynamic route generation.

2. Audit before editing:
   - Build or start the app locally when feasible.
   - Fetch representative pages and inspect final HTML, not just component source.
   - Check title uniqueness, meta descriptions, canonical URLs, robots directives, status codes, hreflang if present, social card images, and structured data validity.
   - Check generated sitemap URLs for important public routes and exclude private, auth, admin, API, duplicate, and low-value filtered pages.
   - When a local, preview, or production URL is available, run `webvitals <url> --runs=3` from dotfiles tools for representative desktop routes; add `--mobile` for mobile-sensitive pages.
   - Capture LCP, CLS, INP, FCP, TTFB, long tasks, LCP element, layout-shift sources, dominant assets, and resource waterfalls before changing performance-sensitive code.

3. Implement narrowly:
   - Reuse existing metadata functions and route registries.
   - Keep canonical URL construction centralized.
   - Generate deterministic, content-specific titles and descriptions.
   - Add JSON-LD only when the page has enough trustworthy data; prefer `WebSite`, `Organization`, `BreadcrumbList`, `Article`, `SoftwareApplication`, or `ProfilePage` where appropriate.
   - Improve LCP by prioritizing the real hero/content image or text, reducing render-blocking resources, tuning font loading, trimming critical bundles, and avoiding late client-only content swaps.
   - Improve CLS by reserving image, ad, embed, and dynamic content dimensions; avoid injecting banners or loading states that move existing content.
   - Improve INP by reducing main-thread work, lazy-loading noncritical widgets, splitting heavy handlers, and removing avoidable hydration or animation cost.
   - Avoid keyword stuffing, hidden text, doorway pages, and pages that index unsafe/private content.

4. Validate:
   - Run the repo's build/typecheck and relevant server or route tests.
   - Add or update focused tests for metadata, sitemap, robots, canonical URLs, and representative dynamic pages.
   - If the app has Playwright or browser tests, verify a public route's rendered head tags from the browser.
   - Re-run `webvitals <url> --runs=3` on the same URLs after changes and report before/after metrics. Target LCP under 2.5s, CLS under 0.1, INP under 200ms, and TTFB under 800ms where realistic.

## Netwrck Notes

- Prioritize character detail pages, category/search landing pages, image/art pages, and high-traffic app entry points.
- Make titles readable first, then keyword-relevant: character or page name, intent/category, and brand.
- Descriptions should summarize the actual page content and stay distinct across generated pages.
- Canonicals must collapse duplicate query/filter variants to the preferred public URL.
- Keep NSFW or user-generated content indexing rules explicit and consistent with product policy.
- Sitemaps for huge catalogues should be chunked or capped according to the site's existing generation strategy.

## Output Expectations

In the final response, include what SEO surfaces changed, what pages or routes were validated, and any known gaps such as live search console checks, production crawl data, or unavailable credentials.
