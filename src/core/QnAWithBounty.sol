// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {QnAAsk} from "./QnAAsk.sol";
import {QnAAnswer} from "./QnAAnswer.sol";
import {QnAAdmin} from "./QnAAdmin.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract QnAWithBounty is QnAAsk, QnAAnswer, QnAAdmin, ReentrancyGuard {
    constructor(address _owner) QnAAdmin(_owner) {}

    function askQuestion(
        address token,
        uint256 bounty,
        uint40 deadline,
        string calldata uri
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        return _askQuestion(token, bounty, deadline, uri);
    }

    function answerQuestion(
        uint256 questionId,
        string calldata uri
    ) external whenNotPaused {
        _postAnswer(questionId, uri);
    }

    function acceptAnswer(
        uint256 questionId,
        uint256 answerId
    ) external onlyAsker(questionId) nonReentrant {
        _acceptAnswer(questionId, answerId);
    }

    function addBounty(
        uint256 questionId,
        uint256 amount
    ) external payable nonReentrant {
        _addBounty(questionId, amount);
    }

    // 🔹 Added: externals to match your tests
    function refundExpired(
        uint256 questionId
    ) external onlyAsker(questionId) nonReentrant {
        _refundExpired(questionId);
    }

    function cancelQuestion(
        uint256 questionId
    ) external onlyAsker(questionId) nonReentrant {
        _cancelQuestion(questionId);
    }

    // views
    function getQuestion(uint256 id) external view returns (Question memory) {
        return questions[id];
    }
    function getAnswer(
        uint256 qid,
        uint256 aid
    ) external view returns (Answer memory) {
        return answers[qid][aid];
    }
}
