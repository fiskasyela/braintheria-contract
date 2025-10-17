// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IQnAWithBounty {
    // --- Struct copies for ABI usage ---
    struct Question {
        address asker;
        address token;
        uint256 bounty;
        uint40 createdAt;
        uint40 deadline;
        uint8 status;
        uint256 acceptedAnswerId;
        bool refunded;
        string uri;
        uint256 answersCount;
    }

    struct Answer {
        address answerer;
        uint40 createdAt;
        uint8 status;
        string uri;
    }

    // --- Core functions ---
    function askQuestion(
        address token,
        uint256 bounty,
        uint40 deadline,
        string calldata uri
    ) external payable returns (uint256);

    function answerQuestion(uint256 questionId, string calldata uri) external;

    function acceptAnswer(uint256 questionId, uint256 answerId) external;

    function addBounty(uint256 questionId, uint256 amount) external payable;

    function refundExpired(uint256 questionId) external;

    function cancelQuestion(uint256 questionId) external;

    // --- Views ---
    function getQuestion(uint256 id) external view returns (Question memory);
    function getAnswer(
        uint256 qid,
        uint256 aid
    ) external view returns (Answer memory);
}
