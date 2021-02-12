// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import "./Crowdsale.sol";

contract LaunchpadFactory {

    using SafeMath for uint256;
    
    /// @notice all the information for this crowdsale in one struct
    struct CrowdsaleInfo {
        address crowdsaleAddress;
        IERC20 tokenAddress;
        address owner;
    }
    
    CrowdsaleInfo[] public crowdsales;  //creating a variable requests of type array which will hold value in format that of Request 
    
    uint256 public crowdsaleIndex;

    event CrowdsaleLaunched(uint256 indexed crowdsaleIndex,address indexed crowdsaleAddress,IERC20 token, uint256 indexed crowdsaleStartTime);
    
    function _preValidateAddress(IERC20 _addr)
        internal pure
      {
        require(address(_addr) != address(0),'Cant be Zero address');
      }
      
    /**
     * @notice Creates a new Crowdsale contract and registers it in the LaunchpadFactory
     * All invested amount would be accumulated in the Crowdsale Contract
     */
    function launchCrowdsale (IERC20 _tokenAddress, uint256 _amountAllocation,address _owner,uint256 _rate,uint256 _crowdsaleStartTime,uint256 _crowdsaleEndTime, uint256 _vestingStartTime, uint256 _vestingEndTime, uint256 _cliffDurationInSecs) public returns (address){
        _preValidateAddress(_tokenAddress);
        require(_crowdsaleStartTime >= block.timestamp, 'Crowdsale Start time should be greater than current time'); // ideally at least 24 hours more to give investors time
        require(_crowdsaleEndTime > _crowdsaleStartTime || _crowdsaleEndTime == 0, 'Crowdsale End Time can either be greater than _crowdsaleStartTime or 0');  //_crowdsaleEndTime = 0 means crowdsale would be concluded manually by owner
        require(_amountAllocation > 0, 'Allocate some amount to start Crowdsale');
        require(address(_tokenAddress) != address(0), 'Invalid Token address');
        require(_rate > 0, 'Rate cannot be Zero'); 
        
                
        if(_crowdsaleEndTime == 0){ // vesting Data would be 0 & can be set when crowdsale is ended manually by owner to avoid confusion
            _vestingStartTime = 0;
            _vestingEndTime = 0;
            _cliffDurationInSecs = 0;
        }
        else if(_crowdsaleEndTime >_crowdsaleStartTime){
            require(_vestingStartTime >= _crowdsaleEndTime, 'Vesting Start time should be greater or equal to Crowdsale EndTime');
            require(_vestingEndTime > _vestingStartTime.add(_cliffDurationInSecs), 'Vesting End Time should be after the cliffPeriod');
        }
        
        TransferHelper.safeTransferFrom(address(_tokenAddress), address(msg.sender), address(this), _amountAllocation);
        Crowdsale newCrowdsale = new Crowdsale(_owner,address(this));
        TransferHelper.safeApprove(address(_tokenAddress), address(newCrowdsale), _amountAllocation);
        newCrowdsale.init(_tokenAddress, _amountAllocation,_rate,_crowdsaleStartTime,_crowdsaleEndTime, _vestingStartTime,_vestingEndTime, _cliffDurationInSecs);
                        
       CrowdsaleInfo memory newCrowdsaleInfo=CrowdsaleInfo({     //creating a variable newCrowdsaleInfo which will hold value in format that of CrowdsaleInfo 
            crowdsaleAddress : address(newCrowdsale),   //setting the value of keys as being passed by crowdsale deployer during the function call
            tokenAddress:_tokenAddress,
            owner:_owner
        });
        crowdsales.push(newCrowdsaleInfo);  //stacking up every crowdsale info ever made to crowdsales variable
       
        emit CrowdsaleLaunched(crowdsaleIndex,address(newCrowdsale),_tokenAddress,_crowdsaleStartTime);
        crowdsaleIndex++;
    }
    
    
}