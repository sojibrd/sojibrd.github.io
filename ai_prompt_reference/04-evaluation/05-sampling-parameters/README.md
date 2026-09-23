# Sampling Parameters

## সংজ্ঞা
মডেল পরের টোকেন কীভাবে বাছবে তা নিয়ন্ত্রণকারী প্যারামিটার — মূলত `temperature`, `top_p`, `max_tokens`, `stop_sequences`।

## কখন ব্যবহার করবেন
- আউটপুট প্রতিবার একই লাগবে (eval, শ্রেণিবিন্যাস, তথ্য নিষ্কাশন) → `temperature=0`
- আউটপুটে ভিন্নতা লাগবে (আইডিয়া, কপি, [Self-consistency](../../02-reasoning-techniques/03-self-consistency/)) → বেশি temperature
- আউটপুট নির্দিষ্ট জায়গায় থামাতে হবে → `stop_sequences`

ডিফল্ট নিয়ম: সন্দেহ হলে `temperature=0` রাখুন, `top_p`-তে হাত দেবেন না।

## কোনটা কখন
| প্যারামিটার | কাজ | কখন বদলাবেন |
|---|---|---|
| `temperature` | এলোমেলো ভাব (০–১) | নির্ভুলতা চাইলে ০, সৃজনশীলতা চাইলে ০.৭–১ |
| `top_p` | সম্ভাব্য টোকেনের পুল ছাঁটাই | সাধারণত হাত দেবেন না |
| `max_tokens` | আউটপুটের সর্বোচ্চ দৈর্ঘ্য | খরচ ও কাটা-পড়া নিয়ন্ত্রণে |
| `stop_sequences` | নির্দিষ্ট টেক্সট এলে থেমে যাওয়া | কাঠামোবদ্ধ আউটপুট কাটতে |

## কাজভিত্তিক সেটিং
```python
# শ্রেণিবিন্যাস, তথ্য নিষ্কাশন, eval — একই ইনপুটে একই আউটপুট চাই
temperature=0

# সাপোর্ট উত্তর, সামারি — সামান্য স্বাভাবিকতা
temperature=0.3

# মার্কেটিং কপি, আইডিয়া জেনারেশন
temperature=0.8

# Self-consistency — ভিন্নতা না থাকলে কৌশলটাই অর্থহীন
temperature=1.0
```

## উদাহরণ — stop sequence
```python
response = client.messages.create(
    model="claude-sonnet-5",
    max_tokens=500,
    temperature=0,
    stop_sequences=["</উত্তর>"],     # উত্তর ট্যাগ শেষ হলেই থেমে যাবে
    messages=messages,
)
```

## মূল নিয়ম
- `temperature` আর `top_p` একসাথে বদলাবেন না — একটা বেছে নিন
- **eval সবসময় `temperature=0`-তে চালান**, নাহলে র‍্যান্ডমনেসকে উন্নতি বা [regression](../03-regression-testing/) ভেবে ভুল করবেন
- `temperature=0` মানে শতভাগ নিশ্চিত পুনরাবৃত্তি নয়, তবে খুব কাছাকাছি
- `max_tokens` কম রাখলে উত্তর মাঝপথে কাটা পড়ে — JSON হলে পার্সিং ভাঙে
