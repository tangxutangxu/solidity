pragma solidity ^0.4.11;
import "./LoopringToken.sol";
import "./SafeMath.sol";

contract MidIncentive {

    mapping(address => uint) balances;

    // 锁定期限6个月 1个月157553个block,6个月157553*6=945318
    uint public constant BLOCKS_LOCK = 945318;

    // 取款期限9个月 1个月157553个block,9个月157553*9=1417977
    uint public constant BLOCKS_WITHDRAW = 1417977;

    // 兑换比率
    uint public constant RATE = 7500;

    // 最大兑换eth个数
    uint256 public constant MAX_AMOUNT = 10000 ether;

    // 兑换的eth个数
    uint public totalEth = 0;

    // LRC地址
    LoopringToken public LRC;

    // 开始block
    uint public startBlock = 0;

    // 激励计划完成后，余额将打入此账户
    address public owner;

    /*
     * EVENTS
     */

    // Emitted when a function is invocated by unauthorized addresses.
    event InvalidCaller(address caller);

    // Emitted when a function is invocated without the specified preconditions.
    // This event will not come alone with an exception.
    event InvalidState(bytes msg);

    // Emitted for each deposit.
    event Deposit(address attendee, uint ethAmount, uint lrcAmount);

    // Emitted for each withdraw.
    event Withdraw(address attendee, uint ethAmount, uint lrcAmount);

    // Emitted for close.
    event Close();

    /*
     * MODIFIERS
     */

    modifier onlyOwner {
        if (owner == msg.sender) {
            _;
        } else {
            InvalidCaller(msg.sender);
            throw;
        }
    }

    modifier inDepositProgress {
        if (depositDue()) {
            _;
        } else {
            InvalidState("not in depositProgress");
            throw;
        }
    }

    modifier inWithdrawProgress {
        if (withdrawDue()) {
            _;
        } else {
            InvalidState("not in withdrawProgress");
            throw;
        }
    }

    modifier afterEnd {
        if (incentiveEnded()) {
            _;
        } else {
            InvalidState("incentive is not ended yet");
            throw;
        }
    }

    /**
     * CONSTRUCTOR
     */

    function MidIncentive(address _owner, uint _startBlock, address _LRC) {
        assert(_startBlock <= block.number);
        startBlock = _startBlock;
        owner = _owner;
        LRC = LoopringToken(_LRC);
    }

    // 结束后调用，剩余的 ETH和RLC发送到owner
    function close() public onlyOwner afterEnd {
        if(LRC.balanceOf(this) > 0) {
            LRC.transfer(owner, LRC.balanceOf(this));
        }

        if (this.balance > 0) {
            owner.transfer(this.balance);
        }
        Close();
    }

    function () payable {
      if(msg.sender == owner){
        // 合约所有者存eth，为激励政策准备资金
      } else {
        // 存入ETH，取出LRC
         withdraw(msg.sender);
      }
    }

    function deposit(address attendee, uint lrcAmount) inDepositProgress {
      uint256 ethAmount = lrcAmount/RATE;
      require(checkDeposit(ethAmount));

      totalEth += ethAmount;
      
      LRC.approve(this,lrcAmount);
      LRC.transferFrom(attendee, this, lrcAmount);

      msg.sender.transfer(ethAmount);
      
      Deposit(attendee, ethAmount, lrcAmount);
    }

    function withdraw(address attendee)  payable inWithdrawProgress {
      uint ethAmount = msg.value;
      uint lrcAmount = SafeMath.mul(ethAmount,RATE);

      require(checkWithdraw(attendee, ethAmount));
      
      balances[attendee] -= ethAmount;
      totalEth -= ethAmount;

      LRC.transfer(owner, lrcAmount);
      Withdraw(attendee, ethAmount, lrcAmount);
    }

    /*
     * INTERNAL FUNCTIONS
     */

    function checkDeposit(uint ethAmount) internal constant returns (bool) {
        return totalEth + ethAmount <= MAX_AMOUNT && totalEth + ethAmount > totalEth;
    }

    function checkWithdraw(address attendee, uint ethAmount) internal constant returns (bool) {
        return balances[attendee] - ethAmount >= 0 && balances[attendee] - ethAmount < balances[attendee];
    }

    // @return true if incentive has ended, false otherwise.
    function incentiveEnded() constant returns (bool) {
        return block.number > startBlock + BLOCKS_WITHDRAW;
    }

    // @return true 存款期间
    function depositDue() constant returns (bool) {
        return block.number <= startBlock && totalEth < MAX_AMOUNT;
    }

    // @return true 取款期间
    function withdrawDue() constant returns (bool) {
        return block.number <= startBlock + BLOCKS_WITHDRAW && block.number > startBlock + BLOCKS_LOCK;
    }
}

