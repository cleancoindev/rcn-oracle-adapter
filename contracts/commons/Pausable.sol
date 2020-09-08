pragma solidity ^0.6.6;

import "./Ownable.sol";


contract Pausable is Ownable {
    mapping(address => bool) public canPause;
    bool public paused;

    event Paused();
    event Started();
    event CanPause(address _pauser, bool _enabled);

    function setPauser(address _pauser, bool _enabled) external onlyOwner {
        canPause[_pauser] = _enabled;
        emit CanPause(_pauser, _enabled);
    }

    function pause() external {
        require(!paused, "already paused");

        require(
            msg.sender == _owner ||
            canPause[msg.sender],
            "not authorized to pause"
        );

        paused = true;
        emit Paused();
    }

    function start() external onlyOwner {
        require(paused, "not paused");
        paused = false;
        emit Started();
    }
}
