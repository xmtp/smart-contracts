// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, console } from "../../lib/forge-std/src/Test.sol";

import { IERC20 } from "../../lib/oz/contracts/token/ERC20/IERC20.sol";
import { IERC20Errors } from "../../lib/oz/contracts/interfaces/draft-IERC6093.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { IAppchainToken } from "../../src/settlement-chain/interfaces/IAppchainToken.sol";

import { Proxy } from "../../src/any-chain/Proxy.sol";

import { AppchainTokenHarness } from "../utils/Harnesses.sol";

import { MockParameterRegistry, MockErc20, MockMigrator, MockFailingMigrator } from "../utils/Mocks.sol";

import { Utils } from "../utils/Utils.sol";

contract AppchainTokenTests is Test {
    bytes32 internal constant _EIP712_DOMAIN_HASH =
        keccak256(
            abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        );

    bytes internal constant _MIGRATOR_KEY = "xmtp.appchainToken.migrator";

    AppchainTokenHarness internal _token;

    address internal _implementation;
    address internal _parameterRegistry;
    address internal _underlying;

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

        _parameterRegistry = address(new MockParameterRegistry());
        _underlying = address(new MockErc20());

        _implementation = address(new AppchainTokenHarness(_parameterRegistry, _underlying));

        _token = AppchainTokenHarness(address(new Proxy(_implementation)));

        _token.initialize();
    }

    /* ============ constructor ============ */

    function test_constructor_zeroParameterRegistry() external {
        vm.expectRevert(IAppchainToken.ZeroParameterRegistry.selector);
        new AppchainTokenHarness(address(0), address(0));
    }

    function test_constructor_zeroUnderlying() external {
        vm.expectRevert(IAppchainToken.ZeroUnderlying.selector);
        new AppchainTokenHarness(_parameterRegistry, address(0));
    }

    /* ============ initial state ============ */

    function test_initialState() external view {
        assertEq(Utils.getImplementationFromSlot(address(_token)), _implementation);
        assertEq(_token.implementation(), _implementation);
        assertEq(_token.parameterRegistry(), _parameterRegistry);
        assertEq(_token.underlying(), _underlying);
        assertEq(_token.migratorParameterKey(), _MIGRATOR_KEY);
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
        vm.expectRevert(IAppchainToken.ZeroAmount.selector);
        _token.deposit(0);
    }

    function test_deposit_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.deposit(100);
    }

    function test_deposit_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.deposit(100);
    }

    function test_deposit() external {
        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
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
        vm.expectRevert(IAppchainToken.ZeroAmount.selector);
        _token.depositWithPermit(0, 0, 0, 0, 0);
    }

    function test_depositWithPermit_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositWithPermit(100, 0, 0, 0, 0);
    }

    function test_depositWithPermit_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositWithPermit(100, 0, 0, 0, 0);
    }

    function test_depositWithPermit() external {
        vm.expectCall(
            _underlying,
            abi.encodeWithSelector(
                MockErc20.permit.selector,
                _alice,
                address(_token),
                100,
                0,
                0,
                bytes32(0),
                bytes32(0)
            )
        );

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
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
        vm.expectRevert(IAppchainToken.ZeroAmount.selector);
        _token.depositFor(_bob, 0);
    }

    function test_depositFor_zeroRecipient() external {
        vm.expectRevert(IAppchainToken.ZeroRecipient.selector);
        _token.depositFor(address(0), 100);
    }

    function test_depositFor_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositFor(_bob, 100);
    }

    function test_depositFor_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositFor(_bob, 100);
    }

    function test_depositFor() external {
        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
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
        vm.expectRevert(IAppchainToken.ZeroAmount.selector);
        _token.depositForWithPermit(_bob, 0, 0, 0, 0, 0);
    }

    function test_depositForWithPermit_zeroRecipient() external {
        vm.expectRevert(IAppchainToken.ZeroRecipient.selector);
        _token.depositForWithPermit(address(0), 100, 0, 0, 0, 0);
    }

    function test_depositForWithPermit_erc20TransferFromFailed_tokenReturnsFalse() external {
        vm.mockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            abi.encode(false)
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositForWithPermit(_bob, 100, 0, 0, 0, 0);
    }

    function test_depositForWithPermit_erc20TransferFromFailed_tokenReverts() external {
        vm.mockCallRevert(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
            ""
        );

        vm.expectRevert(IAppchainToken.TransferFromFailed.selector);

        vm.prank(_alice);
        _token.depositForWithPermit(_bob, 100, 0, 0, 0, 0);
    }

    function test_depositForWithPermit() external {
        vm.expectCall(
            _underlying,
            abi.encodeWithSelector(
                MockErc20.permit.selector,
                _alice,
                address(_token),
                100,
                0,
                0,
                bytes32(0),
                bytes32(0)
            )
        );

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transferFrom.selector, _alice, address(_token), 100),
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
        vm.expectRevert(IAppchainToken.ZeroAmount.selector);
        _token.withdraw(0);
    }

    function test_withdraw_insufficientBalance() external {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, _alice, 0, 100));

        vm.prank(_alice);
        _token.withdraw(100);
    }

    function test_withdraw_erc20TransferFromFailed_tokenReturnsFalse() external {
        _token.__mint(_alice, 100);

        vm.mockCall(_underlying, abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 100), abi.encode(false));

        vm.expectRevert(IAppchainToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdraw(100);
    }

    function test_withdraw_erc20TransferFromFailed_tokenReverts() external {
        _token.__mint(_alice, 100);

        vm.mockCallRevert(_underlying, abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 100), "");

        vm.expectRevert(IAppchainToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdraw(100);
    }

    function test_withdraw() external {
        _token.__mint(_alice, 100);

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 100),
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
        vm.expectRevert(IAppchainToken.ZeroAmount.selector);
        _token.withdrawTo(_bob, 0);
    }

    function test_withdrawTo_zeroRecipient() external {
        vm.expectRevert(IAppchainToken.ZeroRecipient.selector);
        _token.withdrawTo(address(0), 100);
    }

    function test_withdrawTo_insufficientBalance() external {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, _alice, 0, 100));

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);
    }

    function test_withdrawTo_erc20TransferFromFailed_tokenReturnsFalse() external {
        _token.__mint(_alice, 100);

        vm.mockCall(_underlying, abi.encodeWithSelector(MockErc20.transfer.selector, _bob, 100), abi.encode(false));

        vm.expectRevert(IAppchainToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);
    }

    function test_withdrawTo_erc20TransferFromFailed_tokenReverts() external {
        _token.__mint(_alice, 100);

        vm.mockCallRevert(_underlying, abi.encodeWithSelector(MockErc20.transfer.selector, _bob, 100), "");

        vm.expectRevert(IAppchainToken.TransferFailed.selector);

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);
    }

    function test_withdrawTo() external {
        _token.__mint(_alice, 100);

        Utils.expectAndMockCall(
            _underlying,
            abi.encodeWithSelector(MockErc20.transfer.selector, _bob, 100),
            abi.encode(true)
        );

        vm.expectEmit(address(_token));
        emit IERC20.Transfer(_alice, address(0), 100);

        vm.prank(_alice);
        _token.withdrawTo(_bob, 100);

        assertEq(_token.balanceOf(_alice), 0);
    }

    /* ============ migrate ============ */

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _token.migrate();
    }

    function test_migrate_migrationFailed() external {
        address migrator_ = address(new MockFailingMigrator());

        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IMigratable.MigrationFailed.selector,
                migrator_,
                abi.encodeWithSelector(MockFailingMigrator.Failed.selector)
            )
        );

        _token.migrate();
    }

    function test_migrate_emptyCode() external {
        Utils.expectAndMockParameterRegistryCall(
            _parameterRegistry,
            _MIGRATOR_KEY,
            bytes32(uint256(uint160(address(1))))
        );

        vm.expectRevert(abi.encodeWithSelector(IMigratable.EmptyCode.selector, address(1)));

        _token.migrate();
    }

    function test_migrate() external {
        address newImplementation_ = address(new AppchainTokenHarness(_parameterRegistry, address(1)));
        address migrator_ = address(new MockMigrator(newImplementation_));

        Utils.expectAndMockParameterRegistryCall(
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
            0x7f5a3fbeb3c4629869017f0a2c85ede054b6f5edbaf4a91ce9bb65c4c7c2cfbc
        );

        assertEq(
            _token.getPermitDigest(address(10), address(20), 30, 40, 50),
            0x1d1bab673a32cf564a98cb654caff01b884e82b4bf42a72f6dc57934bc3d23d5
        );
    }

    /* ============ DOMAIN_SEPARATOR ============ */

    function test_DOMAIN_SEPARATOR() external view {
        assertEq(
            _token.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    _EIP712_DOMAIN_HASH,
                    keccak256(bytes("XMTP Appchain Token")),
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
        assertEq(name_, "XMTP Appchain Token");
        assertEq(version_, "1");
        assertEq(chainId_, block.chainid);
        assertEq(verifyingContract_, address(_token));
        assertEq(salt_, bytes32(0));
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
