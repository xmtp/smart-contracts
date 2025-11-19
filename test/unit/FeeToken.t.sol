// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC20 } from "../../lib/oz/contracts/token/ERC20/IERC20.sol";
import { IERC20Errors } from "../../lib/oz/contracts/interfaces/draft-IERC6093.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IFeeToken } from "../../src/settlement-chain/interfaces/IFeeToken.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../src/libraries/interfaces/IRegistryParametersErrors.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { FeeTokenHarness } from "../utils/Harnesses.sol";
import { MockMigrator } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract FeeTokenTests is Test {
    bytes32 internal constant _EIP712_DOMAIN_HASH =
        keccak256(
            abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        );

    string internal constant _MIGRATOR_KEY = "xmtp.feeToken.migrator";

    FeeTokenHarness internal _token;

    address internal _implementation;

    address internal _parameterRegistry = makeAddr("parameterRegistry");
    address internal _underlying = makeAddr("underlying");

    address internal _alice;
    uint256 internal _alicePk;
    address internal _bob;
    uint256 internal _bobPk;
    address internal _charlie;
    uint256 internal _charliePk;
    address internal _dave;
    uint256 internal _davePk;

    function setUp() external {
        (_alice, _alicePk) = makeAddrAndKey("alice");
        (_bob, _bobPk) = makeAddrAndKey("bob");
        (_charlie, _charliePk) = makeAddrAndKey("charlie");
        (_dave, _davePk) = makeAddrAndKey("dave");

        _implementation = address(new FeeTokenHarness(_parameterRegistry, _underlying));
        _token = FeeTokenHarness(address(new Proxy(_implementation)));

        _token.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IFeeToken.ZeroParameterRegistry.selector);
        new FeeTokenHarness(address(0), address(0));
    }

    function test_constructor_zeroUnderlying() external {
        vm.expectRevert(IFeeToken.ZeroUnderlying.selector);
        new FeeTokenHarness(_parameterRegistry, address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_token)), _implementation);
        assertEq(_token.implementation(), _implementation);
        assertEq(_token.parameterRegistry(), _parameterRegistry);
        assertEq(_token.underlying(), _underlying);
        assertEq(_token.migratorParameterKey(), _MIGRATOR_KEY);
        assertEq(_token.name(), "XMTP USD Fee Token");
        assertEq(_token.symbol(), "xUSD");
        assertEq(_token.decimals(), 6);
    }

    /* ============ version ============ */

    function test_version() external view {
        assertEq(_token.version(), "1.0.0");
    }

    /* ============ contractName ============ */

    function test_contractName() external view {
        assertEq(_token.contractName(), "FeeToken");
    }

    /* ============ initializer ============ */

    function test_initialize_reinitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _token.initialize();
    }

    /* ============ permit ============ */

    function test_permit() external {
        uint256 deadline_ = vm.getBlockTimestamp();

        (uint8 v_, bytes32 r_, bytes32 s_) = _getPermitSignature(_bob, _charlie, 100, 0, deadline_, _bobPk);

        vm.expectEmit(address(_token));
        emit IERC20.Approval(_bob, _charlie, 100);

        vm.prank(_alice);
        _token.permit(_bob, _charlie, 100, deadline_, v_, r_, s_);

        assertEq(_token.allowance(_bob, _charlie), 100);
        assertEq(_token.nonces(_bob), 1);
    }

    /* ============ deposit ============ */

    function test_deposit_zeroAmount() external {
        vm.expectRevert(IFeeToken.ZeroAmount.selector);
        _token.deposit(0);
    }

    function test_deposit_underlyingTokenTransferFromFailed_returnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.deposit(100);
    }

    function test_deposit_underlyingTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.deposit(100);
    }

    function test_deposit() external {
        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_token));
        emit IERC20.Transfer(address(0), _alice, 100);

        vm.prank(_alice);
        _token.deposit(100);

        assertEq(_token.balanceOf(_alice), 100);
    }

    /* ============ depositWithPermit ============ */

    function test_depositWithPermit_zeroAmount() external {
        vm.expectRevert(IFeeToken.ZeroAmount.selector);
        _token.depositWithPermit(0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_underlyingTokenTransferFromFailed_returnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositWithPermit(100, 0, 0, 0, 0);
    }

    function test_depositWithPermit_underlyingTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositWithPermit(100, 0, 0, 0, 0);
    }

    function test_depositWithPermit() external {
        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_token),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_token));
        emit IERC20.Transfer(address(0), _alice, 100);

        vm.prank(_alice);
        _token.depositWithPermit(100, 0, 0, 0, 0);

        assertEq(_token.balanceOf(_alice), 100);
    }

    /* ============ depositFor ============ */

    function test_depositFor_zeroAmount() external {
        vm.expectRevert(IFeeToken.ZeroAmount.selector);
        _token.depositFor(_bob, 0);
    }

    function test_depositFor_zeroRecipient() external {
        vm.expectRevert(IFeeToken.ZeroRecipient.selector);
        _token.depositFor(address(0), 100);
    }

    function test_depositFor_underlyingTokenTransferFromFailed_returnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositFor(_bob, 100);
    }

    function test_depositFor_underlyingTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositFor(_bob, 100);
    }

    function test_depositFor() external {
        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_token));
        emit IERC20.Transfer(address(0), _bob, 100);

        vm.prank(_alice);
        _token.depositFor(_bob, 100);

        assertEq(_token.balanceOf(_bob), 100);
    }

    /* ============ depositForWithPermit ============ */

    function test_depositForWithPermit_zeroAmount() external {
        vm.expectRevert(IFeeToken.ZeroAmount.selector);
        _token.depositForWithPermit(_bob, 0, 0, 0, 0, 0);
    }

    function test_depositForWithPermit_zeroRecipient() external {
        vm.expectRevert(IFeeToken.ZeroRecipient.selector);
        _token.depositForWithPermit(address(0), 100, 0, 0, 0, 0);
    }

    function test_depositForWithPermit_underlyingTokenTransferFromFailed_returnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositForWithPermit(_bob, 100, 0, 0, 0, 0);
    }

    function test_depositForWithPermit_underlyingTokenTransferFromFailed_reverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IFeeToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositForWithPermit(_bob, 100, 0, 0, 0, 0);
    }

    function test_depositForWithPermit() external {
        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                _alice,
                address(_token),
                100,
                0,
                0,
                0,
                0
            ),
            ""
        );

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _alice, address(_token), 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_token));
        emit IERC20.Transfer(address(0), _bob, 100);

        vm.prank(_alice);
        _token.depositForWithPermit(_bob, 100, 0, 0, 0, 0);

        assertEq(_token.balanceOf(_bob), 100);
    }

    /* ============ withdraw ============ */

    function test_withdraw_zeroAmount() external {
        vm.expectRevert(IFeeToken.ZeroAmount.selector);
        _token.withdraw(0);
    }

    function test_withdraw_insufficientBalance() external {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, _alice, 0, 100));

        vm.prank(_alice);
        _token.withdraw(100);
    }

    function test_withdraw_underlyingTokenTransferFromFailed_returnsFalse() external {
        _token.__mint(_alice, 100);

        vm.mockCall(_underlying, abi.encodeWithSignature("transfer(address,uint256)", _alice, 100), abi.encode(false));

        vm.expectRevert(IFeeToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdraw(100);
    }

    function test_withdraw_underlyingTokenTransferFromFailed_reverts() external {
        _token.__mint(_alice, 100);

        vm.mockCallRevert(_underlying, abi.encodeWithSignature("transfer(address,uint256)", _alice, 100), "");

        vm.expectRevert(IFeeToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdraw(100);
    }

    function test_withdraw() external {
        _token.__mint(_alice, 100);

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature("transfer(address,uint256)", _alice, 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_token));
        emit IERC20.Transfer(_alice, address(0), 100);

        vm.prank(_alice);
        _token.withdraw(100);

        assertEq(_token.balanceOf(_alice), 0);
    }

    /* ============ withdrawTo ============ */

    function test_withdrawTo_zeroAmount() external {
        vm.expectRevert(IFeeToken.ZeroAmount.selector);
        _token.withdrawTo(_bob, 0);
    }

    function test_withdrawTo_zeroRecipient() external {
        vm.expectRevert(IFeeToken.ZeroRecipient.selector);
        _token.withdrawTo(address(0), 100);
    }

    function test_withdrawTo_insufficientBalance() external {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, _alice, 0, 100));

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);
    }

    function test_withdrawTo_underlyingTokenTransferFromFailed_returnsFalse() external {
        _token.__mint(_alice, 100);

        vm.mockCall(_underlying, abi.encodeWithSignature("transfer(address,uint256)", _bob, 100), abi.encode(false));

        vm.expectRevert(IFeeToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);
    }

    function test_withdrawTo_underlyingTokenTransferFromFailed_reverts() external {
        _token.__mint(_alice, 100);

        vm.mockCallRevert(_underlying, abi.encodeWithSignature("transfer(address,uint256)", _bob, 100), "");

        vm.expectRevert(IFeeToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);
    }

    function test_withdrawTo() external {
        _token.__mint(_alice, 100);

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSignature("transfer(address,uint256)", _bob, 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_token));
        emit IERC20.Transfer(_alice, address(0), 100);

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);

        assertEq(_token.balanceOf(_alice), 0);
    }

    /* ============ migrate ============ */

    function test_migrate_parameterOutOfTypeBounds() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(type(uint160).max) + 1)
        );

        vm.expectRevert(IRegistryParametersErrors.ParameterOutOfTypeBounds.selector);

        _token.migrate();
    }

    function test_migrate_zeroMigrator() external {
        Utils.expectAndMockParameterRegistryGet(_parameterRegistry, _MIGRATOR_KEY, 0);
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _token.migrate();
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

        _token.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _token.migrate();
    }

    function test_migrate() external {
        address newImplementation_ = address(new FeeTokenHarness(_parameterRegistry, address(1)));
        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryGet(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectEmit(address(_token));
        emit IMigratable.Migrated(migrator_);

        vm.expectEmit(address(_token));
        emit IERC1967.Upgraded(newImplementation_);

        _token.migrate();

        assertEq(Utils.getImplementationFromSlot(address(_token)), newImplementation_);
        assertEq(_token.parameterRegistry(), _parameterRegistry);
        assertEq(_token.underlying(), address(1));
    }

    /* ============ getPermitDigest ============ */

    function test_getPermitDigest() external view {
        assertEq(
            _token.getPermitDigest(address(1), address(2), 3, 4, 5),
            0x60be5dd30cb9f4c0048cae1064b95b8204b1d722dda6907df648860af00c1d2e
        );

        assertEq(
            _token.getPermitDigest(address(10), address(20), 30, 40, 50),
            0x3b25af714b2dd39785f124b7ce931a634595f6147f951af018aba03dace1c684
        );
    }

    /* ============ DOMAIN_SEPARATOR ============ */

    function test_DOMAIN_SEPARATOR() external view {
        assertEq(
            _token.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    _EIP712_DOMAIN_HASH,
                    keccak256(bytes("XMTP USD Fee Token")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(_token)
                )
            )
        );
    }

    /* ============ PERMIT_TYPEHASH ============ */

    function test_PERMIT_TYPEHASH() external view {
        assertEq(
            _token.PERMIT_TYPEHASH(),
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
        );
    }

    /* ============ eip712Domain ============ */

    function test_eip712Domain() external view {
        (
            bytes1 fields_,
            string memory name_,
            string memory version_,
            uint256 chainId_,
            address verifyingContract_,
            bytes32 salt_,
            uint256[] memory extensions_
        ) = _token.eip712Domain();

        assertEq(fields_, hex"0f");
        assertEq(name_, "XMTP USD Fee Token");
        assertEq(version_, "1");
        assertEq(chainId_, block.chainid);
        assertEq(verifyingContract_, address(_token));
        assertEq(salt_, 0);
        assertEq(extensions_.length, 0);
    }

    /* ============ decimals ============ */

    function test_decimals() external view {
        assertEq(_token.decimals(), 6);
    }

    /* ============ __placeholder ============ */

    function test__placeholder() external {
        _token.__setPlaceholder(100);
        assertEq(_token.__getPlaceholder(), 100);
    }

    /* ============ helper functions ============ */

    function _getPermitSignature(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 nonce_,
        uint256 deadline_,
        uint256 privateKey_
    ) internal view returns (uint8 v_, bytes32 r_, bytes32 s_) {
        return _getSignature(_token.getPermitDigest(owner_, spender_, value_, nonce_, deadline_), privateKey_);
    }

    function _getSignature(
        bytes32 digest_,
        uint256 privateKey_
    ) internal pure returns (uint8 v_, bytes32 r_, bytes32 s_) {
        (v_, r_, s_) = vm.sign(privateKey_, digest_);
    }
}
