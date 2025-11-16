// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { AddressAliasHelper } from "../../src/libraries/AddressAliasHelper.sol";

import { IAppChainGatewayLike } from "../../src/settlement-chain/interfaces/External.sol";
import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";
import { ISettlementChainGateway } from "../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { SettlementChainGatewayHarness } from "../utils/Harnesses.sol";

import { MockMigrator } from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

// TODO: Perhaps remove duplicated test code with internal calls tests.

contract SettlementChainGatewayTests is Test {
    string internal constant _DELIMITER = ".";
    string internal constant _INBOX_KEY = "xmtp.settlementChainGateway.inbox";
    string internal constant _MIGRATOR_KEY = "xmtp.settlementChainGateway.migrator";
    string internal constant _PAUSED_KEY = "xmtp.settlementChainGateway.paused";

    uint256 internal constant _RECEIVE_DEPOSIT_DATA_LENGTH = 36;

    SettlementChainGatewayHarness internal _gateway;

    address internal _implementation;

    address internal _appChainGateway = makeAddr("appChainGateway");
    address internal _feeToken = makeAddr("feeToken");
    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _underlyingFeeToken = makeAddr("underlyingFeeToken");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");

    function setUp() external {
        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("underlying()"), abi.encode(_underlyingFeeToken));
        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("decimals()"), abi.encode(6));

        _implementation = address(new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, _feeToken));
        _gateway = SettlementChainGatewayHarness(address(new Proxy(_implementation)));

        _gateway.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(ISettlementChainGateway.ZeroParameterRegistry.selector);
        new SettlementChainGatewayHarness(address(0), address(0), address(0));
    }

    function test_constructor_zeroAppChainGateway() external {
        vm.expectRevert(ISettlementChainGateway.ZeroAppChainGateway.selector);
        new SettlementChainGatewayHarness(_parameterRegistry, address(0), _feeToken);
    }

    function test_constructor_zeroFeeToken() external {
        vm.expectRevert(ISettlementChainGateway.ZeroFeeToken.selector);
        new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, address(0));
    }

    function test_constructor_invalidFeeTokenDecimals() external {
        vm.mockCall(_feeToken, abi.encodeWithSignature("decimals()"), abi.encode(19));
        vm.expectRevert(ISettlementChainGateway.InvalidFeeTokenDecimals.selector);
        new SettlementChainGatewayHarness(_parameterRegistry, _appChainGateway, _feeToken);
    }

    /* ============ initialize ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _gateway.initialize();
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_gateway)), _implementation);
        assertEq(_gateway.implementation(), _implementation);
        assertEq(_gateway.inboxParameterKey(), _INBOX_KEY);
        assertEq(_gateway.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_gateway.pausedParameterKey(), _PAUSED_KEY);
        assertEq(_gateway.parameterRegistry(), _parameterRegistry);
        assertEq(_gateway.appChainGateway(), _appChainGateway);
        assertEq(_gateway.feeToken(), _feeToken);
        assertFalse(_gateway.paused());
        assertEq(_gateway.__getNonce(), 0);
        assertEq(_gateway.__getUnderlyingFeeToken(), _underlyingFeeToken);
        assertEq(_gateway.__getFeeTokenDecimals(), 6);
        assertEq(_gateway.__getReceiveDepositDataLength(), _RECEIVE_DEPOSIT_DATA_LENGTH);
    }

    /* ============ version ============ */

    function test_version() external view {
        assertEq(_gateway.version(), "0.1.0");
    }

    /* ============ deposit ============ */

    function test_deposit_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.deposit(0, address(0), 0, 0, 0);
    }

    function test_deposit_feeTokenTransferFailed_reverts() external {
        vm.mockCallRevert(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.deposit(1111, address(0), 0, 0, 0);
    }

    function test_deposit_unsupportedChainId() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.deposit(1111, address(0), 0, 0, 0);
    }

    function test_deposit_zeroRecipient() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.ZeroRecipient.selector);

        vm.prank(_alice);
        _gateway.deposit(1111, address(0), 0, 0, 0);
    }

    function test_deposit_zeroAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.ZeroAmount.selector);

        vm.prank(_alice);
        _gateway.deposit(1111, _bob, 0, 0, 0);
    }

    function test_deposit_insufficientAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(100000000000001))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ISettlementChainGateway.InsufficientAmount.selector,
                100000000000000,
                100000000000001
            )
        );

        vm.prank(_alice);
        _gateway.deposit(1111, _bob, 100, 0, 0);
    }

    function test_deposit_feeTokenApproveFailed_reverts() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(0))
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("approve(address,uint256)", inbox_, 100), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.deposit(1111, _bob, 100, 0, 0);
    }

    function test_deposit() external {
        uint256 maxFeePerGas_ = 1 gwei;
        uint256 gasLimit_ = 100_000;
        uint256 amount_ = 3_000_000;
        uint256 submissionCost_ = 0.1 ether;

        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), amount_),
            abi.encode(true)
        );

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(submissionCost_)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, amount_),
            abi.encode(true)
        );

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));
        uint256 expectedCallValue_ = (amount_ * 10 ** 12) - submissionCost_ - (maxFeePerGas_ * gasLimit_);
        uint256 expectedMaxFees_ = _gateway.__convertFromWei(submissionCost_ + (maxFeePerGas_ * gasLimit_));

        Utils.expectAndMockCall(
            inbox_,
            abi.encodeWithSignature(
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                _appChainGateway,
                expectedCallValue_,
                submissionCost_,
                appChainAlias_,
                appChainAlias_,
                gasLimit_,
                maxFeePerGas_,
                amount_,
                abi.encodeCall(IAppChainGatewayLike.receiveDeposit, (_bob))
            ),
            abi.encode(uint256(11))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Deposit(1111, 11, _bob, amount_, expectedMaxFees_);

        vm.prank(_alice);
        _gateway.deposit(1111, _bob, amount_, gasLimit_, maxFeePerGas_);
    }

    /* ============ depositWithPermit ============ */

    function test_depositWithPermit_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.depositWithPermit(0, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_feeTokenTransferFailed_reverts() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCallRevert(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.depositWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_unsupportedChainId() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.depositWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_zeroRecipient() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.ZeroRecipient.selector);

        vm.prank(_alice);
        _gateway.depositWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_zeroAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.ZeroAmount.selector);

        vm.prank(_alice);
        _gateway.depositWithPermit(1111, _bob, 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_insufficientAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(100000000000001))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ISettlementChainGateway.InsufficientAmount.selector,
                100000000000000,
                100000000000001
            )
        );

        vm.prank(_alice);
        _gateway.depositWithPermit(1111, _bob, 100, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_feeTokenApproveFailed_reverts() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(0))
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("approve(address,uint256)", inbox_, 100), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.depositWithPermit(1111, _bob, 100, 0, 0, 0, 0, 0, 0);
    }

    function test_depositWithPermit() external {
        uint256 maxFeePerGas_ = 1 gwei;
        uint256 gasLimit_ = 100_000;
        uint256 amount_ = 3_000_000;
        uint256 submissionCost_ = 0.1 ether;

        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                amount_,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), amount_),
            abi.encode(true)
        );

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(submissionCost_)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, amount_),
            abi.encode(true)
        );

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));
        uint256 expectedCallValue_ = (amount_ * 10 ** 12) - submissionCost_ - (maxFeePerGas_ * gasLimit_);
        uint256 expectedMaxFees_ = _gateway.__convertFromWei(submissionCost_ + (maxFeePerGas_ * gasLimit_));

        Utils.expectAndMockCall(
            inbox_,
            abi.encodeWithSignature(
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                _appChainGateway,
                expectedCallValue_,
                submissionCost_,
                appChainAlias_,
                appChainAlias_,
                gasLimit_,
                maxFeePerGas_,
                amount_,
                abi.encodeCall(IAppChainGatewayLike.receiveDeposit, (_bob))
            ),
            abi.encode(uint256(11))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Deposit(1111, 11, _bob, amount_, expectedMaxFees_);

        vm.prank(_alice);
        _gateway.depositWithPermit(1111, _bob, amount_, gasLimit_, maxFeePerGas_, 0, 0, 0, 0);
    }

    /* ============ depositFromUnderlying ============ */

    function test_depositFromUnderlying_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.depositFromUnderlying(0, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_underlyingTokenTransferFailed_returnsFalse() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_underlyingTokenTransferFailed_reverts() external {
        vm.mockCallRevert(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            ""
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_feeTokenDepositFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_unsupportedChainId() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_zeroRecipient() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(ISettlementChainGateway.ZeroRecipient.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, address(0), 0, 0, 0);
    }

    function test_depositFromUnderlying_zeroAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(ISettlementChainGateway.ZeroAmount.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, _bob, 0, 0, 0);
    }

    function test_depositFromUnderlying_insufficientAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(100000000000001))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ISettlementChainGateway.InsufficientAmount.selector,
                100000000000000,
                100000000000001
            )
        );

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, _bob, 100, 0, 0);
    }

    function test_depositFromUnderlying_feeTokenApproveFailed_reverts() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(0))
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("approve(address,uint256)", inbox_, 100), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, _bob, 100, 0, 0);
    }

    function test_depositFromUnderlying() external {
        uint256 maxFeePerGas_ = 1 gwei;
        uint256 gasLimit_ = 100_000;
        uint256 amount_ = 3_000_000;
        uint256 submissionCost_ = 0.1 ether;

        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), amount_),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", amount_), "");

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(submissionCost_)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, amount_),
            abi.encode(true)
        );

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));
        uint256 expectedCallValue_ = (amount_ * 10 ** 12) - submissionCost_ - (maxFeePerGas_ * gasLimit_);
        uint256 expectedMaxFees_ = _gateway.__convertFromWei(submissionCost_ + (maxFeePerGas_ * gasLimit_));

        Utils.expectAndMockCall(
            inbox_,
            abi.encodeWithSignature(
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                _appChainGateway,
                expectedCallValue_,
                submissionCost_,
                appChainAlias_,
                appChainAlias_,
                gasLimit_,
                maxFeePerGas_,
                amount_,
                abi.encodeCall(IAppChainGatewayLike.receiveDeposit, (_bob))
            ),
            abi.encode(uint256(11))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Deposit(1111, 11, _bob, amount_, expectedMaxFees_);

        vm.prank(_alice);
        _gateway.depositFromUnderlying(1111, _bob, amount_, gasLimit_, maxFeePerGas_);
    }

    /* ============ depositFromUnderlyingWithPermit ============ */

    function test_depositFromUnderlyingWithPermit_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.depositFromUnderlyingWithPermit(0, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_underlyingTokenTransferFailed_returnsFalse() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_underlyingTokenTransferFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCallRevert(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            ""
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_feeTokenDepositFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_unsupportedChainId() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_zeroRecipient() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(ISettlementChainGateway.ZeroRecipient.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_zeroAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(ISettlementChainGateway.ZeroAmount.selector);

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, _bob, 0, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_insufficientAmount() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(100000000000001))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ISettlementChainGateway.InsufficientAmount.selector,
                100000000000000,
                100000000000001
            )
        );

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, _bob, 100, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit_feeTokenApproveFailed_reverts() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(uint256(0))
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("approve(address,uint256)", inbox_, 100), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, _bob, 100, 0, 0, 0, 0, 0, 0);
    }

    function test_depositFromUnderlyingWithPermit() external {
        uint256 maxFeePerGas_ = 1 gwei;
        uint256 gasLimit_ = 100_000;
        uint256 amount_ = 3_000_000;
        uint256 submissionCost_ = 0.1 ether;

        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                amount_,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), amount_),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", amount_), "");

        vm.mockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                block.basefee
            ),
            abi.encode(submissionCost_)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("approve(address,uint256)", inbox_, amount_),
            abi.encode(true)
        );

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));
        uint256 expectedCallValue_ = (amount_ * 10 ** 12) - submissionCost_ - (maxFeePerGas_ * gasLimit_);
        uint256 expectedMaxFees_ = _gateway.__convertFromWei(submissionCost_ + (maxFeePerGas_ * gasLimit_));

        Utils.expectAndMockCall(
            inbox_,
            abi.encodeWithSignature(
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                _appChainGateway,
                expectedCallValue_,
                submissionCost_,
                appChainAlias_,
                appChainAlias_,
                gasLimit_,
                maxFeePerGas_,
                amount_,
                abi.encodeCall(IAppChainGatewayLike.receiveDeposit, (_bob))
            ),
            abi.encode(uint256(11))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.Deposit(1111, 11, _bob, amount_, expectedMaxFees_);

        vm.prank(_alice);
        _gateway.depositFromUnderlyingWithPermit(1111, _bob, amount_, gasLimit_, maxFeePerGas_, 0, 0, 0, 0);
    }

    /* ============ sendParameters ============ */

    function test_sendParameters_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.sendParameters(new uint256[](0), new string[](0), 0, 0, 0);
    }

    function test_sendParameters_feeTokenTransferFailed_reverts() external {
        vm.mockCallRevert(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.sendParameters(new uint256[](1), new string[](0), 0, 0, 100);
    }

    function test_sendParameters_noChainIds() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.NoChainIds.selector);

        vm.prank(_alice);
        _gateway.sendParameters(new uint256[](0), new string[](0), 0, 0, 0);
    }

    function test_sendParameters_noKeys() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);

        vm.prank(_alice);
        _gateway.sendParameters(new uint256[](1), new string[](0), 0, 0, 100);
    }

    function test_sendParameters_unsupportedChainId() external {
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = 1111;

        string[] memory keys_ = new string[](1);
        keys_[0] = "this.is.a.parameter";

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(string[])", keys_), abi.encode(new bytes32[](1)));

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.sendParameters(chainIds_, keys_, 0, 0, 100);
    }

    function test_sendParameters() external {
        uint256[] memory chainIds_ = new uint256[](2);
        chainIds_[0] = 1111;
        chainIds_[1] = 1112;

        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        _gateway.__setInbox(chainIds_[0], inboxes_[0]);
        _gateway.__setInbox(chainIds_[1], inboxes_[1]);

        string[] memory keys_ = new string[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 2 * 3_000_000),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(string[])", keys_),
            abi.encode(values_)
        );

        bytes memory data_ = abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_));

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "calculateRetryableSubmissionFee(uint256,uint256)",
                    data_.length,
                    block.basefee
                ),
                abi.encode(0.1 ether)
            );

            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("approve(address,uint256)", inboxes_[index_], 3_000_000),
                abi.encode(true)
            );

            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                    _appChainGateway,
                    0,
                    0.1 ether,
                    appChainAlias_,
                    appChainAlias_,
                    250_000,
                    1 gwei,
                    3_000_000,
                    data_
                ),
                abi.encode(uint256(11 * (index_ + 1)))
            );

            vm.expectEmit(address(_gateway));
            emit ISettlementChainGateway.ParametersSent(chainIds_[index_], 11 * (index_ + 1), 1, keys_);
        }

        vm.prank(_alice);
        uint256 totalSent_ = _gateway.sendParameters(chainIds_, keys_, 250_000, 1 gwei, 3_000_000);

        assertEq(totalSent_, 2 * 3_000_000);
        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ sendParametersWithPermit ============ */

    function test_sendParametersWithPermit_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.sendParametersWithPermit(new uint256[](0), new string[](0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_sendParametersWithPermit_feeTokenTransferFailed_reverts() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCallRevert(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            ""
        );

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.sendParametersWithPermit(new uint256[](1), new string[](0), 0, 0, 100, 0, 0, 0, 0);
    }

    function test_sendParametersWithPermit_noChainIds() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.NoChainIds.selector);

        vm.prank(_alice);
        _gateway.sendParametersWithPermit(new uint256[](0), new string[](0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_sendParametersWithPermit_noKeys() external {
        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);

        vm.prank(_alice);
        _gateway.sendParametersWithPermit(new uint256[](1), new string[](0), 0, 0, 100, 0, 0, 0, 0);
    }

    function test_sendParametersWithPermit_unsupportedChainId() external {
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = 1111;

        string[] memory keys_ = new string[](1);
        keys_[0] = "this.is.a.parameter";

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(string[])", keys_), abi.encode(new bytes32[](1)));

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.sendParametersWithPermit(chainIds_, keys_, 0, 0, 100, 0, 0, 0, 0);
    }

    function test_sendParametersWithPermit() external {
        uint256[] memory chainIds_ = new uint256[](2);
        chainIds_[0] = 1111;
        chainIds_[1] = 1112;

        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        _gateway.__setInbox(chainIds_[0], inboxes_[0]);
        _gateway.__setInbox(chainIds_[1], inboxes_[1]);

        string[] memory keys_ = new string[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                2 * 3_000_000,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 2 * 3_000_000),
            abi.encode(true)
        );

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(string[])", keys_),
            abi.encode(values_)
        );

        bytes memory data_ = abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_));

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "calculateRetryableSubmissionFee(uint256,uint256)",
                    data_.length,
                    block.basefee
                ),
                abi.encode(0.1 ether)
            );

            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("approve(address,uint256)", inboxes_[index_], 3_000_000),
                abi.encode(true)
            );

            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                    _appChainGateway,
                    0,
                    0.1 ether,
                    appChainAlias_,
                    appChainAlias_,
                    250_000,
                    1 gwei,
                    3_000_000,
                    data_
                ),
                abi.encode(uint256(11 * (index_ + 1)))
            );

            vm.expectEmit(address(_gateway));
            emit ISettlementChainGateway.ParametersSent(chainIds_[index_], 11 * (index_ + 1), 1, keys_);
        }

        vm.prank(_alice);
        uint256 totalSent_ = _gateway.sendParametersWithPermit(
            chainIds_,
            keys_,
            250_000,
            1 gwei,
            3_000_000,
            0,
            0,
            0,
            0
        );

        assertEq(totalSent_, 2 * 3_000_000);
        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ sendParametersFromUnderlying ============ */

    function test_sendParametersFromUnderlying_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.sendParametersFromUnderlying(new uint256[](0), new string[](0), 0, 0, 0);
    }

    function test_sendParametersFromUnderlying_underlyingTokenTransferFailed_returnsFalse() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlying(new uint256[](1), new string[](0), 0, 0, 100);

        assertEq(_gateway.__getNonce(), 0);
    }

    function test_sendParametersFromUnderlying_underlyingTokenTransferFailed_reverts() external {
        vm.mockCallRevert(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            ""
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlying(new uint256[](1), new string[](0), 0, 0, 100);
    }

    function test_sendParametersFromUnderlying_feeTokenDepositFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlying(new uint256[](1), new string[](0), 0, 0, 100);
    }

    function test_sendParametersFromUnderlying_noChainIds() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(ISettlementChainGateway.NoChainIds.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlying(new uint256[](0), new string[](0), 0, 0, 0);
    }

    function test_sendParametersFromUnderlying_noKeys() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlying(new uint256[](1), new string[](0), 0, 0, 100);
    }

    function test_sendParametersFromUnderlying_unsupportedChainId() external {
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = 1111;

        string[] memory keys_ = new string[](1);
        keys_[0] = "this.is.a.parameter";

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(string[])", keys_), abi.encode(new bytes32[](1)));

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlying(chainIds_, keys_, 0, 0, 100);
    }

    function test_sendParametersFromUnderlying() external {
        uint256[] memory chainIds_ = new uint256[](2);
        chainIds_[0] = 1111;
        chainIds_[1] = 1112;

        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        _gateway.__setInbox(chainIds_[0], inboxes_[0]);
        _gateway.__setInbox(chainIds_[1], inboxes_[1]);

        string[] memory keys_ = new string[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 2 * 3_000_000),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 2 * 3_000_000), "");

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(string[])", keys_),
            abi.encode(values_)
        );

        bytes memory data_ = abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_));

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "calculateRetryableSubmissionFee(uint256,uint256)",
                    data_.length,
                    block.basefee
                ),
                abi.encode(0.1 ether)
            );

            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("approve(address,uint256)", inboxes_[index_], 3_000_000),
                abi.encode(true)
            );

            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                    _appChainGateway,
                    0,
                    0.1 ether,
                    appChainAlias_,
                    appChainAlias_,
                    250_000,
                    1 gwei,
                    3_000_000,
                    data_
                ),
                abi.encode(uint256(11 * (index_ + 1)))
            );

            vm.expectEmit(address(_gateway));
            emit ISettlementChainGateway.ParametersSent(chainIds_[index_], 11 * (index_ + 1), 1, keys_);
        }

        vm.prank(_alice);
        uint256 totalSent_ = _gateway.sendParametersFromUnderlying(chainIds_, keys_, 250_000, 1 gwei, 3_000_000);

        assertEq(totalSent_, 2 * 3_000_000);
        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ sendParametersFromUnderlyingWithPermit ============ */

    function test_sendParametersFromUnderlyingWithPermit_paused() external {
        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.Paused.selector);
        _gateway.sendParametersFromUnderlyingWithPermit(new uint256[](0), new string[](0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_sendParametersFromUnderlyingWithPermit_underlyingTokenTransferFailed_returnsFalse() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(false)
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlyingWithPermit(new uint256[](1), new string[](0), 0, 0, 100, 0, 0, 0, 0);

        assertEq(_gateway.__getNonce(), 0);
    }

    function test_sendParametersFromUnderlyingWithPermit_underlyingTokenTransferFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCallRevert(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            ""
        );

        vm.expectRevert(ISettlementChainGateway.TransferFromFailed.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlyingWithPermit(new uint256[](1), new string[](0), 0, 0, 100, 0, 0, 0, 0);
    }

    function test_sendParametersFromUnderlyingWithPermit_feeTokenDepositFailed_reverts() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.expectRevert();

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlyingWithPermit(new uint256[](1), new string[](0), 0, 0, 100, 0, 0, 0, 0);
    }

    function test_sendParametersFromUnderlyingWithPermit_noChainIds() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                0,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 0),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 0), "");

        vm.expectRevert(ISettlementChainGateway.NoChainIds.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlyingWithPermit(new uint256[](0), new string[](0), 0, 0, 0, 0, 0, 0, 0);
    }

    function test_sendParametersFromUnderlyingWithPermit_noKeys() external {
        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.expectRevert(ISettlementChainGateway.NoKeys.selector);

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlyingWithPermit(new uint256[](1), new string[](0), 0, 0, 100, 0, 0, 0, 0);
    }

    function test_sendParametersFromUnderlyingWithPermit_unsupportedChainId() external {
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = 1111;

        string[] memory keys_ = new string[](1);
        keys_[0] = "this.is.a.parameter";

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        vm.mockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 100),
            abi.encode(true)
        );

        vm.mockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 100), "");

        vm.mockCall(_parameterRegistry, abi.encodeWithSignature("get(string[])", keys_), abi.encode(new bytes32[](1)));

        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));

        vm.prank(_alice);
        _gateway.sendParametersFromUnderlyingWithPermit(chainIds_, keys_, 0, 0, 100, 0, 0, 0, 0);
    }

    function test_sendParametersFromUnderlyingWithPermit() external {
        uint256[] memory chainIds_ = new uint256[](2);
        chainIds_[0] = 1111;
        chainIds_[1] = 1112;

        address[] memory inboxes_ = new address[](2);
        inboxes_[0] = makeAddr("inbox0");
        inboxes_[1] = makeAddr("inbox1");

        _gateway.__setInbox(chainIds_[0], inboxes_[0]);
        _gateway.__setInbox(chainIds_[1], inboxes_[1]);

        string[] memory keys_ = new string[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(10101));
        values_[1] = bytes32(uint256(23232));

        address appChainAlias_ = AddressAliasHelper.toAlias(address(_gateway));

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_gateway),
                2 * 3_000_000,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlyingFeeToken,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_gateway), 2 * 3_000_000),
            abi.encode(true)
        );

        Utils.expectAndMockCall(_feeToken, abi.encodeWithSignature("deposit(uint256)", 2 * 3_000_000), "");

        Utils.expectAndMockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(string[])", keys_),
            abi.encode(values_)
        );

        bytes memory data_ = abi.encodeCall(IAppChainGatewayLike.receiveParameters, (1, keys_, values_));

        for (uint256 index_; index_ < chainIds_.length; ++index_) {
            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "calculateRetryableSubmissionFee(uint256,uint256)",
                    data_.length,
                    block.basefee
                ),
                abi.encode(0.1 ether)
            );

            Utils.expectAndMockCall(
                _feeToken,
                abi.encodeWithSignature("approve(address,uint256)", inboxes_[index_], 3_000_000),
                abi.encode(true)
            );

            Utils.expectAndMockCall(
                inboxes_[index_],
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,uint256,bytes)",
                    _appChainGateway,
                    0,
                    0.1 ether,
                    appChainAlias_,
                    appChainAlias_,
                    250_000,
                    1 gwei,
                    3_000_000,
                    data_
                ),
                abi.encode(uint256(11 * (index_ + 1)))
            );

            vm.expectEmit(address(_gateway));
            emit ISettlementChainGateway.ParametersSent(chainIds_[index_], 11 * (index_ + 1), 1, keys_);
        }

        vm.prank(_alice);
        uint256 totalSent_ = _gateway.sendParametersFromUnderlyingWithPermit(
            chainIds_,
            keys_,
            250_000,
            1 gwei,
            3_000_000,
            0,
            0,
            0,
            0
        );

        assertEq(totalSent_, 2 * 3_000_000);
        assertEq(_gateway.__getNonce(), 1);
    }

    /* ============ updateInbox ============ */

    function test_updateInbox() external {
        address inbox_ = makeAddr("inbox");

        vm.mockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(string)", abi.encodePacked(_INBOX_KEY, ".1111")),
            abi.encode(bytes32(uint256(uint160(inbox_))))
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.InboxUpdated(1111, inbox_);

        _gateway.updateInbox(1111);

        assertEq(_gateway.__getInbox(1111), inbox_);

        vm.mockCall(
            _parameterRegistry,
            abi.encodeWithSignature("get(string)", abi.encodePacked(_INBOX_KEY, ".1111")),
            abi.encode(0)
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.InboxUpdated(1111, address(0));

        _gateway.updateInbox(1111);

        assertEq(_gateway.__getInbox(1111), address(0));
    }

    /* ============ receiveWithdrawal ============ */

    function test_receiveWithdrawal_feeTokenTransferFailed_reverts() external {
        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_gateway)), abi.encode(100));

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("transfer(address,uint256)", _alice, 100), "");

        vm.expectRevert();

        _gateway.receiveWithdrawal(_alice);
    }

    function test_receiveWithdrawal() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_gateway)),
            abi.encode(100)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.WithdrawalReceived(_alice, 100);

        uint256 amount_ = _gateway.receiveWithdrawal(_alice);

        assertEq(amount_, 100);
    }

    /* ============ receiveWithdrawalIntoUnderlying ============ */

    function test_receiveWithdrawalIntoUnderlying_feeTokenWithdrawToFailed_reverts() external {
        vm.mockCall(_feeToken, abi.encodeWithSignature("balanceOf(address)", address(_gateway)), abi.encode(100));

        vm.mockCallRevert(_feeToken, abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 100), "");

        vm.expectRevert();

        _gateway.receiveWithdrawalIntoUnderlying(_alice);
    }

    function test_receiveWithdrawalIntoUnderlying() external {
        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("balanceOf(address)", address(_gateway)),
            abi.encode(100)
        );

        Utils.expectAndMockCall(
            _feeToken,
            abi.encodeWithSignature("withdrawTo(address,uint256)", _alice, 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.WithdrawalReceived(_alice, 100);

        uint256 amount_ = _gateway.receiveWithdrawalIntoUnderlying(_alice);

        assertEq(amount_, 100);
    }

    /* ============ updatePauseStatus ============ */

    function test_updatePauseStatus_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(2)));

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _gateway.updatePauseStatus();
    }

    function test_updatePauseStatus_noChange() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        vm.expectRevert(ISettlementChainGateway.NoChange.selector);

        _gateway.updatePauseStatus();

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _gateway.__setPauseStatus(true);

        vm.expectRevert(ISettlementChainGateway.NoChange.selector);

        _gateway.updatePauseStatus();
    }

    function test_updatePauseStatus() external {
        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.PauseStatusUpdated(true);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, bytes32(uint256(1)));

        _gateway.updatePauseStatus();

        assertTrue(_gateway.paused());

        vm.expectEmit(address(_gateway));
        emit ISettlementChainGateway.PauseStatusUpdated(false);

        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _PAUSED_KEY, 0);

        _gateway.updatePauseStatus();

        assertFalse(_gateway.paused());
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _gateway.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, 0);
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _gateway.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = makeAddr("migrator");

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        bytes memory revertData_ = abi.encodeWithSignature("Failed()");

        vm.mockCallRevert(migrator_, bytes(""), revertData_);

        vm.expectRevert(abi.encodeWithSelector(IMigratable.MigrationFailed.selector, migrator_, revertData_));

        _gateway.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, bytes32(uint256(uint160(1))));

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _gateway.migrate();
    }

    function test_migrate() external {
        address newParameterRegistry_ = makeAddr("newParameterRegistry");
        address newAppChainGateway_ = makeAddr("newAppChainGateway");
        address newFeeToken_ = makeAddr("newFeeToken");

        Utils.expectAndMockCall(newFeeToken_, abi.encodeWithSignature("underlying()"), abi.encode(_underlyingFeeToken));
        Utils.expectAndMockCall(newFeeToken_, abi.encodeWithSignature("decimals()"), abi.encode(6));

        address newImplementation_ = address(
            new SettlementChainGatewayHarness(newParameterRegistry_, newAppChainGateway_, newFeeToken_)
        );

        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_gateway));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_gateway));
        emit IERC1967.Upgraded(newImplementation_);

        _gateway.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_gateway)), newImplementation_);
        assertEq(_gateway.parameterRegistry(), newParameterRegistry_);
        assertEq(_gateway.appChainGateway(), newAppChainGateway_);
        assertEq(_gateway.feeToken(), newFeeToken_);
    }

    /* ============ calculateMaxDepositFee ============ */

    function test_calculateMaxDepositFee() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        uint256 maxFeePerGas_ = 1 gwei;
        uint256 gasLimit_ = 100_000;
        uint256 maxBaseFee_ = 2 gwei;
        uint256 submissionCost_ = 0.3 ether;

        uint256 expectedFees_ = submissionCost_ + (maxFeePerGas_ * gasLimit_);

        Utils.expectAndMockCall(
            inbox_,
            abi.encodeWithSignature(
                "calculateRetryableSubmissionFee(uint256,uint256)",
                _RECEIVE_DEPOSIT_DATA_LENGTH,
                maxBaseFee_
            ),
            abi.encode(submissionCost_)
        );

        uint256 fees_ = _gateway.calculateMaxDepositFee(1111, gasLimit_, maxFeePerGas_, maxBaseFee_);

        assertEq(fees_, expectedFees_);
    }

    /* ============ getInbox ============ */

    function test_getInbox_unsupportedChainId() external {
        vm.expectRevert(abi.encodeWithSelector(ISettlementChainGateway.UnsupportedChainId.selector, 1111));
        _gateway.getInbox(1111);
    }

    function test_getInbox() external {
        address inbox_ = makeAddr("inbox");

        _gateway.__setInbox(1111, inbox_);

        assertEq(_gateway.getInbox(1111), inbox_);
    }

    /* ============ appChainAlias ============ */

    function test_appChainAlias() external view {
        assertEq(_gateway.appChainAlias(), AddressAliasHelper.toAlias(address(_gateway)));
    }

    function test_convertToWei_largeValue_succeeds() external {
        // This value would have overflowed under (value * 1e18) / 1e6,
        // but should now succeed with value * 1e12.
        uint256 unsafeValue = (type(uint256).max / 1e18) + 1;

        uint256 expected = unsafeValue * 1e12; // exact 18->6 scaling (no rounding)

        uint256 got = _gateway.__convertToWei(unsafeValue);
        assertEq(got, expected);
    }
}
