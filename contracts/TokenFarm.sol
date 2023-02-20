// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    // mapping token address -> staker address -> amount 
    mapping(address => mapping(address => uint256)) public stakingBalance; //币的地址->用户地址->币的数量
    mapping(address => uint256) public uniqueTokensStaked;//用户地址->币的种类数
    mapping(address => address) public tokenPriceFeedMapping;//币->币价地址
    address[] public stakers; //用户地址list
    address[] public allowedTokens;//可存币种地址
    IERC20 public dappToken;
// stakeTokens - DONE!
// unStakeTokens - DONE
// issueTokens - DONE!
// addAllowedTokens - DONE!
// getValue - DONE!

// 100 ETH 1:1 for every 1 ETH, we give 1 DappToken
// 50 ETH and 50 DAI staked, and we want to give a reward of 1 DAPP / 1 DAI

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner 
    {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function issueTokens() public onlyOwner {
        // Issue tokens to all stakers
        for ( 
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ){
            address recipient = stakers[stakersIndex]; //遍历获取用户账户地址
            uint256 userTotalValue = getUserTotalValue(recipient); //获取该地址总质押价值
            dappToken.transfer(recipient, userTotalValue);
        }
    }

    function getUserTotalValue(address _user) public view returns (uint256){
        uint256 totalValue = 0; //遍历一个用户地址在合约中所有拥有的合法代币，
                                //通过getUserSingleTokenValue计算单一代币总值，最后求和
        require(uniqueTokensStaked[_user] > 0, "No tokens staked!");
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ){
            totalValue = totalValue +      
            getUserSingleTokenValue(_user, allowedTokens[allowedTokensIndex]);
        }
        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token) 
    public
    view 
    returns (uint256) {
        if (uniqueTokensStaked[_user] <= 0){
            return 0;
        }
        // price of the token * stakingBalance[_token][user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);//获取目标token价格
        return 
            // 10000000000000000000 ETH
            // ETH/USD -> 10000000000
            // 10 * 100 = 1,000
            (stakingBalance[_token][_user] * price / (10**decimals));//stakingBalance[_token][_user]这个映射获取用户的代币数
    }

    function getTokenValue(address _token) public view returns (uint256, uint256) {
        // priceFeedAddress
        address priceFeedAddress = tokenPriceFeedMapping[_token];//在PriceFeed这个mapping中获取价格机合约地址
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);//通过接口获取合约
        (,int256 price,,,)= priceFeed.latestRoundData();//.latestRoundData()的第二个参数是价格
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    function stakeTokens(uint256 _amount, address _token) public {//质押代币主函数
        require(_amount > 0, "Amount must be more than 0");
        require(tokenIsAllowed(_token), "Token is currently no allowed");//判断代币是否合法
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);//跟新该用户持有不同代币的种数
        stakingBalance[_token][msg.sender] = stakingBalance[_token][msg.sender] + _amount;
        if (uniqueTokensStaked[msg.sender] == 1){ //如果是新用户（第一次质押），则添加用户地址
            stakers.push(msg.sender);
        }
    }
    
    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0 ;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
        // The code below fixes a problem not addressed in the video, where stakers could appear twice
        // in the stakers array, receiving twice the reward.
        if (uniqueTokensStaked[msg.sender] == 0) { //如果用户已经没有代币质押了，则从用户列表中删除
            for (
                uint256 stakersIndex = 0;
                stakersIndex < stakers.length;
                stakersIndex++
            ) {
                if (stakers[stakersIndex] == msg.sender) {
                    stakers[stakersIndex] = stakers[stakers.length - 1];
                    stakers.pop();
                }
            }
        }
    }

    function updateUniqueTokensStaked(address _user, address _token) internal { //更新用户独特代币数量
        if (stakingBalance[_token][_user] <= 0){
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    function addAllowedTokens(address _token) public onlyOwner { 
        allowedTokens.push(_token);
    }

    function tokenIsAllowed(address _token) public view returns (bool) {
        for( uint256 allowedTokensIndex=0; allowedTokensIndex < allowedTokens.length; allowedTokensIndex++){
            if(allowedTokens[allowedTokensIndex] == _token){
                return true;
            }
        }
        return false; 
    }
    
}
