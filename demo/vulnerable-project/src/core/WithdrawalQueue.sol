// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title WithdrawalQueue
/// @notice Records exit requests and enforces the cooldown before assets move.
/// @dev This contract is pure bookkeeping — it never holds or moves tokens.
///      The vault is the only account permitted to write to it.
///
///      Invariants:
///        - A request is settled at most once (`settled` is monotonic).
///        - A request settles only at or after `unlockAt`.
///        - Only the recorded `account` can settle its own request.
contract WithdrawalQueue {
    struct Request {
        address account;
        uint256 assets;
        uint64 unlockAt;
        bool settled;
    }

    /// @notice The vault permitted to enqueue and settle.
    address public immutable vault;

    /// @notice Delay between requesting an exit and being able to complete it.
    uint64 public immutable cooldown;

    /// @notice All requests ever created, indexed by id.
    Request[] private _requests;

    error NotVault();
    error UnknownRequest(uint256 id);
    error NotRequestOwner(uint256 id);
    error AlreadySettled(uint256 id);
    error StillLocked(uint256 id, uint64 unlockAt);

    event Enqueued(uint256 indexed id, address indexed account, uint256 assets, uint64 unlockAt);
    event Settled(uint256 indexed id, address indexed account, uint256 assets);

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    constructor(address vault_, uint64 cooldown_) {
        require(vault_ != address(0), "VAULT_ZERO");
        vault = vault_;
        cooldown = cooldown_;
    }

    /// @notice Number of requests created so far.
    function requestCount() external view returns (uint256) {
        return _requests.length;
    }

    /// @notice Read a request by id.
    function requestAt(uint256 id) external view returns (Request memory) {
        if (id >= _requests.length) revert UnknownRequest(id);
        return _requests[id];
    }

    /// @notice Record a new exit request for `account`.
    /// @return id The identifier the account will settle with.
    function enqueue(address account, uint256 assets) external onlyVault returns (uint256 id) {
        uint64 unlockAt = uint64(block.timestamp) + cooldown;
        _requests.push(Request({account: account, assets: assets, unlockAt: unlockAt, settled: false}));
        id = _requests.length - 1;
        emit Enqueued(id, account, assets, unlockAt);
    }

    /// @notice Mark request `id` settled on behalf of `caller`.
    /// @dev Reverts unless `caller` owns the request, the cooldown has elapsed,
    ///      and the request has not been settled before. Returns the amount the
    ///      vault owes so the vault performs the transfer, not this contract.
    function settle(uint256 id, address caller) external onlyVault returns (uint256 assets) {
        if (id >= _requests.length) revert UnknownRequest(id);
        Request storage request = _requests[id];

        if (request.account != caller) revert NotRequestOwner(id);
        if (request.settled) revert AlreadySettled(id);
        if (block.timestamp < request.unlockAt) revert StillLocked(id, request.unlockAt);

        request.settled = true;
        assets = request.assets;

        emit Settled(id, caller, assets);
    }
}
