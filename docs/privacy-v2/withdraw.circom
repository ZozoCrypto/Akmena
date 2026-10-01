pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/mux1.circom";

// Merkle tree membership proof using Poseidon hashes.
// Computes the root from a leaf commitment and a path, constraining it
// against the public root. Standard Tornado Cash construction, with
// Poseidon instead of Pedersen/MiMC for cheaper in-circuit hashing.
template MerkleProof(levels) {
    signal input leaf;
    signal input pathElements[levels];
    signal input pathIndices[levels]; // 0 = leaf is left, 1 = leaf is right
    signal output root;

    component hashers[levels];
    component mux[levels];
    signal computed[levels + 1];
    computed[0] <== leaf;

    for (var i = 0; i < levels; i++) {
        // Constrain path index to boolean
        pathIndices[i] * (1 - pathIndices[i]) === 0;

        // mux: if idx==0 -> [cur, sibling]; if idx==1 -> [sibling, cur]
        // MultiMux1 selects c[s] per row: out[0] = left, out[1] = right
        mux[i] = MultiMux1(2);
        mux[i].c[0][0] <== computed[i];
        mux[i].c[0][1] <== pathElements[i];
        mux[i].c[1][0] <== pathElements[i];
        mux[i].c[1][1] <== computed[i];
        mux[i].s <== pathIndices[i];

        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== mux[i].out[0];
        hashers[i].inputs[1] <== mux[i].out[1];
        computed[i + 1] <== hashers[i].out;
    }

    root <== computed[levels];
}

// Private withdrawal proof for a fixed-denomination pool.
//
// Proves, in zero knowledge:
//   1. The prover knows (nullifier, secret) for some commitment in the tree.
//   2. The nullifierHash is correctly derived: nullifierHash = Poseidon(nullifier).
//   3. The recipient / relayer / fee are bound to this proof (public signals),
//      so a relayer cannot redirect funds or change the fee.
//
// Reveals: nullifierHash (double-spend prevention), merkle root, recipient,
// relayer, fee. Hides: which commitment (hence which deposit), nullifier,
// secret.
template Withdraw(levels) {
    // Private inputs
    signal input nullifier;
    signal input secret;
    signal input pathElements[levels];
    signal input pathIndices[levels];

    // Public inputs
    signal input root;
    signal input nullifierHash;
    signal input recipient;
    signal input relayer;
    signal input fee;

    // 1. Commitment well-formedness (kept private)
    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== secret;

    // 2. Nullifier derivation correctness
    component nullifierHasher = Poseidon(1);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHasher.out === nullifierHash;

    // 3. Merkle membership
    component tree = MerkleProof(levels);
    tree.leaf <== commitmentHasher.out;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }
    tree.root === root;

    // recipient / relayer / fee are public inputs, hence part of the
    // public signals the proof is verified against. Any tampering by a
    // relayer (redirecting funds, inflating the fee) invalidates the proof.
    // No additional constraints needed.
}

component main { public [ root, nullifierHash, recipient, relayer, fee ] } = Withdraw(20);
