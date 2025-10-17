// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract QnAStorage {
    enum QuestionStatus {
        Open,
        Resolved,
        Cancelled,
        Expired
    }
    enum AnswerStatus {
        Posted,
        Accepted,
        Rejected
    }

    struct Question {
        address asker;
        address token;
        uint256 bounty;
        uint40 createdAt;
        uint40 deadline;
        QuestionStatus status;
        uint256 acceptedAnswerId;
        bool refunded;
        string uri;
        uint256 answersCount;
    }

    struct Answer {
        address answerer;
        uint40 createdAt;
        AnswerStatus status;
        string uri;
    }

    mapping(uint256 => Question) public questions;
    mapping(uint256 => mapping(uint256 => Answer)) public answers;

    mapping(address => uint256) public answersAccepted;
    mapping(address => uint256) public questionsAsked;
    mapping(address => uint256) public answersPosted;

    uint256 public questionCounter;
    uint256 public constant MIN_DEADLINE_DELAY = 1 hours;
}
