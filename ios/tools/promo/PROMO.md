# Promo page for Arabic puzzle games (with Kalimat), started 2026-11-23

## The page

**Who it's for:** people who like Arabic word games, quizzes and general knowledge.
- Content comes first; the game is the call to action.
- A page that posts only ads doesn't grow. A page that posts a daily puzzle people answer in the comments does. Each video then ends on the game that holds 250 more.

**Name ideas:**
- «ألغاز وكلمات» (Puzzles and Words)
- «تحدي الكلمات» (The Word Challenge)
- «لغز اليوم» (Puzzle of the Day)

Check the handle is free on TikTok, Instagram, YouTube Shorts, Facebook and Snapchat.

**Bio:** «لغز كل يوم 🧩 جاوب في التعليقات. اللعبة: كلمات متقاطعة: ألغاز وذكاء 👇» ("A puzzle every day. Answer in the comments. The game: Kalimat 👇"). Put the App Store link in the bio wherever the platform allows it.

**Other games on the page:**
- Only use footage you recorded yourself, on your own phone, and credit each game.
- Better still, message the developer first. Most indie developers are happy to be featured, and some will feature Kalimat back.
- Never use a game's trailer, art or name in a way that looks like their own ad.

## Videos (all from real gameplay recorded in the iPhone simulator)

| Format | What happens | Why it works |
|---|---|---|
| `challenge-*` | Hook from frame 0 ("سؤال لأهل الخليج", "a question for Gulf people"), then a 5-second countdown over the real board, then the real solve, then "الجواب: …" ("The answer: …") | The viewer plays along and comments an answer, which is what the algorithm rewards |
| `ws-*` | "Find the word" in the real word-search grid, with a countdown, then the line drawn over the word | Same mechanic: the eye hunts through the grid |
| `speedrun-*` | A whole level, sped up (the video says so), ending on «ممتاز!» ("Excellent!") with the IQ score | Satisfying to watch, and shows the full game |

Every video ends with a 2.5-second card: the icon, «كلمات متقاطعة: ألغاز وذكاء», «مجانية على App Store» ("free on the App Store") and «٢٥٠ لغزًا» ("250 puzzles"). Every claim matches the App Store listing.

## How to make them

```sh
cd ~/projects/apps/kalimat/kalimat-ios
tools/promo/record.sh tools/promo/rec3 p03-010,p05-012,p02-w007    # plays + records real levels (~1.5 min per level)
python3 tools/promo/make_videos.py tools/promo/rec3                  # -> rec3/videos/*.mp4 + manifest.csv
```

- **Timing:** each clue is recorded as its own file. `watch_record.py` starts the recorder on the test's `CLUE` line and stops it 2 s after `SOLVED`. The answer frame is the one right after the clue card's "solved" flash.

- **Videos are silent.** At upload, add a trending sound with no lyrics, or a calm instrumental from the platform library.
- **Captions** for each video are ready in `videos/manifest.csv`.

## Posting plan (first 3 weeks)

1. **Volume:** 2–3 videos a day across all platforms (TikTok, Reels, Shorts, Facebook Reels), at the same hours each day, ideally after Maghrib and after Isha Gulf time.
2. **Mix per day:** 1 challenge, plus 1 word search or speedrun.
3. **Hooks:** rotate the three second-line hooks already built into the videos (see the `line2` column of the manifest):
   - «تقدر تحلها في ٥ ثواني؟» ("Can you solve it in 5 seconds?")
   - «جاوب قبل ما يخلص الوقت» ("Answer before time runs out")
   - «اكتب الجواب في التعليقات» ("Write the answer in the comments")
4. **Comments:** reply to the first comments, especially wrong answers («قريب! 😄» "close!"). Replies push the video further.
5. **Measure after 2 weeks:**
   - Note each video's views, average watch time and comment count.
   - Compare by `format`, `hook`/`line2` and pack (Gulf, language, experts…).
   - Make more of what wins.
6. **Pay to boost later:** once a video brings installs, boost it with a small budget (TikTok Spark Ads, or Meta's boost on the same video). The best organic video becomes the paid ad.
