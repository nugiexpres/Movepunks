module Movepunks::MovepunksToken {
    use std::signer;
    use std::string;
    use std::vector;
    use std::option;
    use std::error;

    // Errors
    const E_ONLY_CONTROLLER_CAN_MINT: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;

    // Resource to manage token balances and controllers
    struct MovepunksToken has key {
        name: string,
        symbol: string,
        total_supply: u64,
        balances: vector<(address, u64)>,
        controllers: vector<address>,
        owner: address,
    }

    public fun initialize(
        account: &signer,
        name: string,
        symbol: string
    ) {
        let owner = signer::address_of(account);
        move_to(
            account,
            MovepunksToken {
                name,
                symbol,
                total_supply: 0,
                balances: vector::empty(),
                controllers: vector::empty(),
                owner,
            }
        );
    }

    public fun mint(
        account: &signer,
        token: &mut MovepunksToken,
        to: address,
        amount: u64
    ) {
        let sender = signer::address_of(account);
        assert!(is_controller(&token.controllers, sender), E_ONLY_CONTROLLER_CAN_MINT);
        increase_balance(token, to, amount);
        token.total_supply = token.total_supply + amount;
    }

    public fun burn(
        account: &signer,
        token: &mut MovepunksToken,
        from: address,
        amount: u64
    ) {
        let sender = signer::address_of(account);
        assert!(is_controller(&token.controllers, sender) || sender == from, E_ONLY_CONTROLLER_CAN_MINT);
        decrease_balance(token, from, amount);
        token.total_supply = token.total_supply - amount;
    }

    public fun set_controller(
        account: &signer,
        token: &mut MovepunksToken,
        controller: address,
        add: bool
    ) {
        let sender = signer::address_of(account);
        assert!(sender == token.owner, E_ONLY_CONTROLLER_CAN_MINT);

        if (add) {
            vector::push_back(&mut token.controllers, controller);
        } else {
            let index = find_index(&token.controllers, controller);
            if (option::is_some(index)) {
                vector::remove(&mut token.controllers, option::borrow(index).unwrap());
            }
        }
    }

    // Helper function to check if an address is a controller
    public fun is_controller(controllers: &vector<address>, controller: address): bool {
        vector::contains(controllers, controller)
    }

    // Helper function to find index of an address in vector
    public fun find_index(controllers: &vector<address>, controller: address): option::Option<u64> {
        vector::index_of(controllers, controller)
    }

    // Helper function to increase balance
    public fun increase_balance(token: &mut MovepunksToken, to: address, amount: u64) {
        let index = find_index(&token.balances, to);
        if (option::is_some(index)) {
            let idx = option::borrow(index).unwrap();
            let (addr, bal) = &mut token.balances[idx];
            *bal = *bal + amount;
        } else {
            vector::push_back(&mut token.balances, (to, amount));
        }
    }

    // Helper function to decrease balance
    public fun decrease_balance(token: &mut MovepunksToken, from: address, amount: u64) {
        let index = find_index(&token.balances, from);
        if (option::is_some(index)) {
            let idx = option::borrow(index).unwrap();
            let (addr, bal) = &mut token.balances[idx];
            assert!(*bal >= amount, E_INSUFFICIENT_BALANCE);
            *bal = *bal - amount;
        } else {
            assert!(false, E_INSUFFICIENT_BALANCE);
        }
    }
}
