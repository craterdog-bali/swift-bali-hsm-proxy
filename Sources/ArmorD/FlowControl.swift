//
//  FlowControl.swift
//  paymentDemo
//
//  Created by Derk Norton on 1/6/20.
//  Copyright © 2020 Aren Dalloul. All rights reserved.
//

import Foundation

public protocol FlowControl {
    func stepFailed(device: ArmorD, error: String)
    func nextStep(device: ArmorD, result: [UInt8]?)
}
