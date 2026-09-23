# Prompt Caching

## সংজ্ঞা
প্রম্পটের যে অংশ বারবার একই থাকে, সেটা সার্ভারে ক্যাশ করে রাখা। পরের কলে ওই অংশ আবার প্রসেস করতে হয় না — খরচ ও লেটেন্সি দুটোই কমে।

## কখন ব্যবহার করবেন
- বড় system prompt বা টুল সংজ্ঞা, যা প্রতি কলে একই
- একই ডকুমেন্ট নিয়ে একাধিক প্রশ্ন
- মাল্টি-টার্ন কথোপকথন

## উদাহরণ
```python
response = client.messages.create(
    model="claude-sonnet-5",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": LONG_SYSTEM_PROMPT + COMPANY_POLICY_DOC,
            "cache_control": {"type": "ephemeral"},   # ← এই বিন্দু পর্যন্ত ক্যাশ
        }
    ],
    messages=[{"role": "user", "content": user_question}],
)

usage = response.usage
print(usage.cache_creation_input_tokens)   # প্রথম কলে ভরে
print(usage.cache_read_input_tokens)       # পরের কলে এখান থেকে পড়ে
```

## মূল নিয়ম
- ক্যাশ **প্রিফিক্স-ভিত্তিক** — শুরুর দিকে একটা অক্ষর বদলালেও পুরো ক্যাশ ভেঙে যায়
- তাই বদলানো জিনিস (তারিখ, ইউজারের নাম, র‍্যান্ডম আইডি) কখনো ক্যাশ ব্লকের ভেতরে রাখবেন না
- ক্যাশ লেখার খরচ সাধারণ ইনপুটের চেয়ে বেশি — একবারই ব্যবহার হবে এমন প্রম্পট ক্যাশ করে লাভ নেই
- ক্যাশের একটা TTL থাকে; সেটা পেরোলে আবার নতুন করে তৈরি হয়
- কনটেক্সটের ক্রম ঠিক রাখলে ক্যাশ এমনিতেই কাজ করে, দেখুন [Context Engineering](../04-context-engineering/)
