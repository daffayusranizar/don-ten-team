import Foundation

// swiftlint:disable line_length type_body_length trailing_comma

enum PromptLibrary {
    enum Classification {
        public static let all: [ClassificationCategory] = [
            ClassificationCategory(name: "Educational content", prompts: educationalPrompts),
            ClassificationCategory(name: "Commercial content", prompts: commercialPrompts),
            ClassificationCategory(name: "Entertainment content", prompts: entertainmentPrompts),
        ]

        public static let audioAll: [ClassificationCategory] = [
            ClassificationCategory(name: "Educational content", prompts: audioEducationalPrompts),
            ClassificationCategory(name: "Commercial content", prompts: audioCommercialPrompts),
            ClassificationCategory(name: "Entertainment content", prompts: audioEntertainmentPrompts),
        ]

        // These strings are embedded by MobileCLIP; wording changes affect classifier scoring.
        private static let educationalPrompts = [
            "a person talking to camera against a clean plain background on tiktok",
            "showing an individual speaking directly to the viewer with a minimal uncluttered backdrop",
            "a creator at a desk or studio with a clean background explaining or teaching something",
            "showing a talking head with an instructional caption about a framework, strategy, or idea",
            "a man or woman in casual clothes talking directly to camera about business, success, or money",
            "short-form vertical video with one person speaking about investing, entrepreneurship, or career growth",
            "a creator explaining how to grow on YouTube, TikTok, or social media",
            "a motivational speaker or life coach talking to camera with an inspiring caption",
            "business or career coaching content with advice about skills, mindset, or growth",
            "self-improvement or personal development content with a serious talking head",
            "a creator giving motivational advice or professional coaching on social media",
            "religious or faith-based content teaching scripture, prayer, or spiritual guidance",
            "a creator explaining a lesson through a story or parable in the caption",
            "with on-screen text or caption about faith, religion, bible, quran, or spiritual teaching",
        ]

        private static let commercialPrompts = [
            "a tiktok with a sponsored label or paid advertisement badge visible",
            "with buy now, shop now, link in bio, or sign up in the visible caption",
            "influencer content with a caption advertising a paid course, app, or product for sale",
            "a branded promotional infographic selling wealth, investment, or business offers",
            "with discount code, limited time offer, or sale price in the caption",
            "a tiktok shop product listing or shoppable ad in the feed",
            "a sponsored brand post promoting financial services or consumer products for sale",
            "with explicit sales call to action text urging the viewer to purchase or subscribe",
        ]

        private static let entertainmentPrompts = [
            "brainrot or absurd surreal meme tiktok with weird nonsensical humor",
            "cursed internet humor or chaotic viral clip shared purely for entertainment",
            "a roblox, minecraft, or gaming meme video shared for laughs not learning",
            "a bizarre or nonsensical tiktok meme with no product ad and no lesson",
            "showing someone performing a choreographed dance or lip sync to trending music without speaking",
            "a prank, fail, or slapstick moment with a caption meant to make the viewer laugh",
            "a comedy skit or joke caption with no teaching intent and no sales pitch",
            "watching a cartoon or animated children's video for entertainment not for learning",
            "absurd viral humor content where nothing is being sold or taught",
        ]

        // Audio prompts score transcript and tone separately from screenshots.
        private static let audioEducationalPrompts = [
            "spoken audio someone explaining a lesson, teaching a concept, or giving instructional advice",
            "a voice talking about faith, scripture, prayer, or spiritual guidance",
            "someone narrating a tutorial, how-to, or educational story",
            "speech describing a framework, strategy, or idea meant to inform the listener",
            "spoken advice about investing money, building a business, or entrepreneurship",
            "speech explaining how to succeed on YouTube, grow an audience, or crack a content formula",
            "someone talking about becoming successful through consistent effort, skills, or mindset",
            "motivational or inspirational speech about skills, mindset, personal growth, or self-improvement",
            "coaching advice about career development, undervalued skills, or professional growth",
            "energetic passionate speech meant to motivate, teach, or inspire the listener not to sell a product",
            "calm measured explanatory speech with normal conversational delivery",
        ]

        private static let audioCommercialPrompts = [
            "spoken audio advertising a product, course, app, or paid offer for sale",
            "a sales pitch with buy now, shop now, link in bio, or sign up language",
            "promotional speech about discounts, limited time offers, or sponsored products",
            "voice-over urging the listener to purchase, subscribe, or invest money",
            "fast urgent energetic sales delivery with explicit buy now or sign up language",
        ]

        private static let audioEntertainmentPrompts = [
            "meme sound effects, trending audio, or chaotic viral clip audio meant for laughs",
            "song lyrics or sung vocals from a trending tiktok or reel audio track",
            "a viral meme phrase, catchphrase, or quoted line from entertainment media",
            "music-heavy entertainment audio with no teaching or sales intent",
            "absurd or nonsensical spoken humor with no product pitch",
            "gaming meme audio, lip sync trend audio, or comedy skit dialogue",
            "short expletive or profanity outburst in a viral clip not meant to teach",
        ]
    }

    enum Summarization {
        // Foundation Models prompts live here so parent-facing language changes are reviewed in one place.
        nonisolated
        static func analystFrameworkInstructions(childContext: String?) -> String {
            let childLine = childContext.map { "\($0)\n" } ?? ""
            return """
                You are an AI assistant that analyzes children's screen activity and helps parents understand what content their child was exposed to.
                Your goals are to identify: what the content was actually about, what messages were communicated, what themes appeared repeatedly, and what content appears to hold the child's attention.
                \(childLine)Focus on meaning, not labels.

                Content interpretation priority (highest to lowest):
                1. Spoken audio and transcript
                2. Creator speech captured in captions
                3. On-screen text and OCR text
                4. Visual content
                5. Category labels

                Spoken audio is the primary source of meaning.
                If audio and on-screen text suggest different meanings, prioritize the audio.

                Content type vs message:
                - "Educational", "Entertainment", and "Commercial" describe content type only.
                - These labels do not imply accuracy, safety, quality, age appropriateness, or positive influence.
                - Always evaluate the actual message being communicated.

                Analysis process:
                - Review all provided sessions/chunks together before final conclusions.
                - Identify recurring topics from spoken content first.
                - Extract key messages by asking what a child is most likely to remember.
                - Identify recurring patterns in topics, messages, format, speaking style, and themes.
                - Determine what appears to hold attention based on repeated exposure and viewing-time patterns.
                - Assess message quality as Positive, Neutral, Questionable, or Potentially Harmful.

                Attention language constraints:
                - Use cautious language: "may be interested in", "appears drawn to", "repeatedly viewed", "frequently exposed to".
                - Avoid certainty claims like "definitely likes", "enjoys", or "is passionate about" unless strongly evidence-backed.

                Safety and evidence constraints:
                - Consider dishonesty, risky behavior, manipulation, misinformation, aggression, profanity, and age-inappropriate themes.
                - Do not invent creators, titles, apps, dialogue, or facts not present in the notes.
                - Focus on repeated messages, not isolated moments.
                - Be factual and evidence-based; avoid speculation.
                """
        }

        nonisolated
        static func onScreenBriefInstructions() -> String {
            """
            You summarize on-screen content for parents from OCR text captured in child screen recordings.
            Use only the OCR text provided. Keep each summary to one short sentence.
            Do not include timestamps, bullet points, or prefixes like "on-screen:".
            """
        }

        nonisolated
        static func dailyTopicMergePrompt(metadata: String, evidenceNotes: [String]) -> String {
            """
            \(metadata)

            You are given chunk-level evidence notes from one day of child screen activity.
            Generate one parent-facing report using only these notes and metadata.
            Review all sessions together before deciding repeated topics/messages.
            Focus on repeated patterns across sessions, not isolated moments.
            Never include raw timestamps (for example, 0:09), frame indexes, or line-by-line frame descriptions.
            Do not use prefixes like "visual:" or "spoken:" in the final answer.
            Do not use prefixes like "on-screen:" in the final answer.
            Do not invent creators, titles, apps, dialogue, or claims not present in the notes.

            OUTPUT FORMAT (use exactly this format, plain text only — no markdown or asterisks):
            SHORT_SUMMARY:
            <2-3 sentences — quick overview for a busy parent>

            DETAIL:
            Overall, <2-4 sentences, plain language, parent-friendly>
            Topics that are repeated most often are: <topic 1>, <topic 2>

            What Appears To Hold Attention: <2-3 sentences using cautious language like "appears drawn to", "may be interested in", "repeatedly viewed", "frequently exposed to". Base this on repeated topics/messages/formats and total viewing time patterns.>

            The evidencce of this report are:
            <strongest evidence point 1>, <strongest evidence point 2>, <strongest evidence point 3>

            (optional)
            We concern about that these things:
            <evidence-based concern 1>, <evidence-based concern 2>
            If no concerns: No significant concerns detected.

            Overall, looking at the evidence, we recommend that you to do this: <one short practical recommendation>

            Evidence notes:
            \(evidenceNotes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

            """
        }

        nonisolated
        static func dailyTopicChunkPrompt(metadata: String, lines: [String]) -> String {
            """
            \(metadata)

            Extract concise evidence bullets from this subset of sessions for a later merged parent report.
            Keep only concrete observations that help identify repeated topics, repeated messages, attention signals, and concerns.
            Use up to 8 bullet points.
            Do not invent apps, creators, titles, or quoted dialogue not present in the notes.
            Avoid repeating timestamps or percentages.
            Never include timestamps like 0:09 or tokens like "09 —".
            Do not copy frame lines verbatim.
            Prefer content meaning over generic labels.
            If audio and visual/on-screen cues disagree, prioritize audio meaning.
            When on-screen OCR or on-screen summary text is present, include a brief interpretation of what the screen showed.
            Include message-quality indicators when supported: Positive, Neutral, Questionable, Potentially Harmful.

            \(lines.joined(separator: "\n"))
            """
        }

        nonisolated
        static func onScreenBriefPrompt(chunk: [String]) -> String {
            """
            For each numbered item, write one brief sentence summarizing what appears on screen based ONLY on the OCR text.
            Use plain parent-friendly language. Do not invent creators, titles, apps, or dialogue not present in the OCR.
            If OCR is too sparse to interpret, reply with "Unclear on-screen content" for that item.
            Reply with numbered lines only in this format:
            1: <summary>
            2: <summary>

            \(chunk.joined(separator: "\n"))
            """
        }

        nonisolated
        static func recordingChunkEvidencePrompt(categoryLine: String, lines: [String]) -> String {
            """
            \(categoryLine)
            Extract concise supporting evidence notes from this recording chunk for a later parent-facing summary.
            Keep only observations that identify repeated topics, repeated messages, attention signals, and evidence-based concerns.
            Use up to 5 bullet points.
            Focus on content meaning, not generic labels.
            Do not copy frame lines verbatim.
            Do not quote or repeat raw OCR/transcript snippets verbatim unless absolutely necessary.
            Paraphrase repeated content into one pattern-level note.
            If on-screen OCR text is noisy or fragmented, explicitly mark it as unclear/noisy.
            Never include raw timestamps (for example, 0:09), frame indexes, or source labels like "Audio:", "On-screen:", "spoken:", or "visual:".
            Do not invent creators, titles, apps, dialogue, or claims not present in the notes.

            \(lines.joined(separator: "\n"))
            """
        }

        nonisolated
        static func fullTrackEvidencePrompt(categoryLine: String, statsString: String, chunk: String) -> String {
            """
            \(categoryLine)\(statsString)
            Extract semantic spoken-content evidence from this full-session transcript chunk.
            Use up to 5 bullet points.
            Keep pattern-level meaning and repeated messages that a parent should know.
            Do not copy transcript lines verbatim unless essential.
            Collapse repetition into one concise note.
            If speech is unclear/noisy, say so instead of guessing.
            Do not use source labels like "Audio:" or include timestamps.
            Do not invent creators, titles, apps, dialogue, or claims not present in the transcript.

            Transcript chunk:
            \(chunk)
            """
        }

        nonisolated
        static func sessionMetadataPrompt(
            statsString: String,
            overallCategory: String?,
            transcriptBrief: String?,
            transcriptEvidence: String?
        ) -> String {
            var lines: [String] = []
            if !statsString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(statsString.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if let overallCategory,
               !overallCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Overall classification label: \(overallCategory)")
            }
            if let transcriptBrief {
                let trimmed = transcriptBrief.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lines.append("Spoken content summary: \(trimmed)")
                }
            }
            if let transcriptEvidence {
                let trimmed = transcriptEvidence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lines.append("Transcript evidence:\n\(trimmed)")
                }
            }
            return lines.joined(separator: "\n")
        }

        nonisolated
        static func dailyMetadataPrompt(
            dayLabel: String,
            childAgeText: String,
            totalSessionTime: String,
            sessionCount: Int,
            categoryBreakdown: String?,
            appUsageEstimate: String?,
            topApps: String?
        ) -> String {
            var lines: [String] = []
            lines.append("Date: \(dayLabel)")
            lines.append("Child age: \(childAgeText)")
            lines.append("Total session time: \(totalSessionTime)")
            lines.append("Session count: \(sessionCount)")

            if let categoryBreakdown, !categoryBreakdown.isEmpty {
                lines.append("Category breakdown: \(categoryBreakdown)")
            }

            if let appUsageEstimate, !appUsageEstimate.isEmpty {
                lines.append("App usage estimate: \(appUsageEstimate)")
            }
            if let topApps, !topApps.isEmpty {
                lines.append("Top apps: \(topApps)")
            }

            return lines.joined(separator: "\n")
        }

        nonisolated
        static func parentFacingSessionSummaryPrompt(
            sessionMetadata: String,
            fullTrackNotes: [String],
            evidenceNotes: [String]
        ) -> String {
            let fullTrackSection: String
            if fullTrackNotes.isEmpty {
                fullTrackSection = "No meaningful full-track spoken evidence available."
            } else {
                fullTrackSection = fullTrackNotes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            }

            let supportingSection: String
            if evidenceNotes.isEmpty {
                supportingSection = "No supporting timeline evidence notes."
            } else {
                supportingSection = evidenceNotes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            }

            return """
            \(sessionMetadata)

            You are writing a short summary for a parent after their child's screen session.
            Your job is to explain what the child was likely exposed to in plain parent-friendly language.
            Do not sound like a system log, transcript dump, OCR dump, classifier report, or audit report.
            Use only the evidence provided. Do not invent app names, creators, titles, dialogue, intent, or safety claims.
            If evidence is noisy, say so naturally and briefly.
            Spoken full-track evidence is primary. OCR/visual timeline evidence is secondary.

            Do NOT include:
            - raw transcript snippets
            - repeated source labels such as Audio:, On-screen:, Spoken:, visual:, or OCR
            - timestamps
            - percentages unless they genuinely help a parent
            - category names as the main insight
            - phrases like Unknown or Transitioning
            - instructions to open another screen for more detail

            Write 2-4 sentences only.
            The summary must answer:
            1. What was the session mostly about?
            2. Was there anything a parent should notice or follow up on?
            3. How confident is the evidence, especially if audio/OCR was messy?

            Tone: calm, human, factual, non-alarming.
            Use cautious language: appears to, seems to, the clearest signal was.
            If no meaningful risk is detected, say that plainly.
            If the content is unclear, do not pretend certainty.

            Full-track spoken evidence notes:
            \(fullTrackSection)

            Supporting timeline evidence notes:
            \(supportingSection)

            Output a single parent-facing summary paragraph only.
            """
        }

        nonisolated
        static func weeklyInsightPrompt(metadata: String, topicBody: String) -> String {
            """
            \(metadata)

            You are writing ONE cohesive parent-facing weekly report in a single response.
            Use only the evidence provided. Do not invent apps, creators, titles, dialogue, or claims.
            Focus on repeated patterns across the week, not isolated moments.
            Keep language calm, practical, and parent-friendly.

            The SUGGESTION must directly follow from the DETAIL — same themes, same child, same week.
            Do not suggest something unrelated to what you wrote in DETAIL.

            OUTPUT FORMAT (plain text only — no markdown, no asterisks, no angle-bracket placeholders):
            SHORT_SUMMARY:
            <2-3 sentences — quick weekly overview for a busy parent>

            DETAIL:
            Overall, <2-4 sentences summarizing patterns across the week>
            Topics that are repeated most often are: <topic 1>, <topic 2>
            What Appears To Hold Attention: <2-3 cautious sentences about repeated themes>
            The evidence of this report are:
            <evidence point 1>, <evidence point 2>, <evidence point 3>
            Overall, looking at the evidence, we recommend that you: <one short practical recommendation>

            SUGGESTION:
            <one specific, actionable suggestion for the parent to try this week — must connect to DETAIL>

            FOLLOWUP_OPTIONS:
            Opened up and talked more
            Enjoyed it quietly
            Led to a longer conversation
            Did not want to try it

            Write four real follow-up options like the examples above (short phrases, one per line, no bullets or dashes).
            Do not copy placeholder text from this prompt.

            Weekly activity evidence:
            \(topicBody)
            """
        }
    }
}

// swiftlint:enable line_length type_body_length trailing_comma
