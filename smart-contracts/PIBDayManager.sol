pragma solidity 0.5.0;

import "./safeMath.sol";

contract PIBDayManager {
    using SafeMath for uint;

    uint public day;
    uint public initialDay;

    constructor() public {
        initialDay = now;
    }

    function getDay() public returns (uint) {
        while (isNewDay()) {
            day++;
        }
        return day;
    }

    function isNewDay() public view returns (bool) {
        if (now > initialDay.add(day.mul(1 days))) {
            return true;
        } else {
            return false;
        }
    }
}