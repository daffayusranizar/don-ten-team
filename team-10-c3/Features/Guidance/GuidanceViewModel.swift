//
//  GuidanceViewModel.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P2]

import Foundation

struct ActivityItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let imageName: String

    // List content
    let shortDescription: String
    let subtitle: String?

    // Detail content
    let detailDescription: String
    let howToTitle: String
    let howTo: [String]
    let tipsTitle: String
    let tips: [String]
}

struct ActivitySection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let activities: [ActivityItem]
}

enum ActivityLibrary {
    static let outdoor: ActivitySection = .init(
        id: "outdoor",
        title: "Outdoor Activity",
        activities: [
            .init(
                id: "football",
                title: "2 Person Football Game",
                imageName: "football-img",
                shortDescription: "Play short football passing challenges together to build teamwork, focus, and connection.",
                subtitle: nil,
                detailDescription: "Grab a ball and stand a few steps apart with your child. Take turns passing, controlling, and kicking the ball back while counting your successful passes together. Keep the game light, fun, and encouraging to build teamwork, confidence, and quality bonding time.",
                howToTitle: "How to do it",
                howTo: [
                    "Stand 3–5 meters apart facing each other.",
                    "Use a soft football suitable for children.",
                    "Parent passes the ball gently to the child.",
                    "Child controls the ball, then passes it back.",
                    "Count successful passes together without dropping the ball.",
                    "After every 5 passes, take one step farther apart.",
                    "Add fun challenges like one-touch passes or weaker-foot kicks.",
                    "Encourage and celebrate every successful teamwork moment together."
                ],
                tipsTitle: "Tips for playing with kids",
                tips: [
                    "Use a soft foam ball or a half-inflated ball for ages 5–6. It is easier to control, less intimidating, and safer in a small space.",
                    "While playing, ask light questions like who they would play football with or what position they would choose.",
                    "If your child plays football at school or watches it regularly, ask them to teach you something they know."
                ]
            ),
            .init(
                id: "weekend-walk",
                title: "Weekend Walk Together",
                imageName: "walk-img",
                shortDescription: "Have a meaningful walk while asking your kids about how their day went.",
                subtitle: nil,
                detailDescription: "Walking side by side is one of the easiest ways to get a child to open up. When there is no eye contact pressure, no sitting across a table, and no sense of being questioned, children talk more freely. A walk removes all of that. There is no agenda, no screen competing for attention, and no time limit beyond when you turn back home.",
                howToTitle: "How to do it",
                howTo: [
                    "Pick a time when neither of you is hungry, tired, or rushing. After breakfast on a weekend morning works well.",
                    "Let your child choose the direction when you step outside. Giving them that small control sets a relaxed tone from the start.",
                    "Leave your phone in your pocket. If you need it for safety, keep it face down and notifications silent.",
                    "Walk at your child's pace. If they stop to look at something, stop with them. Curiosity is the point.",
                    "Start with an easy opener like “so what do you want to do this weekend?” before moving into deeper questions."
                ],
                tipsTitle: "Things to talk about on your walk",
                tips: [
                    "“What was the best part of your week at school?” Open enough that any answer works, but more specific than just asking how school was.",
                    "“If you could change one thing about your class, what would it be?” This gives your child permission to share frustrations without it feeling like a complaint.",
                    "“What is something you learned this week that surprised you?” A simple question that often leads to a longer conversation than you expect."
                ]
            )
        ]
    )

    static let boardGames: ActivitySection = .init(
        id: "board-games",
        title: "Board Games",
        activities: [
            .init(
                id: "scrabble",
                title: "Scrabble",
                imageName: "scrabble-img",
                shortDescription: "Take turns building words on the board and score points for every letter. Trains vocabulary, spelling, and recall in a way that feels like competition, not studying.",
                subtitle: "A word game for 2–4 players | Best for ages 7 and up",
                detailDescription: "Scrabble puts parent and child on an equal intellectual footing, a child who knows an unusual short word can genuinely outscore an adult. For ages 7–10, it builds spelling and vocabulary naturally without feeling like homework. The physical tiles, the board, and the score tracking keep hands busy and screens forgotten.",
                howToTitle: "How to play",
                howTo: [
                    "Each player draws 7 letter tiles from the bag and keeps them on their rack, hidden from other players.",
                    "The first player places a word on the board crossing the centre star. Score the points shown on each tile.",
                    "Players take turns adding words that connect to existing letters on the board, like a crossword.",
                    "After each turn, draw new tiles from the bag to refill your rack back to 7.",
                    "The game ends when all tiles are used or no more words can be played. Highest score wins."
                ],
                tipsTitle: "Tips for playing with kids",
                tips: [
                    "For ages 7–8, allow a dictionary or phone dictionary so they can look up words freely, the goal is vocabulary, not memorisation.",
                    "Play with open racks for the first few games, let your child see your tiles and ask “which word would you play?” to teach strategy.",
                    "Short words score too, celebrate when your child plays “ZAP” or “JOY” on a triple letter score."
                ]
            ),
            .init(
                id: "congklak",
                title: "Congklak",
                imageName: "congklak-img",
                shortDescription: "No tools no problem, all you need is a circle and small rocks.",
                subtitle: "A traditional game for 2 players | Best for ages 4 and up",
                detailDescription: "Congklak is one of the oldest traditional games in Indonesia. Chances are your parents or grandparents played it too. Introducing it to your child is not just a game, it is passing down a piece of your own family history.",
                howToTitle: "How to do it",
                howTo: [
                    "Place 7 seeds in each of the 14 small holes. Leave the two large end holes (rumah) empty, this is where you collect your seeds.",
                    "The first player picks up all seeds from any hole on their side and drops them one by one anti-clockwise into each hole, including their own rumah, but not their opponent’s.",
                    "If the last seed lands in a hole that already has seeds, pick them all up and keep going.",
                    "If the last seed lands in your own rumah, you get another turn.",
                    "If the last seed lands in an empty hole on your side, take that seed plus all seeds in the hole directly opposite, add them to your rumah.",
                    "The game ends when one player’s side is empty. Count the seeds in each rumah, the most seeds wins."
                ],
                tipsTitle: "Tips for playing with kids",
                tips: [
                    "For ages 6–7, teach only the basic move first. Introduce the capturing rule once they are comfortable.",
                    "Let your child count seeds out loud as they distribute. Natural counting practice.",
                    "Ask while playing: “why did you choose that hole?” Gets them thinking strategically.",
                    "Play with grandparents if possible. Many already know the game and can teach it directly."
                ]
            )
        ]
    )

    static let allSections: [ActivitySection] = [
        outdoor,
        boardGames
    ]

    static let allActivities: [ActivityItem] = allSections.flatMap(\.activities)
}
