// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {QnAWithBounty} from "../src/core/QnAWithBounty.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MockERC20 is IERC20 {
    string public constant name = "Mock";
    string public constant symbol = "MCK";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
    }
    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "bal");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }
    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }
    function transferFrom(
        address f,
        address t,
        uint256 a
    ) external returns (bool) {
        require(balanceOf[f] >= a, "bal");
        uint256 al = allowance[f][msg.sender];
        require(al >= a, "allow");
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract QnAWithBountyTest is Test {
    QnAWithBounty qna;
    MockERC20 token;
    address asker = address(0xA11CE);
    address ans1 = address(0xB0B);
    address ans2 = address(0xCAFE);

    function setUp() public {
        qna = new QnAWithBounty(address(this)); // owner = this
        token = new MockERC20();
        // fund test addresses
        vm.deal(asker, 100 ether);
        token.mint(asker, 1_000e18);
    }

    function test_NativeFlow_Accept() public {
        vm.prank(asker);
        uint256 qid = qna.askQuestion{value: 1 ether}(
            address(0),
            1 ether,
            uint40(block.timestamp + 2 hours),
            "ipfs://Q"
        );
        // answers
        vm.prank(ans1);
        qna.answerQuestion(qid, "ipfs://A1");
        vm.prank(ans2);
        qna.answerQuestion(qid, "ipfs://A2");

        uint256 balBefore = ans2.balance;
        vm.prank(asker);
        qna.acceptAnswer(qid, 2);
        assertEq(ans2.balance, balBefore + 1 ether);
    }

    function test_ERC20Flow_RefundAfterDeadline() public {
        // approve & ask
        vm.startPrank(asker);
        token.approve(address(qna), type(uint256).max);
        uint256 qid = qna.askQuestion(
            address(token),
            100e18,
            uint40(block.timestamp + 2 hours),
            "ipfs://Q"
        );
        vm.stopPrank();

        // no answers; fast-forward
        vm.warp(block.timestamp + 3 hours);
        uint256 balBefore = token.balanceOf(asker);
        vm.prank(asker);
        qna.refundExpired(qid);
        assertEq(token.balanceOf(asker), balBefore + 100e18);
    }

    function test_AddBountyAndAccept() public {
        vm.startPrank(asker);
        uint256 qid = qna.askQuestion{value: 0}(
            address(0),
            0,
            uint40(block.timestamp + 2 hours),
            "Q"
        );
        vm.stopPrank();

        vm.prank(asker);
        qna.addBounty{value: 0.5 ether}(qid, 0.5 ether);

        vm.prank(ans1);
        qna.answerQuestion(qid, "A1");

        uint256 balBefore = ans1.balance;
        vm.prank(asker);
        qna.acceptAnswer(qid, 1);
        assertEq(ans1.balance, balBefore + 0.5 ether);
    }

    function test_CancelBeforeAnyAnswer() public {
        vm.prank(asker);
        uint256 qid = qna.askQuestion{value: 0.2 ether}(
            address(0),
            0.2 ether,
            uint40(block.timestamp + 2 hours),
            "Q"
        );

        uint256 balBefore = asker.balance;
        vm.prank(asker);
        qna.cancelQuestion(qid);
        assertEq(asker.balance, balBefore + 0.2 ether);
    }

    function test_Reverts_WrongAccept() public {
        vm.prank(asker);
        uint256 qid = qna.askQuestion{value: 1 ether}(
            address(0),
            1 ether,
            uint40(block.timestamp + 2 hours),
            "Q"
        );
        // no answers yet
        vm.prank(asker);
        vm.expectRevert(); // bad answerId
        qna.acceptAnswer(qid, 1);
    }
}
