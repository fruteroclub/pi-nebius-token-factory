---
name: landing-page-from-five-questions
description: Turn a five-answer business brief into a verified Astro landing page.
---

# Landing page from five questions

Use this skill when the user wants a first landing page from an idea, without an existing product specification.

## Intake

Ask these questions one at a time. Do not start implementation until all five have an answer:

1. What problem does this solve, and for whom?
2. What is the simplest solution or offer?
3. How does it work in three concrete actions?
4. What outcome or benefit should a visitor expect?
5. What is the pricing or call to action? If pricing is unknown, say so plainly and use a contact or waitlist action instead.

After question five, restate the brief in five bullets. Ask for confirmation before writing files.

## Build

1. Inspect the current directory. If it is not an Astro project, create one using the current local `create-astro` package. Astro must be installed in the generated project, never globally.
2. Build one static, responsive landing page from the approved answers.
3. Use the repository's design instructions when present. Do not invent testimonials, customer logos, pricing facts, performance claims, or company details.
4. Use the actual five answers as the information architecture: problem, solution, how it works, benefits, pricing or CTA.
5. Add a concise README section: local development, production build, and the facts that still need confirmation.

## Verification

Run `npm run build`. If the project offers a check or test script, run it too. Fix errors before reporting completion.

## Render boundary

If `render` is available, use it only to inspect, validate, or prepare deployment instructions unless the user explicitly authorizes deployment. Do not create a Render service, deploy, or send credentials without that authorization.
