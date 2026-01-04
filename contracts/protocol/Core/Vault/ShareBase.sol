// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

//适配最小代理合约的ERC20
abstract contract ShareBase {

    string public name;
    string public symbol;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    bool internal _sharesInited;

    function _initShares(
        string memory _name,
        string memory _symbol
    ) internal {
        require(!_sharesInited, "ShareBase: already inited");
        _sharesInited = true;

        name = _name;
        symbol = _symbol;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            require(a >= amount, "ShareBase: allowance");
            unchecked { allowance[from][msg.sender] = a - amount; }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function decimals() public view returns (uint256) {
        return 18;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "ShareBase: to=0");
        uint256 bal = balanceOf[from];
        require(bal >= amount, "ShareBase: balance");
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ShareBase: mint to=0");
        totalSupply += amount;
        unchecked { balanceOf[to] += amount; }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        require(bal >= amount, "ShareBase: burn>bal");
        unchecked { balanceOf[from] = bal - amount; }
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}