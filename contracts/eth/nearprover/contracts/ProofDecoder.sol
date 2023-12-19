// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import "rainbow-bridge-sol/nearbridge/contracts/Borsh.sol";
import "rainbow-bridge-sol/nearbridge/contracts/NearDecoder.sol";

library ProofDecoder {
    using Borsh for Borsh.Data;
    using ProofDecoder for Borsh.Data;
    using NearDecoder for Borsh.Data;

    struct Proof {
        bytes32 client_block_merkle_root;
        BlindedProof[] batch;
        MerklePath ancestry;
        MerklePath cache;
    }

    function decodeProof(Borsh.Data memory data) internal view returns (Proof memory proof) {
        proof.client_block_merkle_root = data.decodeBytes32();

        proof.batch = new BlindedProof[](data.decodeU32());
        for (uint i = 0; i < proof.batch.length; i++) {
            proof.batch[i] = data.decodeBlindedProof();
        }

        proof.ancestry = data.decodeMerklePath();
        proof.cache = data.decodeMerklePath();
    }

    struct BlindedProof {
        bytes32 outcome_proof_block_hash;
        bytes32 outcome_hash;
        LookupMerklePath outcome_proof;
        LookupMerklePath outcome_root_proof;
        LookupMerklePath block_proof;
        Header transaction_header;
        //bytes32 intermediate_root;
    }

    function decodeBlindedProof(Borsh.Data memory data) internal view returns (BlindedProof memory proof) {
        proof.outcome_proof_block_hash = data.decodeBytes32();
        proof.outcome_hash = data.decodeBytes32();
        proof.outcome_proof = data.decodeLookupMerklePath();
        proof.outcome_root_proof = data.decodeLookupMerklePath();
        proof.block_proof = data.decodeLookupMerklePath();
        proof.transaction_header = data.decodeHeader();
        //proof.intermediate_root = data.decodeBytes32();
    }

    struct Header {
        bytes32 hash;
        bytes32 outcome_root;
    }

    function decodeHeader(Borsh.Data memory data) internal view returns (Header memory header) {
        header.hash = sha256(
            abi.encodePacked(sha256(abi.encodePacked(data.decodeBytes32(), data.decodeBytes32())), data.decodeBytes32())
        );
        header.outcome_root = data.decodeBytes32();
    }

    struct MerklePathItem {
        bytes32 hash;
        uint8 direction; // 0 = left, 1 = right
    }

    function decodeMerklePathItem(Borsh.Data memory data) internal view returns (MerklePathItem memory item) {
        item.hash = data.decodeBytes32();
        item.direction = data.decodeU8();
        require(item.direction < 2, "ProofDecoder: MerklePathItem direction should be 0 or 1");
    }

    struct MerklePath {
        MerklePathItem[] items;
    }

    function decodeMerklePath(Borsh.Data memory data) internal view returns (MerklePath memory path) {
        path.items = new MerklePathItem[](data.decodeU32());
        for (uint i = 0; i < path.items.length; i++) {
            path.items[i] = data.decodeMerklePathItem();
        }
    }

    struct LookupMerklePathItem {
        uint8 either; // 0 = left, 1 = right
        uint32 index;
        MerklePathItem item;
    }

    function decodeLookupMerklePathItem(Borsh.Data memory data)
        internal
        view
        returns (LookupMerklePathItem memory item)
    {
        item.either = data.decodeU8();
        if (item.either == 0) {
            item.index = data.decodeU32();
        } else if (item.either == 1) {
            item.item = data.decodeMerklePathItem();
        } else {
            revert("ProofDecoder: LookupMerklePathItem either should be 0 or 1");
        }
    }

    struct LookupMerklePath {
        LookupMerklePathItem[] items;
    }

    function decodeLookupMerklePath(Borsh.Data memory data) internal view returns (LookupMerklePath memory path) {
        path.items = new LookupMerklePathItem[](data.decodeU32());
        for (uint i = 0; i < path.items.length; i++) {
            path.items[i] = data.decodeLookupMerklePathItem();
        }
    }
}
