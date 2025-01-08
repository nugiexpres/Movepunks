module Staking::NFTStakingVault {

    use Std::Timestamp;
    use Std::Signer;
    use Std::Option;
    use Std::Vector;
    use Movepunks::NFTContract;
    use MovepunksToken::RewardTokenContract;

    /// Struct to represent a stake, containing the owner's address, staking timestamp, and last claimed timestamp.
    struct Stake {
        owner: address,
        staked_at: u64,
        last_claimed_at: Option<u64>, // None = never claimed
    }

    /// Struct to represent the staking vault.
    struct Vault has key {
        total_items_staked: u64,
        stakes: vector<(u64, Stake)>, // token_id => Stake
    }

    /// Initialize the staking vault for an account.
    public fun initialize_vault(account: &signer) {
        move_to(account, Vault {
            total_items_staked: 0,
            stakes: Vector::empty(),
        });
    }

    /// Stake NFTs by transferring them to the vault.
    public fun stake(
        account: &signer,
        token_ids: vector<u64>,
        nft_contract: &mut NFTContract,
    ) {
        let vault = borrow_global_mut<Vault>(Signer::address_of(account));
        let sender = Signer::address_of(account);

        let len = Vector::length(&token_ids);
        let now = Timestamp::now_seconds();

        for i in 0..len {
            let token_id = Vector::borrow(&token_ids, i);
            assert!(
                NFTContract::owner_of(&nft_contract, *token_id) == sender,
                1 // Error: Not the owner of the NFT
            );

            NFTContract::transfer(&mut nft_contract, sender, address_of(vault), *token_id);

            let stake = Stake {
                owner: sender,
                staked_at: now,
                last_claimed_at: Option::none(),
            };

            Vector::push(&mut vault.stakes, (*token_id, stake));
        }

        vault.total_items_staked = vault.total_items_staked + len as u64;
    }

    /// Claim rewards for staked NFTs. Claims can only be made on Thursdays; otherwise, rewards are forfeited.
    public fun claim(
        account: &signer,
        token_ids: vector<u64>,
        reward_contract: &mut RewardTokenContract,
    ) {
        let vault = borrow_global_mut<Vault>(Signer::address_of(account));
        let sender = Signer::address_of(account);
        let now = Timestamp::now_seconds();

        for i in 0..Vector::length(&token_ids) {
            let token_id = Vector::borrow(&token_ids, i);
            let (index, stake) = find_stake(&vault.stakes, *token_id);

            assert!(stake.owner == sender, 2); // Error: Not the owner of the token
            if !is_thursday(now) {
                // If not Thursday, forfeit the reward by removing the stake
                Vector::remove(&mut vault.stakes, index);
                NFTContract::transfer(&mut nft_contract, address_of(vault), sender, *token_id);
                continue;
            }

            let staking_period = now - stake.staked_at;

            let reward = calculate_reward(staking_period);
            RewardTokenContract::mint(reward_contract, sender, reward);

            // Update the last claimed timestamp
            vault.stakes[index].1.last_claimed_at = Option::some(now);
        }
    }

    /// Calculate the daily staking reward based on the staking period.
    fun calculate_reward(staking_period: u64): u64 {
        if staking_period <= 30 * 24 * 3600 {
            1
        } else if staking_period < 90 * 24 * 3600 {
            2
        } else if staking_period < 180 * 24 * 3600 {
            4
        } else {
            8
        }
    }

    /// Check if the current day is Thursday.
    fun is_thursday(timestamp: u64): bool {
        let day_of_week = (timestamp / (24 * 3600) + 4) % 7; // 0 = Thursday
        day_of_week == 0
    }

    /// Utility function to find a stake in the vault.
    fun find_stake(
        stakes: &vector<(u64, Stake)>,
        token_id: u64,
    ): (usize, &mut Stake) {
        let len = Vector::length(stakes);
        for i in 0..len {
            let (id, stake) = Vector::borrow_mut(stakes, i);
            if *id == token_id {
                return (i, stake);
            }
        }
        assert!(false, 4); // Error: Token not found
    }
}

