import os

# The exact files flagged by the Solidity compiler
files = [
    "test/attack/AttackWave3_PolicyBoundary.t.sol",
    "test/attack/phase_c_cross_module/Attack_EconomicEscalation.t.sol",
    "test/attack/phase_f_agent/Attack_BoundaryDesync.t.sol",
    "test/authorization/AkmenaPolicyBoundary.t.sol"
]

for filepath in files:
    if not os.path.exists(filepath):
        print(f"Skipping {filepath} (Not found)")
        continue
        
    with open(filepath, 'r') as f:
        content = f.read()
    
    parts = content.split("executeAgentCall(")
    new_content = parts[0]
    
    for part in parts[1:]:
        comma_count = 0
        paren_depth = 0
        insert_idx = -1
        
        # Traverse the characters to find the 3rd root-level comma
        for idx, char in enumerate(part):
            if char == '(': 
                paren_depth += 1
            elif char == ')':
                if paren_depth > 0: 
                    paren_depth -= 1
                else: 
                    break # Reached the end of the executeAgentCall parameters
            elif char == ',' and paren_depth == 0:
                comma_count += 1
                if comma_count == 3:
                    insert_idx = idx
                    break
        
        # If we found the 3rd comma, verify if this call only has 5 arguments
        if insert_idx != -1:
            remaining_commas = 0
            temp_depth = 0
            for char in part[insert_idx+1:]:
                if char == '(': temp_depth += 1
                elif char == ')':
                    if temp_depth > 0: temp_depth -= 1
                    else: break
                elif char == ',' and temp_depth == 0:
                    remaining_commas += 1
            
            # If there is only 1 remaining comma, it means there are 5 arguments total.
            # We patch it to 6 by injecting the ESCROW_ENGINE key.
            if remaining_commas == 1: 
                part = part[:insert_idx+1] + ' bytes32("ESCROW_ENGINE"),' + part[insert_idx+1:]
        
        new_content += "executeAgentCall(" + part
        
    with open(filepath, 'w') as f:
        f.write(new_content)
        print(f"Successfully patched: {filepath}")

print("\nAll legacy tests have been dynamically routed!")
