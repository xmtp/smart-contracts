// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

interface IERC20InboxLike {
    function depositERC20(uint256 amount_) external returns (uint256 messageNumber_);
}

interface IERC20Like {
    function approve(address spender, uint256 amount_) external returns (bool success_);

    function balanceOf(address account_) external view returns (uint256 balance_);
}

contract MockArbSys {
    function withdrawEth(address recipient_) external payable {}
}

contract FeeTokenBridging is Script {
    address internal constant _APPCHAIN_NATIVE_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address internal constant _SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN = 0xd06d8E471F0EeB1bb516303EdE399d004Acb1615;
    address internal constant _SETTLEMENT_CHAIN_OUTBOX_FROM_APPCHAIN = 0xE401acFc336524955152b7260df47c3E23e4A54A;
    address internal constant _ARB_SYS = 0x0000000000000000000000000000000000000064; // address(100)
    address internal constant _NODE_INTERFACE = 0x00000000000000000000000000000000000000C8; // address(200)

    error PrivateKeyNotSet();
    error WithdrawFailed();

    uint256 internal _privateKey;
    address internal _account;

    function setUp() external virtual {
        _privateKey = vm.envUint("PRIVATE_KEY");

        require(_privateKey != 0, PrivateKeyNotSet());

        _account = vm.addr(_privateKey);
    }

    function logPrivateKey() external view {
        console.logBytes32(bytes32(_privateKey));
    }

    function logAccount() external view {
        console.log("account", _account);
    }

    function logSettlementChainTokenBalance() external {
        vm.createSelectFork(vm.envString("BASE_TESTNET_RPC_URL"));
        console.log("settlement chain token balance", IERC20Like(_APPCHAIN_NATIVE_TOKEN).balanceOf(_account));
    }

    function logAppChainBalance() external {
        vm.createSelectFork(vm.envString("XMTP_TESTNET_RPC_URL"));
        console.log("app chain balance", _account.balance);
    }

    function deposit(uint256 amount_) external {
        vm.createSelectFork(vm.envString("BASE_TESTNET_RPC_URL"));

        vm.startBroadcast(_privateKey);
        IERC20Like(_APPCHAIN_NATIVE_TOKEN).approve(_SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN, amount_);
        IERC20InboxLike(_SETTLEMENT_CHAIN_INBOX_TO_APPCHAIN).depositERC20(amount_);
        vm.stopBroadcast();
    }

    function withdraw(uint256 amount_) external {
        vm.createSelectFork(vm.envString("XMTP_TESTNET_RPC_URL"));

        vm.etch(_ARB_SYS, type(MockArbSys).runtimeCode);

        vm.startBroadcast(_privateKey);
        (bool success_, ) = _ARB_SYS.call{ value: amount_ }(abi.encodeWithSignature("withdrawEth(address)", _account));
        if (!success_) revert WithdrawFailed();
        vm.stopBroadcast();
    }
}
