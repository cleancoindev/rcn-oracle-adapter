pragma solidity ^0.6.6;


interface PausedProvided {
    function isPaused() external view returns (bool);
}