# Problem Understanding — Google Pay UPI Database

The goal is to reconstruct a reliable PostgreSQL database from nine exports and optimize 30 supplied payment, support, and reporting queries without changing their results.

| Problem | Business requirement and stakeholder | Workload class | Queries |
|---|---|---|---|
| P1 | Payers need fast payment history, VPA verification and linked-account display (user app). | Real-time | R01, R02, R22 |
| P2 | Payments core must check daily transfer limits before authorizing payments. | Real-time | R03, W01 |
| P3 | Bank partners and operations must reconcile old pending payments and callbacks promptly. | Operational / near-real-time | R04, W02 |
| P4 | Merchants need collections and settlement reports; success staff need merchants with zero payments. | Interactive + analytics | R05, R06, R13 |
| P5 | Fraud team needs suspicious payee/repeat-payment detection; merchant risk needs refund trends. | Near-real-time + analytics | R08, R09, R17 |
| P6 | Users need rewards and bill views; rewards/billing teams must run expiry and overdue jobs. | Real-time + batch | R10–R12, W03–W05 |
| P7 | Compliance needs KYC exposure reports; support needs quick disputes and reference lookups. | Analytics + real-time support | R16, R18, R23, R24 |
| P8 | Banks and analysts need failure/latency/volume reports that remain usable at 20× scale. | Analytics | R07, R14, R15, R19–R21, R25 |

**Assumptions.** Users can link multiple accounts and VPAs; some transaction counterparties are external to Google Pay; P2P transactions do not require a merchant; pending payments may have no completion time; monetary values require exact decimal storage; dates/times are timezone-aware; reporting queries can tolerate higher latency than payment-path queries. These assumptions must be checked against the full CSV data.
