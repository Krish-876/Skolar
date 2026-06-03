# Skolar - Project Notes


## Existing Features (Prototype Complete)


### AI Pipeline
- PDF parsing via pdfplumber → question extraction via Groq (LLaMA 3.3 70B)
- Semantic embeddings via sentence-transformers (all-MiniLM-L6-v2), stored in Supabase pgvector
- MMR-based diverse example selection (DICL-inspired)
- Exam type filtering: quiz / midsem / compre scoping
- MCQ generation with 4 options + correct index
- Open question generation with structured model answers (marks-calibrated markdown)
- Thread-safe parallel generation (3 concurrent Groq workers)
- FastAPI backend with 7 endpoints, fully Supabase-backed

### Mock Test Platform
- 4 exam types: Quiz, Midsem, Compre Part A, Compre Part B
- MCQ Blitz mode (Compre Part A): timed quiz, score tracking, confetti
- Written Practice mode (Quiz / Midsem / Compre Part B): flashcard + paper views
- Model answers with structured markdown rendering
- Setup screen: exam type grid, subject picker, question count slider

### Exam Prediction / Question Bank Browser
- Filter by subject, year, exam type, question type
- Backed by GET /questions endpoint

### Focus Session Timer
- Preset chips: Pomodoro (25 min), 45 min, 1 hr
- Custom duration picker: 5 min to 3 hr
- Auto-reset if user leaves app mid-session

### Community Feed
- Feed cards: student name, subject, difficulty badge, upvotes, attempt count
- Upvote / downvote (in-memory state)

### Analytics Dashboard
- Donut ring chart (task progress breakdown)
- Weekly line chart (performance over 7 days)
- Task list with assignee avatars and due dates
- Recent activity feed

### Architecture
- Clean Architecture, feature-first folder structure
- Riverpod state management (AsyncNotifierProvider)
- Either<Failure, Data> error handling
- Supabase for data store (PostgreSQL + pgvector)
- College-scoped data isolation on every query

## Expected Features (Planned)

### Auth and Backend
- College email authentication (Firebase Auth / Supabase Auth)
- College name from userProvider (remove hardcoded fallback)
- PYQ upload through app UI (currently raw API only)
- Community feed backend connection (replace mock data with live Supabase query)
- Wire Attempt button in feed to MockTestNotifier.fetchQuestions()

### Personalisation
- Personal learning goal mode (e.g. DSA every day for 90 days)
- AI daily question plan
- Lives and streak system
- Coin economy: earn 1 coin per completed daily task
- Spend coins to protect streaks (like Leetcode)
- Dashboard integration with Focus session history and streaks
- Mock test scores and leaderboard
- Daily college-wide puzzle: one AI-generated logic/aptitude challenge

### ML Extension
- Full DICL pipeline: retrieve top 15 by cosine similarity → MMR over those 15 → pick 5 diverse (currently MMR runs over entire bank - see Tech Debt)
- Fine-tune FLAN-T5 on generated question-answer pairs
- Experiment comparing MMR vs random vs top-k selection
- Distractor quality analysis for MCQ options



## Feature Ideas (From Brainstorming - Not Yet in Roadmap)

### Weakness Tracker + Post-Result Flagging ⭐
- After mock test: weak topics flagged automatically from wrong answers
- Student enters real exam marks after results are released
- App correlates mock performance vs actual marks
- Compre prep: flagged weak areas from midsem get weighted higher in generation
- Quick Revision mode before compre: flashcard session over flagged weak areas only
- No edtech product currently does this loop

### Clean Subject Discussion Feed
- Replace college WhatsApp subject groups
- Subject-scoped, college-scoped, searchable
- Text posts alongside existing test-sharing posts
- Posts are permanent and searchable unlike WhatsApp

### Peer-to-Peer Doubt Solving
- Student posts a doubt from inside a mock test
- Other students from same college answer
- Best answer upvoted → answerer earns coins
- Feeds into coin economy
- Zero API cost

### User Growth Card / Resume Export
- Auto-generated from activity history: tests attempted, streak data, subjects covered, score improvement
- One-tap export as shareable card or PDF
- Skolar branding on every export = free distribution / viral marketing

### College Leaderboard
- Rank students by coins, streak, tests attempted
- Social pressure to study consistently
- Scoped per college

### B2B Professor Portal
- Professor-facing web UI wrapping existing /upload-pyq endpoint
- Upload PYQs, tag subject/exam type, view question bank, download generated papers
- Turns Skolar from student app into institutional product
- Unlocks college licensing as a revenue model



## Tech Debt

- DICL pipeline incomplete: MMR currently runs over entire question bank instead of top-15 retrieval → MMR over those 15. Fix is ~3 lines in pipeline.py (see conversation notes)
- Duplicate controller file: widgets/focus_timer_controller.dart duplicates controllers/focus_timer_controller.dart - delete widgets copy
- FocusTimerController.resume() is a no-op - re-start ticker or remove
- FocusTimerStatus.paused defined but never set
- No session persistence for focus sessions
- Vote state (upvotes/downvotes) is in-memory only - needs Supabase write when auth lands
- College name hardcoded as 'BITS Pilani · Hyderabad' in feed TopBar


## Checklist

**Moat:** College-specific AI calibration using institutional PYQ data - gets stronger with every college that onboards, impossible to replicate without the data corpus.

**Retention:** Daily puzzles, streaks, lives, coins - Duolingo's psychology applied to serious academic prep which Duolingo never touched.

**Monetisation:** Coin economy - earn via daily tasks and puzzles, spend to protect streaks. Non-intrusive, felt as earned not purchased. Scales naturally with user growth.

**Network Effects:** Community feed + college leaderboard + shared daily puzzle means every new user makes the platform more valuable for existing users. Classic flywheel.

**B2B Ceiling:** Professor portal turns it from a student app into an institutional product. Colleges pay for access. Completely different revenue scale.

**The one real risk:** PYQ cold start calibration is only as good as the data uploaded per college. Solve by going deep at BITS Hyderabad first, proving it works, then expanding college by college.


*Skolar - Built by Krishna, BITS Pilani Hyderabad, B.Tech CSE 2024–2028*