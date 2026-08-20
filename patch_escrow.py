file_path = "src/economics/EscrowEngine.sol"
with open(file_path, "r") as f:
    content = f.read()

last_brace_idx = content.rfind("}")

new_func = """
    /// @notice Unified interface for the PolicyBoundary dynamic routing
    function verifyTransientProof(uint256 proofId, address operator, uint256 amount) external view returns (bool) {
        LibStorage.EscrowData memory targetData = getEscrow(proofId);
        return targetData.status == 1 && targetData.buyer == operator && targetData.amount >= amount;
    }
"""

new_content = content[:last_brace_idx] + new_func + content[last_brace_idx:]

with open(file_path, "w") as f:
    f.write(new_content)
print("Successfully patched EscrowEngine.sol!")
