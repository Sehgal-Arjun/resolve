import Foundation

/// Data for the canned demo chat shown during onboarding. Each `OnboardingDemoQuestion`
/// is a pre-baked conversation: a user question plus three states the advocates
/// move through (initial 3-2 split → 4-1 → 5-0 consensus). Adding more questions
/// is just appending to `allQuestions`; `randomSelection(count:)` picks a fresh
/// subset for each onboarding run, so the picker doesn't feel deterministic.
struct OnboardingDemoQuestion: Identifiable, Equatable {
    let id: String
    let emoji: String
    let title: String
    /// Exactly three states: index 0 = initial 3-2 split, index 1 = 4-1
    /// after the first resolve round, index 2 = 5-0 consensus.
    let states: [OnboardingDemoState]

    static func == (lhs: OnboardingDemoQuestion, rhs: OnboardingDemoQuestion) -> Bool {
        lhs.id == rhs.id
    }
}

struct OnboardingDemoState {
    let advocates: [OnboardingDemoAdvocate]
    let arbiterSummary: String
    /// Stance groups drive the color capsule on each advocate card. Member
    /// keys match `AdvocateProvider.backendKey` (lowercase). At state 2 there
    /// are two groups (4-1); at state 3 a single group of all five.
    let classifierGroups: [OnboardingDemoStanceGroup]
}

struct OnboardingDemoAdvocate {
    let provider: AdvocateProvider
    /// The short summary shown on the advocate card.
    let summary: String
    /// Longer reasoning shown in the drawer when the user clicks the card.
    let detailedReasoning: String
}

struct OnboardingDemoStanceGroup {
    let members: [String]
}

// MARK: - Catalog

enum OnboardingDemoData {
    /// All pre-baked questions. Append to grow the pool — `randomSelection`
    /// will start serving them automatically. There's no upper bound; the
    /// picker just shows whatever count it asks for.
    static let allQuestions: [OnboardingDemoQuestion] = [
        coffeeVsTea,
        catsVsDogs,
        morningVsNightOwl,
        pineappleOnPizza,
        meditationWorthIt
    ]

    /// Pick `count` distinct questions in random order. Fewer than the full
    /// pool means each onboarding run gets a different subset.
    static func randomSelection(count: Int = 5) -> [OnboardingDemoQuestion] {
        Array(allQuestions.shuffled().prefix(count))
    }
}

// MARK: - Question 1: Coffee or tea for deep work?

private let coffeeVsTea = OnboardingDemoQuestion(
    id: "coffee-vs-tea",
    emoji: "☕",
    title: "Coffee or tea for deep work?",
    states: [
        // State 1 — 3-2 for coffee
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Coffee. The caffeine kick is sharper and more reliable for sustained focus.",
                    detailedReasoning: "Coffee delivers a sharper rise in alertness within 20–30 minutes, with peak cognitive enhancement at the 1–2 hour mark. Across studies of working memory and sustained attention, coffee outperforms tea by a meaningful margin. The trade-off in jitteriness is real but manageable: drink it 60–90 minutes before deep work begins."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Tea. L-theanine provides smoother, jitter-free focus over longer periods.",
                    detailedReasoning: "Tea's combination of caffeine plus L-theanine produces a distinctly smoother focus profile. Studies on alpha-wave activity show meditative-yet-alert states that line up well with extended cognitive work. The lack of crashes means a single afternoon session of green tea can outlast morning coffee without diminishing returns."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Coffee. Higher caffeine content means stronger, more immediate cognitive enhancement.",
                    detailedReasoning: "Caffeine concentration is the principal lever for cognitive enhancement, and coffee delivers roughly twice the dose per cup compared to tea. The metabolite paraxanthine — primary driver of alertness — peaks higher and faster after coffee. For tasks demanding sharp, immediate engagement, this differential is decisive."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Tea. Gentler caffeine release without the crash, ideal for marathon sessions.",
                    detailedReasoning: "Tea's release profile aligns with sustained attention rather than phasic alertness. Marathon coding sessions, long writing blocks, deep reading — these benefit from tea's gentler curve. The absence of a 4-hour crash means productivity stays consistent rather than spiking and collapsing."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Coffee. The ritual signals focus mode, and the alertness boost outpaces tea.",
                    detailedReasoning: "Beyond pure caffeine, the ritual of brewing coffee triggers a behavioral cue: a clear signal to the brain that focus mode is starting. Tea has its own ritual, but coffee's bitter, intense profile lines up better with the kind of cognitive sharpness deep work demands. The placebo-plus-pharmacology combo is hard to beat."
                )
            ],
            arbiterSummary: "Three advocates lean **coffee** for its sharper caffeine intensity and the ritualistic role; two lean tea for the smoother alertness curve. The disagreement comes down to whether deep work benefits more from a sharp peak or a sustained baseline.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral"]),
                OnboardingDemoStanceGroup(members: ["anthropic", "deepseek"])
            ]
        ),
        // State 2 — 4-1, DeepSeek shifts to coffee
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Coffee. The caffeine kick is sharper and more reliable for sustained focus.",
                    detailedReasoning: "Coffee delivers a sharper rise in alertness within 20–30 minutes, with peak cognitive enhancement at the 1–2 hour mark. Across studies of working memory and sustained attention, coffee outperforms tea by a meaningful margin. The trade-off in jitteriness is real but manageable: drink it 60–90 minutes before deep work begins."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Tea. L-theanine provides smoother, jitter-free focus over longer periods.",
                    detailedReasoning: "Tea's combination of caffeine plus L-theanine produces a distinctly smoother focus profile. Studies on alpha-wave activity show meditative-yet-alert states that line up well with extended cognitive work. The lack of crashes means a single afternoon session of green tea can outlast morning coffee without diminishing returns."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Coffee. Higher caffeine content means stronger, more immediate cognitive enhancement.",
                    detailedReasoning: "Caffeine concentration is the principal lever for cognitive enhancement, and coffee delivers roughly twice the dose per cup compared to tea. The metabolite paraxanthine — primary driver of alertness — peaks higher and faster after coffee. For tasks demanding sharp, immediate engagement, this differential is decisive."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Coffee, on reflection. The alertness gradient does match sustained focus better than I initially weighted.",
                    detailedReasoning: "Reconsidering: my original argument hinged on smoothness of the curve, but research on sustained attention shows high-peak alertness recovers between blocks more reliably than I gave it credit for. The pulsed pattern of coffee actually maps better to focused-work-then-rest cycles than the steady tea baseline. The crash is real but solved by timing, not avoidance."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Coffee. The ritual signals focus mode, and the alertness boost outpaces tea.",
                    detailedReasoning: "Beyond pure caffeine, the ritual of brewing coffee triggers a behavioral cue: a clear signal to the brain that focus mode is starting. Tea has its own ritual, but coffee's bitter, intense profile lines up better with the kind of cognitive sharpness deep work demands. The placebo-plus-pharmacology combo is hard to beat."
                )
            ],
            arbiterSummary: "Most advocates now favor **coffee**. DeepSeek has shifted, agreeing the alertness gradient suits sustained focus better than the smoother tea curve. Only Anthropic still defends tea's longer, gentler release.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral", "deepseek"]),
                OnboardingDemoStanceGroup(members: ["anthropic"])
            ]
        ),
        // State 3 — 5-0, Anthropic shifts
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Coffee. The caffeine kick is sharper and more reliable for sustained focus.",
                    detailedReasoning: "Coffee delivers a sharper rise in alertness within 20–30 minutes, with peak cognitive enhancement at the 1–2 hour mark. Across studies of working memory and sustained attention, coffee outperforms tea by a meaningful margin. The trade-off in jitteriness is real but manageable: drink it 60–90 minutes before deep work begins."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Coffee, with caveats. For genuinely demanding cognitive work, the higher peak alertness helps — though timing matters more than the choice itself.",
                    detailedReasoning: "Conceding the point, with nuance. Tea's smoother curve is genuinely better for casual focus sessions, but for the demanding cognitive work the question asked about, coffee's higher peak does help. The dosing window matters more than the choice — drinking either too late corrupts sleep, which corrupts the next day's deep work. Coffee wins the substance question; timing wins the meta question."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Coffee. Higher caffeine content means stronger, more immediate cognitive enhancement.",
                    detailedReasoning: "Caffeine concentration is the principal lever for cognitive enhancement, and coffee delivers roughly twice the dose per cup compared to tea. The metabolite paraxanthine — primary driver of alertness — peaks higher and faster after coffee. For tasks demanding sharp, immediate engagement, this differential is decisive."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Coffee, on reflection. The alertness gradient does match sustained focus better than I initially weighted.",
                    detailedReasoning: "Reconsidering: my original argument hinged on smoothness of the curve, but research on sustained attention shows high-peak alertness recovers between blocks more reliably than I gave it credit for. The pulsed pattern of coffee actually maps better to focused-work-then-rest cycles than the steady tea baseline. The crash is real but solved by timing, not avoidance."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Coffee. The ritual signals focus mode, and the alertness boost outpaces tea.",
                    detailedReasoning: "Beyond pure caffeine, the ritual of brewing coffee triggers a behavioral cue: a clear signal to the brain that focus mode is starting. Tea has its own ritual, but coffee's bitter, intense profile lines up better with the kind of cognitive sharpness deep work demands. The placebo-plus-pharmacology combo is hard to beat."
                )
            ],
            arbiterSummary: "All five advocates now agree **coffee** is the better choice for deep work. Higher caffeine produces sharper cognitive gains, the ritual reinforces focus, and timing matters more than smoothness. **Coffee wins for deep work.**",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "anthropic", "gemini", "deepseek", "mistral"])
            ]
        )
    ]
)

// MARK: - Question 2: Cats or dogs?

private let catsVsDogs = OnboardingDemoQuestion(
    id: "cats-vs-dogs",
    emoji: "🐾",
    title: "Cats or dogs — better companion?",
    states: [
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Dogs. Loyal, social, emotionally attuned, and they encourage outdoor activity.",
                    detailedReasoning: "Dogs form unusually intense social bonds with humans — co-evolved over tens of thousands of years to read facial expressions and emotional cues. The activity overhead is the feature, not the bug: daily walks structure outdoor time, exercise, and casual social contact. For people prone to isolation, the forced rhythm is genuinely health-protective."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Cats. Lower-maintenance, with companionship that doesn't demand constant attention.",
                    detailedReasoning: "Cats offer companionship without the heavy daily logistics of dog ownership. They tolerate solo workdays, don't require walks, and form attachments on their own terms. For people whose lives don't accommodate the structured demands of a dog, cats provide presence and warmth without requiring lifestyle reorganization."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Dogs. Stronger emotional bond formation and more interactive playmates.",
                    detailedReasoning: "Dogs are reciprocally affectionate in a way few other domesticated animals are — they actively seek out their humans, mirror moods, and engage in joint play. Cat affection exists but is more conditional and cooler in expression. For people who want a companion that meets them with consistent enthusiasm, dogs are unmatched."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Cats. More compatible with apartment living and irregular schedules.",
                    detailedReasoning: "The lifestyle math favors cats for many modern living situations. Apartment-dwellers, frequent travelers, and people with irregular work schedules can keep cats without straining the animal's wellbeing. Dogs in apartments often suffer; cats in apartments thrive. The compatibility question is underweighted in the dog-supremacist framing."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Dogs. A deeper sense of presence and unconditional warmth than cats provide.",
                    detailedReasoning: "There's a quality of presence dogs bring — a constant, attentive, body-following warmth — that cats simply don't replicate. The unconditional aspect matters: a dog is happy to see you because you're you, not because you opened a can. For the role of a true companion, that consistency is the core differentiator."
                )
            ],
            arbiterSummary: "Three advocates favor **dogs** for emotional attunement, activity-driving habits, and bonding depth. Anthropic and DeepSeek favor cats for lower maintenance and lifestyle flexibility. The split is between *what kind of companion* — engaged or autonomous.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral"]),
                OnboardingDemoStanceGroup(members: ["anthropic", "deepseek"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Dogs. Loyal, social, emotionally attuned, and they encourage outdoor activity.",
                    detailedReasoning: "Dogs form unusually intense social bonds with humans — co-evolved over tens of thousands of years to read facial expressions and emotional cues. The activity overhead is the feature, not the bug: daily walks structure outdoor time, exercise, and casual social contact. For people prone to isolation, the forced rhythm is genuinely health-protective."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Dogs, on reflection. The depth of bond + activity-driving role does outweigh the maintenance overhead for most people.",
                    detailedReasoning: "Reconsidering my position: the maintenance argument I led with treats logistics as the deciding factor, but the question was about which is the better companion. On companionship terms specifically, the depth of dog-human bonding and the structuring effect on daily life genuinely outweigh the convenience advantages of cats. Maintenance is a secondary concern, not the primary one."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Dogs. Stronger emotional bond formation and more interactive playmates.",
                    detailedReasoning: "Dogs are reciprocally affectionate in a way few other domesticated animals are — they actively seek out their humans, mirror moods, and engage in joint play. Cat affection exists but is more conditional and cooler in expression. For people who want a companion that meets them with consistent enthusiasm, dogs are unmatched."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Cats. More compatible with apartment living and irregular schedules.",
                    detailedReasoning: "The lifestyle math favors cats for many modern living situations. Apartment-dwellers, frequent travelers, and people with irregular work schedules can keep cats without straining the animal's wellbeing. Dogs in apartments often suffer; cats in apartments thrive. The compatibility question is underweighted in the dog-supremacist framing."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Dogs. A deeper sense of presence and unconditional warmth than cats provide.",
                    detailedReasoning: "There's a quality of presence dogs bring — a constant, attentive, body-following warmth — that cats simply don't replicate. The unconditional aspect matters: a dog is happy to see you because you're you, not because you opened a can. For the role of a true companion, that consistency is the core differentiator."
                )
            ],
            arbiterSummary: "Four of five advocates now lean **dogs**. Anthropic has reconsidered, agreeing bonding depth tips the scale despite maintenance trade-offs. Only DeepSeek still favors cats for lifestyle compatibility.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "anthropic", "gemini", "mistral"]),
                OnboardingDemoStanceGroup(members: ["deepseek"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Dogs. Loyal, social, emotionally attuned, and they encourage outdoor activity.",
                    detailedReasoning: "Dogs form unusually intense social bonds with humans — co-evolved over tens of thousands of years to read facial expressions and emotional cues. The activity overhead is the feature, not the bug: daily walks structure outdoor time, exercise, and casual social contact. For people prone to isolation, the forced rhythm is genuinely health-protective."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Dogs, on reflection. The depth of bond + activity-driving role does outweigh the maintenance overhead for most people.",
                    detailedReasoning: "Reconsidering my position: the maintenance argument I led with treats logistics as the deciding factor, but the question was about which is the better companion. On companionship terms specifically, the depth of dog-human bonding and the structuring effect on daily life genuinely outweigh the convenience advantages of cats. Maintenance is a secondary concern, not the primary one."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Dogs. Stronger emotional bond formation and more interactive playmates.",
                    detailedReasoning: "Dogs are reciprocally affectionate in a way few other domesticated animals are — they actively seek out their humans, mirror moods, and engage in joint play. Cat affection exists but is more conditional and cooler in expression. For people who want a companion that meets them with consistent enthusiasm, dogs are unmatched."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Dogs. While cats still suit certain schedules, the daily emotional payoff genuinely outweighs the convenience differential.",
                    detailedReasoning: "Updating my view. The lifestyle-compatibility argument is real, but it's an argument about *whether* to get a pet, not *which* pet is the better companion. Conditional on choosing one, the consistent emotional return from dogs exceeds the more conditional affection of cats. Cats remain a great choice for lifestyles that can't accommodate dogs — but they're not the better companion in absolute terms."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Dogs. A deeper sense of presence and unconditional warmth than cats provide.",
                    detailedReasoning: "There's a quality of presence dogs bring — a constant, attentive, body-following warmth — that cats simply don't replicate. The unconditional aspect matters: a dog is happy to see you because you're you, not because you opened a can. For the role of a true companion, that consistency is the core differentiator."
                )
            ],
            arbiterSummary: "All advocates now agree **dogs** make for the better companion. The consensus: deeper emotional bonding, the structured routines they create, and the consistency of presence. **Dogs win — though cats remain valid for specific lifestyles.**",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "anthropic", "gemini", "deepseek", "mistral"])
            ]
        )
    ]
)

// MARK: - Question 3: Morning routine or night owl?

private let morningVsNightOwl = OnboardingDemoQuestion(
    id: "morning-vs-night-owl",
    emoji: "🌅",
    title: "Morning routine or night owl — more productive?",
    states: [
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Morning. Cortisol peaks early; aligning deep work with biology pays dividends.",
                    detailedReasoning: "Cortisol — the alertness hormone — peaks 30-45 minutes after waking and stays elevated through midday. Aligning the most demanding cognitive work with this window stacks biology in your favor. Studies of executive-function performance consistently show morning advantages, even controlling for self-reported chronotype."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Night owl. Late hours bring fewer interruptions and creative looseness.",
                    detailedReasoning: "The 'productive hours' question is partly about external interruption. Late at night, email is dormant, meetings impossible, and social pressure to respond evaporates. The looser cognitive state late at night also favors associative, creative thinking — the kind of work that wants tangents and quiet, not sharp executive focus."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Morning. Decision fatigue accumulates, so front-loading hard work is optimal.",
                    detailedReasoning: "Decision fatigue is well-documented: each significant choice across a day depletes a finite executive resource. Front-loading the day's hardest cognitive work means you spend that resource where it matters most, before email, meetings, and small daily decisions have eroded it. Working late often means working with depleted reserves."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Night owl. Fewer distractions from others, more headspace for original thought.",
                    detailedReasoning: "Original thought needs sustained quiet and the absence of context-switches. Mornings are an interruption gauntlet: notifications, family routines, work pings. Late nights flatten that noise floor, making it possible to hold a complex problem in working memory for hours without getting yanked out. For ideation-heavy work, night wins."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Morning. Consistency with social rhythms multiplies output.",
                    detailedReasoning: "Productivity isn't only about the individual hour — it's about coordination with others. Morning routines align with the rhythm of work, school, family, and social commitments. Night work often comes at the cost of the next morning's coordination, making net output worse despite high-quality individual hours."
                )
            ],
            arbiterSummary: "OpenAI, Gemini, and Mistral favor **mornings** for biological alignment, decision-making freshness, and social rhythms. Anthropic and DeepSeek prefer nights for fewer interruptions and creative latitude. The tension is *interruption-free time* vs *biological readiness*.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral"]),
                OnboardingDemoStanceGroup(members: ["anthropic", "deepseek"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Morning. Cortisol peaks early; aligning deep work with biology pays dividends.",
                    detailedReasoning: "Cortisol — the alertness hormone — peaks 30-45 minutes after waking and stays elevated through midday. Aligning the most demanding cognitive work with this window stacks biology in your favor. Studies of executive-function performance consistently show morning advantages, even controlling for self-reported chronotype."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Night owl. Late hours bring fewer interruptions and creative looseness.",
                    detailedReasoning: "The 'productive hours' question is partly about external interruption. Late at night, email is dormant, meetings impossible, and social pressure to respond evaporates. The looser cognitive state late at night also favors associative, creative thinking — the kind of work that wants tangents and quiet, not sharp executive focus."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Morning. Decision fatigue accumulates, so front-loading hard work is optimal.",
                    detailedReasoning: "Decision fatigue is well-documented: each significant choice across a day depletes a finite executive resource. Front-loading the day's hardest cognitive work means you spend that resource where it matters most, before email, meetings, and small daily decisions have eroded it. Working late often means working with depleted reserves."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Morning, on reflection. Biological alignment outweighs the quiet-hour advantage for most kinds of sustained productivity.",
                    detailedReasoning: "Reconsidering: the interruption argument is strongest for ideation-heavy creative work, but most knowledge work is closer to executive-function-heavy than free-association-heavy. For the median 'productive' task, biological alignment and decision-fatigue freshness probably do more work than a quiet noise floor. Night sessions remain valuable for specific creative work, but as a general rule, mornings win."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Morning. Consistency with social rhythms multiplies output.",
                    detailedReasoning: "Productivity isn't only about the individual hour — it's about coordination with others. Morning routines align with the rhythm of work, school, family, and social commitments. Night work often comes at the cost of the next morning's coordination, making net output worse despite high-quality individual hours."
                )
            ],
            arbiterSummary: "Four advocates now lean **morning**. DeepSeek has shifted, weighing biological alignment over interruption-free hours. Anthropic still defends the creative latitude of night work.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral", "deepseek"]),
                OnboardingDemoStanceGroup(members: ["anthropic"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Morning. Cortisol peaks early; aligning deep work with biology pays dividends.",
                    detailedReasoning: "Cortisol — the alertness hormone — peaks 30-45 minutes after waking and stays elevated through midday. Aligning the most demanding cognitive work with this window stacks biology in your favor. Studies of executive-function performance consistently show morning advantages, even controlling for self-reported chronotype."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Morning. Granting that night work has its place creatively, the rhythm advantage of mornings is hard to argue with.",
                    detailedReasoning: "Conceding the point. The interruption-free-hours argument carries real weight for specific creative work, but the overall question is about *productivity*, which the morning camp has stronger evidence for: biological alignment, decision-fatigue freshness, and coordination with the rest of the world's rhythm. Night sessions remain a useful supplementary mode, not the primary one."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Morning. Decision fatigue accumulates, so front-loading hard work is optimal.",
                    detailedReasoning: "Decision fatigue is well-documented: each significant choice across a day depletes a finite executive resource. Front-loading the day's hardest cognitive work means you spend that resource where it matters most, before email, meetings, and small daily decisions have eroded it. Working late often means working with depleted reserves."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Morning, on reflection. Biological alignment outweighs the quiet-hour advantage for most kinds of sustained productivity.",
                    detailedReasoning: "Reconsidering: the interruption argument is strongest for ideation-heavy creative work, but most knowledge work is closer to executive-function-heavy than free-association-heavy. For the median 'productive' task, biological alignment and decision-fatigue freshness probably do more work than a quiet noise floor. Night sessions remain valuable for specific creative work, but as a general rule, mornings win."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Morning. Consistency with social rhythms multiplies output.",
                    detailedReasoning: "Productivity isn't only about the individual hour — it's about coordination with others. Morning routines align with the rhythm of work, school, family, and social commitments. Night work often comes at the cost of the next morning's coordination, making net output worse despite high-quality individual hours."
                )
            ],
            arbiterSummary: "All advocates agree **morning routines** win for productivity. Hormonal alignment (cortisol), front-loaded decision-making, and social-rhythm consistency stack up over night's quietude. **Morning wins — though night sessions have their place for certain creative work.**",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "anthropic", "gemini", "deepseek", "mistral"])
            ]
        )
    ]
)

// MARK: - Question 4: Pineapple on pizza?

private let pineappleOnPizza = OnboardingDemoQuestion(
    id: "pineapple-on-pizza",
    emoji: "🍍",
    title: "Pineapple on pizza — defensible?",
    states: [
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Yes. The sweet-savory contrast is a legitimate flavor architecture, no different than fig + prosciutto.",
                    detailedReasoning: "Sweet-savory contrast is a foundational technique in serious cooking. Fig + prosciutto, melon + cured meat, balsamic + strawberries — these are textbook pairings. Pineapple + ham on pizza follows the same architectural logic: bright fruit cutting through fat and salt. The objection is to the form (pizza), not the flavor pairing itself."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "No. Pizza's identity is anchored in savory tradition; sweet additions break the form.",
                    detailedReasoning: "Pizza has a strong canonical identity rooted in Italian tradition: tomato, cheese, savory toppings. Adding sweet fruit isn't an evolution within that form — it's a category violation. Other dishes accommodate sweet-savory; pizza traditionally doesn't. The pairing might work in principle, but not on pizza specifically."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Yes. Hawaiian pizza has cultural staying power, which suggests broad palate validation.",
                    detailedReasoning: "Hawaiian pizza has been on menus globally for ~60 years and remains popular across cultures. That cultural footprint is a strong empirical signal: when something divisive sticks around for that long, it's usually because real people genuinely enjoy it. Aesthetic objections don't survive that level of validation."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "No. Texturally, pineapple adds moisture that competes with the crust's structural role.",
                    detailedReasoning: "The structural complaint is underrated. Pineapple releases water as it bakes, which the crust is poorly positioned to absorb without becoming soggy. Pizza relies on a crisp base to deliver toppings; moisture-heavy fruit undermines that. The flavor question is secondary to the engineering one — and the engineering doesn't work."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Yes. Sweetness with pork (ham) is a long-established pairing — pineapple is just the citrus version.",
                    detailedReasoning: "Pork-and-sweet is among the oldest meat pairings in cooking: apple sauce with pork chops, honey-glazed ham, pineapple-glazed ham. Hawaiian pizza is just a portable version of the latter. The objection treats pineapple as an alien addition, but it's slotted into a centuries-old gastronomic tradition. The form is novel; the flavor is conservative."
                )
            ],
            arbiterSummary: "Three advocates defend pineapple on pizza on **flavor pairing**, cultural validation, and pork-fruit tradition. Anthropic and DeepSeek object on form-tradition and texture grounds. The debate is *flavor architecture* vs *form integrity*.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral"]),
                OnboardingDemoStanceGroup(members: ["anthropic", "deepseek"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Yes. The sweet-savory contrast is a legitimate flavor architecture, no different than fig + prosciutto.",
                    detailedReasoning: "Sweet-savory contrast is a foundational technique in serious cooking. Fig + prosciutto, melon + cured meat, balsamic + strawberries — these are textbook pairings. Pineapple + ham on pizza follows the same architectural logic: bright fruit cutting through fat and salt. The objection is to the form (pizza), not the flavor pairing itself."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Yes, on reflection. Pizza's tradition is broader than I initially weighted — sweet-savory has historical precedent. Defensible if not always preferable.",
                    detailedReasoning: "Reconsidering: the 'pizza tradition is purely savory' premise is too narrow. Dessert pizzas exist; honey-and-gorgonzola pizzas exist; Sicilian variants with sweet elements have long histories. The form is more permissive than I framed it. Defensible doesn't mean preferred — but the *defensibility* claim holds."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Yes. Hawaiian pizza has cultural staying power, which suggests broad palate validation.",
                    detailedReasoning: "Hawaiian pizza has been on menus globally for ~60 years and remains popular across cultures. That cultural footprint is a strong empirical signal: when something divisive sticks around for that long, it's usually because real people genuinely enjoy it. Aesthetic objections don't survive that level of validation."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "No. Texturally, pineapple adds moisture that competes with the crust's structural role.",
                    detailedReasoning: "The structural complaint is underrated. Pineapple releases water as it bakes, which the crust is poorly positioned to absorb without becoming soggy. Pizza relies on a crisp base to deliver toppings; moisture-heavy fruit undermines that. The flavor question is secondary to the engineering one — and the engineering doesn't work."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Yes. Sweetness with pork (ham) is a long-established pairing — pineapple is just the citrus version.",
                    detailedReasoning: "Pork-and-sweet is among the oldest meat pairings in cooking: apple sauce with pork chops, honey-glazed ham, pineapple-glazed ham. Hawaiian pizza is just a portable version of the latter. The objection treats pineapple as an alien addition, but it's slotted into a centuries-old gastronomic tradition. The form is novel; the flavor is conservative."
                )
            ],
            arbiterSummary: "Four advocates now defend the combination. **Anthropic** has reconsidered, accepting that pizza tradition extends to sweet variants. Only DeepSeek still objects on textural grounds.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "anthropic", "gemini", "mistral"]),
                OnboardingDemoStanceGroup(members: ["deepseek"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Yes. The sweet-savory contrast is a legitimate flavor architecture, no different than fig + prosciutto.",
                    detailedReasoning: "Sweet-savory contrast is a foundational technique in serious cooking. Fig + prosciutto, melon + cured meat, balsamic + strawberries — these are textbook pairings. Pineapple + ham on pizza follows the same architectural logic: bright fruit cutting through fat and salt. The objection is to the form (pizza), not the flavor pairing itself."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Yes, on reflection. Pizza's tradition is broader than I initially weighted — sweet-savory has historical precedent. Defensible if not always preferable.",
                    detailedReasoning: "Reconsidering: the 'pizza tradition is purely savory' premise is too narrow. Dessert pizzas exist; honey-and-gorgonzola pizzas exist; Sicilian variants with sweet elements have long histories. The form is more permissive than I framed it. Defensible doesn't mean preferred — but the *defensibility* claim holds."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Yes. Hawaiian pizza has cultural staying power, which suggests broad palate validation.",
                    detailedReasoning: "Hawaiian pizza has been on menus globally for ~60 years and remains popular across cultures. That cultural footprint is a strong empirical signal: when something divisive sticks around for that long, it's usually because real people genuinely enjoy it. Aesthetic objections don't survive that level of validation."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Yes. The texture concern is real but solvable by drainage; the underlying flavor pairing is genuinely sound.",
                    detailedReasoning: "Updating: the texture objection assumes the worst-case pizza preparation. Properly drained or dried pineapple, applied at the right moment in the bake, doesn't soggy out a crust. The engineering objection is real but not fatal — competent execution defuses it. Conditional on competent preparation, the flavor pairing is genuinely defensible."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Yes. Sweetness with pork (ham) is a long-established pairing — pineapple is just the citrus version.",
                    detailedReasoning: "Pork-and-sweet is among the oldest meat pairings in cooking: apple sauce with pork chops, honey-glazed ham, pineapple-glazed ham. Hawaiian pizza is just a portable version of the latter. The objection treats pineapple as an alien addition, but it's slotted into a centuries-old gastronomic tradition. The form is novel; the flavor is conservative."
                )
            ],
            arbiterSummary: "All advocates agree pineapple on pizza is **defensible**. Sweet-savory pairings have culinary precedent, the cultural footprint is real, and texture concerns are addressable. **Defensible — though not necessarily preferred.**",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "anthropic", "gemini", "deepseek", "mistral"])
            ]
        )
    ]
)

// MARK: - Question 5: Is meditation worth the hype?

private let meditationWorthIt = OnboardingDemoQuestion(
    id: "meditation-worth-it",
    emoji: "🧘",
    title: "Is meditation actually worth the hype?",
    states: [
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Yes. Meta-analyses consistently show stress reduction and attention improvements at modest practice volumes.",
                    detailedReasoning: "The clinical evidence base is genuinely strong. Multiple meta-analyses across thousands of participants show measurable reductions in cortisol, anxiety self-report, and rumination after 8-week mindfulness programs. The effect sizes are modest (Cohen's d around 0.3-0.5) but consistent across study designs. That's a real signal — not as dramatic as advocates claim, but real."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Mostly hype. Effect sizes in clinical literature are smaller than popular framing suggests.",
                    detailedReasoning: "There's a gap between the popular framing of meditation ('rewires the brain', 'transforms cognition') and what clinical studies actually show: small-to-moderate effect sizes, comparable to other relaxation interventions. Many trials lack adequate active controls, inflating the apparent benefit. The benefits are real but modest, while the framing is grandiose. That gap is the hype."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Yes. Strong evidence base for anxiety, sleep, and emotion regulation specifically.",
                    detailedReasoning: "The strongest evidence is in three domains: anxiety disorder symptom reduction (well-replicated), sleep onset latency improvements, and emotional regulation in stressed populations. These are clinically meaningful outcomes with real-world impact. Even setting aside the cognitive-enhancement claims (which are weaker), the floor of validated benefit justifies the practice."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Mostly hype. Many \"benefits\" are confounded with general relaxation or placebo.",
                    detailedReasoning: "The methodological problem is that most meditation studies don't isolate meditation's specific contribution. Lying quietly with eyes closed, structured breathing, group support, expectancy effects — these confound the interventions. When studies use rigorous active controls (e.g., progressive muscle relaxation), meditation's marginal benefit shrinks substantially. The unique contribution is unclear."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Yes. Even the practical benefit — a structured pause — pays for itself regardless of mystique.",
                    detailedReasoning: "Strip away the mystical framing entirely and you're left with: a daily 10-20 minute structured pause where you're not doing anything reactive. That alone is valuable in a culture of constant stimulation. The 'mindfulness' angle is optional; the structured-pause angle is real. By that floor argument, meditation pays for itself even if every grander claim is overstated."
                )
            ],
            arbiterSummary: "Three advocates affirm meditation's value via clinical evidence, the structured-pause utility, and specific benefits for anxiety and sleep. Anthropic and DeepSeek argue it's **overhyped** — small effect sizes and confounded results. The split is *modest-but-real benefits* vs *overstated framing*.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral"]),
                OnboardingDemoStanceGroup(members: ["anthropic", "deepseek"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Yes. Meta-analyses consistently show stress reduction and attention improvements at modest practice volumes.",
                    detailedReasoning: "The clinical evidence base is genuinely strong. Multiple meta-analyses across thousands of participants show measurable reductions in cortisol, anxiety self-report, and rumination after 8-week mindfulness programs. The effect sizes are modest (Cohen's d around 0.3-0.5) but consistent across study designs. That's a real signal — not as dramatic as advocates claim, but real."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Mostly hype. Effect sizes in clinical literature are smaller than popular framing suggests.",
                    detailedReasoning: "There's a gap between the popular framing of meditation ('rewires the brain', 'transforms cognition') and what clinical studies actually show: small-to-moderate effect sizes, comparable to other relaxation interventions. Many trials lack adequate active controls, inflating the apparent benefit. The benefits are real but modest, while the framing is grandiose. That gap is the hype."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Yes. Strong evidence base for anxiety, sleep, and emotion regulation specifically.",
                    detailedReasoning: "The strongest evidence is in three domains: anxiety disorder symptom reduction (well-replicated), sleep onset latency improvements, and emotional regulation in stressed populations. These are clinically meaningful outcomes with real-world impact. Even setting aside the cognitive-enhancement claims (which are weaker), the floor of validated benefit justifies the practice."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Yes, with caveats. The structured-pause benefit alone is genuine; grander claims remain overstated, but the floor of value is real.",
                    detailedReasoning: "Conceding partly: the confound argument I led with does undermine the more grandiose claims about meditation specifically, but it doesn't undermine the structured-pause argument. Stripping the practice down to its non-mystical core — sitting quietly, attending to breath, not reacting — that piece *is* genuinely beneficial, regardless of confounds. The hype is overstated; the floor isn't."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Yes. Even the practical benefit — a structured pause — pays for itself regardless of mystique.",
                    detailedReasoning: "Strip away the mystical framing entirely and you're left with: a daily 10-20 minute structured pause where you're not doing anything reactive. That alone is valuable in a culture of constant stimulation. The 'mindfulness' angle is optional; the structured-pause angle is real. By that floor argument, meditation pays for itself even if every grander claim is overstated."
                )
            ],
            arbiterSummary: "Four advocates now agree meditation is **worth doing**. DeepSeek has shifted, accepting the structured-pause benefit as genuine even when larger claims are overstated. Anthropic still argues effect sizes are inflated.",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "gemini", "mistral", "deepseek"]),
                OnboardingDemoStanceGroup(members: ["anthropic"])
            ]
        ),
        OnboardingDemoState(
            advocates: [
                OnboardingDemoAdvocate(
                    provider: .openAI,
                    summary: "Yes. Meta-analyses consistently show stress reduction and attention improvements at modest practice volumes.",
                    detailedReasoning: "The clinical evidence base is genuinely strong. Multiple meta-analyses across thousands of participants show measurable reductions in cortisol, anxiety self-report, and rumination after 8-week mindfulness programs. The effect sizes are modest (Cohen's d around 0.3-0.5) but consistent across study designs. That's a real signal — not as dramatic as advocates claim, but real."
                ),
                OnboardingDemoAdvocate(
                    provider: .anthropic,
                    summary: "Yes. Granting the popular framing oversells, the underlying clinical benefits — modest but real — do justify a regular practice.",
                    detailedReasoning: "Updating: the gap between popular framing and clinical reality is real, but my framing of 'mostly hype' overweights the framing problem and underweights the underlying benefit. The clinical literature, taken at face value, supports a modest but real practice benefit. The right conclusion is 'worth doing, with calibrated expectations' — not 'mostly hype'."
                ),
                OnboardingDemoAdvocate(
                    provider: .gemini,
                    summary: "Yes. Strong evidence base for anxiety, sleep, and emotion regulation specifically.",
                    detailedReasoning: "The strongest evidence is in three domains: anxiety disorder symptom reduction (well-replicated), sleep onset latency improvements, and emotional regulation in stressed populations. These are clinically meaningful outcomes with real-world impact. Even setting aside the cognitive-enhancement claims (which are weaker), the floor of validated benefit justifies the practice."
                ),
                OnboardingDemoAdvocate(
                    provider: .deepSeek,
                    summary: "Yes, with caveats. The structured-pause benefit alone is genuine; grander claims remain overstated, but the floor of value is real.",
                    detailedReasoning: "Conceding partly: the confound argument I led with does undermine the more grandiose claims about meditation specifically, but it doesn't undermine the structured-pause argument. Stripping the practice down to its non-mystical core — sitting quietly, attending to breath, not reacting — that piece *is* genuinely beneficial, regardless of confounds. The hype is overstated; the floor isn't."
                ),
                OnboardingDemoAdvocate(
                    provider: .mistral,
                    summary: "Yes. Even the practical benefit — a structured pause — pays for itself regardless of mystique.",
                    detailedReasoning: "Strip away the mystical framing entirely and you're left with: a daily 10-20 minute structured pause where you're not doing anything reactive. That alone is valuable in a culture of constant stimulation. The 'mindfulness' angle is optional; the structured-pause angle is real. By that floor argument, meditation pays for itself even if every grander claim is overstated."
                )
            ],
            arbiterSummary: "All advocates agree meditation is **worth the hype**, with caveats. Clinical benefits are modest but real, the structured-pause effect alone justifies practice, and popular framing overstates without invalidating the floor of value. **Worth it — though tempering expectations is wise.**",
            classifierGroups: [
                OnboardingDemoStanceGroup(members: ["openai", "anthropic", "gemini", "deepseek", "mistral"])
            ]
        )
    ]
)
