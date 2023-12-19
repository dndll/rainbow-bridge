// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import "rainbow-bridge-sol/nearbridge/contracts/AdminControlled.sol";
import "rainbow-bridge-sol/nearbridge/contracts/INearBridge.sol";
import "./ProofDecoder.sol";
import "./INearProver.sol";

error InvalidOutcomeRoot();
error InvalidBlockRoot();
error InvalidOutcomeRootRoot();
error InvalidBlockHash();

contract NearProver is INearProver, AdminControlled {
    using Borsh for Borsh.Data;
    using ProofDecoder for Borsh.Data;

    INearBridge public bridge;

    constructor(
        INearBridge _bridge,
        address _admin,
        uint _pausedFlags
    ) AdminControlled(_admin, _pausedFlags) {
        bridge = _bridge;
    }

    uint constant UNPAUSE_ALL = 0;
    uint constant PAUSED_VERIFY = 1;

    function lookupItems(ProofDecoder.LookupMerklePath memory proof, ProofDecoder.MerklePath memory cache)
        internal
        pure
        returns (ProofDecoder.MerklePath memory path)
    {
        for (uint256 i = 0; i < proof.items.length; i++) {
            if (proof.items.length == 0) {
                return path;
            }
            path.items = new ProofDecoder.MerklePathItem[](proof.items.length);
            ProofDecoder.LookupMerklePathItem memory lookup = proof.items[i];

            if (lookup.either == 0) {
                path.items[i] = cache.items[lookup.index];
            } else if (lookup.either == 1) {
                path.items[i] = lookup.item;
            }
        }
        return path;
    }

    function proveOutcome(bytes memory proofData, uint64 blockHeight)
        public
        view
        override
        pausable(PAUSED_VERIFY)
        returns (bool)
    {
        Borsh.Data memory borsh = Borsh.from(proofData);
        ProofDecoder.Proof memory proof = borsh.decodeProof();
        borsh.done();

        bytes32 hash;
        ProofDecoder.BlindedProof memory blindedProof;
        ProofDecoder.MerklePath memory path;
        ProofDecoder.LookupMerklePathItem memory lookup;

        for (uint256 index = 0; index < proof.batch.length; index++) {
            blindedProof = proof.batch[index];

            // Outcome proof
            hash = _computeLookupRoot(blindedProof.outcome_hash, blindedProof.outcome_proof, proof.cache);

            //Outcome root proof
            hash = _computeLookupRoot(sha256(abi.encodePacked(hash)), blindedProof.outcome_root_proof, proof.cache);

            if (hash != blindedProof.transaction_header.outcome_root) {
                revert InvalidOutcomeRoot();
            }

            // Block hash from header
            hash = blindedProof.transaction_header.hash;
            if (hash != blindedProof.outcome_proof_block_hash) {
                revert InvalidBlockHash();
            }

            // Block proof
            path.items = new ProofDecoder.MerklePathItem[](
                blindedProof.block_proof.items.length + proof.ancestry.items.length
            );
            for (uint256 i = 0; i < blindedProof.block_proof.items.length; i++) {
                lookup = blindedProof.block_proof.items[i];
                if (lookup.either == 0) {
                    path.items[i] = proof.cache.items[lookup.index];
                } else if (lookup.either == 1) {
                    path.items[i] = lookup.item;
                }
            }
            for (uint256 i = 0; i < proof.ancestry.items.length; i++) {
                path.items[blindedProof.block_proof.items.length + i] = proof.ancestry.items[i];
            }

            hash = _computeRoot(hash, path);
            if (hash != proof.client_block_merkle_root) {
                revert InvalidBlockRoot();
            }

            bytes32 expectedBlockMerkleRoot = bridge.blockMerkleRoots(blockHeight);
            require(hash == expectedBlockMerkleRoot, "NearProver: block merkle proof is not expected merkle root");
        }

        return true;
    }

    function _computeRoot(bytes32 node, ProofDecoder.MerklePath memory proof) internal pure returns (bytes32 hash) {
        hash = node;
        for (uint i = 0; i < proof.items.length; i++) {
            ProofDecoder.MerklePathItem memory item = proof.items[i];
            if (item.direction == 0) {
                hash = sha256(abi.encodePacked(item.hash, hash));
            } else {
                hash = sha256(abi.encodePacked(hash, item.hash));
            }
        }
    }

    function _computeLookupRoot(
        bytes32 node,
        ProofDecoder.LookupMerklePath memory proof,
        ProofDecoder.MerklePath memory cache
    ) internal pure returns (bytes32 hash) {
        ProofDecoder.MerklePath memory path;
        path.items = new ProofDecoder.MerklePathItem[](proof.items.length);
        for (uint i = 0; i < proof.items.length; i++) {
            ProofDecoder.LookupMerklePathItem memory item = proof.items[i];
            if (item.either == 0) {
                path.items[i] = cache.items[item.index];
            } else if (item.either == 1) {
                path.items[i] = item.item;
            }
        }
        return _computeRoot(node, path);
    }
}
