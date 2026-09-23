# Self-consistency

## সংজ্ঞা
একই প্রম্পট কয়েকবার চালিয়ে (temperature > 0) একাধিক উত্তর নেওয়া, তারপর সবচেয়ে বেশিবার আসা উত্তরটা বেছে নেওয়া। সহজ কথায় — মেজরিটি ভোট।

## কখন ব্যবহার করবেন
- উত্তরটা একটা নির্দিষ্ট মান (ক্যাটাগরি, সংখ্যা, হ্যাঁ/না)
- নির্ভুলতা খরচের চেয়ে বেশি গুরুত্বপূর্ণ
- মডেল মাঝে মাঝে ভুল করে, কিন্তু বেশিরভাগ সময় ঠিক করে

কখন **নয়**: লম্বা লেখা তৈরিতে — সেখানে "মেজরিটি" বলে কিছু নেই।

## উদাহরণ
```python
from collections import Counter

def classify_with_vote(ticket, runs=5):
    votes = []
    for _ in range(runs):
        r = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=100,
            temperature=1.0,          # ভিন্নতা দরকার, তাই ০ নয়
            messages=[{"role": "user", "content": PROMPT.format(ticket=ticket)}],
        )
        votes.append(r.content[0].text.strip())

    counts = Counter(votes)
    winner, count = counts.most_common(1)[0]

    return {
        "ক্যাটাগরি": winner,
        "আস্থা": count / runs,        # ৩/৫ = ০.৬ → মানুষের রিভিউ দরকার
        "সব_ভোট": dict(counts),
    }
```

## মূল নিয়ম
- খরচ সরাসরি গুণ হয় — ৫ বার চালানো মানে ৫ গুণ বিল
- **আস্থার স্কোরটাই আসল লাভ** — ভোট ভাগ হয়ে গেলে বুঝবেন কেসটা কঠিন, সেটা মানুষের কাছে পাঠান
- `temperature=0` রাখলে সব উত্তর একই আসবে, কৌশলটাই অর্থহীন হয়ে যাবে — দেখুন [Sampling Parameters](../../04-evaluation/05-sampling-parameters/)
