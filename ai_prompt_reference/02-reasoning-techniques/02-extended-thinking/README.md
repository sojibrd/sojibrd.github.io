# Extended Thinking / Reasoning Tokens

## সংজ্ঞা
মডেলের নিজস্ব চিন্তার বাজেট, যা API প্যারামিটার দিয়ে চালু করা হয়। হাতে লেখা Chain-of-Thought-এর বিল্ট-ইন ও প্রশিক্ষিত সংস্করণ।

## কখন ব্যবহার করবেন
- জটিল কোড ডিবাগিং, গণিত, বহুধাপ পরিকল্পনা
- যেখানে ভুলের খরচ বেশি, আর কয়েক সেকেন্ড বেশি লাগলে সমস্যা নেই

কখন **নয়**: শ্রেণিবিন্যাস, তথ্য নিষ্কাশন, সামারি — এসবে চিন্তার বাজেট শুধু টাকা পোড়ায়।

## উদাহরণ
```python
import anthropic

client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-sonnet-5",
    max_tokens=8000,
    thinking={
        "type": "enabled",
        "budget_tokens": 4000,     # max_tokens-এর চেয়ে কম হতে হবে
    },
    messages=[{
        "role": "user",
        "content": "এই SQL কোয়েরিটা প্রোডাকশনে ২০ সেকেন্ড নিচ্ছে। কারণ কী হতে পারে?\n\n" + query,
    }],
)

# response.content-এ দুই ধরনের ব্লক আসে
for block in response.content:
    if block.type == "thinking":
        log.debug(block.thinking)   # ডিবাগিং লগে রাখুন, ইউজারকে দেখানোর দরকার নেই
    elif block.type == "text":
        print(block.text)           # আসল উত্তর
```

## মূল নিয়ম
- `budget_tokens` সবসময় `max_tokens`-এর চেয়ে **কম** রাখতে হবে
- thinking চালু থাকলে [Response Prefilling](../../01-basic-techniques/07-response-prefilling/) কাজ করবে না
- বাজেট বাড়ালেই মান বাড়ে না — কাজটা সত্যিই জটিল না হলে ৩০০০-এর বেশি দিয়ে লাভ নেই
- thinking ব্লক নিজে থেকে ইউজারকে দেখাবেন না, তবে ডিবাগিং লগে রাখা কাজের
