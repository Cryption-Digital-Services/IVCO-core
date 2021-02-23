// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
    
    function decimals() external returns(uint8);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface INonStandardERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transfer` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    function transfer(address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transferFrom` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external;

    function approve(address spender, uint256 amount)
        external
        returns (bool success);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
}

// helper methods for interacting with ERC20 tokens that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract Crowdsale is ReentrancyGuard  {
    using SafeMath for uint256;
    
    address public owner;
    
    //@notice the amount of token investor will recieve against 1 stableCoin
    uint256 public rate;    
    
    ///@notice TokenAddress available for purchase in this Crowdsale
    IERC20 public token;    
    
    /// @notice decimal of token that is available for purchase in this Crowdsale
    uint256 public tokenDecimal;
    
    uint256 public tokenRemainingForSale;
    
    /// @notice of LaunchpadFactory Contract
    address public LaunchpadFactory;    
    
    IERC20 private usdc = IERC20(0xC1e7958EA57c742fe8f3278388a94B53998DDBe5);   //0xb7a4F3E9097C08dA09517b5aB877F7a917224ede mainnet addresses
    IERC20 private dai = IERC20(0x34737f90FD62BC9B897760Cd16F3dFa4418096E1);    //0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa
    IERC20 private usdt = IERC20(0x9093F303C897717edaD0445C26BD0B33Fe45fD11);   //0x07de306FF27a2B630B1141956844eB1552B956B5 

    /// @notice start of vesting period as a timestamp
    uint256 public vestingStart;
    
     /// @notice start of crowdsale as a timestamp
    uint256 public crowdsaleStartTime;
    
     /// @notice end of crowdsale as a timestamp
    uint256 public crowdsaleEndTime;

    /// @notice end of vesting period as a timestamp
    uint256 public vestingEnd;
    
    /// @notice Number of Tokens Allocated for crowdsale
    uint256 public crowdsaleTokenAllocated;

    /// @notice cliff duration in seconds
    uint256 public cliffDuration;

    /// @notice amount vested for a investor. 
    mapping(address => uint256) public vestedAmount;

    /// @notice cumulative total of tokens drawn down (and transferred from the deposit account) per investor
    mapping(address => uint256) public totalDrawn;

    /// @notice last drawn down time (seconds) per investor
    mapping(address => uint256) public lastDrawnAt;
    
    /**
       * Event for Tokens purchase logging
       * @param investor who invested & got the tokens
       * @param investedAmount of stableCoin paid for purchase
       * @param tokenPurchased amount
       * @param stableCoin address used to invest
       * @param tokenRemaining amount of token still remaining for sale in crowdsale
    */
    event TokenPurchase(
        address indexed investor,
        uint256 investedAmount,
        uint256 indexed tokenPurchased,
        IERC20 indexed stableCoin,
        uint256 tokenRemaining
    );

    /// @notice event emitted when a successful drawn down of vesting tokens is made
    event DrawDown(address indexed _investor, uint256 _amount,uint256 indexed drawnTime);
    
    /// @notice event emitted when crowdsale is ended manually
    event CrowdsaleEndedManually(uint256 indexed crowdsaleEndedManuallyAt);
    
     /// @notice event emitted when the crowdsale raised funds are withdrawn by the owner 
    event FundsWithdrawn(address indexed beneficiary,IERC20 indexed _token,uint256 amount);
    
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    
    constructor(address _owner,address _launchpad) public {
        LaunchpadFactory = _launchpad;
        owner = _owner;
    }
    
    /**
     * @notice initialize the Crowdsale contract. This is called only once upon Crowdsale creation and the LaunchpadFactory ensures the Crowdsale has the correct paramaters
     */
    function init (IERC20 _tokenAddress,uint256 _amount, uint256 _rate,uint256 _crowdsaleStartTime,uint256 _crowdsaleEndTime, uint256 _vestingStartTime, uint256 _vestingEndTime,uint256 _cliffDurationInSecs) public {
        require(msg.sender == address(LaunchpadFactory), 'FORBIDDEN');
        TransferHelper.safeTransferFrom(address(_tokenAddress), msg.sender, address(this), _amount);
        token = _tokenAddress;
        rate = _rate;
        crowdsaleStartTime = _crowdsaleStartTime;
        crowdsaleEndTime = _crowdsaleEndTime;
        vestingStart = _vestingStartTime;
        vestingEnd = _vestingEndTime;
        crowdsaleTokenAllocated = _amount;
        tokenRemainingForSale = _amount;
        cliffDuration = _cliffDurationInSecs;
        tokenDecimal = token.decimals();
    }
    
    modifier isCrowdsaleOver(){
        require(_getNow() >= crowdsaleEndTime && crowdsaleEndTime != 0,"Crowdsale Not Ended Yet");
        _;
    }
    
    function buyTokenWithStableCoin(IERC20 _stableCoin, uint256 amount) external {   
        require(_getNow() >= crowdsaleStartTime,"Crowdsale isnt started yet");
        require(_stableCoin == usdt || _stableCoin == usdc || _stableCoin == dai,'Unsupported StableCoin');
        if(crowdsaleEndTime != 0){
            require(_getNow() < crowdsaleEndTime, "Crowdsale Ended");
        }
        
        uint256 tokenPurchased = amount.mul(rate);
        
        if (_stableCoin != dai) {
            tokenPurchased.mul(1e12);
        }
        
        if(tokenDecimal != 18){ 
            tokenPurchased = tokenDecimal > 18 ? tokenPurchased.mul(10**(tokenDecimal-18)) : tokenPurchased.div(10**(18-tokenDecimal)) ;
        }
        require(tokenPurchased <= tokenRemainingForSale,"Exceeding purchase amount");
        
        if(_stableCoin == usdt){
          doTransferIn(address(_stableCoin), msg.sender, amount) ;  
        }
        else{
            _stableCoin.transferFrom(msg.sender, address(this), amount);
            
        }
        tokenRemainingForSale = tokenRemainingForSale.sub(tokenPurchased);
        _updateVestingSchedule(msg.sender, tokenPurchased);
        
        emit TokenPurchase(msg.sender,amount,tokenPurchased,_stableCoin,tokenRemainingForSale);
    }
    
    function _updateVestingSchedule(address _investor, uint256 _amount) internal {
        require(_investor != address(0), "Beneficiary cannot be empty");
        require(_amount > 0, "Amount cannot be empty");

        vestedAmount[_investor] =  vestedAmount[_investor].add(_amount);
    }
    
    /**
     * @notice Vesting schedule and associated data for an investor
     * @return _amount
     * @return _totalDrawn
     * @return _lastDrawnAt
     * @return _remainingBalance
     * @return _availableForDrawDown
     */
    function vestingScheduleForBeneficiary(address _investor)
    external view
    returns (uint256 _amount, uint256 _totalDrawn, uint256 _lastDrawnAt, uint256 _remainingBalance, uint256 _availableForDrawDown) {
        return (
        vestedAmount[_investor],
        totalDrawn[_investor],
        lastDrawnAt[_investor],
        vestedAmount[_investor].sub(totalDrawn[_investor]),
        _availableDrawDownAmount(_investor)
        );
    }

     /**
     * @notice Draw down amount currently available (based on the block timestamp)
     * @param _investor beneficiary of the vested tokens
     * @return _amount tokens due from vesting schedule
     */
    function availableDrawDownAmount(address _investor) external view returns (uint256 _amount) {
        return _availableDrawDownAmount(_investor);
    }
    
    function _availableDrawDownAmount(address _investor) internal view returns (uint256 _amount) {
        
        // Cliff Period
        if (_getNow() <= vestingStart.add(cliffDuration) || vestingStart == 0) {
            // the cliff period has not ended, no tokens to draw down
            return 0;
        }

        // Schedule complete
        if (_getNow() > vestingEnd) {
            return vestedAmount[_investor].sub(totalDrawn[_investor]);
        }

        // Schedule is active

        // Work out when the last invocation was
        uint256 timeLastDrawnOrStart = lastDrawnAt[_investor] == 0 ? vestingStart : lastDrawnAt[_investor];

        // Find out how much time has past since last invocation
        uint256 timePassedSinceLastInvocation = _getNow().sub(timeLastDrawnOrStart);

        // Work out how many due tokens - time passed * rate per second
        uint256 drawDownRate = vestedAmount[_investor].div(vestingEnd.sub(vestingStart));
        uint256 amount = timePassedSinceLastInvocation.mul(drawDownRate);

        return amount;
    }

    /**
     * @notice Draws down any vested tokens due
     * @dev Must be called directly by the investor assigned the tokens in the schedule
     */
    function drawDown() nonReentrant isCrowdsaleOver external{
        _drawDown(msg.sender);
    }
    
    function _drawDown(address _investor) internal {
        require(vestedAmount[_investor] > 0, "There is no schedule currently in flight");

        uint256 amount = _availableDrawDownAmount(_investor);
        require(amount > 0, "No allowance left to withdraw");

        // Update last drawn to now
        lastDrawnAt[_investor] = _getNow();

        // Increase total drawn amount
        totalDrawn[_investor] = totalDrawn[_investor].add(amount);

        // Safety measure - this should never trigger
        require(
            totalDrawn[_investor] <= vestedAmount[_investor],
            "Safety Mechanism - Drawn exceeded Amount Vested"
        );

        // Issue tokens to investor
        require(token.transfer(_investor, amount), "Unable to transfer tokens");

        emit DrawDown(_investor, amount,_getNow());
    }

    function _getNow() internal view returns (uint256) {
        return block.timestamp;
    }

    function getContractTokenBalance(IERC20 _token) public view returns (uint256) {
        return _token.balanceOf(address(this));
    }
    
    /**
     * @notice Balance remaining in vesting schedule
     * @param _investor beneficiary of the vested tokens
     * @return _remainingBalance tokens still due (and currently locked) from vesting schedule
    */
    function remainingBalance(address _investor) public view returns (uint256) {
        return vestedAmount[_investor].sub(totalDrawn[_investor]);
    }
    
    function endCrowdsale(uint256 _vestingStartTime,uint256 _vestingEndTime,uint256 _cliffDurationInSecs) external onlyOwner {
        require(crowdsaleEndTime == 0,"Crowdsale would end automatically after endTime");
        crowdsaleEndTime = _getNow();
        require(_vestingStartTime >= crowdsaleEndTime, 'Vesting Start time should be greater or equal to Crowdsale EndTime');
        require(_vestingEndTime > _vestingStartTime.add(_cliffDurationInSecs), 'Vesting End Time should be after the cliffPeriod');

        vestingStart = _vestingStartTime;
        vestingEnd = _vestingEndTime;
        cliffDuration = _cliffDurationInSecs;
        if(tokenRemainingForSale!=0){
            withdrawFunds(token,tokenRemainingForSale);  //when crowdsaleEnds withdraw unsold tokens to the owner
        }
        emit CrowdsaleEndedManually(crowdsaleEndTime);
    }
    
    function withdrawFunds(IERC20 _token, uint256 amount) public isCrowdsaleOver onlyOwner {
        require(getContractTokenBalance(_token) >= amount,"the contract doesnt have tokens");
        
        if (_token == usdt) {
            return doTransferOut(address(_token), msg.sender, amount);
        }

        _token.transfer(msg.sender, amount);
        
        emit FundsWithdrawn(msg.sender,_token,amount);
    }
    
    /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     *  This may revert due to insufficient balance or insufficient allowance.
    */
    function doTransferIn(
        address tokenAddress,
        address from,
        uint256 amount
    ) internal returns (uint256) {
        INonStandardERC20 _token = INonStandardERC20(tokenAddress);
        uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));
        _token.transferFrom(from, address(this), amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {
                    // This is a non-standard ERC-20
                    success := not(0) // set success to true
                }
                case 32 {
                    // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0) // Set `success = returndata` of external call
                }
                default {
                    // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");

        // Calculate the amount that was actually transferred
        uint256 balanceAfter = IERC20(tokenAddress).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter.sub(balanceBefore); // underflow already checked above, just subtract
    }

    /**
     * @dev Performs a transfer out, ideally returning an explanatory error code upon failure tather than reverting.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     */
    function doTransferOut(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        INonStandardERC20 _token = INonStandardERC20(tokenAddress);
        _token.transfer(to, amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {
                    // This is a non-standard ERC-20
                    success := not(0) // set success to true
                }
                case 32 {
                    // This is a complaint ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0) // Set `success = returndata` of external call
                }
                default {
                    // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }

}
