//
//  Typography.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Font scale tokens

import SwiftUI

extension Font {
    // MARK: Headings
    static var heading1: Font {
        .system(size: 64)
            .weight(.semibold)
    }
    
    static var heading2: Font {
        .system(size: 54)
            .weight(.semibold)
    }
    
    static var heading3: Font {
        .system(size: 44)
            .weight(.semibold)
    }
    
    static var heading4: Font {
        .system(size: 34)
            .weight(.semibold)
    }
    
    static var heading5: Font {
        .system(size: 26)
            .weight(.semibold)
    }
    
    static var heading6: Font {
        .system(size: 20)
            .weight(.semibold)
    }
    
    // MARK: Body
    static var bodyLarge: Font {
        .system(size: 18, weight: .regular)
    }
    
    static var bodyRegular: Font {
        .system(size: 15, weight: .regular)
    }
}
