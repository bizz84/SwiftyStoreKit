import Foundation
import StoreKit

struct CodeRedemption: Hashable {
    
    let atomically: Bool
    let callback: (TransactionResult) -> Void

    func hash(into hasher: inout Hasher) {
        hasher.combine(atomically)
    }
    
    static func == (lhs: CodeRedemption, rhs: CodeRedemption) -> Bool {
        return true
    }
}

class CodeRedemptionController: TransactionController {

    private var codeRedemption: CodeRedemption?

    func set(_ codeRedemption: CodeRedemption) {
        self.codeRedemption = codeRedemption
    }
    
    func clearCodeRedemption() {
        self.codeRedemption = nil
    }

    func processTransaction(_ transaction: SKPaymentTransaction, on paymentQueue: PaymentQueue) -> Bool {

        let transactionProductIdentifier = transaction.payment.productIdentifier

        guard let codeRedemption = self.codeRedemption else {

            return false
        }
        
        let transactionState = transaction.transactionState

        if transactionState == .purchased {
            let purchase = PurchaseCodeRedemptionDetails(productId: transactionProductIdentifier, quantity: transaction.payment.quantity, transaction: transaction, originalTransaction: transaction.original, needsFinishTransaction: !codeRedemption.atomically)
            
            codeRedemption.callback(.redeemed(purchase: purchase))

            if codeRedemption.atomically {
                paymentQueue.finishTransaction(transaction)
            }
            
            self.clearCodeRedemption()
            return true
        }

        if transactionState == .failed {

            codeRedemption.callback(.failed(error: transactionError(for: transaction.error as NSError?)))

            paymentQueue.finishTransaction(transaction)
            
            self.clearCodeRedemption()
            return true
        }

        self.clearCodeRedemption()
        return false
    }

    func transactionError(for error: NSError?) -> SKError {
        let message = "Unknown error"
        let altError = NSError(domain: SKErrorDomain, code: SKError.unknown.rawValue, userInfo: [ NSLocalizedDescriptionKey: message ])
        let nsError = error ?? altError
        return SKError(_nsError: nsError)
    }

    func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction] {

        return transactions.filter { !processTransaction($0, on: paymentQueue) }
    }
}
