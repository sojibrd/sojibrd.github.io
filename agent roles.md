# Claude Roles — Personal Reference
> Stack: Ember 6.4 GJS · TypeScript  
> উদ্দেশ্য: AI দিয়ে কাজ করানোর সময় কীভাবে prompt দিতে হয়

---

## কীভাবে ব্যবহার করবে

প্রতিদিন সকালে একটা প্রশ্ন করো নিজেকে:

```
আজকের কাজটা কী?
├── নতুন কিছু বানাতে হবে?  → Spec Driven:     DESIGN → TYPES → TEST → BUILD → REVIEW
├── পুরনো কিছু ঠিক করতে হবে? → Legacy Rescue:  NARRATE → EXPLAIN → REFACTOR → MIGRATE → TEST
├── কোনো decision নিতে হবে?  → Decision Making: TRADEOFF → CHALLENGE → ADR
└── ship করতে হবে?           → Quality Driven:  EDGE → CHALLENGE → PERF → A11Y → REVIEW
```

---

## Category 01 — Development (10 roles)

---

### #01 Implementer — `BUILD:`

**কাজ:** নতুন component বা feature এর কোড লেখা

**Template:**
```
BUILD:
Stack: Ember 6.4 GJS
Task: [কী বানাতে হবে]
Constraint: [কী avoid করবে]
Output: Code only
```

**Example:**
```
BUILD:
Stack: Ember 6.4 GJS
Task: reusable <Modal> component with focus trap
Constraint: no jQuery, use native FocusTrap pattern, accessible
Output: Code only
```

---

### #02 Debugger — `DEBUG:`

**কাজ:** bug খোঁজা এবং fix করা

**Template:**
```
DEBUG:
Symptom: [কী হচ্ছে]
Expected: [কী হওয়া উচিত]
[paste relevant code]
```

**Example:**
```
DEBUG:
Symptom: @tracked array push করলে template re-render হচ্ছে না
Expected: list আপডেট হওয়া উচিত
[paste component code]
```

---

### #03 Reviewer — `REVIEW:`

**কাজ:** code quality, pattern, best practice check করা

**Template:**
```
REVIEW: [stack constraint]
Check: [কী দেখতে হবে]
[paste diff only]
```

**Example:**
```
REVIEW: Ember GJS, no classic syntax
Check: reactivity issue, memory leak, a11y
[paste component diff]
```

---

### #04 Refactorer — `REFACTOR:`

**কাজ:** কাজ করছে কিন্তু messy — clean করা

**Template:**
```
REFACTOR: [goal]
Constraint: [কী change করা যাবে না]
[paste code]
```

**Example:**
```
REFACTOR: reduce cognitive complexity → readable
Constraint: public API same রাখতে হবে
[paste function]
```

---

### #05 Test Writer — `TEST:`

**কাজ:** unit বা integration test লেখা

**Template:**
```
TEST: [type], QUnit
Component: [নাম]
Cover: [কী কী case]
```

**Example:**
```
TEST: unit, QUnit
Component: <UserCard>
Cover: loading state, empty state, error state, happy path
```

---

### #06 Architect — `DESIGN:`

**কাজ:** কোড লেখার আগে structure plan করা

**Template:**
```
DESIGN: component structure
Feature: [কী বানাবে]
Constraint: [limitation]
Output: tree + data flow
```

**Example:**
```
DESIGN: component structure
Feature: multi-step checkout form
Constraint: no external state library
Output: component tree + data flow
```

---

### #07 Type Designer — `TYPES:`

**কাজ:** TypeScript interface ও type define করা

**Template:**
```
TYPES: TypeScript interfaces
For: [কী এর জন্য]
Include: [extra requirement]
```

**Example:**
```
TYPES: TypeScript interfaces
For: API response /api/users/:id
Include: error union types, loading state
```

---

### #08 API Designer — `API:`

**কাজ:** component এর public interface design করা

**Template:**
```
API: component public interface
For: [component নাম]
Output: props + events + slots
```

**Example:**
```
API: component public interface
For: <DataTable>
Output: props + events + named blocks
```

---

### #09 Mock / Stub Writer — `MOCK:`

**কাজ:** test এর জন্য fake data বা service তৈরি

**Template:**
```
MOCK: [কী mock করবে]
For: [কোথায় use হবে]
[context]
```

**Example:**
```
MOCK: Ember Data store
For: <UserList> integration test
Include: 5 UserModel records with edge case data
```

---

### #10 Boilerplate Generator — `SCAFFOLD:`

**কাজ:** নতুন file এর starting structure তৈরি করা

**Template:**
```
SCAFFOLD: [type]
Name: [নাম]
Include: [কী কী লাগবে]
```

**Example:**
```
SCAFFOLD: Ember GJS component
Name: <DataTable>
Include: loading slot, empty slot, error slot, TypeScript
```

---

## Category 02 — Analysis (7 roles)

---

### #11 Explainer — `EXPLAIN:`

**কাজ:** অপরিচিত concept বা code বোঝা

**Template:**
```
EXPLAIN: [topic]
Level: [আমার background]
Format: [কীভাবে explain চাও]
```

**Example:**
```
EXPLAIN: Glimmer VM tracking system
Level: আমি React hooks জানি
Format: analogy দিয়ে শুরু করো, তারপর detail
```

---

### #12 Performance Auditor — `PERF:`

**কাজ:** render bottleneck বা slow code খোঁজা

**Template:**
```
PERF: [কী খুঁজতে হবে]
Stack: Ember GJS
[paste component]
```

**Example:**
```
PERF: unnecessary re-render খোঁজো
Stack: Ember GJS
[paste heavy list component]
```

---

### #13 Security Auditor — `SEC:`

**কাজ:** security vulnerability খোঁজা

**Template:**
```
SEC: [কী ধরনের vulnerability]
Context: [use case]
[paste code]
```

**Example:**
```
SEC: XSS vulnerability check
Context: user-generated HTML render করছি
[paste template code]
```

---

### #14 A11y Auditor — `A11Y:`

**কাজ:** accessibility issue খোঁজা

**Template:**
```
A11Y: WCAG 2.2 check
Component: [নাম]
Focus: [কী দেখতে হবে]
```

**Example:**
```
A11Y: WCAG 2.2 check
Component: <Dropdown>
Focus: keyboard navigation, ARIA roles, focus management
```

---

### #15 Complexity Analyzer — `COMPLEXITY:`

**কাজ:** code কতটা complex সেটা measure করা

**Template:**
```
COMPLEXITY: cognitive + cyclomatic
[paste function]
Suggest: কীভাবে কমানো যায়
```

**Example:**
```
COMPLEXITY: cognitive + cyclomatic score দাও
[paste 50-line function]
Suggest: refactor strategy
```

---

### #16 Dependency Auditor — `DEPS:`

**কাজ:** addon বা package use করা safe কিনা check করা

**Template:**
```
DEPS: [addon/package নাম]
Check: [কী দেখতে হবে]
```

**Example:**
```
DEPS: ember-animated v1.0
Check: Ember 6 compatibility, maintenance status, alternatives
```

---

### #17 Bundle Analyzer — `BUNDLE:`

**কাజ:** JS bundle size কমানোর strategy

**Template:**
```
BUNDLE: [সমস্যা]
Suggest: [কী ধরনের solution চাও]
```

**Example:**
```
BUNDLE: initial JS payload অনেক বড়
Current: 800kb gzipped
Suggest: code split strategy for Ember 6
```

---

## Category 03 — Transformation (4 roles)

---

### #18 Migrator — `MIGRATE:`

**কাজ:** পুরনো pattern থেকে নতুনে নিয়ে যাওয়া

**Template:**
```
MIGRATE: [from] → [to]
Constraint: [কী same রাখতে হবে]
[paste old code]
```

**Example:**
```
MIGRATE: classic component → GJS
Constraint: same behavior, same public API
[paste classic .hbs + .js file]
```

---

### #19 Translator — `CONVERT:`

**কাজ:** এক framework থেকে অন্যটায় convert করা

**Template:**
```
CONVERT: [A] → [B]
Map: [key concept mapping]
[paste code]
```

**Example:**
```
CONVERT: React → Ember GJS
Map: useState → @tracked, useEffect → @ember/destroyable
[paste React component]
```

---

### #20 Modernizer — `MODERNIZE:`

**কাজ:** পুরনো/legacy code আধুনিক করা

**Template:**
```
MODERNIZE: [কী replace করতে হবে]
Replace with: [কী দিয়ে]
[paste legacy code]
```

**Example:**
```
MODERNIZE: jQuery dependency সরাও
Replace with: native browser APIs
[paste legacy component]
```

---

### #21 Formatter — `FORMAT:`

**কাজ:** code style/convention ঠিক করা

**Template:**
```
FORMAT: project conventions apply করো
Rules: [rules list]
[paste messy code]
```

**Example:**
```
FORMAT: project conventions apply করো
Rules: 2-space indent, single quote, no semicolon, Prettier
[paste unformatted code]
```

---

## Category 04 — Documentation (5 roles)

---

### #22 Docs Writer — `DOCS:`

**কাজ:** component বা feature এর usage guide লেখা

**Template:**
```
DOCS: [কী document করবে]
Audience: [কে পড়বে]
```

**Example:**
```
DOCS: <DataTable> component usage guide
Audience: নতুন team member যে Ember জানে না
Include: install, basic usage, props table, examples
```

---

### #23 JSDoc Writer — `JSDOC:`

**কাজ:** code এ TSDoc/JSDoc comment যোগ করা

**Template:**
```
JSDOC: TSDoc comments যোগ করো
[paste function/class]
Include: @param @returns @throws
```

**Example:**
```
JSDOC: TSDoc comments যোগ করো
[paste service method]
Include: @param @returns @throws @example
```

---

### #24 README Writer — `README:`

**কাজ:** addon বা project এর README লেখা

**Template:**
```
README: [project/addon নাম]
Include: [কী কী section]
```

**Example:**
```
README: ember-my-table addon
Include: install, peer deps, basic usage, API table, changelog link
```

---

### #25 ADR Writer — `ADR:`

**কাজ:** Architecture Decision Record লেখা

**Template:**
```
ADR: decision record
Decision: [কী সিদ্ধান্ত নিয়েছো]
Include: context, options considered, outcome, consequences
```

**Example:**
```
ADR: decision record
Decision: GJS over HBS for all new components
Include: context, options, outcome, migration plan
```

---

### #26 Changelog Writer — `CHANGELOG:`

**কাজ:** release changelog তৈরি করা

**Template:**
```
CHANGELOG: semantic format
[paste git log or PR list]
Format: Added / Changed / Fixed / Removed
```

**Example:**
```
CHANGELOG: semantic format
[paste last 10 commit messages]
Format: Keep a Changelog standard
```

---

## Category 05 — Thinking Partner (6 roles)

---

### #27 Rubber Duck — `THINK:`

**কাজ:** নিজের চিন্তা clarify করা — Claude শুধু প্রশ্ন করবে, solve করবে না

**Template:**
```
THINK: solve করো না, শুধু প্রশ্ন করো
Problem: [সমস্যা explain করো]
Goal: আমাকে নিজে answer খুঁজে পেতে সাহায্য করো
```

**Example:**
```
THINK: solve করো না, শুধু প্রশ্ন করো
Problem: জানি না service এ রাখবো নাকি component এ
Goal: সঠিক প্রশ্ন করে আমাকে decision নিতে সাহায্য করো
```

---

### #28 Devil's Advocate — `CHALLENGE:`

**কাজ:** নিজের approach এর দুর্বলতা খোঁজা — L5 এর সবচেয়ে গুরুত্বপূর্ণ habit

**Template:**
```
CHALLENGE: আমার approach
Approach: [তোমার solution describe করো]
Goal: failure mode খোঁজো, আমি ভুল প্রমাণ করো
```

**Example:**
```
CHALLENGE: আমার approach
Approach: সব global state একটা Ember Service এ রাখবো
Goal: কোথায় এটা ভেঙে পড়বে? scale এ কী সমস্যা হবে?
```

---

### #29 Tradeoff Analyzer — `TRADEOFF:`

**কাজ:** দুটো option এর মধ্যে সঠিকটা বেছে নেওয়া

**Template:**
```
TRADEOFF: [A] vs [B]
Context: [use case]
Output: comparison table + recommendation
```

**Example:**
```
TRADEOFF: Ember Data vs TanStack Query
Context: read-heavy dashboard, 10+ API endpoints
Output: table + recommendation
```

---

### #30 Root Cause Finder — `RCA:`

**কাজ:** symptom না, আসল কারণ খোঁজা

**Template:**
```
RCA: [সমস্যার নাম]
Symptom: [কী দেখছো]
[paste relevant code]
```

**Example:**
```
RCA: production memory leak
Symptom: heap 20 মিনিটে 200mb → 800mb
[paste service + component code]
```

---

### #31 Edge Case Hunter — `EDGE:`

**কাজ:** feature ship করার আগে কোথায় ভাঙতে পারে খোঁজা

**Template:**
```
EDGE: কোথায় ভাঙতে পারে?
Feature: [describe করো]
Find: race condition, boundary, unexpected input
```

**Example:**
```
EDGE: কোথায় ভাঙতে পারে?
Feature: infinite scroll list with search filter
Find: race condition, empty result, rapid scroll, network timeout
```

---

### #32 Code Narrator — `NARRATE:`

**কাজ:** অপরিচিত code step by step বোঝা

**Template:**
```
NARRATE: step by step explain করো
[paste unfamiliar code]
Explain: প্রতিটি block কী করছে এবং কেন
```

**Example:**
```
NARRATE: step by step explain করো
[paste Glimmer component with complex modifier]
Explain: কী হচ্ছে, কেন হচ্ছে, কোথায় side effect
```

---

## Category 06 — Planning (4 roles)

---

### #33 Task Breakdown — `BREAKDOWN:`

**কাজ:** বড় feature কে ছোট deliverable এ ভাগ করা

**Template:**
```
BREAKDOWN: subtask এ ভাগ করো
Feature: [বড় feature]
Output: ordered list with dependencies
```

**Example:**
```
BREAKDOWN: subtask এ ভাগ করো
Feature: real-time notification system
Output: ordered task list, dependency marked, estimate rough
```

---

### #34 PR Description Writer — `PR:`

**কাজ:** pull request description লেখা

**Template:**
```
PR: description লেখো
[paste diff summary or commit log]
Include: what changed, why, how to test
```

**Example:**
```
PR: description লেখো
[paste git log --oneline of last 5 commits]
Include: what, why, test plan, screenshot needed?
```

---

### #35 Interview Prep — `INTERVIEW:`

**কাজ:** technical interview বা system design practice

**Template:**
```
INTERVIEW: [topic]
Level: [target level]
Format: [question / mock / feedback]
```

**Example:**
```
INTERVIEW: frontend system design
Topic: design a design system from scratch
Level: Google L5
Format: আমাকে interview করো, তারপর feedback দাও
```

---

## Daily Workflow Quick Reference

```
আজকের কাজ                    → কোন flow
─────────────────────────────────────────
নতুন feature                 → DESIGN → TYPES → TEST → BUILD → REVIEW
পুরনো code modernize         → NARRATE → EXPLAIN → REFACTOR → MIGRATE → TEST
Architecture decision         → TRADEOFF → CHALLENGE → ADR
Ship করার আগে quality check  → EDGE → CHALLENGE → PERF → A11Y → REVIEW
হঠাৎ production bug          → DEBUG → RCA → CHALLENGE
```

---

## Universal Prompt Template

```
Stack: Ember 6.4 GJS/GTS, TypeScript
Layer: [UI / Data / Side-effect]
[ROLE PREFIX]:
Task: [1 line — actual problem]
Constraint: [pattern to follow / avoid]
Output: [Code / Review / Explain / ADR]
```

---

*প্রতিটি role এর example Ember 6.4 GJS context এ লেখা।*
