# Problem Understanding – Google Pay Digital Payments

## 1. Project Overview

Google Pay is a UPI-based application that allows users to send money to other people (P2P) and make payments to merchants (P2M). Users can link bank accounts, use UPI IDs (VPAs), earn scratch-card rewards, pay bills and raise disputes.

The current database has no documented schema, and only data exports are available. Different teams have reported problems with slow payment operations, delayed reconciliation, fraud checks and reporting. The aim is to understand these problems and identify what the database needs to support.

## 2. Business Problems and Requirements

| ID | Business need | Stakeholders | Type | Queries |
|---|---|---|---|---|
| P1 | Transaction history and the pay screen are slow. Users need quick access to recent payments, VPA checks and linked bank accounts. | Payer, Payee | Customer-facing / Real-time | R01, R02, R22 |
| P2 | The daily UPI limit is checked on every payment. This check needs to be faster so that it does not delay payments. | Payer | Customer-facing / Real-time | R03, W01 |
| P3 | Stuck PENDING payments and delayed bank callbacks are slowing down reconciliation. These need to be handled promptly. | Bank partner, Reconciliation / Ops | Customer-facing / Real-time | R04, W02 |
| P4 | Merchants need to track live collections and daily settlements. The success team also needs a correct list of merchants who have never received a payment. | Merchant, Success team, Bank partner | Reporting / Analytics (also includes live collection tracking) | R05, R06, R13 |
| P5 | Fraud & Risk needs to identify mule accounts, repeated payments and unusual refund rates as close to real time as possible. | Payer, Payee, Merchant, Fraud & Risk | Customer-facing / Real-time | R08, R09, R17 |
| P6 | Slow reward and bill reminder jobs affect scratch cards, reward expiry and overdue bill notifications. These jobs need to run on time. | Payer, Rewards team | Customer-facing / Real-time | R10, R11, R12, W03–W05 |
| P7 | Compliance needs KYC-risk reports, while customer support needs instant UPI reference lookups and faster access to dispute queues. | Payer, Payee, Compliance (RBI/KYC), Customer Support | Reporting / Analytics (also includes real-time support lookups) | R16, R18, R23, R24 |
| P8 | Bank partners and business teams need reliable dashboards for failure codes, payment latency and success rates. These reports must also support the expected 20× growth in UPI volume. | Bank partner, Analytics / Business teams | Reporting / Analytics | R07, R14, R15, R19–R21, R25 |

## 3. Assumptions

1. A user can link one or more bank accounts and have UPI IDs (VPAs) associated with them.
2. Payments can be made between individuals (P2P) or between users and merchants (P2M).
3. Every payment receives a unique 12-digit UPI reference number.
4. Transactions can end in success, failure, reversal or refund.
5. Payment-related operations require quick access to transaction and account information.
6. Reconciliation and bank callback processing should keep pending payment information up to date.
7. Rewards, scratch-card expiry and bill reminder jobs should process their records on time.
8. Reporting and analytics require access to historical transaction data.
9. The database should be planned with the expected 20× increase in UPI volume in mind.

## 4. Overall Understanding

The database needs to support both fast payment operations and reliable reporting. Users should be able to make payments and check transaction details without unnecessary delays, while internal teams should be able to handle reconciliation, fraud checks, disputes and business analysis. It should also be able to support future growth in transaction volume.