# sojibrd.github.io — Agent Instructions

ব্যক্তিগত portfolio। workspace-এর একমাত্র সাইট যেটা **Next.js নয়** — plain static HTML/CSS, কোনো build, `package.json` বা Actions workflow নেই। GitHub Pages সরাসরি `master`-এর ফাইলগুলোই পরিবেশন করে, তাই **push করলেই লাইভ**।

- **repo public, আর root-এর প্রতিটা ফাইল লাইভ URL-এ পড়া যায়** — `index.html` থেকে লিংক না থাকলেও (`https://sojibrd.github.io/<ফাইলের-নাম>`)। এখানে কিছু রাখার আগে ধরে নিন যেকেউ সেটা পড়তে পারবে।
- এই repo-তে **শুধু সাইটের জিনিস** — পেজ, স্টাইল, অ্যাসেট। নোট, ডেটা ডাম্প, training data, CV বা ব্যক্তিগত ডক এখানে নয়; সেগুলোর জায়গা `brainstorming/`। ২০২৬-০৯-২১-এ এমন ১৫টা ফাইল `brainstorming/unrelated/`-এ সরানো হয়েছে।
- বর্তমান ফাইল: `index.html` (portfolio), `requirements-mcq-tool.html` (System Design Requirements Analyzer — স্বতন্ত্র টুল, `index.html` থেকে লিংক করা নেই), `favicon.svg`, `prompt/` (`ai_prompt_reference`-এর static export — `BASE_PATH=/prompt npm run build` দিয়ে বানিয়ে `out/` এখানে কপি করা; হাতে edit করবেন না), `.nojekyll` (না থাকলে Pages `prompt/_next/` বাদ দেয়)।
- সাইট **dark-only**, কিন্তু এখানে বাকি সাইটগুলোর theme contract (`--t-*` টোকেন, role class) **প্রযোজ্য নয়** — স্টাইল `index.html`-এর ভেতরেই। ছাঁচ মেলাতে গিয়ে Next.js-এর কনভেনশন টেনে আনবেন না।
- `README.md`-এ লাইভ প্রজেক্টের তালিকা বদলালে root `README.md`-এর টেবিলও মিলিয়ে নিন।
