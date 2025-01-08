module Staking::NFTStakingVault {

    use Std::Timestamp;
    use Std::Signer;
    use Std::Option;
    use Std::Vector;

    struct Stake {
        owner: address,
        staked_at: u64,
        last_claimed_at: Option<u64>, // None = belum pernah klaim
    }

    struct Vault has key {
        total_items_staked: u64,
        stakes: vector<(u64, Stake)>, // token_id => Stake
    }

    public fun initialize_vault(account: &signer) {
        move_to(account, Vault {
            total_items_staked: 0,
            stakes: Vector::empty(),
        });
    }

    /// Fungsi untuk staking NFT
    public fun stake(
        account: &signer,
        token_ids: vector<u64>,
        nft_contract: &mut NFTContract,
    ) {
        let vault = borrow_global_mut<Vault>(Signer::address_of(account));
        let sender = Signer::address_of(account);

        // Iterasi melalui token_ids untuk staking
        let len = Vector::length(&token_ids);
        let now = Timestamp::now_seconds();

        for i in 0..len {
            let token_id = Vector::borrow(&token_ids, i);
            assert!(
                NFTContract::owner_of(&nft_contract, *token_id) == sender,
                1 // Error: Anda bukan pemilik NFT
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

    /// Fungsi untuk klaim reward
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

            assert!(stake.owner == sender, 2); // Error: Anda bukan pemilik token
            assert!(is_thursday(now), 3); // Error: Reward hanya bisa diklaim pada hari Kamis

            let staking_period = now - stake.staked_at;

            let reward = calculate_reward(staking_period);
            RewardTokenContract::mint(reward_contract, sender, reward);

            // Update waktu klaim terakhir
            vault.stakes[index].1.last_claimed_at = Option::some(now);
        }
    }

    /// Fungsi untuk menghitung reward
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

    /// Fungsi untuk memeriksa apakah hari ini Kamis
    fun is_thursday(timestamp: u64): bool {
        let day_of_week = (timestamp / (24 * 3600) + 4) % 7; // 0 = Kamis
        day_of_week == 0
    }

    /// Fungsi utilitas untuk menemukan stake dalam vault
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
        assert!(false, 4); // Error: Token tidak ditemukan
    }
}
