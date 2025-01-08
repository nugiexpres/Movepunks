module Movepunks::Movepunks {
    use std::signer;
    use std::string;
    use std::vector;
    use std::option;
    use std::error;

    // Errors
    const E_CONTRACT_PAUSED: u64 = 1;
    const E_INVALID_MINT_AMOUNT: u64 = 2;
    const E_MAX_SUPPLY_EXCEEDED: u64 = 3;
    const E_MAX_MINT_PER_TX_EXCEEDED: u64 = 4;
    const E_INSUFFICIENT_FUNDS: u64 = 5;
    const E_TOKEN_NOT_FOUND: u64 = 6;

    // Constants
    const BASE_EXTENSION: string = ".json";

    // Resource to manage Movepunks state
    struct MovepunksState has key {
        base_uri: string,
        cost: u64,
        max_supply: u64,
        max_mint_per_tx: u64,
        total_supply: u64,
        paused: bool,
        owner: address,
        token_owners: vector<address>,
    }

    public fun initialize(
        account: &signer,
        max_supply: u64,
        cost: u64,
        max_mint_per_tx: u64,
        base_uri: string
    ) {
        let owner = signer::address_of(account);
        move_to(
            account,
            MovepunksState {
                base_uri,
                cost,
                max_supply,
                max_mint_per_tx,
                total_supply: 0,
                paused: true,
                owner,
                token_owners: vector::empty<address>(),
            }
        );
    }

    public fun mint(account: &signer, state: &mut MovepunksState, amount: u64, payment: u64) {
        assert(!state.paused, E_CONTRACT_PAUSED);
        assert(amount > 0, E_INVALID_MINT_AMOUNT);
        assert(amount <= state.max_mint_per_tx, E_MAX_MINT_PER_TX_EXCEEDED);
        assert(state.total_supply + amount <= state.max_supply, E_MAX_SUPPLY_EXCEEDED);
        assert(payment >= state.cost * amount, E_INSUFFICIENT_FUNDS);

        let sender = signer::address_of(account);
        for _ in 0..amount {
            vector::push_back(&mut state.token_owners, sender);
        }
        state.total_supply = state.total_supply + amount;
    }

    public fun set_paused(account: &signer, state: &mut MovepunksState, pause_state: bool) {
        assert(signer::address_of(account) == state.owner, E_INSUFFICIENT_FUNDS);
        state.paused = pause_state;
    }

    public fun set_base_uri(account: &signer, state: &mut MovepunksState, new_base_uri: string) {
        assert(signer::address_of(account) == state.owner, E_INSUFFICIENT_FUNDS);
        state.base_uri = new_base_uri;
    }

    public fun get_token_owner(state: &MovepunksState, token_id: u64): address {
        assert(token_id < vector::length(&state.token_owners), E_TOKEN_NOT_FOUND);
        vector::borrow(&state.token_owners, token_id)
    }

    public fun token_uri(state: &MovepunksState, token_id: u64): string {
        assert(token_id < vector::length(&state.token_owners), E_TOKEN_NOT_FOUND);
        string::concat_all(vector::pack([
            &state.base_uri,
            &std::string::from_u64(token_id),
            &BASE_EXTENSION,
        ]))
    }
}
