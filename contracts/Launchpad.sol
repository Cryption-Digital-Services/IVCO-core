// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

abstract contract Context {
    function _msgSender() internal virtual view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal virtual view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// import ierc20 & safemath & non-standard
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

contract Crowdsale  {
    using SafeMath for uint256;

    address public owner;
    
    uint256 public rate;
    bool public crowdsaleOver;
    IERC20 public token;
    mapping(address => uint256) public claimable;
    IERC20 private usdc = IERC20(0xb7a4F3E9097C08dA09517b5aB877F7a917224ede);
    IERC20 private dai = IERC20(0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
    IERC20 private usdt = IERC20(0x07de306FF27a2B630B1141956844eB1552B956B5);
    
    /// @notice information stuct on each user than stakes LP tokens.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has invested.
        uint256 lastInvestedTime; // Timestamp when user invested last time.
    }
    
    /// @notice all the settings for this farm in one struct
    struct CrowdsaleInfo {
        IERC20 token;
        uint256 startTime;
        uint256 endTime;
        uint256 cliffDurationInSecs;
    }
    
    CrowdsaleInfo public crowdsaleInfo;

    constructor(uint256 _rate, address _token,address _owner) public {
        rate = _rate;
        token = IERC20(_token);
        crowdsaleOver = false;
        owner = _owner;
    }
    
    /**
     * @notice initialize the Crowdsale contract. This is called only once upon Crowdsale creation and the Launchpad ensures the Crowdsale has the correct paramaters
     */
    function init (IERC20 _tokenAddress,address _owner, uint256 _amount, uint256 _rate, uint256 _startTime, uint256 _endTime,uint256 _cliffDurationInSecs) public {
        require(msg.sender == address(Launchpad), 'FORBIDDEN');
        
        TransferHelper.safeTransferFrom(address(_tokenAddress), msg.sender, address(this), _amount);
        crowdsaleInfo.token = _tokenAddress;
        
        crowdsaleInfo.startTime = _startTime;
        crowdsaleInfo.endTime = _endTime;
        
        crowdsaleInfo.cliffDurationInSecs = _cliffDurationInSecs;
    }


    modifier iscrowdsaleOver() {
        require(crowdsaleOver == true, "Crowdsale is ongoing");
        _;
    }

    function endCrowdsale() external onlyOwner {
        crowdsaleOver = true;
    }
    
    function buyTokenWithStableCoin(IERC20 _stableCoin, uint256 amount)
        external
    {
        require(crowdsaleOver == false, "Crowdsale has ended,invest in other crowdsale");

        if (_stableCoin == usdt) {
            claimable[msg.sender] = claimable[msg.sender].add(
                amount.mul(1e12).mul(rate).div(1e18)
            );
            doTransferIn(address(_stableCoin), msg.sender, amount);
        } else if (_stableCoin == usdc) {
            claimable[msg.sender] = claimable[msg.sender].add(
                amount.mul(1e12).mul(rate).div(1e18)
            );
            _stableCoin.transferFrom(msg.sender, address(this), amount);
        } else if (_stableCoin == dai) {
            
            claimable[msg.sender] = claimable[msg.sender].add(
                amount.mul(rate).div(1e18)
            );
            _stableCoin.transferFrom(msg.sender, address(this), amount);
        }
    }

    function claim() external iscrowdsaleOver {
        // it checks for user msg.sender claimable amount and transfer them to msg.sender
        require(claimable[msg.sender] > 0, "NO tokens left to be claim");
        token.transfer(msg.sender, claimable[msg.sender]);
        claimable[msg.sender] = 0;
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function adminTransferEthFund() external onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function getContractTokenBalance(IERC20 _token)
        public
        view
        returns (uint256)
    {
        return _token.balanceOf(address(this));
    }

    function fundsWithdrawal(IERC20 _token, uint256 value) external onlyOwner {
        require(
            getContractTokenBalance(_token) >= value,
            "the contract doesnt have tokens"
        );
        if (_token == usdt) {
            return doTransferOut(address(_token), msg.sender, value);
        }

        _token.transfer(msg.sender, value);
    }

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
     * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
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
    
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
}


contract LaunchpadFactory is Ownable{
    Crowdsale[] public crowdsaleContract;
    
    
    uint256 public Launchpadcount;

    mapping(uint256 => mapping(address => Crowdsale)) public crowdsaleContracts;

    event CrowdsaleEvent(uint256 count, address manager, Crowdsale crowdsaleContract);
    
    function _preValidateAddress(address _addr)
        internal pure
      {
        require(_addr != address(0),'Cant be Zero address');
      }
      
    /**
     * @notice Creates a new Crowdsale contract and registers it in the LaunchpadFactory
     * All invested amount would be accumulated in the Crowdsale Contract
     */
    function launchCrowdsale (IERC20 _tokenAddress, uint256 _amountAllocation,address _owner,uint256 _rate, uint256 _startTime, uint256 _endTime, uint256 _cliffDurationInSecs) public returns (address){
        require(_startTime >= block.timestamp, 'START'); // ideally at least 24 hours more to give investors time
        require(_amountAllocation > 0, 'Allocate some amount to start Crowdsale');
        require(address(_tokenAddress) != address(0), 'Invalid Token address');
        require(_rate > 0, 'Rate cannot be Zero'); 

        TransferHelper.safeTransferFrom(address(_tokenAddress), address(msg.sender), address(this), params.requiredAmount);
        Crowdsale newCrowdsale = new Crowdsale();
        TransferHelper.safeApprove(address(_rewardToken), address(newFarm), params.requiredAmount);
        newCrowdsale.init(_tokenAddress, _amountAllocation,_owner,_rate, _startTime,_endTime, _cliffDurationInSecs);
        
        factory.registerCrowdsale(address(newCrowdsale));
        return (address(newCrowdsale));
    }
    
    
    // function createLaunchpad(
    //     uint256 _rate,
    //     address _token,
    //     address _owner
    // ) public onlyOwner{
    //     require(_rate > 0);
    //     _preValidateAddress(_token);
        
    //     Crowdsale newlaunchpad = new Launchpad(
    //       _rate,
    //       _token,
    //       _owner
    //     );
    //     launchpad.push(newlaunchpad);
    //     launchpads[Launchpadcount][msg.sender] = newlaunchpad;
    //     Launchpadcount++;
    //     emit launchpadevents(Launchpadcount, msg.sender, newlaunchpad);
    // }
    
    
}