//
//  Y2KBackgroundPalette.swift
//  chocho
//

import SwiftUI

enum Y2KBackgroundPalette {
    struct Pair: Identifiable, Equatable {
        let id: Int
        let fill: Color
        let accent: Color
    }

    static let pairs: [Pair] = [
        Pair(id: 0, fill: Color(hex: "#FFE5F1"), accent: Color(hex: "#C7D2FF")), // bubblegum
        Pair(id: 1, fill: Color(hex: "#BEE7FF"), accent: Color(hex: "#CFFFF4")), // aqua candy
        Pair(id: 2, fill: Color(hex: "#D9CCFF"), accent: Color(hex: "#F8F6FF")), // digital lavender
        Pair(id: 3, fill: Color(hex: "#FFD9C2"), accent: Color(hex: "#FFF4E8")), // peach milk
        Pair(id: 4, fill: Color(hex: "#E6FFB8"), accent: Color(hex: "#CFFFF4")), // lime soda
        Pair(id: 5, fill: Color(hex: "#FFD6F7"), accent: Color(hex: "#FFEAF7")), // jelly pink
        Pair(id: 6, fill: Color(hex: "#E9F1FF"), accent: Color(hex: "#D6E4FF")), // y2k chrome candy
        Pair(id: 7, fill: Color(hex: "#C7D2FF"), accent: Color(hex: "#BEE7FF")), // soft cyber
        Pair(id: 8, fill: Color(hex: "#FFF0B8"), accent: Color(hex: "#FFD6F7")), // plastic toy
        Pair(id: 9, fill: Color(hex: "#CFFFF4"), accent: Color(hex: "#F4FFFD")), // dreamy mint
        Pair(id: 10, fill: Color(hex: "#FFD9C2"), accent: Color(hex: "#FFE5F1")), // japanese magazine
        Pair(id: 11, fill: Color(hex: "#DDF8FF"), accent: Color(hex: "#F4FEFF")), // translucent aqua
        Pair(id: 12, fill: Color(hex: "#D9CCFF"), accent: Color(hex: "#ECE6FF")), // glossy lavender
        Pair(id: 13, fill: Color(hex: "#BEE7FF"), accent: Color(hex: "#EAF7FF")), // sky plastic
        Pair(id: 14, fill: Color(hex: "#FFF6F9"), accent: Color(hex: "#FFD6F7")), // milk candy
        Pair(id: 15, fill: Color(hex: "#FFF0B8"), accent: Color(hex: "#C7D2FF")), // retro web
        Pair(id: 16, fill: Color(hex: "#D6FFF2"), accent: Color(hex: "#BEE7FF")), // cute tech
        Pair(id: 17, fill: Color(hex: "#FFD9C2"), accent: Color(hex: "#FFF0B8")), // soft fruit
        Pair(id: 18, fill: Color(hex: "#F8F6FF"), accent: Color(hex: "#BEE7FF")), // ccd glow
        Pair(id: 19, fill: Color(hex: "#FFCFEF"), accent: Color(hex: "#D9CCFF")), // pastel cyberpink
        Pair(id: 20, fill: Color(hex: "#F3F8FF"), accent: Color(hex: "#CFFFF4")), // transparent toy
        Pair(id: 21, fill: Color(hex: "#FFF0F6"), accent: Color(hex: "#FFF7CC")), // ice cream
        Pair(id: 22, fill: Color(hex: "#E6E0FF"), accent: Color(hex: "#DDF8FF")), // dreamy webcore
        Pair(id: 23, fill: Color(hex: "#F5E8FF"), accent: Color(hex: "#D6FFF2")), // soft holographic
        Pair(id: 24, fill: Color(hex: "#FFD9C2"), accent: Color(hex: "#FFEFD9")), // peach soda
        Pair(id: 25, fill: Color(hex: "#FFD6F7"), accent: Color(hex: "#BEE7FF")), // pixel girl
        Pair(id: 26, fill: Color(hex: "#E5D9FF"), accent: Color(hex: "#F8F6FF")), // transparent purple toy
        Pair(id: 27, fill: Color(hex: "#CFFFF4"), accent: Color(hex: "#E9FFE2")), // fresh mint gum
        Pair(id: 28, fill: Color(hex: "#FFF0B8"), accent: Color(hex: "#FFE5D6")), // warm plastic
        Pair(id: 29, fill: Color(hex: "#CFE8FF"), accent: Color(hex: "#F7FBFF")), // ccd sky
    ]

    static func shuffledIndices() -> [Int] {
        Array(pairs.indices).shuffled()
    }

    /// Nine preset swatches plus one refresh control per row.
    static let colorBallCountPerRow = 9
    static let slotCountPerRow = colorBallCountPerRow + 1

    static func ballSize(availableWidth: CGFloat, spacing: CGFloat = 6) -> CGFloat {
        let width = max(availableWidth, 1)
        let gaps = spacing * CGFloat(slotCountPerRow - 1)
        return (width - gaps) / CGFloat(slotCountPerRow)
    }

    static func apply(
        _ pair: Pair,
        to colors: inout PuzzleBackgroundColors,
        style: PuzzleBackgroundStyle
    ) {
        switch style {
        case .grid, .polkaDots, .halftone:
            colors.fillColor = pair.fill
            colors.lineColor = pair.accent
        case .stripes:
            colors.fillColor = pair.fill
            colors.alternateColor = pair.accent
        }
    }
}
