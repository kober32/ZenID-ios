//
//  BasicTableCellViewModel.swift
//  ZenIDDemo
//
//  Created by Libor Polehna on 22.06.2021.
//  Copyright © 2021 Trask, a.s. All rights reserved.
//

import Foundation


struct BasicTableCellViewModel {
    let title: String
    let action: (() -> Void)?
}
