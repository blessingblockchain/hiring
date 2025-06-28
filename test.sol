// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    constructor() {
        _setOwner(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(_msgSender());
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }
    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
library SafeMath {
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }
}
abstract contract BaseToken {
    event TokenCreated(
        address indexed owner,
        address indexed token,
        string tokenType,
        uint256 version
    );
}
interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}
interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}
contract Token is IERC20, Ownable, BaseToken {
    using SafeMath for uint256;
    uint256 public constant VERSION = 3;
     struct Stake {
        uint256 amount;
        uint256 lastUpdate;
        uint256 rewardDebt;
    }
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private _isAutomatedMarketMakerPair;
    mapping(address => Stake) public stakes;
    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;
    uint256 private _totalSupply;
    address public feeReceiver;
    uint256 public fee;
    bool private swapping;
    uint256 public swapTokensAtAmount;
    uint256 public stakingPeriod;
    uint256 public totalRewardsDistributed;
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;    
    uint256 public rewardRate;
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardClaimed(address indexed user, uint256 reward);
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address feeReceiver_,
        address router
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        
        fee = 3;
        swapTokensAtAmount = totalSupply_ * 1 / 1000;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        
        _isAutomatedMarketMakerPair[uniswapV2Pair] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[feeReceiver] = true;
        _isExcludedFromFees[uniswapV2Pair] = true;
        
        uint256 ownerAmount = totalSupply_ * 70 / 100;
        uint256 rewardAmount = totalSupply_ - ownerAmount;
        _mint(owner(), ownerAmount);
        _mint(address(this), rewardAmount);
        stakingPeriod = 30 days;
        rewardRate = ((rewardAmount) / ownerAmount) / stakingPeriod;
        
        if (feeReceiver_ == address(0x0)) return;
        feeReceiver = feeReceiver_;
        emit TokenCreated(owner(), address(this), "base", VERSION);
    }
    function name() public view virtual returns (string memory) {
        return _name;
    }
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(
        address account,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[account][spender];
    }
    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function burn(address account, uint256 amount) public virtual onlyOwner returns(bool) {
        _burn(account, amount);
        return true;
    }
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
}
    function _approve(
        address account,
        address spender,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[account][spender] = amount;
        emit Approval(account, spender, amount);
    }
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual  {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        if(amount == 0) {
            emit Transfer(sender, recipient, amount);
        }
     
        uint256 contractTokenBalance = balanceOf(address(this));
        
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
        if( 
            canSwap &&
            !swapping &&
            !_isAutomatedMarketMakerPair[sender] &&
            !_isExcludedFromFees[sender] &&
            !_isExcludedFromFees[recipient]
        ) {
            swapping = true;
            
            swapTokensForEth(swapTokensAtAmount);
            swapping = false;
        }
        
        bool takeFee = !swapping;
        if(_isExcludedFromFees[sender] || _isExcludedFromFees[recipient]) {
            takeFee = false;
        }
        
        uint256 fees = 0;
        if(takeFee){
            fees = amount * fee / 100;
            
            if(fees > 0){
            _balances[sender] = _balances[sender].sub(fees, "ERC20: transfer amount exceeds balance");
            _balances[address(this)] = _balances[address(this)] + fees;   
            emit Transfer(sender, address(this), fees); 
            }
        }
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient] + amount;   
        emit Transfer(sender, recipient, amount);
    }
    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);    
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            feeReceiver,
            block.timestamp
        );   
    }
    function stake(address stakingToken, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        Stake storage userStake = stakes[msg.sender];
        if (userStake.amount > 0) {
            userStake.rewardDebt += calculateReward(msg.sender);
        }
        IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);
        userStake.amount = _amount;
        userStake.lastUpdate = block.timestamp;
        emit Staked(msg.sender, _amount);
    }
    function withdraw() external {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake to withdraw");
        uint256 reward = claimReward(msg.sender);
        uint256 stakedAmount = userStake.amount;
        userStake.amount = 0;
        userStake.lastUpdate = 0;
        transfer(msg.sender, stakedAmount);
        emit Withdrawn(msg.sender, stakedAmount, reward);
    }
    function calculateReward(address _user) public view returns (uint256) {
        Stake memory userStake = stakes[_user];
        if (userStake.amount == 0) return 0;
        uint256 stakingDuration = block.timestamp - userStake.lastUpdate;
        if (stakingDuration > stakingPeriod) {
            stakingDuration = stakingPeriod;
        }
        uint256 reward = userStake.amount * stakingDuration * rewardRate;
        return reward;
    }
    function claimReward(address _user) public returns (uint256) {
        Stake storage userStake = stakes[_user];
        if (userStake.amount == 0) return 0;
        uint256 reward = calculateReward(_user) + userStake.rewardDebt;
        if (reward + totalRewardsDistributed > balanceOf(address(this))) {
            reward = balanceOf(address(this)) - totalRewardsDistributed;
        }
        if (reward > 0) {
            totalRewardsDistributed += reward;
            userStake.rewardDebt = 0;
            transfer(_user, reward);
            emit RewardClaimed(_user, reward);
        }
        return reward;
    }
}
