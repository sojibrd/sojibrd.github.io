# Theme Contract — এক-ফাইল থিমিং

`ai_prompt_reference`-এর সব ভিজ্যুয়াল সিদ্ধান্ত CSS-এ থাকে, কম্পোনেন্টে নয়।
কনট্র্যাক্টটি `system_design`-এর সাথে অভিন্ন — একই টোকেন নাম, একই প্যালেট, একই চেহারা।

## থিম বদলানো

```css
/* app/globals.css — লাইন ৮ */
@import "./themes/control-room.css";
```

**এই একটা লাইনই** পুরো সাইটের চেহারা ঠিক করে। বর্তমান থিম: `control-room.css` (একমাত্র থিম)।

**নতুন থিম লিখতে:** `app/themes/<name>.css`-এ একটা `:root {}` ব্লক, নিচের সব `--t-*` ভেরিয়েবল সেট করে। তারপর উপরের লাইনটা বদলান। **কম্পোনেন্টে কখনো হাত দেবেন না।**

> সাইট **dark-only**। `.dark` ক্লাস, theme toggle বা `prefers-color-scheme` কিছুই নেই। light চাইলে সেটা একটা নতুন থিম ফাইল, কোড পরিবর্তন নয়।

---

## অলঙ্ঘনীয় নিয়ম

1. **কম্পোনেন্টে কোনো ভিজ্যুয়াল সিদ্ধান্ত নয়।** রঙ তো নয়ই — `rounded-*`, `shadow-*`, `border-2`, `uppercase`, `tracking-*`, `font-bold` কোনোটাই না। এগুলো role class-এ থাকে।
2. **Tailwind শুধু লেআউটের জন্য** — `flex`, `grid`, `gap`, `w-`, `min-h-`, `truncate`, `overflow-*`। চেহারার জন্য নয়।
3. **কম্পোনেন্ট বলে *কী*, থিম বলে *কেমন*।** `aria-current`, `aria-selected`, `aria-pressed` — অবস্থা জানায়; সেটা দেখতে কেমন হবে তা CSS ঠিক করে।
4. **নতুন ভিজ্যুয়াল দরকার হলে আগে থিম ফাইলে টোকেন যোগ করুন**, তারপর role class লিখুন।
5. **Tailwind Typography plugin ব্যবহার করবেন না।** Markdown-এর সম্পূর্ণ চেহারা `.doc-prose`-এর দখলে; `prose*` ক্লাস ফিরে এলে দুই সিস্টেম একই element নিয়ে specificity যুদ্ধ করবে।

**একমাত্র ব্যতিক্রম — `.doc-prose`।** Markdown সরাসরি `<h2>`, `<td>`, `<blockquote>` হয়ে DOM-এ আসে; role class বসানোর মতো কম্পোনেন্ট নেই। তাই কনট্র্যাক্টের এই একটি ব্লক raw element স্টাইল করে — কিন্তু `.doc-prose`-এর ভেতরে scoped, আর সব মান `--t-doc-*` থেকে পড়ে।

---

## Role classes (`app/globals.css`)

| শ্রেণি | ক্লাস |
|---|---|
| Surface | `surface-app` `surface-panel` `surface-raised` `surface-well` |
| Text | `t-title` `t-label` `t-body` `t-caption` `t-mono` `t-strong` `t-accent` `t-muted` `t-ok` `t-quote` |
| Seam | `seam` `seam-b` `seam-b-heavy` `seam-t` `seam-l` |
| Control | `control` + `control--primary` `control--alert` `control--quiet` |
| Chip | `chip` + `chip--accent` `chip--alert` `chip--ok` |
| Callout | `callout` + `callout--accent` `callout--alert` |
| Nav | `tab` `row` `overlay` `drawer-enter` `topic-group` |
| **Gauge** | **`gauge` / `gauge-fill`** — অনুপাত দেখানো বার |
| **Doc chrome** | হেডার প্লেট `chip` + `t-title`, TOC `row` + `aria-current`, prev/next `surface-raised` |
| **Doc** | **`doc-prose`** — লম্বা Markdown কলাম (heading, table, code, quote, list) |

### State attributes

| অ্যাট্রিবিউট | কোথায় | অর্থ |
|---|---|---|
| `aria-current` | `.row` | বর্তমান নেভ আইটেম |
| `aria-selected` | `.tab` | নির্বাচিত ট্যাব (অগ্রগতি পেজের ফিল্টার) |
| `aria-pressed` | `.control` | চালু অবস্থা |
| `aria-expanded` | `.control` | সাইডবার ডিসক্লোজার (কোনো ভিজ্যুয়াল পরিবর্তন নেই — শুধু a11y) |

---

## থিম টোকেন (`--t-*`)

নতুন থিম ফাইলে এগুলো সব সেট করতে হবে। রেফারেন্স: `app/themes/control-room.css`।

- **Type:** `font-sans` `font-mono` `title-family|weight|tracking|transform` `label-family|size|weight|tracking|transform` `control-family|weight|tracking|transform` `quote-style`
- **App:** `app-bg` `app-bg-image|size` `select-bg|fg` `overlay-bg|filter` `disabled-opacity` `hover-fill` `selected-bg|fg` `accent` `ok` `ok-soft` `ease`
- **Text:** `text-title` `text-body` `text-label` `text-muted` `text-faint`
- **Surface:** `panel-*` `raised-*` `well-*` `seam` `seam-heavy`
- **Control:** `control-*` `primary-*` `alert-*`
- **Chip / Callout:** `chip-*` `callout-*`
- **Gauge:** `gauge-track` `gauge-border|border-width` `gauge-radius` `gauge-fill` `gauge-fill-glow`
- **Nav:** `tab-*` `scrollbar-*` `drawer-animation`
- **Doc prose:** `doc-family` `doc-size` `doc-leading` `doc-flow` `doc-flow-tight` `doc-heading-lead` `doc-body` `doc-heading` `doc-strong` `doc-link` `doc-link-hover` `doc-marker` `doc-bullet` `doc-heading-family|weight|tracking|transform` `doc-h1|h2|h3|h4-size` `doc-code-fg|bg|border` `doc-pre-fg`

> `system_design`-এর থিম ফাইলে এর বাইরেও টোকেন আছে (`unit-*`, `lamp-*`, `wire-*`, `gauge-*`, `diagram-*`) — ওগুলো ওই সাইটের সিমুলেটর ও Mermaid-এর জন্য। এখানে ক্যানভাস নেই, তাই ইচ্ছাকৃতভাবে বাদ। দুই সাইটের থিম sync করতে হলে ম্যানুয়াল diff — শেয়ার্ড প্যাকেজ নেই।

---

## ফন্ট শেল্ফ (`app/layout.tsx`)

তিনটি family একবারই লোড হয়; থিম ঠিক করে কোন role কোনটি পায়।

| ভেরিয়েবল | ফন্ট | control-room-এ ভূমিকা |
|---|---|---|
| `--font-condensed` | Barlow Semi Condensed | `--t-font-sans` — title, label, control, heading |
| `--font-mono-family` | JetBrains Mono | `--t-font-mono` — label, কোড, inline code |
| `--font-bengali` | Noto Sans Bengali | `--t-doc-family` — পড়ার কলাম; `--t-font-sans`-এর fallback |

> Latin ফেসগুলোতে বাংলা glyph নেই। `--t-font-sans`-এর স্ট্যাকে Noto Sans Bengali **দ্বিতীয়** — তাই latin লেবেল condensed চরিত্র রাখে, বাংলা নির্দিষ্টভাবে Noto-তে পড়ে, ব্রাউজারের এলোমেলো fallback-এ নয়।
>
> নতুন family যোগ করাই `layout.tsx` এডিট করার **একমাত্র** কারণ।
