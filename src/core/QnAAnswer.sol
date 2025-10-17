// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {QnAStorage} from "./QnAStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract QnAAnswer is QnAStorage {
    using SafeERC20 for IERC20;

    event AnswerPosted(
        uint256 indexed questionId,
        uint256 indexed answerId,
        address indexed answerer,
        string uri
    );
    event AnswerAccepted(
        uint256 indexed questionId,
        uint256 indexed answerId,
        address indexed asker,
        address winner
    );
    event BountyPaid(
        uint256 indexed questionId,
        address indexed to,
        uint256 amount,
        address token
    );

    function _postAnswer(uint256 questionId, string calldata uri) internal {
        Question storage q = questions[questionId];
        require(q.asker != address(0), "Q not found");
        require(q.status == QuestionStatus.Open, "Not open");

        uint256 newId = ++q.answersCount;
        answers[questionId][newId] = Answer({
            answerer: msg.sender,
            createdAt: uint40(block.timestamp),
            status: AnswerStatus.Posted,
            uri: uri
        });

        answersPosted[msg.sender] += 1;
        emit AnswerPosted(questionId, newId, msg.sender, uri);
    }

    function _acceptAnswer(uint256 questionId, uint256 answerId) internal {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        require(answerId > 0 && answerId <= q.answersCount, "Bad answerId");
        Answer storage a = answers[questionId][answerId];
        require(a.status == AnswerStatus.Posted, "Already handled");

        a.status = AnswerStatus.Accepted;
        q.status = QuestionStatus.Resolved;
        q.acceptedAnswerId = answerId;

        address winner = a.answerer;
        uint256 amount = q.bounty;
        address token = q.token;

        if (amount > 0) {
            q.bounty = 0;
            if (token == address(0)) {
                (bool ok, ) = winner.call{value: amount}("");
                require(ok, "Native payout failed");
            } else {
                IERC20(token).safeTransfer(winner, amount);
            }
            emit BountyPaid(questionId, winner, amount, token);
        }

        answersAccepted[winner] += 1;
        emit AnswerAccepted(questionId, answerId, q.asker, winner);
    }
}
