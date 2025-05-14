// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, stdError } from "../../lib/forge-std/src/Test.sol";

import { SequentialMerkleProofs } from "../../src/libraries/SequentialMerkleProofs.sol";

import { SequentialMerkleProofsHarness } from "../utils/Harnesses.sol";

contract SequentialMerkleProofsTests is Test {
    struct Sample {
        uint256 startingIndex;
        uint256 leafCount;
        bytes[] leaves;
        bytes32[] proofElements;
        bytes32 root;
    }

    Sample[] internal _balancedSamples;
    Sample[] internal _unbalancedSamples;

    SequentialMerkleProofsHarness internal _sequentialMerkleProofs;

    function setUp() external {
        _sequentialMerkleProofs = new SequentialMerkleProofsHarness();

        _buildBalancedSamples();
        _buildUnbalancedSamples();
    }

    /* ============ hashLeaf ============ */

    function test_hashLeaf() external view {
        assertEq(
            _sequentialMerkleProofs.__hashLeaf("Hello"),
            0x0b8faa8dd08a172ebf9582ef1c73d06a82e28d18c61a8b47b13d01f1740e9a11
        );

        assertEq(
            _sequentialMerkleProofs.__hashLeaf("World"),
            0x817d5a47d8f38274199af57907aa20a633a5f767439cfc22e11a5dd5a4493f2a
        );

        assertEq(
            _sequentialMerkleProofs.__hashLeaf("Lorem ipsum dolor sit amet"),
            0xa5dc43044db877acef8181b04b78a81c39a01d8ba78e29a5fe06a99732e626d3
        );

        assertEq(
            _sequentialMerkleProofs.__hashLeaf("Lorem ipsum dolor sit amet consectetur adipiscing elit"),
            0xa5fe16054246ec55b4c4f376e432cce9f5d7e9c6859bf2801c1d05e0a187341c
        );
    }

    /* ============ hashNodePair ============ */

    function test_hashNodePair() external view {
        assertEq(
            _sequentialMerkleProofs.__hashNodePair(
                0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f,
                0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
            ),
            0x30c08f17fca6d5b183fd798df2c94be55f9191aa17b64e14af24dea51d56a200
        );

        assertEq(
            _sequentialMerkleProofs.__hashNodePair(
                0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f,
                0x1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100
            ),
            0xaf45a9d3cd256488928e96458a0fe6bde6182c416dad6228c15900570ad4ce86
        );

        assertEq(
            _sequentialMerkleProofs.__hashNodePair(
                0x0000000000000000000000000000000000000000000000000000000000000000,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            ),
            0xcf86af75a8a3ad149001943d69c6f6baf87e648e765e365f9aea84c06a306fea
        );
    }

    /* ============ hashPairlessNode ============ */

    function test_hashPairlessNode() external view {
        assertEq(
            _sequentialMerkleProofs.__hashPairlessNode(
                0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
            ),
            0x4bde7d5c3f4483ac1642c0f72078ce38639cca66529ce401be6200d03194f0a5
        );

        assertEq(
            _sequentialMerkleProofs.__hashPairlessNode(
                0x1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100
            ),
            0x26960017dbb60afc80dfcc5a6ccbfa17711de9e934a46ae4532a79ac33344a02
        );

        assertEq(
            _sequentialMerkleProofs.__hashPairlessNode(
                0x0000000000000000000000000000000000000000000000000000000000000000
            ),
            0xeb14eebf6aaf45d22d20a202b833f1d484603044dea188a8eb1585c22d01a41f
        );

        assertEq(
            _sequentialMerkleProofs.__hashPairlessNode(
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            ),
            0x2f8f0f26e7f767c7dea71e75bf4f70510db5b05f50e842eeb6dc09d678b87640
        );
    }

    /* ============ hashRoot ============ */

    function test_hashRoot() external view {
        assertEq(
            _sequentialMerkleProofs.__hashRoot(1, 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f),
            0x42bdfcbf85f7e8aafa85a4c4ce995c0f8413225503d8b5aeaadaa7a044083acb
        );

        assertEq(
            _sequentialMerkleProofs.__hashRoot(78, 0x1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100),
            0xda04fbfbac2808039eaf34829fbb30df8855c1589785cb5764e23b1b32fd2537
        );

        assertEq(
            _sequentialMerkleProofs.__hashRoot(
                46984,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            ),
            0x6bd1491b7fd13801bace4086092489a8e34ac0c15920d1ad7921e0f402eae63e
        );
    }

    /* ============ verify ============ */

    function test_verify_noProofElements() external {
        vm.expectRevert(SequentialMerkleProofs.NoProofElements.selector);
        _sequentialMerkleProofs.verify(0, 0, new bytes[](0), new bytes32[](0));
    }

    function test_verify_noLeafs_nonZeroStartingIndex() external {
        vm.expectRevert(SequentialMerkleProofs.NoLeaves.selector);
        _sequentialMerkleProofs.verify(0, 1, new bytes[](0), new bytes32[](1));
    }

    function test_verify_noLeafs_nonZeroLeafCount() external {
        bytes32[] memory proofElements_ = new bytes32[](1);
        proofElements_[0] = bytes32(uint256(1));

        vm.expectRevert(SequentialMerkleProofs.NoLeaves.selector);

        _sequentialMerkleProofs.verify(0, 0, new bytes[](0), proofElements_);
    }

    function test_verify_invalidBitCount32Input() external {
        bytes[] memory leaves_ = new bytes[](1);
        leaves_[0] = bytes(hex"00");

        bytes32[] memory proofElements_ = new bytes32[](1);
        proofElements_[0] = bytes32(uint256(type(uint32).max) + 1);

        vm.expectRevert(SequentialMerkleProofs.InvalidBitCount32Input.selector);

        _sequentialMerkleProofs.verify(0, 0, leaves_, proofElements_);
    }

    function test_verify_noLeafs() external {
        _sequentialMerkleProofs.verify(0, 0, new bytes[](0), new bytes32[](1));
    }

    function test_verify_balancedSamples() external view {
        for (uint256 index_; index_ < _balancedSamples.length; ++index_) {
            Sample storage sample_ = _balancedSamples[index_];
            _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);
        }
    }

    function test_verify_balancedSamples_invalidProofs() external {
        for (uint256 index_; index_ < _balancedSamples.length; ++index_) {
            Sample storage sample_ = _balancedSamples[index_];

            _testVerifyWithIncorrectRoot(sample_);
            _testVerifyWithIncorrectStartingIndex(sample_);
            _testVerifyWithOutOfBoundsStartingIndex(sample_);
            _testVerifyWithIncorrectLeaf(sample_);
            _testVerifyWithIncorrectLeafCount(sample_);

            if (sample_.proofElements.length == 1) continue;

            _testVerifyWithIncorrectProofElement(sample_);
        }
    }

    function test_verify_unbalancedSamples() external view {
        for (uint256 index_; index_ < _unbalancedSamples.length; ++index_) {
            Sample storage sample_ = _unbalancedSamples[index_];
            _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);
        }
    }

    function test_verify_unbalancedSamples_invalidProofs() external {
        for (uint256 index_; index_ < _unbalancedSamples.length; ++index_) {
            Sample storage sample_ = _unbalancedSamples[index_];

            _testVerifyWithIncorrectRoot(sample_);
            _testVerifyWithIncorrectStartingIndex(sample_);
            _testVerifyWithOutOfBoundsStartingIndex(sample_);
            _testVerifyWithIncorrectLeaf(sample_);
            _testVerifyWithIncorrectLeafCount(sample_);

            if (sample_.proofElements.length == 1) continue;

            _testVerifyWithIncorrectProofElement(sample_);
        }
    }

    /* ============ getRoot ============ */

    function test_getRoot_noProofElements() external {
        vm.expectRevert(SequentialMerkleProofs.NoProofElements.selector);
        _sequentialMerkleProofs.getRoot(0, new bytes[](0), new bytes32[](0));
    }

    function test_getRoot_noLeafs_nonZeroStartingIndex() external {
        vm.expectRevert(SequentialMerkleProofs.NoLeaves.selector);
        _sequentialMerkleProofs.getRoot(1, new bytes[](0), new bytes32[](1));
    }

    function test_getRoot_noLeafs_nonZeroLeafCount() external {
        bytes32[] memory proofElements_ = new bytes32[](1);
        proofElements_[0] = bytes32(uint256(1));

        vm.expectRevert(SequentialMerkleProofs.NoLeaves.selector);

        _sequentialMerkleProofs.getRoot(0, new bytes[](0), proofElements_);
    }

    function test_getRoot_invalidProof() external {
        vm.expectRevert(SequentialMerkleProofs.InvalidProof.selector);
        _sequentialMerkleProofs.getRoot(0, new bytes[](1), new bytes32[](1));
    }

    function test_getRoot_invalidBitCount32Input() external {
        bytes[] memory leaves_ = new bytes[](1);
        leaves_[0] = bytes(hex"00");

        bytes32[] memory proofElements_ = new bytes32[](1);
        proofElements_[0] = bytes32(uint256(type(uint32).max) + 1);

        vm.expectRevert(SequentialMerkleProofs.InvalidBitCount32Input.selector);

        _sequentialMerkleProofs.getRoot(0, leaves_, proofElements_);
    }

    function test_getRoot_noLeaves() external {
        assertEq(_sequentialMerkleProofs.getRoot(0, new bytes[](0), new bytes32[](1)), bytes32(0));
    }

    function test_getRoot_balancedSamples() external view {
        for (uint256 index_; index_ < _balancedSamples.length; ++index_) {
            Sample storage sample_ = _balancedSamples[index_];

            assertEq(
                _sequentialMerkleProofs.getRoot(sample_.startingIndex, sample_.leaves, sample_.proofElements),
                sample_.root
            );
        }
    }

    function test_getRoot_unbalancedSamples() external view {
        for (uint256 index_; index_ < _unbalancedSamples.length; ++index_) {
            Sample storage sample_ = _unbalancedSamples[index_];

            assertEq(
                _sequentialMerkleProofs.getRoot(sample_.startingIndex, sample_.leaves, sample_.proofElements),
                sample_.root
            );
        }
    }

    /* ============ getLeafCount ============ */

    function test_getLeafCount_noProofElements() external {
        vm.expectRevert(SequentialMerkleProofs.NoProofElements.selector);
        _sequentialMerkleProofs.getLeafCount(new bytes32[](0));
    }

    function test_getLeafCount_invalidLeafCount() external {
        bytes32[] memory proofElements_ = new bytes32[](1);
        proofElements_[0] = bytes32(uint256(type(uint32).max) + 1);

        vm.expectRevert(SequentialMerkleProofs.InvalidLeafCount.selector);

        _sequentialMerkleProofs.getLeafCount(proofElements_);
    }

    function test_getLeafCount() external view {
        bytes32[] memory proofElements_ = new bytes32[](1);

        assertEq(_sequentialMerkleProofs.getLeafCount(proofElements_), 0);

        proofElements_[0] = bytes32(uint256(1));

        assertEq(_sequentialMerkleProofs.getLeafCount(proofElements_), 1);

        proofElements_[0] = bytes32(uint256(1111));

        assertEq(_sequentialMerkleProofs.getLeafCount(proofElements_), 1111);
    }

    /* ============ bitCount32 ============ */

    function test_bitCount32_invalidBitCount32Input() external {
        vm.expectRevert(SequentialMerkleProofs.InvalidBitCount32Input.selector);
        _sequentialMerkleProofs.__bitCount32(uint256(type(uint32).max) + 1);
    }

    function test_bitCount32() external view {
        assertEq(_sequentialMerkleProofs.__bitCount32(0), 0);
        assertEq(_sequentialMerkleProofs.__bitCount32(uint256(type(uint32).max)), 32);

        for (uint256 i_ = 0; i_ < 32; ++i_) {
            assertEq(_sequentialMerkleProofs.__bitCount32(1 << i_), 1); // One bit set
            assertEq(_sequentialMerkleProofs.__bitCount32((1 << i_) - 1), i_); // i_ bits set
        }
    }

    /* ============ roundUpToPowerOf2 ============ */

    function test_roundUpToPowerOf2_invalidBitCount32Input() external {
        vm.expectRevert(SequentialMerkleProofs.InvalidBitCount32Input.selector);
        _sequentialMerkleProofs.__roundUpToPowerOf2(uint256(type(uint32).max) + 1);
    }

    function test_roundUpToPowerOf2() external view {
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(0), 1);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(1), 1);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(2), 2);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(3), 4);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(4), 4);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(5), 8);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(6), 8);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(7), 8);
        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(8), 8);

        assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(uint256(type(uint32).max)), 1 << 32);

        for (uint256 i_ = 4; i_ < 32; ++i_) {
            assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2(1 << i_), 1 << i_); // Exact power of 2
            assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2((1 << i_) - 1), 1 << i_); // 1 less than
            assertEq(_sequentialMerkleProofs.__roundUpToPowerOf2((1 << (i_ - 1)) + 1), 1 << i_); // 1 more than prev
        }
    }

    /* ============ getBalancedLeafCount ============ */

    function test_getBalancedLeafCount_invalidBitCount32Input() external {
        vm.expectRevert(SequentialMerkleProofs.InvalidBitCount32Input.selector);
        _sequentialMerkleProofs.__getBalancedLeafCount(uint256(type(uint32).max) + 1);
    }

    function test_getBalancedLeafCount() external view {
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(0), 0);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(1), 2);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(2), 2);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(3), 4);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(4), 4);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(5), 8);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(6), 8);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(7), 8);
        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(8), 8);

        assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(uint256(type(uint32).max)), 1 << 32);

        for (uint256 i_ = 4; i_ < 32; ++i_) {
            assertEq(_sequentialMerkleProofs.__getBalancedLeafCount(1 << i_), 1 << i_); // Exact power of 2
            assertEq(_sequentialMerkleProofs.__getBalancedLeafCount((1 << i_) - 1), 1 << i_); // 1 less than
            assertEq(_sequentialMerkleProofs.__getBalancedLeafCount((1 << (i_ - 1)) + 1), 1 << i_); // 1 more than prev
        }
    }

    /* ============ getReversedLeafNodesFromLeaves ============ */

    function test_getReversedLeafNodesFromLeaves() external view {
        bytes[] memory leaves_ = new bytes[](4);

        leaves_[0] = bytes(hex"a8152e7c56b62d9fcb8af361257a260b2b9481c8683e8df1651a31508cc6ee31");
        leaves_[1] = bytes(hex"007f47e1c51d53cab18977050347e8e8dc488bdd9590babe3e104fcb9a1ef599");
        leaves_[2] = bytes(hex"7cbe68a29af312d42c40e6d083bb64fe2ba0ac6bf1cac8e4b10f5356142e3828");
        leaves_[3] = bytes(hex"4a864e860c0d0247c6aa5ebcb2bc3f15fc4ddf86213258f4bf0b72e51c9d9c69");

        bytes32[] memory reversedLeafNodes_ = _sequentialMerkleProofs.__getReversedLeafNodesFromLeaves(leaves_);

        assertEq(reversedLeafNodes_[0], 0x8613e086c6c42ab3b7027723e29bf61497f3629e0fb0c1b0453c93f053e22a18);
        assertEq(reversedLeafNodes_[1], 0x09a458689dbd19291ce83007725819f0c69504e282d7669b7d08576162bd7f52);
        assertEq(reversedLeafNodes_[2], 0x569dab69f958322840fb959938fee8dbc2bde84f55584935a8230303db6aaebd);
        assertEq(reversedLeafNodes_[3], 0xb8283b9a33ca222061b7d8d5f85170289c5c4a7f96997ce2ae5bafc94fc8a59b);
    }

    /* ============ helpers ============ */

    function _buildBalancedSamples() internal {
        /* ============ Sample 1 ============ */

        _balancedSamples.push(
            Sample({
                startingIndex: 0,
                leafCount: 2,
                leaves: new bytes[](1),
                proofElements: new bytes32[](2),
                root: 0xeeef536868dc2c030bec2d3602cc13fbe660bd5d63deca6a0a4dfd201eb941c0
            })
        );

        _balancedSamples[0].leaves[0] = bytes(hex"6330b989705733cc5c1f7285b8a5b892e08be86ed6fbe9d254713a4277bc5bd2");

        _balancedSamples[0].proofElements[0] = bytes32(_balancedSamples[0].leafCount);
        _balancedSamples[0].proofElements[1] = bytes32(
            0xb8283b9a33ca222061b7d8d5f85170289c5c4a7f96997ce2ae5bafc94fc8a59b
        );

        /* ============ Sample 2 ============ */

        _balancedSamples.push(
            Sample({
                startingIndex: 1,
                leafCount: 8,
                leaves: new bytes[](4),
                proofElements: new bytes32[](4),
                root: 0x00f8c0ad3c60c727ededce5717c8baa64047b5c3f29e409085df14dc3bfda1a7
            })
        );

        _balancedSamples[1].leaves[0] = bytes(hex"a8152e7c56b62d9fcb8af361257a260b2b9481c8683e8df1651a31508cc6ee31");
        _balancedSamples[1].leaves[1] = bytes(hex"007f47e1c51d53cab18977050347e8e8dc488bdd9590babe3e104fcb9a1ef599");
        _balancedSamples[1].leaves[2] = bytes(hex"7cbe68a29af312d42c40e6d083bb64fe2ba0ac6bf1cac8e4b10f5356142e3828");
        _balancedSamples[1].leaves[3] = bytes(hex"4a864e860c0d0247c6aa5ebcb2bc3f15fc4ddf86213258f4bf0b72e51c9d9c69");

        _balancedSamples[1].proofElements[0] = bytes32(_balancedSamples[1].leafCount);
        _balancedSamples[1].proofElements[1] = 0xb7f40118daf8bbb92b1759e810c6eb4b0b92e04d1b7e4be48a147721ea457d87;
        _balancedSamples[1].proofElements[2] = 0x06331c9b61be683c1819b2cd20c83f315499477f6253ae8d8bb02cbc6bd93c9f;
        _balancedSamples[1].proofElements[3] = 0xc3d064e0f1ace0f92e6c822d5346de5330fb23a6c31a0c84a80d9d5c8543cc0e;

        /* ============ Sample 3 ============ */

        _balancedSamples.push(
            Sample({
                startingIndex: 9,
                leafCount: 16,
                leaves: new bytes[](4),
                proofElements: new bytes32[](5),
                root: 0x31338b156e26447f0a3a965981b0be87957bf5606b44e0dcdc99eb4646048942
            })
        );

        _balancedSamples[2].leaves[0] = bytes(hex"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2");
        _balancedSamples[2].leaves[1] = bytes(hex"112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00");
        _balancedSamples[2].leaves[2] = bytes(hex"f0e1d2c3b4a5968778695a4b3c2d1e0f1f2e3d4c5b6a79887766554433221100");
        _balancedSamples[2].leaves[3] = bytes(hex"abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789");

        _balancedSamples[2].proofElements[0] = bytes32(_balancedSamples[2].leafCount);
        _balancedSamples[2].proofElements[1] = 0x194f8cb59bc03a6e9dfcc3566bed0a85a069f50de609f51af6c74dee673450d4;
        _balancedSamples[2].proofElements[2] = 0x2642cf6153e4ddfd7ea9c1c99d86efe99c03d29bce0ce4adbf7c0162865aa93a;
        _balancedSamples[2].proofElements[3] = 0x9d8799ecccbca75f60304876c8426007565302fdb72449fe980917d7847d43e7;
        _balancedSamples[2].proofElements[4] = 0x1f70e7dd11a042e3868e8b0992118a3d7bd301b029a3b967a5b2042466c5110c;
    }

    function _buildUnbalancedSamples() internal {
        /* ============ Sample 1 ============ */

        _unbalancedSamples.push(
            Sample({
                startingIndex: 0,
                leafCount: 1,
                leaves: new bytes[](1),
                proofElements: new bytes32[](1),
                root: 0x5b833bdf4f55e39d1838653841d4a2c651a71b5626b7936e1bedb5212cae96e3
            })
        );

        _unbalancedSamples[0].leaves[0] = bytes(hex"6330b989705733cc5c1f7285b8a5b892e08be86ed6fbe9d254713a4277bc5bd2");

        _unbalancedSamples[0].proofElements[0] = bytes32(_unbalancedSamples[0].leafCount);

        /* ============ Sample 2 ============ */

        _unbalancedSamples.push(
            Sample({
                startingIndex: 4,
                leafCount: 7,
                leaves: new bytes[](2),
                proofElements: new bytes32[](3),
                root: 0x38631dd8b5081555ec3c51cc8db7918ee90158fa33a70674c1399234d23908b2
            })
        );

        _unbalancedSamples[1].leaves[0] = bytes(hex"4a864e860c0d0247c6aa5ebcb2bc3f15fc4ddf86213258f4bf0b72e51c9d9c69");
        _unbalancedSamples[1].leaves[1] = bytes(hex"51b7ae2bab96bd3fbb3b26e1efefb0b9b6a60054ed7ffcfa700374d58f315a31");

        _unbalancedSamples[1].proofElements[0] = bytes32(_unbalancedSamples[1].leafCount);
        _unbalancedSamples[1].proofElements[1] = 0x6b379ab3dd3b0b8df76cbe09e2a04f21ebf601f2932d3505ecfb89417f3de836;
        _unbalancedSamples[1].proofElements[2] = 0x52bd35868bccc1b1f4c3ac67dd7e3b3db4a24f60436411162d633e6d1118de89;

        /* ============ Sample 3 ============ */

        _unbalancedSamples.push(
            Sample({
                startingIndex: 9,
                leafCount: 13,
                leaves: new bytes[](4),
                proofElements: new bytes32[](3),
                root: 0xf92d4ca528834b0350cecd9307bec2dd97d0a6bbb58b077ab51cdad36fc5c087
            })
        );

        _unbalancedSamples[2].leaves[0] = bytes(hex"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2");
        _unbalancedSamples[2].leaves[1] = bytes(hex"112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00");
        _unbalancedSamples[2].leaves[2] = bytes(hex"f0e1d2c3b4a5968778695a4b3c2d1e0f1f2e3d4c5b6a79887766554433221100");
        _unbalancedSamples[2].leaves[3] = bytes(hex"abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789");

        _unbalancedSamples[2].proofElements[0] = bytes32(_unbalancedSamples[2].leafCount);
        _unbalancedSamples[2].proofElements[1] = 0x2642cf6153e4ddfd7ea9c1c99d86efe99c03d29bce0ce4adbf7c0162865aa93a;
        _unbalancedSamples[2].proofElements[2] = 0x1f70e7dd11a042e3868e8b0992118a3d7bd301b029a3b967a5b2042466c5110c;

        /* ============ Sample 4 ============ */

        _unbalancedSamples.push(
            Sample({
                startingIndex: 200,
                leafCount: 324,
                leaves: new bytes[](22),
                proofElements: new bytes32[](7),
                root: 0x8f28d0f19d1805a3b539bcc2bb0e627ded4bf5b873bebc9199ed179a30ca312c
            })
        );

        _unbalancedSamples[3].leaves[0] = bytes(hex"fe0403dd500c862ddbbb4736c071a575d9fd43fbdeea602833234e9cd198bb3f");
        _unbalancedSamples[3].leaves[1] = bytes(hex"5129d77889ad52ef899ba3d85e01a6df5c230804ccc586faa7e8376b89aa0600");
        _unbalancedSamples[3].leaves[2] = bytes(hex"f1d6a296210c112eda6ca002273abc7d21b933cf99ca0c8292e344ba2d62f750");
        _unbalancedSamples[3].leaves[3] = bytes(hex"907f141e1702157a9ca13881b0ecb0cb10be9b588bd6499479496965ce933225");
        _unbalancedSamples[3].leaves[4] = bytes(hex"c77ccc18e17ec5d50bbbf775f564debfa1f9da8031be2fc7ce618cea8a625226");
        _unbalancedSamples[3].leaves[5] = bytes(hex"aad8eb018edb0690bbdcebe48db820a6a13e3f8102bb0e5535fdfed79eaa5c39");
        _unbalancedSamples[3].leaves[6] = bytes(hex"374346003edf10ea2da568e8e973857ec4291bf10a8bf81612b36efaf6e93c23");
        _unbalancedSamples[3].leaves[7] = bytes(hex"45a3c2e32a3c8ea5e34562806f8279e85cfad69f6015588b599dc2e774d50cee");
        _unbalancedSamples[3].leaves[8] = bytes(hex"9322c7cbfb342280d72d4eba15c0d9711e3f730072375bc4b0cf538970014e7a");
        _unbalancedSamples[3].leaves[9] = bytes(hex"b3017e1b1874f68c4508c0b147a4f2b96dd166274c81bb4a86082d391efad6fa");
        _unbalancedSamples[3].leaves[10] = bytes(hex"76d7f81c6813544dc594db8b5f3d6cef292e91d02a50ad556e6bcddc1eb59f8c");
        _unbalancedSamples[3].leaves[11] = bytes(hex"320cfee2fb238c49255d102213b395963c2a3ebd7a8ee424e8df02b01361e484");
        _unbalancedSamples[3].leaves[12] = bytes(hex"697fa39a1e23106c54eeecf38d213bfe2fcf896f55b790815085241b7e7e7361");
        _unbalancedSamples[3].leaves[13] = bytes(hex"510fde4a04ecbe4bf94a514ab836074270959d2b96492a56909706de0b0248be");
        _unbalancedSamples[3].leaves[14] = bytes(hex"5fa7828c8c661f4243c97527d637bf318e5e801dcf3b488f0f302622abdf61e9");
        _unbalancedSamples[3].leaves[15] = bytes(hex"6f7fafb63e26bafeb5fd21a76615d0f2b45e6684324e294f10078661c00b4026");
        _unbalancedSamples[3].leaves[16] = bytes(hex"e80b189bd7a1e5d0a04d9ba778d11f1bbffec4e276f502780a97fc7006715ac5");
        _unbalancedSamples[3].leaves[17] = bytes(hex"25e66cd82e8fa7b6072d7759d2b49d0979bad20b018c730f4d1fcac7a6959bd4");
        _unbalancedSamples[3].leaves[18] = bytes(hex"0695e86d43e2c5097acd182042d09cda438fc1f773335ce0f190dbed668ff508");
        _unbalancedSamples[3].leaves[19] = bytes(hex"783eb995b1a99bb4181dad1c386dff06c5c02469a4893ca8c0a5b5fd82f7747a");
        _unbalancedSamples[3].leaves[20] = bytes(hex"44fb0e55a04f4d5accd7a9e00fd5bbbf8926083ef169c0711f503ae16b589c20");
        _unbalancedSamples[3].leaves[21] = bytes(hex"2815ef424dd0613d69f70546821ebddf2fe1b7452510cd21d25f3e438863e8a3");

        _unbalancedSamples[3].proofElements[0] = bytes32(_unbalancedSamples[3].leafCount);
        _unbalancedSamples[3].proofElements[1] = 0x55f9b393403d39fdf3b35fe8f394e13a272509df05d5562e5da6937c11bb1214;
        _unbalancedSamples[3].proofElements[2] = 0xa4c0ad363d17cb84be9e3f757278de2b26843e918e48e33e1b00438764fefa2b;
        _unbalancedSamples[3].proofElements[3] = 0xafee522c5ba27318361dd426e355fa02e5821fbc8b2ba52dea3b36885d76ec94;
        _unbalancedSamples[3].proofElements[4] = 0x25171fda9d5059c4cc4b8a86af5e0634dd8217cd2167c8d868733eef3f23054f;
        _unbalancedSamples[3].proofElements[5] = 0x1e3106cd69a1fec956fa702eae218bdba94f7150d87c05210b282e334218d265;
        _unbalancedSamples[3].proofElements[6] = 0xd2b4a539a1349d2d145fe307c30ce5bd43fa10887ce20a8a71da53300c0a6150;
    }

    function _testVerifyWithIncorrectRoot(Sample storage sample_) internal {
        unchecked {
            sample_.root = bytes32(uint256(sample_.root) + 1);
        }

        vm.expectRevert(SequentialMerkleProofs.InvalidProof.selector);

        _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);

        unchecked {
            sample_.root = bytes32(uint256(sample_.root) - 1);
        }
    }

    function _testVerifyWithIncorrectStartingIndex(Sample storage sample_) internal {
        unchecked {
            sample_.startingIndex += 1;
        }

        vm.expectRevert();

        _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);

        unchecked {
            sample_.startingIndex -= 1;
        }
    }

    function _testVerifyWithOutOfBoundsStartingIndex(Sample storage sample_) internal {
        uint256 originalStartingIndex_ = sample_.startingIndex;

        unchecked {
            sample_.startingIndex = sample_.leafCount + 1;
        }

        vm.expectRevert();

        _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);

        unchecked {
            sample_.startingIndex = originalStartingIndex_;
        }
    }

    function _testVerifyWithIncorrectLeaf(Sample storage sample_) internal {
        bytes memory originalLeaf_ = sample_.leaves[0];

        sample_.leaves[0] = bytes(hex"0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f");

        vm.expectRevert(SequentialMerkleProofs.InvalidProof.selector);

        _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);

        sample_.leaves[0] = originalLeaf_;
    }

    function _testVerifyWithIncorrectLeafCount(Sample storage sample_) internal {
        unchecked {
            sample_.proofElements[0] = bytes32(uint256(sample_.proofElements[0]) + 1);
        }

        vm.expectRevert();

        _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);

        unchecked {
            sample_.proofElements[0] = bytes32(uint256(sample_.proofElements[0]) - 1);
        }
    }

    function _testVerifyWithIncorrectProofElement(Sample storage sample_) internal {
        unchecked {
            sample_.proofElements[1] = bytes32(uint256(sample_.proofElements[1]) + 1);
        }

        vm.expectRevert(SequentialMerkleProofs.InvalidProof.selector);

        _sequentialMerkleProofs.verify(sample_.root, sample_.startingIndex, sample_.leaves, sample_.proofElements);

        unchecked {
            sample_.proofElements[1] = bytes32(uint256(sample_.proofElements[1]) - 1);
        }
    }
}
