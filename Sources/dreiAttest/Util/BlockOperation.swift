//
//  BlockOperation.swift
//  dreiAttestTests
//
//  Created by Nils Becker on 11.03.21.
//

import Foundation

private enum OperationState {
    case notStarted, running, done
}

class BlockOperation: Operation {
    typealias DoneNotifier = () -> Void

    let block: (@escaping DoneNotifier) -> Void
    weak var owner: AnyObject? = nil
    private var state: OperationState = .notStarted {
        willSet {
            willChangeValue(for: \.isExecuting)
            willChangeValue(for: \.isFinished)
        }
        didSet {
            didChangeValue(for: \.isExecuting)
            didChangeValue(for: \.isFinished)
        }
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        state == .running
    }

    override var isFinished: Bool {
        state == .done
    }

    init(_ block: @escaping (@escaping DoneNotifier) -> Void) {
        self.block = block
        super.init()
    }

    override func start() {
        main()
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        state = .running
        block { [unowned self] in
            self.state = .done
        }
    }
}
