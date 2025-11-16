// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, console } from "../../lib/forge-std/src/Test.sol";

import { IDepositSplitter } from "../../src/settlement-chain/interfaces/IDepositSplitter.sol";

import { Utils } from "../utils/Utils.sol";
import { DepositSplitterHarness } from "../utils/Harnesses.sol";

contract DepositSplitterTests is Test {
    DepositSplitterHarness internal _splitter;

    address internal _feeToken = makeAddr("feeToken");
    address internal _payerRegistry = makeAddr("payerRegistry");
    address internal _settlementChainGateway = makeAddr("settlementChainGateway");
    address internal _underlyingFeeToken = makeAddr("underlyingFeeToken");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");

    uint256 internal _appChainId = 111;

    function setUp() external {
        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("underlying()"), abi.encode(_underlyingFeeToken));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", _payerRegistry, type(uint256).max),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", _settlementChainGateway, type(uint256).max),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("approve(address,uint256)", _feeToken, type(uint256).max),
            abi.encode(true)
        );

        _splitter = new DepositSplitterHarness(_feeToken, _payerRegistry, _settlementChainGateway, _appChainId);
    }

    /* ============ constructor ============ */

    function test_constructor_zeroFeeToken() external {
        vm.expectRevert(IDepositSplitter.ZeroFeeToken.selector);
        new DepositSplitterHarness(address(0), address(0), address(0), 0);
    }

    function test_constructor_zeroPayerRegistry() external {
        vm.expectRevert(IDepositSplitter.ZeroPayerRegistry.selector);
        new DepositSplitterHarness(_feeToken, address(0), _settlementChainGateway, _appChainId);
    }

    function test_constructor_zeroSettlementChainGateway() external {
        vm.expectRevert(IDepositSplitter.ZeroSettlementChainGateway.selector);
        new DepositSplitterHarness(_feeToken, _payerRegistry, address(0), _appChainId);
    }

    function test_constructor_zeroAppChainId() external {
        vm.expectRevert(IDepositSplitter.ZeroAppChainId.selector);
        new DepositSplitterHarness(_feeToken, _payerRegistry, _settlementChainGateway, 0);
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_splitter.feeToken(), _feeToken);
        assertEq(_splitter.payerRegistry(), _payerRegistry);
        assertEq(_splitter.settlementChainGateway(), _settlementChainGateway);
        assertEq(_splitter.appChainId(), _appChainId);
        assertEq(_splitter.__getUnderlyingFeeToken(), _underlyingFeeToken);
    }

    /* ============ version ============ */

    function test_version() external view {
        assertEq(_splitter.version(), "0.1.0");
    }

    /* ============ deposit ============ */

    function test_deposit_feeTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _splitter.deposit(address(0), 0, address(0), 0, 0, 0);
    }

    function test_deposit_zeroTotalAmount() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(true)
        );

        vm.expectRevert(IDepositSplitter.ZeroTotalAmount.selector);

        vm.prank(_alice);
        _splitter.deposit(_bob, 0, _charlie, 0, 0, 0);
    }

    function test_deposit_onlyPayerRegistryDeposit() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 2),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        vm.prank(_alice);
        _splitter.deposit(_bob, 2, _charlie, 0, 0, 0);
    }

    function test_deposit_onlySettlementChainGatewayDeposit() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.deposit(_bob, 0, _charlie, 1, 0, 0);
    }

    function test_deposit_bothDeposits() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 3),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.deposit(_bob, 2, _charlie, 1, 0, 0);
    }

    /* ============ depositWithPermit ============ */

    function test_depositWithPermit_feeTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _splitter.depositWithPermit(address(0), 0, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_zeroTotalAmount() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(true)
        );

        vm.expectRevert(IDepositSplitter.ZeroTotalAmount.selector);

        vm.prank(_alice);
        _splitter.depositWithPermit(_bob, 0, _charlie, 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_onlyPayerRegistryDeposit() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                2,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 2),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        vm.prank(_alice);
        _splitter.depositWithPermit(_bob, 2, _charlie, 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_onlySettlementChainGatewayDeposit() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                1,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.depositWithPermit(_bob, 0, _charlie, 1, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_bothDeposits() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                3,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 3),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.depositWithPermit(_bob, 2, _charlie, 1, 0, 0, 0, 0, 0, 0);
    }

    /* ============ depositFromUnderlying ============ */

    function test_depositFromUnderlying_underlyingTokenTransferFromFailed_returnsFalse() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(false)
        );

        vm.expectRevert(IDepositSplitter.TransferFromFailed.selector);

        vm.prank(_alice);
        _splitter.depositFromUnderlying(address(0), 0, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_underlyingTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            ""
        );

        vm.expectRevert(IDepositSplitter.TransferFromFailed.selector);

        vm.prank(_alice);
        _splitter.depositFromUnderlying(address(0), 0, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_feeTokenDepositFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert();

        vm.prank(_alice);
        _splitter.depositFromUnderlying(address(0), 0, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_zeroTotalAmount() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(IDepositSplitter.ZeroTotalAmount.selector);

        vm.prank(_alice);
        _splitter.depositFromUnderlying(_bob, 0, _charlie, 0, 0, 0);
    }

    function test_depositFromUnderlying_onlyPayerRegistryDeposit() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 2),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 2), "");

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        vm.prank(_alice);
        _splitter.depositFromUnderlying(_bob, 2, _charlie, 0, 0, 0);
    }

    function test_depositFromUnderlying_onlySettlementChainGatewayDeposit() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 1), "");

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.depositFromUnderlying(_bob, 0, _charlie, 1, 0, 0);
    }

    function test_depositFromUnderlying_bothDeposits() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 3),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 3), "");

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.depositFromUnderlying(_bob, 2, _charlie, 1, 0, 0);
    }

    /* ============ depositFromUnderlyingWithPermit ============ */

    function test_depositFromUnderlyingWithPermit_underlyingTokenTransferFromFailed_returnsFalse() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(false)
        );

        vm.expectRevert(IDepositSplitter.TransferFromFailed.selector);

        vm.prank(_alice);
        _splitter.depositFromUnderlyingWithPermit(address(0), 0, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_underlyingTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            ""
        );

        vm.expectRevert(IDepositSplitter.TransferFromFailed.selector);

        vm.prank(_alice);
        _splitter.depositFromUnderlyingWithPermit(address(0), 0, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_feeTokenDepositFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert();

        vm.prank(_alice);
        _splitter.depositFromUnderlyingWithPermit(address(0), 0, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_zeroTotalAmount() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 0),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(IDepositSplitter.ZeroTotalAmount.selector);

        vm.prank(_alice);
        _splitter.depositFromUnderlyingWithPermit(_bob, 0, _charlie, 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_onlyPayerRegistryDeposit() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                2,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 2),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 2), "");

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        vm.prank(_alice);
        _splitter.depositFromUnderlyingWithPermit(_bob, 2, _charlie, 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_onlySettlementChainGatewayDeposit() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                1,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 1),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 1), "");

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.depositFromUnderlyingWithPermit(_bob, 0, _charlie, 1, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_bothDeposits() external {
        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_splitter),
                3,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_splitter), 3),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 3), "");

        Utils.expectAndMockCall(_payerRegistry, abi.encodeWithSignature("deposit(address,uint96)", _bob, 2), "");

        Utils.expectAndMockCall(
            _settlementChainGateway,
            abi.encodeWithSignature("deposit(uint256,address,uint256,uint256,uint256)", _appChainId, _charlie, 1, 0, 0),
            ""
        );

        vm.prank(_alice);
        _splitter.depositFromUnderlyingWithPermit(_bob, 2, _charlie, 1, 0, 0, 0, 0, 0, 0);
    }
}
