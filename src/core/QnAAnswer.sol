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
        address indexed answerer,
        uint256 bounty,
        address token
    );

    function _postAnswer(
        uint256 questionId,
        string calldata uri
    ) internal returns (uint256 answerId) {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        require(block.timestamp < q.deadline, "Expired");

        answerId = ++q.answersCount;
        Answer storage a = answers[questionId][answerId];
        a.answerer = msg.sender;
        a.createdAt = uint40(block.timestamp);
        a.uri = uri;

        answersPosted[msg.sender] += 1;

        emit AnswerPosted(questionId, answerId, msg.sender, uri);
    }

    function _acceptAnswer(uint256 questionId, uint256 answerId) internal {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        require(answerId > 0 && answerId <= q.answersCount, "Invalid answer");
        require(q.acceptedAnswerId == 0, "Already accepted");

        Answer storage a = answers[questionId][answerId];
        require(a.answerer != address(0), "Answer not found");

        q.status = QuestionStatus.Resolved;
        q.acceptedAnswerId = answerId;

        uint256 bounty = q.bounty;
        q.bounty = 0;
        address token = q.token;

        if (bounty > 0) {
            if (token == address(0)) {
                (bool ok, ) = a.answerer.call{value: bounty}("");
                require(ok, "Native transfer failed");
            } else {
                IERC20(token).safeTransfer(a.answerer, bounty);
            }
        }

        emit AnswerAccepted(questionId, answerId, a.answerer, bounty, token);
    }
}