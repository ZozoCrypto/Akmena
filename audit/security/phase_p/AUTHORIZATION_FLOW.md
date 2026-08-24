# Akmena Authorization Flow

                 AI AGENT
                    |
                    | proposes action
                    v
             +--------------+
             | Policy Layer |
             +--------------+
                    |
                    | permitted?
                    v
          +---------------------+
          | Execution Intent    |
          | EIP-712             |
          +---------------------+
                    |
                    | signature
                    v
          +---------------------+
          | Authorization       |
          | Verifier            |
          +---------------------+
                    |
          +---------+----------+
          |         |          |
          v         v          v
       Nonce      Time       Policy
          |         |          |
          +---------+----------+
                    |
                    v
             Proof Boundary
                    |
                    v
             Exact Execution
                    |
                    v
              External Target
                    |
                    v
             Monetary Layer

Security boundary:

AI proposal
    !=
authorization

Frontend
    !=
authorization

Agent
    !=
authorization

Authorization
    =
cryptographically bounded execution
