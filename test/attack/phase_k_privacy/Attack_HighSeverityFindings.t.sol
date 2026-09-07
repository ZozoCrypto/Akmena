// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";

contract AttackableERC20 is IERC20 {
    string public constant name = "Attack AKM";
    string public constant symbol = "aAKM";
    uint8 public constant decimals = 18;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];

        require(allowed >= amount, "allowance");

        _allowances[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(_balances[from] >= amount, "balance");

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }
}

contract Attack_HighSeverityFindingsTest is Test {
    PrivacyEngine internal privacy;

    AttackableERC20 internal token;
    EscrowEngine internal escrow;

    address internal victim = address(0x1111);
    address internal attacker = address(0x2222);
    address internal intendedRecipient = address(0x3333);
    address internal attackerRecipient = address(0x4444);
    address internal seller = address(0x5555);

    function setUp() public {
        privacy = new PrivacyEngine();

        token = new AttackableERC20();
        escrow = new EscrowEngine(address(token));
    }

    /*
     * HIGH FINDING #1
     *
     * The commitment binds the legitimate recipient.
     *
     * This regression verifies that a caller cannot substitute an
     * attacker-controlled recipient during settlement.
     */
    function test_Attack_PrivacySettlementRecipientRedirection() public {
        uint256 amount = 5 ether;

        bytes32 secret = keccak256("victim-secret");
        bytes32 nullifierHash = keccak256("victim-nullifier");

        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    nullifierHash,
                    secret,
                    amount,
                    intendedRecipient
                )
            );

        vm.deal(victim, amount);

        vm.prank(victim);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        uint256 attackerBefore = attackerRecipient.balance;
        uint256 privacyBefore = address(privacy).balance;

        vm.prank(attacker);
        vm.expectRevert(PrivacyEngine.InvalidCommitment.selector);

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(attackerRecipient)
        );

        assertEq(
            attackerRecipient.balance,
            attackerBefore,
            "CRITICAL: attacker-controlled recipient received funds"
        );

        assertEq(
            address(privacy).balance,
            privacyBefore,
            "CRITICAL: privacy funds moved during rejected substitution"
        );

        assertFalse(
            privacy.nullifierHashes(nullifierHash),
            "Rejected substitution consumed the nullifier"
        );

        assertTrue(
            privacy.commitments(commitment),
            "Rejected substitution consumed the commitment"
        );
    }

    /*
     * HIGH FINDING #2
     *
     * The attacker tries to use a victim's approved EscrowEngine allowance
     * to create an escrow without being the victim.
     *
     * Current production code is expected to reject this.
     */
    function test_Attack_EscrowCannotPullVictimFundsViaArbitraryBuyer()
        public
    {
        uint256 amount = 100 ether;

        token.mint(victim, amount);

        vm.prank(victim);
        token.approve(address(escrow), amount);

        uint256 victimBefore = token.balanceOf(victim);
        uint256 escrowBefore = token.balanceOf(address(escrow));

        vm.prank(attacker);

        vm.expectRevert(
            IEscrowEngine.UnauthorizedAccess.selector
        );

        escrow.createEscrow(
            victim,
            seller,
            amount
        );

        assertEq(
            token.balanceOf(victim),
            victimBefore,
            "CRITICAL: attacker pulled victim tokens"
        );

        assertEq(
            token.balanceOf(address(escrow)),
            escrowBefore,
            "CRITICAL: escrow received unauthorized tokens"
        );
    }

    /*
     * Control test:
     * The actual buyer must still be able to create and fund an escrow.
     */
    function test_Control_BuyerCanCreateEscrow() public {
        uint256 amount = 25 ether;

        token.mint(victim, amount);

        vm.prank(victim);
        token.approve(address(escrow), amount);

        vm.prank(victim);

        uint256 escrowId = escrow.createEscrow(
            victim,
            seller,
            amount
        );

        assertEq(escrowId, 1);
        assertEq(token.balanceOf(address(escrow)), amount);

        LibStorage.EscrowData memory data =
            escrow.getEscrow(escrowId);

        assertEq(data.buyer, victim);
        assertEq(data.seller, seller);
        assertEq(data.amount, amount);
        assertEq(data.asset, address(token));
        assertEq(data.status, 1);
    }
}
